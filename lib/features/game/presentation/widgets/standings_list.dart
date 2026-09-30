import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';

/// Standings that move from the previous order to the new one
/// ([Motion.medium]); each row's points count up by what it gained this
/// round. Under reduce-motion both jump to the end.
///
/// A row: rank, a rank-change arrow (with its words for screen readers),
/// avatar, name, «+N» and the points. The leader's rank is gold with a
/// trophy; the viewer's row is `primaryContainer` with «Вы».
class StandingsList extends StatelessWidget {
  const StandingsList({super.key, required this.rows});

  /// Row height at text scale 1.0, without the gap below it.
  static const rowHeight = 60.0;

  /// The height one row takes, gap included: rows grow with the text scale
  /// so nothing clips.
  static double rowExtent(BuildContext context) {
    final title = Theme.of(context).textTheme.titleMedium;
    final line =
        MediaQuery.textScalerOf(context).scale(title?.fontSize ?? 18) *
        (title?.height ?? 1.35);
    return math.max(rowHeight, line + Spacing.md * 2) + Spacing.xxs;
  }

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    final animate = !Motion.reduced(context);
    final extent = rowExtent(context);
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
      height: rows.length * extent,
      child: Stack(
        children: [
          for (final (index, row) in rows.indexed)
            TweenAnimationBuilder<double>(
              key: ValueKey(row.playerId),
              tween: Tween(
                begin: (previousIndex[row.playerId] ?? index).toDouble(),
                end: index.toDouble(),
              ),
              duration: animate ? Motion.medium : Duration.zero,
              curve: Motion.emphasized,
              builder: (context, position, child) => Positioned(
                top: position * extent,
                left: 0,
                right: 0,
                height: extent,
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
    final scheme = theme.colorScheme;
    final game = GameColors.of(context);
    final me = row.isMe;
    final leader = row.rank == 1;
    final fill = me ? scheme.primaryContainer : scheme.surfaceContainer;
    final text = me ? scheme.onPrimaryContainer : scheme.onSurface;
    // Light `gained` on primaryContainer is below 4.5:1, so the viewer's
    // own «+N» uses the row's text colour.
    final gainedColor = me ? text : game.gained;
    final delta = row.rankDelta;
    final titleStyle = theme.textTheme.titleMedium?.copyWith(color: text);
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xxs),
      child: MergeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                // Rank with its change arrow under it; shrinks rather than
                // overflowing with very large text.
                SizedBox(
                  width: 36,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${row.rank}',
                          style: titleStyle?.tabular.copyWith(
                            fontFamily: AppFonts.display,
                            color: leader ? game.gold : text,
                          ),
                        ),
                        if (delta != 0)
                          Semantics(
                            label: delta > 0
                                ? l10n.standingsMovedUp(delta)
                                : l10n.standingsMovedDown(-delta),
                            child: ExcludeSemantics(
                              child: Icon(
                                delta > 0
                                    ? Icons.arrow_drop_up_rounded
                                    : Icons.arrow_drop_down_rounded,
                                color: delta > 0 ? game.correct : game.wrong,
                                size: IconSizes.md,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                PlayerAvatar(
                  playerId: row.playerId,
                  name: row.name,
                  size: 32,
                  isMe: me,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: StandingName(
                    name: row.name,
                    style: titleStyle,
                    leader: leader,
                    me: me,
                    color: text,
                    maxBadgeWidth: constraints.maxWidth * 0.2,
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                // Points with «+N» under them; large text shrinks the
                // numbers rather than the row overflowing.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(
                            begin: row.points - row.gained,
                            end: row.points,
                          ),
                          duration: animate ? Motion.slow : Duration.zero,
                          builder: (context, points, _) => Text(
                            l10n.pointsShort(points),
                            style: titleStyle?.tabular,
                          ),
                        ),
                        if (row.gained > 0)
                          Text(
                            l10n.revealGained(row.gained),
                            style: theme.textTheme.labelLarge?.tabular.copyWith(
                              color: gainedColor,
                            ),
                          ),
                      ],
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

/// A player's name, then the leader's trophy and «Вы». The badges are
/// capped at [maxBadgeWidth] (they shrink first), so the name keeps its
/// room. Shared by the standings and the final results.
/// [новое имя — согласовать]
class StandingName extends StatelessWidget {
  const StandingName({
    super.key,
    required this.name,
    required this.style,
    required this.leader,
    required this.me,
    required this.color,
    required this.maxBadgeWidth,
  });

  final String name;
  final TextStyle? style;
  final bool leader;
  final bool me;
  final Color color;
  final double maxBadgeWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = GameColors.of(context);
    return Row(
      children: [
        Flexible(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (leader || me) ...[
          const SizedBox(width: Spacing.xxs),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBadgeWidth),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (leader)
                    ExcludeSemantics(
                      child: Icon(
                        Icons.emoji_events_rounded,
                        color: game.gold,
                        size: IconSizes.sm,
                      ),
                    ),
                  if (leader && me) const SizedBox(width: Spacing.xxs),
                  if (me)
                    Text(
                      context.l10n.lobbyYouBadge,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
