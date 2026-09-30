import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';

/// The DJ's embedded YouTube player of a youtube_embed round (wave 4)
/// [новое имя — согласовать]: the official player, full width at 16:9,
/// fully visible above the round's scrolling content and never under
/// anything.
///
/// It reads the live game state rather than a snapshot, so the player is
/// disposed in the very frame the round leaves play (reveal, void, pause,
/// ad break), even while the old screen is still fading out.
class DjVideoSlot extends ConsumerWidget {
  const DjVideoSlot({super.key, required this.roundId});

  final String roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stage = ref.watch(
      gameControllerProvider.select(
        (s) => s is GameRoundState && s.round.roundId == roundId
            ? s.djVideo
            : null,
      ),
    );
    if (stage is! DjVideoPlayer) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final minWidth = controller.youTubePlayerMinWidthDp;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = youTubePlayerSize(
          constraints.maxWidth,
          minWidthDp: minWidth,
        );
        if (size == null) {
          // Below the YouTube 200 px floor: the cue instead.
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => controller.youTubePlayerUnavailable(roundId),
          );
          return const SizedBox.shrink();
        }
        return SizedBox.fromSize(
          size: size,
          child: YouTubeRoundPlayer(
            key: ValueKey('youtube-$roundId-${stage.videoId}'),
            roundId: roundId,
            videoId: stage.videoId,
            startS: stage.startS,
          ),
        );
      },
    );
  }
}

/// Owns one [YouTubeEmbedPlayer]: created when shown, disposed when it
/// leaves the tree or the app goes to the background (no background play),
/// recreated when the app comes back. Player errors go to the controller,
/// which reports them and moves on to the next video or the cue.
class YouTubeRoundPlayer extends ConsumerStatefulWidget {
  const YouTubeRoundPlayer({
    super.key,
    required this.roundId,
    required this.videoId,
    required this.startS,
  });

  final String roundId;
  final String videoId;
  final int startS;

  @override
  ConsumerState<YouTubeRoundPlayer> createState() => _YouTubeRoundPlayerState();
}

class _YouTubeRoundPlayerState extends ConsumerState<YouTubeRoundPlayer>
    with WidgetsBindingObserver {
  YouTubeEmbedPlayer? _player;
  StreamSubscription<YouTubePlayerEvent>? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  void _create() {
    if (_player != null) return;
    final controller = ref.read(gameControllerProvider.notifier);
    final player = ref
        .read(youTubePlayerFactoryProvider)
        .create(
          YouTubePlayerSpec(
            videoId: widget.videoId,
            startS: widget.startS,
            origin: controller.youTubePlayerOrigin,
            interfaceLanguage:
                WidgetsBinding.instance.platformDispatcher.locale.languageCode,
          ),
        );
    _player = player;
    _events = player.events.listen(_onEvent);
  }

  void _onEvent(YouTubePlayerEvent event) {
    switch (event) {
      case YouTubePlayerFailed(:final code):
        ref
            .read(gameControllerProvider.notifier)
            .youTubeVideoFailed(
              roundId: widget.roundId,
              videoId: widget.videoId,
              code: code,
            );
      case YouTubePlayerStateChanged(:final state):
        // Diagnostics only: pre-roll ads make player states useless for
        // timing (the start is the DJ's tap).
        if (kDebugMode) debugPrint('[youtube] ${widget.videoId}: $state');
      case YouTubePlayerReady():
        break;
    }
  }

  void _release() {
    final player = _player;
    _player = null;
    unawaited(_events?.cancel());
    _events = null;
    if (player != null) unawaited(player.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_player == null) setState(_create);
      case AppLifecycleState.hidden ||
          AppLifecycleState.paused ||
          AppLifecycleState.detached:
        if (_player != null) setState(_release);
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = _player;
    return ColoredBox(
      color: Colors.black,
      child: player == null
          ? const SizedBox.expand()
          : player.buildView(context),
    );
  }
}

/// The short consent sheet shown in place of the player before it may load
/// (EU/EEA or region unknown, YouTube III.E.4.i).
class YouTubeConsentCard extends ConsumerWidget {
  const YouTubeConsentCard({super.key, required this.roundId});

  final String roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final controller = ref.read(gameControllerProvider.notifier);
    return Card(
      key: const ValueKey('youtube-consent'),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.gameYouTubeConsentTitle,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: Spacing.xs),
            Text(
              l10n.gameYouTubeConsentBody,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: Spacing.md),
            FilledButton(
              key: const ValueKey('youtube-consent-allow'),
              onPressed: () => controller.youTubeConsentAnswered(
                roundId: roundId,
                granted: true,
              ),
              child: Text(l10n.gameYouTubeConsentAllow),
            ),
            const SizedBox(height: Spacing.xs),
            TextButton(
              key: const ValueKey('youtube-consent-decline'),
              onPressed: () => controller.youTubeConsentAnswered(
                roundId: roundId,
                granted: false,
              ),
              child: Text(l10n.gameYouTubeConsentDecline),
            ),
          ],
        ),
      ),
    );
  }
}
