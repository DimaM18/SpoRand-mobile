import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
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

/// Whether [state] is the DJ's round of a youtube_embed room, i.e. a screen
/// that may show the embedded YouTube player. That screen is calm: no
/// motion, glow, timer ring, SnackBar, dialog or sheet, and it never fades
/// in or out (`docs/DEVELOPMENT.md` §7, YouTube rules).
/// [новое имя — согласовать]
bool isPlayerRound(GameUiState state) =>
    state is GameRoundState && state.round.isDj && state.round.video != null;

/// «Раунд 3 из 10», the bonus chip and, when the screen shows answers, the
/// answer timer ring.
class RoundHeader extends StatelessWidget {
  const RoundHeader({super.key, required this.round, this.timer});

  final RoundView round;

  /// The [AnswerTimerRing] of this round, when the screen shows one. It is
  /// there from the first frame of the round, so the header never changes
  /// height under the answers.
  final Widget? timer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final timer = this.timer;
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: Spacing.xs,
            runSpacing: Spacing.xxs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.gameRoundOf(round.number, round.roundsTotal),
                style: theme.textTheme.labelLarge?.tabular.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (round.isBonus)
                StatusChip(
                  icon: Icons.star_rounded,
                  label: l10n.gameBonusRound,
                ),
            ],
          ),
        ),
        if (timer != null) ...[const SizedBox(width: Spacing.sm), timer],
      ],
    );
  }
}

/// Where the round's controls go relative to the embedded player.
enum _PlayerLayout {
  /// No player on this screen.
  none,

  /// Player on top (edge-to-edge on a phone), the DJ controls under it.
  portrait,

  /// Player on the left (vertically centred on black), controls and round
  /// in a scrolling side pane.
  landscape,

  /// The window is too small for a legal player right now (split screen,
  /// a tiny window): the DJ gets the cue until it grows. Not a playback
  /// failure, so the player comes back.
  unavailable,
}

/// A round in progress: header, prompt, stage (equalizer, emoji puzzle or
/// the song card of a text round), a fixed-height status line, then the
/// answers, the owner's card or the DJ's cards, and the answered counter.
///
/// youtube_embed DJ (`docs/DEVELOPMENT.md` §7): the official player comes
/// first, 16:9, at least [youTubePlayerFloorWidthDp] wide, fully visible and
/// never under anything; the scrolling body sits below it (portrait) or
/// beside it (landscape) and clips. See [playerLayoutFor].
class RoundScreen extends StatelessWidget {
  const RoundScreen({super.key, required this.state});

  final GameRoundState state;

  /// The side pane next to the player in landscape gets this much when the
  /// window has room for it (note, DJ button, round).
  static const landscapePaneMinWidth = 280.0;

  /// The narrowest side pane in landscape: below it the player goes on top
  /// instead. [новое имя — согласовать]
  static const landscapePaneFloorWidth = 200.0;

  /// Room kept under the player in portrait for the DJ button to start.
  /// [новое имя — согласовать]
  static const portraitControlsMinHeight = TapTargets.answer;

