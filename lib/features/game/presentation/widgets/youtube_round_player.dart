import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';

/// The DJ's embedded YouTube player of a youtube_embed round (wave 4)
/// [новое имя — согласовать]: the official player, full width at 16:9,
/// fully visible above the round's scrolling content and never under
/// anything.
///
/// It reads the live game state rather than a snapshot, so the player is
/// disposed in the very frame the round leaves play (reveal, void, pause,
/// ad break). Its width comes from the parent (`RoundScreen.playerLayoutFor`):
/// the full screen width in portrait (no gutter), the left pane in
/// landscape, zero when the window is too small for a legal player.
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
        // Below the YouTube 200 px floor (the round layout gave no room):
        // no player; the round body shows the cue until the window grows.
        if (size == null) return const SizedBox.shrink();
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
    // Nothing may float over the player: drop any SnackBar left from an
    // earlier screen (e.g. the lobby) once the player is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
    });
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

/// The short consent card shown in place of the player before it may load
/// (EU/EEA or region unknown, YouTube III.E.4.i). No player exists yet, so
/// it is an ordinary card in the round's list.
class YouTubeConsentCard extends ConsumerWidget {
  const YouTubeConsentCard({super.key, required this.roundId});

  final String roundId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final controller = ref.read(gameControllerProvider.notifier);
    return PartyCard(
      key: const ValueKey('youtube-consent'),
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.privacy_tip_rounded,
                  color: scheme.primary,
                  size: IconSizes.lg,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.gameYouTubeConsentTitle,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.gameYouTubeConsentBody,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: Spacing.lg),
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
    );
  }
}
