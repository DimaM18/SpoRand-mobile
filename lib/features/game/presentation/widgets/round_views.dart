import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/equalizer_bars.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/widgets/answer_grid.dart';

String promptText(AppLocalizations l10n, GameMode prompt) => switch (prompt) {
  GameMode.whoseSong => l10n.gamePromptWhoseSong,
  GameMode.guessTrack => l10n.gamePromptGuessTrack,
};

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

/// A round in progress: prompt, listening indicator, answers or the
/// owner's card, and the answered counter.
class RoundScreen extends StatelessWidget {
  const RoundScreen({super.key, required this.state});

  final GameRoundState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final round = state.round;
    final animate = !MediaQuery.disableAnimationsOf(context);
    final status = switch (state.phase) {
      RoundLocked() => l10n.gameListen,
      RoundOpen() => l10n.gameTapFast,
      RoundAnswered(:final ack) => switch (ack) {
        AnswerAckStatus.pending => l10n.gameAnswerSent,
        AnswerAckStatus.accepted => l10n.gameAnswerAccepted,
        AnswerAckStatus.rejected => l10n.gameAnswerRejected,
      },
      RoundTimeUp() => l10n.gameTimeUp,
      RoundOwnerWatching() => l10n.gameYourTrackHint,
    };
    return ListView(
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
          promptText(l10n, round.prompt),
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: Spacing.md),
        Center(
          child: EqualizerBars(
            animate: animate && state.phase is! RoundAnswered,
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
        if (state.showsButtons)
          AnswerGrid(state: state)
        else
          const _OwnerCard(),
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
  }
}

/// «Это твой трек!»: no buttons for the track's owner.
class _OwnerCard extends StatelessWidget {
  const _OwnerCard();

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
          const Icon(Icons.headphones_rounded, color: Colors.white, size: 48),
          const SizedBox(height: Spacing.sm),
          Text(
            context.l10n.gameYourTrack,
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