  /// Where the player goes in a [body] of that size and how wide it is, or
  /// null when no legal player fits (the DJ then gets the cue for now).
  ///
  /// Landscape (wider than tall) puts it beside a side pane: as wide as the
  /// height allows, leaving the pane [landscapePaneMinWidth] when there is
  /// room, but never less than the 356 dp floor while the pane keeps
  /// [landscapePaneFloorWidth]. Otherwise it goes on top at full width
  /// (letterboxed when the window is short). Rotation and resizing only
  /// change these numbers, never the widget tree, so the video keeps playing.
  /// [новое имя — согласовать]
  static ({bool landscape, double width})? playerLayoutFor(Size body) {
    const floor = youTubePlayerFloorWidthDp;
    if (body.width > body.height) {
      final width = math.min(
        body.height * 16 / 9,
        math.max(body.width - landscapePaneMinWidth, floor),
      );
      if (width >= floor && body.width - width >= landscapePaneFloorWidth) {
        return (landscape: true, width: width);
      }
    }
    final width = math.min(
      body.width,
      (body.height - portraitControlsMinHeight) * 16 / 9,
    );
    if (width >= floor) return (landscape: false, width: width);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final round = state.round;
    if (!isPlayerRound(state)) return _RoundBody(state: state);
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = state.showsVideoPlayer
            ? playerLayoutFor(constraints.biggest)
            : (landscape: false, width: 0.0);
        final landscape = layout?.landscape ?? false;
        // One Flex for every case keeps the player's element (and the loaded
        // video) across a rotation or a resize.
        return Flex(
          direction: landscape ? Axis.horizontal : Axis.vertical,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlayerPane(
              playerWidth: layout?.width ?? 0,
              child: DjVideoSlot(roundId: round.roundId),
            ),
            Expanded(
              child: _RoundBody(
                state: state,
                player: layout == null
                    ? _PlayerLayout.unavailable
                    : landscape
                    ? _PlayerLayout.landscape
                    : _PlayerLayout.portrait,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// The black pane that holds the player: exactly the player in portrait,
/// the player centred vertically in landscape. No padding, border, radius,
/// clip, opacity or anything stacked on top.
class _PlayerPane extends StatelessWidget {
  const _PlayerPane({required this.playerWidth, required this.child});

  final double playerWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(
    // The player's own letterbox colour (as in `YouTubeRoundPlayer`), not a
    // theme colour: it frames the video, never text.
    color: Colors.black,
    child: Center(
      child: SizedBox(width: playerWidth, child: child),
    ),
  );
}

class _RoundBody extends StatelessWidget {
  const _RoundBody({required this.state, this.player = _PlayerLayout.none});

  final GameRoundState state;
  final _PlayerLayout player;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final round = state.round;
    final phase = state.phase;
    final reduce = Motion.reduced(context);
    // The DJ's player screen stays still (no equalizer loop, no ring).
    final calm = isPlayerRound(state);
    final playerShown =
        (player == _PlayerLayout.portrait ||
            player == _PlayerLayout.landscape) &&
        state.showsVideoPlayer;
    // The window cannot hold a legal player right now: the cue instead.
    final playerTooSmall =
        player == _PlayerLayout.unavailable && state.showsVideoPlayer;
    final screen = MediaQuery.sizeOf(context);
    final gutter = player == _PlayerLayout.landscape
        ? Spacing.md
        : Spacing.gutter(screen.width);
    // Below 700 dp of height the rhythm tightens (and tiles are 76 dp), so
    // four answers stay above the fold at the unlock.
    final compact = screen.height < TapTargets.compactHeight;
    final gap = compact ? Spacing.xs : Spacing.md;
    final status = switch (phase) {
      RoundLocked() => _lockedStatus(l10n, round),
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
      // On the player screen the note and the button already say what to
      // do: the status line carries the DJ's role instead.
      RoundDjCue() when playerShown && !round.djMayAnswer =>
        l10n.gameDjRoundNoAnswer,
      RoundDjCue() => l10n.gameDjCueSecret,
      RoundDjWatching() => l10n.gameDjWatchingHint,
    };
    final textPrompt = round.textPrompt;
    final emojiPrompt = round.emojiPrompt;
    final voidNotice = state.voidNotice;
    final showsTimer = state.showsButtons && !calm;

    final Widget? stage;
    if (round.isTextRound) {
      stage = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.gameTextRoundHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (textPrompt != null) ...[
            const SizedBox(height: Spacing.sm),
            SongCard(title: textPrompt.title, artists: textPrompt.artists),
          ],
        ],
      );
    } else if (emojiPrompt != null) {
      stage = PartyCard(
        padding: EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: compact ? Spacing.xs : Spacing.lg,
        ),
        child: Center(
          child: EmojiPuzzle(
            key: ValueKey('emoji-puzzle-${round.roundId}'),
            emoji: emojiPrompt.emoji,
            revealed: phase is! RoundLocked,
            size: compact ? 56 : 60,
          ),
        ),
      );
    } else if (!playerShown && phase is! RoundDjCue) {
      stage = Center(
        child: ExcludeSemantics(
          child: EqualizerBars(
            animate: !reduce && !calm && phase is! RoundAnswered,
            width: 120,
            height: 36,
          ),
        ),
      );
    } else {
      stage = null;
    }

    final list = ListView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        playerShown ? Spacing.md : Spacing.xs,
        gutter,
        Spacing.xl,
      ),
      children: [
        if (playerShown) ...[
          ..._playerControls(
            context,
            landscape: player == _PlayerLayout.landscape,
          ),
          const SizedBox(height: Spacing.lg),
        ],
        RoundHeader(
          round: round,
          timer: showsTimer
              ? AnswerTimerRing(
                  key: ValueKey('answer-timer-${round.roundId}'),
                  window: Duration(milliseconds: round.answerWindowMs),
                  running: phase is RoundOpen,
                  size: compact ? 48 : 56,
                )
              : null,
        ),
        SizedBox(height: gap),
        _PromptText(
          promptText(l10n, round.prompt, round.mode),
          // The question is for the others while the DJ starts the song.
          secondary: phase is RoundDjCue || phase is RoundDjWatching,
        ),
        SizedBox(height: gap),
        if (stage != null) ...[stage, const SizedBox(height: Spacing.xs)],
        _StatusSlot(
          text: status,
          // Everything the line shows up to and during the answer window:
          // the tiles never move at the unlock.
          reserve: [
            _lockedStatus(l10n, round),
            if (state.showsButtons) l10n.gameTapFast,
          ],
        ),
        SizedBox(height: compact ? Spacing.sm : Spacing.lg),
        if (phase is RoundDjCue) ...[
          ..._djCue(context, state, playerTooSmall: playerTooSmall),
          if (!round.djMayAnswer && !playerShown) ...[
            const SizedBox(height: Spacing.sm),
            Text(
              l10n.gameDjRoundNoAnswer,
              key: const ValueKey('dj-no-answer'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
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
          const SizedBox(height: Spacing.sm),
          Text(
            l10n.gameProgress(state.answeredCount, state.eligibleCount),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.tabular.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (state.airplayWarning) ...[
          const SizedBox(height: Spacing.md),
          PartyBanner(
            icon: Icons.volume_up_rounded,
            message: l10n.gameAirplayWarning,
          ),
        ],
      ],
    );
    // Over the round, not in its layout: when the notice goes, nothing moves
    // under the player's finger. It sits inside this body, which is always
    // below (or beside) the YouTube player, never over it.
    return Stack(
      children: [
        list,
        if (voidNotice != null)
          Positioned(
            top: Spacing.xs,
            left: gutter,
            right: gutter,
            child: VoidNoticeBanner(text: voidNoticeText(l10n, voidNotice)),
          ),
      ],
    );
  }

  /// The status line before the round opens.
  static String _lockedStatus(AppLocalizations l10n, RoundView round) {
    final djName = round.djName;
    if (round.isTextRound || round.isEmojiRound) {
      return l10n.gameTextRoundLocked;
    }
    if (round.waitsForDj) {
      return djName == null
          ? l10n.gameDjStarting
          : l10n.gameDjStartingNamed(djName);
    }
    return l10n.gameListen;
  }

  /// Under the player: the note, then «Музыка играет!» (the tonal
  /// «Отмечено» once tapped, in the same slot, so nothing below moves).
  /// Beside the player (landscape) the button comes first, so it stays
  /// above the fold. The note already says what to do, so the button shows
  /// no hint of its own and the status line carries the DJ's role.
  List<Widget> _playerControls(
    BuildContext context, {
    required bool landscape,
  }) {
    final round = state.round;
    final button = DjMusicPlayingButton(
      round: round,
      minHeight: landscape ? 72.0 : TapTargets.answer,
      done: state.phase is! RoundDjCue,
      showHint: false,
    );
    const note = YouTubePressPlayNote(key: ValueKey('youtube-note'));
    const gap = SizedBox(height: Spacing.md);
    return landscape ? [button, gap, note] : [note, gap, button];
  }

  /// The DJ's part of a round they have not started yet: the consent card,
  /// or the BYOP cue card (also the fallback when no video plays). With the
  /// player on screen, its controls sit right under the player instead.
  static List<Widget> _djCue(
    BuildContext context,
    GameRoundState state, {
    required bool playerTooSmall,
  }) {
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
      DjVideoPlayer() when playerTooSmall => [
        note(l10n.gameYouTubeWindowTooSmall),
        DjCueCard(round: round),
      ],
      DjVideoPlayer() => const [],
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

/// The round's question: Unbounded while it fits one line at the current
/// text scale (clamped to [maxTextScale]); a longer (translated or larger)
/// prompt falls back to the Nunito headline.
/// [secondary] (the DJ, whom the question is not for) sets it quietly in
/// `titleMedium` and `onSurfaceVariant`.
class _PromptText extends StatelessWidget {
  const _PromptText(this.text, {this.secondary = false});

  final String text;
  final bool secondary;

  /// The question is already display-sized: past 1.5x it would push the
  /// answers off the screen, which large text must never do.
  static const maxTextScale = 1.5;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxTextScale,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    if (secondary) {
      return Semantics(
        header: true,
        child: Text(
          text,
          key: const ValueKey('round-prompt'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final display = theme.textTheme.headlineMedium ?? const TextStyle();
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: text, style: display),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout(maxWidth: constraints.maxWidth);
        final fits = !painter.didExceedMaxLines;
        painter.dispose();
        return Semantics(
          header: true,
          child: Text(
            text,
            key: const ValueKey('round-prompt'),
            textAlign: TextAlign.center,
            style: fits ? display : theme.textTheme.headlineSmall,
          ),
        );
      },
    );
  }
}

/// «Нажми ▶ в плеере…» under the YouTube player: the play symbol is a
/// Material icon drawn inline, never the ▶ character (no bundled font has
/// it, and the platform fallback draws a colour emoji). Screen readers get
/// «Нажми кнопку воспроизведения…». [новое имя — согласовать]
class YouTubePressPlayNote extends StatelessWidget {
  const YouTubePressPlayNote({super.key});

  /// Splits the ARB text at the icon's placeholder.
  static const _marker = '\u{FFFC}';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyLarge ?? const TextStyle();
    final parts = l10n.gameYouTubePressPlay(_marker).split(_marker);
    // WidgetSpan children already follow the text scale.
    final iconSize = (style.fontSize ?? 16) * 1.25;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final (i, part) in parts.indexed) ...[
            if (i > 0)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: ExcludeSemantics(
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: iconSize,
                    color: style.color ?? theme.colorScheme.onSurface,
                  ),
                ),
              ),
            TextSpan(text: part),
          ],
        ],
      ),
      textAlign: TextAlign.center,
      semanticsLabel: l10n.gameYouTubePressPlay(l10n.gameYouTubePlayButton),
    );
  }
}

