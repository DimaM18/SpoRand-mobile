import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/game/domain/game_state.dart';

/// Standings that animate from the previous order to the new one; each
/// row's points count up by what it gained this round.
class StandingsList extends StatelessWidget {
  const StandingsList({super.key, required this.rows});

  static const rowHeight = 56.0;

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    final before = [...rows]
      ..sort((a, b) {
        final byRank = (a.previousRank ?? a.rank).compareTo(
          b.previousRank ?? b.rank,
        );
        return byRank != 0
            ? byRank
            : (b.points - b.gained).compareTo(a.points - a.gained);
      });
    final previousIndex = {
      for (final (i, row) in before.indexed) row.playerId: i,
    };
    return SizedBox(
      height: rows.length * rowHeight,
      child: Stack(
        children: [
          for (final (index, row) in rows.indexed)
            TweenAnimationBuilder<double>(
              key: ValueKey(row.playerId),
              tween: Tween(
                begin: (previousIndex[row.playerId] ?? index).toDouble(),
                end: index.toDouble(),
              ),
              duration: animate ? Motion.slow : Duration.zero,
              curve: Motion.emphasized,
              builder: (context, position, child) => Positioned(
                top: position * rowHeight,
                left: 0,
                right: 0,
                height: rowHeight,
                child: child!,
              ),
              child: _StandingTile(row: row, animate: animate),
            ),
        ],
      ),
    );
  }
}

class _StandingTile extends StatelessWidget {
  const _StandingTile({required this.row, required this.animate});

  final StandingRow row;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final highlight = row.isMe
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainer;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xxs),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
        decoration: BoxDecoration(
          color: highlight,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${row.rank}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (row.rankDelta != 0)
              Icon(
                row.rankDelta > 0
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                color: row.rankDelta > 0
                    ? theme.colorScheme.tertiary
                    : theme.colorScheme.error,
              ),
            Expanded(
              child: Text(
                row.name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (row.gained > 0)
              Padding(
                padding: const EdgeInsets.only(right: Spacing.xs),
                child: Text(
                  l10n.revealGained(row.gained),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: row.points - row.gained, end: row.points),
              duration: animate ? Motion.slow : Duration.zero,
              builder: (context, points, _) => Text(
                l10n.pointsShort(points),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
