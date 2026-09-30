import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/end_of_game_views.dart';
import 'package:sporand/features/game/presentation/widgets/reveal_view.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/lobby/presentation/room_route_sync.dart';

/// The round screen: renders [GameUiState]; all logic lives in
/// [GameController].
class GamePage extends ConsumerWidget {
  const GamePage({super.key, required this.roomId});

  final String roomId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(gameControllerProvider);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return RoomRouteSync(
      roomId: roomId,
      child: Scaffold(
        appBar: AppBar(
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
          child: AnimatedSwitcher(
            duration: reduceMotion ? Duration.zero : Motion.medium,
            child: KeyedSubtree(
              key: ValueKey(_screenKey(state)),
              child: _body(context, state),
            ),
          ),
        ),
      ),
    );
  }

  /// Phase changes inside a round keep the same key (no cross-fade), so the
  /// buttons do not move under the player's finger.
  static String _screenKey(GameUiState state) => switch (state) {
    GameRoundState(:final round) => 'round-${round.roundId}',
    GameRevealState(:final reveal) => 'reveal-${reveal.round.roundId}',
    GameBonusState(:final bonusId) => 'bonus-$bonusId',
    _ => state.runtimeType.toString(),
  };

  static Widget _body(BuildContext context, GameUiState state) {
    final l10n = context.l10n;
    return switch (state) {
      GameIdle() ||
      GameFinishedState() => StatusScreen(title: l10n.gameWaiting, busy: true),
      GameStartingState() => StartingScreen(state: state),
      GameRoundState() => RoundScreen(state: state),
      GameRevealState(:final reveal) => RevealScreen(reveal: reveal),
      GameVoidedState(:final reason) => StatusScreen(
        title: l10n.gameVoided,
        subtitle: switch (reason) {
          RoundVoidReason.playbackTimeout ||
          RoundVoidReason.playbackFailed => l10n.gameVoidedPlayback,
          RoundVoidReason.hostDisconnected => l10n.gameVoidedHost,
          RoundVoidReason.serverRestart => l10n.gameVoidedServer,
          RoundVoidReason.unknown => null,
        },
        icon: Icons.replay_rounded,
      ),
      GamePausedState() => StatusScreen(
        title: l10n.gamePaused,
        subtitle: l10n.gamePausedHint,
        busy: true,
      ),
      GameBonusState() => BonusScreen(state: state),
      GameAdBreakState() => AdBreakScreen(state: state),
    };
  }
}