/// The round's status line in a slot tall enough for every text in
/// [reserve] at the current width and text scale, so the answers below
/// never move when the line changes from «Слушай…» to «Жми быстрее
/// всех!».
class _StatusSlot extends StatelessWidget {
  const _StatusSlot({required this.text, this.reserve = const []});

  final String text;
  final List<String> reserve;

  /// A supporting line: it never outgrows the question above it.
  static const maxTextScale = 1.5;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxTextScale,
    child: Builder(builder: _build),
  );

  Widget _build(BuildContext context) {
    final theme = Theme.of(context);
    final style = (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        var reserved = 0.0;
        for (final candidate in {text, ...reserve}) {
          final painter = TextPainter(
            text: TextSpan(text: candidate, style: style),
            textAlign: TextAlign.center,
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: constraints.maxWidth);
          reserved = math.max(reserved, painter.height);
          painter.dispose();
        }
        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: reserved),
          child: Center(
            child: Semantics(
              liveRegion: true,
              child: Text(text, textAlign: TextAlign.center, style: style),
            ),
          ),
        );
      },
    );
  }
}

/// «Раунд пропущен: <причина>» over a spare round. It ignores pointers, so
/// it never blocks the answers under it.
class VoidNoticeBanner extends StatelessWidget {
  const VoidNoticeBanner({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return IgnorePointer(
      child: Semantics(
        liveRegion: true,
        child: Material(
          key: const ValueKey('void-notice'),
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.replay_rounded,
                    color: scheme.onInverseSurface,
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onInverseSurface,
                    ),
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
/// provider logo (cover images are not cleared; `docs/DEVELOPMENT.md` §7).
class SongCard extends StatelessWidget {
  const SongCard({super.key, required this.title, required this.artists});

  final String title;
  final List<String> artists;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PartyCard(
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_note_rounded,
                color: scheme.onPrimaryContainer,
                size: IconSizes.md,
              ),
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                Text(
                  artists.join(', '),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The DJ's card (external_player, and the youtube_embed fallback): the
/// song to start in their own music app, a hand-off button, and
/// «Музыка играет!». Only the DJ gets the cue, so only the DJ sees the
/// title before the reveal.
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
              // No player on this card's screen, so a toast is allowed.
              showPartyToast(context, l10n.gameDjOpenAppFailed);
            },
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(l10n.gameDjOpenApp),
          ),
        ],
        const SizedBox(height: Spacing.lg),
        DjMusicPlayingButton(round: round, minHeight: 96),
      ],
    );
  }
}

