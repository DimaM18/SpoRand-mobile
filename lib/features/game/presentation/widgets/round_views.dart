import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/equalizer_bars.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/answer_grid.dart';
import 'package:sporand/features/game/presentation/widgets/emoji_puzzle.dart';
import 'package:sporand/features/game/presentation/widgets/youtube_round_player.dart';

/// The question of a round. A text round (provider `none`) keeps the room
/// mode's question.
String promptText(
  AppLocalizations l10n,
  RoundPrompt prompt, [
  GameMode? mode,
]) => switch (prompt) {
  RoundPrompt.whoseSong => l10n.gamePromptWhoseSong,
  RoundPrompt.guessTrack => l10n.gamePromptGuessTrack,
  RoundPrompt.textRound => switch (mode) {
    GameMode.guessTrack => l10n.gamePromptGuessTrack,
    GameMode.whoseSong ||
    GameMode.emojiQuiz ||
    null => l10n.gamePromptWhoseSong,
  },
  RoundPrompt.emojiRound => l10n.gamePromptEmoji,
};

/// Why a round was voided, or null when the server gave no known reason.
String? voidReasonText(AppLocalizations l10n, RoundVoidReason reason) =>
    switch (reason) {
      RoundVoidReason.playbackTimeout ||
      RoundVoidReason.playbackFailed => l10n.gameVoidedPlayback,
      RoundVoidReason.hostDisconnected => l10n.gameVoidedHost,
      RoundVoidReason.serverRestart => l10n.gameVoidedServer,
      RoundVoidReason.unknown => null,
    };

/// «Раунд пропущен: <причина>» (the reason starts lower-case after the
/// colon).
String voidNoticeText(AppLocalizations l10n, RoundVoidReason reason) {
  final text = voidReasonText(l10n, reason);
  if (text == null || text.isEmpty) return l10n.gameVoidedNoticeNoReason;
  return l10n.gameVoidedNotice(
    text.substring(0, 1).toLowerCase() + text.substring(1),
  );
}

class RoundHeader extends StatelessWidget {
  const RoundHeader({super.key, required this.round});

  final RoundView round;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          l10n.gameRoundOf(round.number, round.roundsTotal),
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        if (round.isBonus)
          Chip(
            avatar: const Icon(Icons.star_rounded, size: 18),
            label: Text(l10n.gameBonusRound),
          ),
      ],
    );
  }
}

/// A round in progress: prompt, listening indicator (or the song card of a
/// text round), then the answers, the owner's card or the DJ's cards, and
/// the answered counter.
class RoundScreen extends StatelessWidget {
  const RoundScreen({super.key, required this.state});

