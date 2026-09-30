import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/lobby/presentation/room_route_sync.dart';

/// `game.results`: podium, full table and «Сыграть ещё» for the host.
class ResultsPage extends ConsumerWidget {
  const ResultsPage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(gameControllerProvider);
    return RoomRouteSync(
      roomId: roomId,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.resultsTitle),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () => confirmLeaveRoom(context, ref),
              child: Text(l10n.lobbyLeave),
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
        body: SafeArea(
          top: false,
          child: state is GameFinishedState
              ? _ResultsBody(state: state)
              : const Center(child: CircularProgressIndicator()),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.xs,
        Spacing.lg,
        Spacing.xl,
      ),
      children: [
        _Podium(rows: state.podium),
        const SizedBox(height: Spacing.md),
        Text(
          [
            l10n.resultsRounds(state.roundsPlayed),
            if (state.bonusUsed) l10n.resultsBonusUsed,
          ].join(' · '),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: Spacing.lg),
        for (final row in state.standings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: row.isMe
                  ? theme.colorScheme.primary
                  : theme.colorScheme.surfaceContainerHighest,
              child: Text(
                '${row.rank}',
                style: TextStyle(
                  color: row.isMe
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            title: Text(row.name),
            subtitle: Text(l10n.resultsCorrect(row.correctCount)),
            trailing: Text(
              l10n.pointsShort(row.points),
              style: theme.textTheme.titleMedium,
            ),
          ),
      ],
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows});

  final List<StandingRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final animate = !MediaQuery.disableAnimationsOf(context);
    // Second, first, third, like a real podium.
    final order = [
      if (rows.length > 1) (rows[1], 0.66),
      (rows[0], 1.0),
      if (rows.length > 2) (rows[2], 0.45),
    ];
    return SizedBox(
      height: 220,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final (row, height) in order)
            Expanded(
              child: _PodiumColumn(row: row, height: height, animate: animate),
            ),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn({
    required this.row,
    required this.height,
    required this.animate,
  });

  final StandingRow row;
  final double height;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          Text(
            context.l10n.pointsShort(row.points),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.xxs),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: height),
            duration: animate ? Motion.slow : Duration.zero,
            curve: Motion.emphasizedDecelerate,
            builder: (context, value, _) => Container(
              height: 140 * value,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: Spacing.xs),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: party.gradient.take(2).toList(),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(Radii.md),
                ),
              ),
              child: Text(
                '${row.rank}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Spacing.lg,
          Spacing.xs,
          Spacing.lg,
          Spacing.md,
        ),
        child: state.isHost
            ? FilledButton.icon(
                onPressed: ref.read(gameControllerProvider.notifier).playAgain,
                icon: const Icon(Icons.replay_rounded),
                label: Text(l10n.resultsPlayAgain),
              )
            : Text(
                l10n.resultsWaitingHost,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}