/// «Музыка играет!» (BYOP and youtube_embed DJ) on a [TimedCtaButton]:
/// `Listener.onPointerDown` carries the OS touch time, which becomes
/// `audio_start_mono_us` (through the process anchor) with
/// `source: dj_tap`; `onTap` would fire only when the finger lifts. In a
/// youtube_embed round it sits below (or beside) the player, never on it.
///
/// [done] shows the tonal «Отмечено» state after the tap (no SnackBar, and
/// the slot under the player keeps its place).
class DjMusicPlayingButton extends ConsumerWidget {
  const DjMusicPlayingButton({
    super.key,
    required this.round,
    this.minHeight = TapTargets.answer,
    this.done = false,
    this.showHint = true,
  });

  final RoundView round;

  /// 96 dp on the BYOP card, 88 dp under the player, 72 dp in landscape.
  final double minHeight;
  final bool done;

  /// «Нажми, как только песня зазвучит» under the label (and as the
  /// screen-reader hint); off under the YouTube player, whose note already
  /// says it.
  final bool showHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(gameControllerProvider.notifier);

    void started(int? audioStartMonoUs) {
      // A screen-reader activation (null) has no touch time: the controller
      // reads the input clock instead.
      final reported = controller.djStarted(
        roundId: round.roundId,
        audioStartMonoUs: audioStartMonoUs,
      );
      if (reported) unawaited(HapticFeedback.mediumImpact());
    }

