import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/widgets/emoji_puzzle.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/game/presentation/widgets/standings_list.dart';

/// `round.reveal`: this player's result (pill, points, reaction time, the
/// server's streak), a recap of the correct option next to a wrong pick,
/// the answer with the track and its attribution, and the standings.
///
/// Never artwork, logos or lyrics; the reveal never shows the player.
class RevealScreen extends ConsumerWidget {
  const RevealScreen({super.key, required this.reveal});

  final RevealView reveal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final result = reveal.myResult;
    final kind = !reveal.answered
        ? ResultKind.noAnswer
        : reveal.correct
        ? ResultKind.correct
        : ResultKind.wrong;
    final points = result?.points ?? 0;
    final streak = result?.streak ?? 0;
    final reaction = result?.reactionMs;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final correctLabel = reveal.correctLabel;
    final track = reveal.track;
    final year = track.year;
    final emoji = reveal.round.emojiPrompt?.emoji;
    final attributionUrl = Uri.tryParse(track.attribution.url ?? '');
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
    final recap = kind == ResultKind.wrong ? _recap(ref) : const <Widget>[];
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Spacing.xs, gutter, Spacing.xl),
      children: [
        RoundHeader(round: reveal.round),
        // The celebration ring is painted behind the pill; the clip keeps it
        // off the header and the points.
        ClipRect(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
            child: Center(
              child: reveal.wasOwner
                  ? _OwnerPill(text: l10n.revealOwnerYou)
                  : CelebrationBurst(
                      play: kind == ResultKind.correct,
                      child: ResultPill(kind: kind),
                    ),
            ),
          ),
        ),
        if (kind == ResultKind.correct && points > 0)
          Center(child: PointsGained(points: points)),
        if (reaction != null && reveal.answered) ...[
          const SizedBox(height: Spacing.xxs),
          Text(
            l10n.revealReaction(
              NumberFormat('0.00', locale).format(reaction / 1000),
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.tabular,
          ),
        ],
        if (streak >= 2) ...[
          const SizedBox(height: Spacing.sm),
          Center(child: StreakChip(streak: streak)),
        ],
        const SizedBox(height: Spacing.lg),
        for (final tile in recap) ...[tile, const SizedBox(height: Spacing.sm)],
        if (recap.isNotEmpty) const SizedBox(height: Spacing.sm),
        PartyCard(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (emoji != null) ...[
                Center(
                  child: EmojiPuzzle(
                    emoji: emoji,
                    revealed: true,
                    animate: false,
                    size: 36,
                  ),
                ),
                const SizedBox(height: Spacing.sm),
              ],
              if (reveal.ownerNames.isNotEmpty)
                Text(
                  l10n.revealOwner(reveal.ownerNames.join(', ')),
                  style: theme.textTheme.titleLarge,
                )
              else if (correctLabel != null)
                Text(
                  l10n.revealAnswer(correctLabel),
                  style: theme.textTheme.titleLarge,
                ),
              const SizedBox(height: Spacing.xs),
              Text(
                '${track.title} — ${track.artists.join(', ')}',
                key: const ValueKey('reveal-track'),
                style: theme.textTheme.titleMedium,
              ),
              if (year != null)
                Text(
                  // A string: a year is not grouped like a number.
                  l10n.revealYear('$year'),
                  key: const ValueKey('reveal-year'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              if (track.attribution.text case final text?) ...[
                const SizedBox(height: Spacing.xxs),
                Text(
                  text,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (attributionUrl != null && attributionUrl.hasScheme)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => ref
                        .read(externalLinkLauncherProvider)
                        .open(attributionUrl),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: Text(attributionUrl.host),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.lg),
        Semantics(
          header: true,
          child: Text(l10n.revealStandings, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: Spacing.xs),
        StandingsList(rows: reveal.standings),
      ],
    );
  }

  /// After a wrong pick: the correct option(s) and the pick, as static
  /// tiles in the round's order, each with its shape marker and a word.
  List<Widget> _recap(WidgetRef ref) {
    final clock = ref.read(inputClockProvider);
    return [
      for (final (index, option) in reveal.round.options.indexed)
        if (reveal.correctOptionIds.contains(option.optionId) ||
            option.optionId == reveal.myOptionId)
          AnswerTile(
            key: ValueKey('reveal-option-${option.optionId}'),
            label: option.label,
            index: index,
            mode: reveal.correctOptionIds.contains(option.optionId)
                ? AnswerTileMode.correct
                : AnswerTileMode.wrong,
            clock: clock,
            // Recap tiles are never tappable.
            onCommit: (_) {},
          ),
    ];
  }
}

/// «Это был твой трек»: the owner did not answer this round.
class _OwnerPill extends StatelessWidget {
  const _OwnerPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: TapTargets.min),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          color: scheme.primaryContainer,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.headphones_rounded,
                color: scheme.onPrimaryContainer,
                size: IconSizes.md,
              ),
            ),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Text(
                text,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
