import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/standings_list.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/lobby/presentation/room_route_sync.dart';

/// `game.results`: title, podium, the full table, «Сыграть ещё» for the
/// host and «На главную» for everyone.
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameControllerProvider);
    return RoomRouteSync(
      roomId: roomId,
      child: Scaffold(
        // The title lives in the bar (no empty 56 dp band above the list).
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: Text(context.l10n.resultsTitle),
        ),
        body: SafeArea(
          top: false,
          child: state is GameFinishedState
              ? _ResultsBody(state: state)
              : PartyLoader(status: context.l10n.gameWaiting),
        ),
        bottomNavigationBar: state is GameFinishedState
            ? _ResultsActions(state: state)
            : null,
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody({required this.state});

  final GameFinishedState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
    return ListView(
      padding: EdgeInsets.fromLTRB(gutter, Spacing.xs, gutter, Spacing.xl),
      children: [
        _Podium(rows: state.podium),
        const SizedBox(height: Spacing.md),
        Text(
          [
            l10n.resultsRounds(state.roundsPlayed),
            if (state.bonusUsed) l10n.resultsBonusUsed,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.tabular.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        for (final row in state.standings) _ResultRow(row: row),
      ],
    );
  }
}

/// One line of the final table: rank, avatar, name with «Вы», correct
/// answers and points. The winner's rank is gold with a trophy.
class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.row});

  final StandingRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final game = GameColors.of(context);
    final me = row.isMe;
    final leader = row.rank == 1;
    final text = me ? scheme.onPrimaryContainer : scheme.onSurface;
    final subtle = me ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xxs),
      child: MergeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: me ? scheme.primaryContainer : scheme.surfaceContainer,
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              children: [
                SizedBox(
                  width: 32,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '${row.rank}',
                      style: theme.textTheme.titleMedium?.tabular.copyWith(
                        fontFamily: AppFonts.display,
                        color: leader ? game.gold : text,
                      ),
                    ),
                  ),
                ),
                PlayerAvatar(playerId: row.playerId, name: row.name, isMe: me),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StandingName(
                        name: row.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: text,
                        ),
                        leader: leader,
                        me: me,
                        color: text,
                        maxBadgeWidth: constraints.maxWidth * 0.2,
                      ),
                      Text(
                        l10n.resultsCorrect(row.correctCount),
                        style: theme.textTheme.bodySmall?.tabular.copyWith(
                          color: subtle,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.xs),
                // Large text shrinks the points rather than overflowing.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: constraints.maxWidth * 0.4,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Text(
                      l10n.pointsShort(row.points),
                      style: theme.textTheme.titleMedium?.tabular.copyWith(
                        color: text,
                      ),
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

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final animate = !Motion.reduced(context);
    // Second, first, third, like a real podium.
    final order = [
      if (rows.length > 1) (rows[1], 0.66),
      (rows[0], 1.0),
      if (rows.length > 2) (rows[2], 0.45),
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (row, height) in order)
          Expanded(
            child: _PodiumColumn(row: row, height: height, animate: animate),
          ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.row,
    required this.height,
    required this.animate,
  });

  /// The tallest column; the others are [height] of it.
  static const maxColumn = 140.0;

  final StandingRow row;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final game = GameColors.of(context);
    final leader = row.rank == 1;
    final points = l10n.pointsShort(row.points);
    return Semantics(
      label: l10n.resultsPodiumSemantics(row.rank, row.name, points),
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (leader)
              Icon(
                Icons.emoji_events_rounded,
                color: game.gold,
                size: IconSizes.lg,
              ),
            PlayerAvatar(
              playerId: row.playerId,
              name: row.name,
              size: 56,
              isMe: row.isMe,
            ),
            const SizedBox(height: Spacing.xxs),
            Text(
              row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: leader ? game.gold : null,
              ),
            ),
            Text(
              points,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.tabular.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: animate ? 0 : height, end: height),
              duration: animate ? Motion.slow : Duration.zero,
              curve: Motion.emphasizedDecelerate,
              builder: (context, value, child) =>
                  SizedBox(height: maxColumn * value, child: child),
              // Clipped, so the number never pokes out while the column
              // rises.
              child: ClipRect(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // The text-safe fill: white rank numbers stay >= 6.12:1.
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: party.ctaGradient,
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(Radii.md),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: MediaQuery.withNoTextScaling(
                        child: Text(
                          '${row.rank}',
                          style: theme.textTheme.headlineLarge?.tabular
                              .copyWith(color: party.onCta),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsActions extends ConsumerWidget {
  const _ResultsActions({required this.state});

  final GameFinishedState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return PartyActionBar(
      children: [
        if (state.isHost) ...[
          PartyButton(
            label: l10n.resultsPlayAgain,
            icon: Icons.replay_rounded,
            glow: true,
            onPressed: ref.read(gameControllerProvider.notifier).playAgain,
          ),
          // Destructive-ish: kept away from the hero action.
          const SizedBox(height: Spacing.md),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.xs),
            child: Text(
              l10n.resultsWaitingHost,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        OutlinedButton.icon(
          onPressed: () => confirmLeaveRoom(context, ref),
          icon: const Icon(Icons.home_rounded),
          label: Text(l10n.lobbyBackHome),
        ),
      ],
    );
  }
}