    return TimedCtaButton(
      key: ValueKey(done ? 'dj-music-played' : 'dj-music-playing'),
      label: l10n.gameDjMusicPlaying,
      hint: showHint ? l10n.gameDjMusicPlayingHint : null,
      minHeight: minHeight,
      done: done,
      doneLabel: l10n.gameDjTapped,
      clock: controller.inputClock,
      onCommit: started,
    );
  }
}

/// «Это твой трек!»: no answers for the track's owner.
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

/// A hero banner on the text-safe CTA fill ([PartyColors.ctaGradient]).
class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    return PartyCard(
      tone: PartyCardTone.cta,
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        children: [
          ExcludeSemantics(child: Icon(icon, size: IconSizes.xl)),
          const SizedBox(height: Spacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(color: party.onCta),
          ),
        ],
      ),
    );
  }
}

/// `game.starting`: the countdown in a decorative neon ring.
class StartingScreen extends StatelessWidget {
  const StartingScreen({super.key, required this.state});

  final GameStartingState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                l10n.gameStartingTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: Spacing.lg),
            SizedBox.square(
              dimension: 160,
              child: CustomPaint(
                painter: _RingPainter(
                  colors: PartyColors.of(context).neonGradient,
                ),
                child: Center(
                  child: MediaQuery.withClampedTextScaling(
                    maxScaleFactor: 1.5,
                    child: _CountdownNumber(countdownMs: state.countdownMs),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              l10n.gameStartingRounds(state.roundsTotal),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The seconds left of `game.starting`, as plain text that changes once a
/// second. Visual only (the server schedules the rounds): a one-shot
/// [Timer] per step, never `DateTime.now()` or a `Stopwatch`, and no frame
/// loop. It has no motion, so it keeps counting under reduce-motion, and
/// the platform's animation scale cannot speed it up.
class _CountdownNumber extends StatefulWidget {
  const _CountdownNumber({required this.countdownMs});

  final int countdownMs;

  @override
  State<_CountdownNumber> createState() => _CountdownNumberState();
}

class _CountdownNumberState extends State<_CountdownNumber> {
  Timer? _step;
  int _leftMs = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_CountdownNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.countdownMs != widget.countdownMs) _start();
  }

  @override
  void dispose() {
    _step?.cancel();
    super.dispose();
  }

  void _start() {
    _step?.cancel();
    _leftMs = math.max(0, widget.countdownMs);
    _schedule();
  }

  /// The next whole-second boundary of the remaining time.
  void _schedule() {
    if (_leftMs <= 0) return;
    final stepMs = _leftMs % 1000 == 0 ? 1000 : _leftMs % 1000;
    _step = Timer(Duration(milliseconds: stepMs), () {
      if (!mounted) return;
      setState(() => _leftMs -= stepMs);
      _schedule();
    });
  }

  @override
  Widget build(BuildContext context) => Text(
    '${(_leftMs / 1000).ceil().clamp(1, 99)}',
    style: Theme.of(context).textTheme.displayLarge?.tabular,
  );
}

/// A decorative [PartyColors.neonGradient] ring (never behind text: the
/// number sits inside it on the plain surface).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.colors});

  final List<Color> colors;

  static const _stroke = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(_stroke / 2);
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..shader = SweepGradient(colors: [...colors, colors.first])
            .createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.colors != colors;
}

/// A full-screen status between rounds: an icon or the equalizer (static
/// under reduce-motion), the title in a live region, and a subtitle.
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              ExcludeSemantics(
                child: Icon(
                  icon,
                  size: IconSizes.xl,
                  color: theme.colorScheme.primary,
                ),
              ),
            if (busy) ...[
              const SizedBox(height: Spacing.md),
              ExcludeSemantics(
                child: EqualizerBars(
                  animate: !Motion.reduced(context),
                  width: 96,
                  height: 32,
                ),
              ),
            ],
            const SizedBox(height: Spacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
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