  final GameRoundState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final round = state.round;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final djName = round.djName;
    final status = switch (state.phase) {
      RoundLocked() when round.isTextRound || round.isEmojiRound =>
        l10n.gameTextRoundLocked,
      RoundLocked() when round.waitsForDj =>
        djName == null ? l10n.gameDjStarting : l10n.gameDjStartingNamed(djName),
      RoundLocked() => l10n.gameListen,
      RoundOpen() => l10n.gameTapFast,
      RoundAnswered(:final ack, :final rejection) => switch (ack) {
        AnswerAckStatus.pending => l10n.gameAnswerSent,
        AnswerAckStatus.accepted => l10n.gameAnswerAccepted,
        AnswerAckStatus.rejected
            when rejection == AnswerValidation.djIneligible =>
          l10n.gameAnswerRejectedDj,
        AnswerAckStatus.rejected => l10n.gameAnswerRejected,
      },
      RoundTimeUp() => l10n.gameTimeUp,
      RoundOwnerWatching() => l10n.gameYourTrackHint,
      RoundDjCue() => switch (state.djVideo) {
        DjVideoPlayer() => l10n.gameYouTubeTapWhenPlaying,
        _ => l10n.gameDjCueSecret,
      },
      RoundDjWatching() => l10n.gameDjWatchingHint,
    };
    final textPrompt = round.textPrompt;
    final emojiPrompt = round.emojiPrompt;
    final voidNotice = state.voidNotice;
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.xl,
      ),
      children: [
        RoundHeader(round: round),
        const SizedBox(height: Spacing.md),
        Text(
          promptText(l10n, round.prompt, round.mode),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.md),
        if (round.isTextRound) ...[
          Text(
            l10n.gameTextRoundHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (textPrompt != null) ...[
            const SizedBox(height: Spacing.sm),
            SongCard(title: textPrompt.title, artists: textPrompt.artists),
          ],
        ] else if (emojiPrompt != null)
          Center(
            child: EmojiPuzzle(
              key: ValueKey('emoji-puzzle-${round.roundId}'),
              emoji: emojiPrompt.emoji,
              revealed: state.phase is! RoundLocked,
            ),
          )
        else
          Center(
            child: EqualizerBars(
              animate:
                  animate &&
                  state.phase is! RoundAnswered &&
                  state.phase is! RoundDjCue,
              width: 120,
              height: 36,
            ),
          ),
        const SizedBox(height: Spacing.xs),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: Spacing.lg),
        if (state.phase is RoundDjCue) ...[
          ..._djCue(context, state),
          if (!round.djMayAnswer) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.gameDjRoundNoAnswer,
              key: const ValueKey('dj-no-answer'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ] else if (state.showsButtons)
          AnswerGrid(state: state)
        else if (round.youAreOwner)
          const _OwnerCard()
        else
          const _DjWatchingCard(),
        if (state.eligibleCount > 0) ...[
          const SizedBox(height: Spacing.md),
          Text(
            l10n.gameProgress(state.answeredCount, state.eligibleCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        if (state.airplayWarning) ...[
          const SizedBox(height: Spacing.md),
          Text(
            l10n.gameAirplayWarning,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
    // Over the round, not in its layout: when the notice goes, nothing moves
    // under the player's finger.
    final body = Stack(
      children: [
        list,
        if (voidNotice != null)
          Positioned(
            top: Spacing.xs,
            left: Spacing.lg,
            right: Spacing.lg,
            child: VoidNoticeBanner(text: voidNoticeText(l10n, voidNotice)),
          ),
      ],
    );
    if (!round.isDj || round.video == null) return body;
    // youtube_embed DJ: the official player sits above the scrolling
    // content, full width and fully visible; nothing (not even the void
    // notice) is ever drawn over it.
    return Column(
      children: [
        DjVideoSlot(roundId: round.roundId),
        Expanded(child: body),
      ],
    );
  }

  /// The DJ's part of a round they have not started yet: the consent sheet,
  /// the player's «Музыка играет!» button, or the BYOP cue card.
  static List<Widget> _djCue(BuildContext context, GameRoundState state) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final round = state.round;
    Widget note(String text) => Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Text(
        text,
        key: const ValueKey('youtube-note'),
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
    );
    return switch (state.djVideo) {
      null => [DjCueCard(round: round)],
      DjVideoConsent() => [YouTubeConsentCard(roundId: round.roundId)],
      DjVideoPlayer() => [
        note(l10n.gameYouTubePressPlay),
        DjMusicPlayingButton(round: round),
      ],
      DjVideoCueFallback(:final reason) => [
        note(
          reason == VideoPlaybackFailureReason.consentDeclined
              ? l10n.gameYouTubeDeclined
              : l10n.gameYouTubeFallback,
        ),
        DjCueCard(round: round),
      ],
    };
  }
}

/// «Раунд пропущен: <причина>» over a spare round. It ignores pointers, so
/// it never blocks the answers under it.
class VoidNoticeBanner extends StatelessWidget {
  const VoidNoticeBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Material(
          key: const ValueKey('void-notice'),
          color: scheme.inverseSurface,
          elevation: 3,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(Icons.replay_rounded, color: scheme.onInverseSurface),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(color: scheme.onInverseSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A generated song card: title and artists only. Never artwork or a
/// provider logo (A2.3: cover images are not cleared).
class SongCard extends StatelessWidget {
  const SongCard({super.key, required this.title, required this.artists});

  final String title;
  final List<String> artists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Icon(Icons.music_note_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    artists.join(', '),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The DJ's card (external_player, A2.2): the song to start in their own
/// music app, a hand-off button, and «Музыка играет!». Only the DJ gets the
/// cue, so only the DJ sees the title before the reveal.
///
/// «Музыка играет!» is a [Listener]: `onPointerDown` carries the OS touch
/// time, which becomes `audio_start_mono_us` (through the process anchor)
/// with `source: dj_tap`. `onTap` would fire only when the finger lifts.
class DjCueCard extends ConsumerWidget {
  const DjCueCard({super.key, required this.round});

  final RoundView round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cue = round.cue;
    if (cue == null) return const SizedBox.shrink();
    final controller = ref.read(gameControllerProvider.notifier);
    final canOpen = ref.read(musicAppLauncherProvider).canOpen(cue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.gameDjCueTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: Spacing.sm),
        SongCard(title: cue.title, artists: cue.artists),
        if (canOpen) ...[
          const SizedBox(height: Spacing.sm),
          OutlinedButton.icon(
            key: const ValueKey('dj-open-app'),
            onPressed: () async {
              final opened = await controller.openCueInMusicApp();
              if (opened || !context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(l10n.gameDjOpenAppFailed)),
                );
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.gameDjOpenApp),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        DjMusicPlayingButton(round: round),
      ],
    );
  }
}

/// «Музыка играет!» (BYOP and youtube_embed DJ): a [Listener], because
/// `onPointerDown` carries the OS touch time, which becomes
/// `audio_start_mono_us` (through the process anchor) with
/// `source: dj_tap`; `onTap` would fire only when the finger lifts. In a
/// youtube_embed round it sits below the player, never on it.
class DjMusicPlayingButton extends ConsumerWidget {
  const DjMusicPlayingButton({super.key, required this.round});

  final RoundView round;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final controller = ref.read(gameControllerProvider.notifier);

    void started(int? audioStartMonoUs) {
      final reported = controller.djStarted(
        roundId: round.roundId,
        audioStartMonoUs: audioStartMonoUs,
      );
      if (reported) unawaited(HapticFeedback.mediumImpact());
    }

    return Semantics(
      button: true,
      label: l10n.gameDjMusicPlaying,
      hint: l10n.gameDjMusicPlayingHint,
      excludeSemantics: true,
      // A screen-reader activation has no touch time: the controller
      // reads the input clock instead.
      onTap: () => started(null),
      child: Listener(
        key: const ValueKey('dj-music-playing'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) =>
            started(tapMonoUsFromPointer(controller.inputClock, event)),
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(Spacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: party.gradient),
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: Spacing.xs),
              Text(
                l10n.gameDjMusicPlaying,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                l10n.gameDjMusicPlayingHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «Это твой трек!»: no buttons for the track's owner.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard();

  @override
  Widget build(BuildContext context) => _BannerCard(
    icon: Icons.headphones_rounded,
    title: context.l10n.gameYourTrack,
  );
}

/// The DJ started the song and may not answer this round (dj_ineligible):
/// «Ты DJ этого раунда — отвечают остальные».
class _DjWatchingCard extends StatelessWidget {
  const _DjWatchingCard();

  @override
  Widget build(BuildContext context) => _BannerCard(
    icon: Icons.speaker_rounded,
    title: context.l10n.gameDjRoundNoAnswer,
  );
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    return Container(
      padding: const EdgeInsets.all(Spacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: party.gradient),
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 48),
          const SizedBox(height: Spacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key, required this.state});

  final GameStartingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final seconds = (state.countdownMs / 1000).ceil();
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.gameStartingTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: Spacing.lg),
          // Visual only: the rounds themselves are scheduled by the server.
          TweenAnimationBuilder<double>(
            tween: Tween(begin: seconds.toDouble(), end: 0),
            duration: animate
                ? Duration(milliseconds: state.countdownMs)
                : Duration.zero,
            builder: (context, value, _) => Text(
              '${value.ceil().clamp(1, 99)}',
              style: theme.textTheme.displayLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: Spacing.md),
          Text(l10n.gameStartingRounds(state.roundsTotal)),
        ],
      ),
    );
  }
}

class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.busy = false,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = this.subtitle;
    final icon = this.icon;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 56, color: theme.colorScheme.primary),
            if (busy) ...[
              const SizedBox(height: Spacing.md),
              EqualizerBars(
                animate: !MediaQuery.disableAnimationsOf(context),
                width: 96,
                height: 32,
              ),
            ],
            const SizedBox(height: Spacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: Spacing.xs),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
