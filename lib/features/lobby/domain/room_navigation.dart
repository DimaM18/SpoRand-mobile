import 'package:sporand/app/router/routes.dart';
import 'package:sporand/features/game/domain/game_state.dart';

/// Which room screen matches the game state: lobby before and between
/// games, the round screen during a game, results at the end.
String roomLocationFor({required String roomId, required GameUiState game}) =>
    switch (game) {
      GameIdle() => Routes.lobby(roomId),
      GameFinishedState() => Routes.results(roomId),
      _ => Routes.game(roomId),
    };
