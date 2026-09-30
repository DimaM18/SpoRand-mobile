import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import 'e2e_env.dart';
import 'e2e_phone.dart';
import 'wire_tap.dart';

/// How far the server's reaction time may be from the truth computed from
/// the simulated clocks: the clock-sync error on a loopback socket (well
/// under a millisecond) plus event-loop jitter of both processes.
const int reactionToleranceMs = 30;

Future<void> sleepUntil(int e2eUs) async {
  final wait = e2eUs - e2eNowUs();
  if (wait > 0) await Future<void>.delayed(Duration(microseconds: wait));
}

/// The option of [round] labelled [label] (whose_song labels are the
/// players' display names).
RoundOption optionLabelled(GameRoundState round, String label) =>
    round.round.options.firstWhere((o) => o.label == label);

/// The last frame of [type] this phone received for [roundId].
WireFrame receivedFor(E2ePhone phone, String type, String roundId) => phone.wire
    .receivedOf(type)
    .lastWhere((f) => f.payload['round_id'] == roundId);

/// The last frame of [type] this phone sent for [roundId].
WireFrame sentFor(E2ePhone phone, String type, String roundId) =>
    phone.wire.sentOf(type).lastWhere((f) => f.payload['round_id'] == roundId);

RoundResult resultOf(RoundReveal reveal, E2ePhone phone) =>
    reveal.results.firstWhere((r) => r.playerId == phone.playerId);

/// When this phone's game state first had the answer buttons of [roundId]
/// enabled (the local unlock), in e2e time.
int unlockedAtUs(E2ePhone phone, String roundId) => phone.gameStates
    .firstWhere(
      (s) =>
          s.state is GameRoundState &&
          (s.state as GameRoundState).round.roundId == roundId &&
          (s.state as GameRoundState).phase is RoundOpen,
    )
    .atUs;

/// A mono time the server announced as `*_server_ms`, on the e2e time line
/// as this phone's clock sync maps it (`mono = server_us + offset_us`).
int serverMsToE2eUs(E2ePhone phone, int serverMs) =>
    phone.clock.e2eUsOf(serverMs * 1000 + phone.session.clock.offsetUs!);

/// The speed part of a correct answer's points: [RoundResult.points] minus
/// the streak bonus (`min((streak − 1) × score_streak_bonus_points,
/// score_streak_bonus_cap)`), so players with different streaks compare by
/// speed alone.
int speedPoints(E2ePhone phone, RoundResult result) {
  final config = phone.session.config.values;
  final perStreak = config['score_streak_bonus_points']! as int;
  final cap = config['score_streak_bonus_cap']! as int;
  final bonus = ((result.streak - 1) * perStreak).clamp(0, cap);
  return result.points - bonus;
}
