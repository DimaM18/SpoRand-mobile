import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';

/// Everything the game screens render, as a sealed state machine. Built by
/// `GameController` from server messages; widgets only draw it.
sealed class GameUiState {
  const GameUiState();
}

/// No game running (the room is in the lobby or between games).
final class GameIdle extends GameUiState {
  const GameIdle();
}

/// `game.starting`: countdown before the first round.
final class GameStartingState extends GameUiState {
  const GameStartingState({
    required this.gameId,
    required this.roundsTotal,
    required this.countdownMs,
  });

  final String gameId;
  final int roundsTotal;
  final int countdownMs;
}

/// Static facts of the current round (`round.prepare`).
final class RoundView {
  const RoundView({
    required this.roundId,
    required this.roundIndex,
    required this.roundsTotal,
    required this.kind,
    required this.prompt,
    required this.options,
    required this.youAreOwner,
    required this.answerWindowMs,
    required this.audioStartSource,
  });

  factory RoundView.fromPrepare(RoundPrepare m, {required int roundsTotal}) =>
      RoundView(
        roundId: m.roundId,
        roundIndex: m.roundIndex,
        roundsTotal: roundsTotal,
        kind: m.kind,
        prompt: m.prompt,
        options: m.options,
        youAreOwner: m.youAreOwner,
        answerWindowMs: m.answerWindowMs,
        audioStartSource: m.audioStartSource,
      );

  final String roundId;
  final int roundIndex;
  final int roundsTotal;
  final RoundKind kind;
  final GameMode prompt;

  /// In the server's per-player order; never re-sorted.
  final List<RoundOption> options;
  final bool youAreOwner;
  final int answerWindowMs;
  final AudioStartSource audioStartSource;

  int get number => roundIndex + 1;
  bool get isBonus => kind == RoundKind.bonus;
}

sealed class RoundPhase {
  const RoundPhase();
}

/// Buttons visible but disabled until the audio starts.
final class RoundLocked extends RoundPhase {
  const RoundLocked();
}

/// Buttons enabled; the first pointer down commits.
final class RoundOpen extends RoundPhase {
  const RoundOpen();
}

enum AnswerAckStatus { pending, accepted, rejected }

final class RoundAnswered extends RoundPhase {
  const RoundAnswered({
    required this.optionId,
    this.ack = AnswerAckStatus.pending,
    this.rejection,
  });

  final String optionId;
  final AnswerAckStatus ack;
  final AnswerValidation? rejection;

  RoundAnswered withAck(bool accepted, AnswerValidation? reason) =>
      RoundAnswered(
        optionId: optionId,
        ack: accepted ? AnswerAckStatus.accepted : AnswerAckStatus.rejected,
        rejection: reason,
      );
}

/// «Это твой трек!»: the owner does not answer (whose_song_owner_can_answer
/// = false).
final class RoundOwnerWatching extends RoundPhase {
  const RoundOwnerWatching();
}

/// The answer window passed locally without a tap.
final class RoundTimeUp extends RoundPhase {
  const RoundTimeUp();
}

final class GameRoundState extends GameUiState {
  const GameRoundState({
    required this.round,
    required this.phase,
    this.answeredCount = 0,
    this.eligibleCount = 0,
    this.airplayWarning = false,
  });

  final RoundView round;
  final RoundPhase phase;
  final int answeredCount;
  final int eligibleCount;

  /// Host only: AirPlay adds ~2 s of latency (brief §5).
  final bool airplayWarning;

  bool get showsButtons => !round.youAreOwner;
  bool get buttonsEnabled => phase is RoundOpen;

  GameRoundState copyWith({
    RoundPhase? phase,
    int? answeredCount,
    int? eligibleCount,
    bool? airplayWarning,
  }) => GameRoundState(
    round: round,
    phase: phase ?? this.phase,
    answeredCount: answeredCount ?? this.answeredCount,
    eligibleCount: eligibleCount ?? this.eligibleCount,
    airplayWarning: airplayWarning ?? this.airplayWarning,
  );
}

/// One line of the standings table.
final class StandingRow {
  const StandingRow({
    required this.playerId,
    required this.name,
    required this.rank,
    required this.points,
    required this.gained,
    required this.isMe,
    this.previousRank,
    this.correctCount = 0,
  });

  final String playerId;
  final String name;
  final int rank;
  final int points;

  /// Points gained in the last round (drives the reveal animation).
  final int gained;
  final bool isMe;
  final int? previousRank;
  final int correctCount;

  /// Positive when the player climbed.
  int get rankDelta => previousRank == null ? 0 : previousRank! - rank;
}

final class RevealView {
  const RevealView({
    required this.round,
    required this.correctOptionIds,
    required this.track,
    required this.ownerNames,
    required this.standings,
    this.myOptionId,
    this.myResult,
  });

  final RoundView round;
  final List<String> correctOptionIds;
  final RevealTrack track;

  /// whose_song: whose track it was; empty in guess_track.
  final List<String> ownerNames;
  final List<StandingRow> standings;
  final String? myOptionId;
  final RoundResult? myResult;

  bool get wasOwner => round.youAreOwner;
  bool get answered => myOptionId != null;
  bool get correct => myResult?.correct ?? false;

  String? get correctLabel {
    for (final option in round.options) {
      if (correctOptionIds.contains(option.optionId)) return option.label;
    }
    return null;
  }
}

final class GameRevealState extends GameUiState {
  const GameRevealState(this.reveal);

  final RevealView reveal;
}

/// `round.voided`: a spare round replaces it.
final class GameVoidedState extends GameUiState {
  const GameVoidedState({required this.reason, this.round});

  final RoundVoidReason reason;
  final RoundView? round;
}

/// The host (playback device) dropped; the room waits for it.
final class GamePausedState extends GameUiState {
  const GamePausedState();
}

sealed class BonusPhase {
  const BonusPhase();
}

/// «Посмотри рекламу — +1 раунд для всех». [canWatch]: this player is
/// eligible and a rewarded ad is loaded.
final class BonusOffered extends BonusPhase {
  const BonusOffered({required this.canWatch});

  final bool canWatch;
}

final class BonusRequested extends BonusPhase {
  const BonusRequested();
}

/// Someone (maybe this player) is watching the ad.
final class BonusSponsorWatching extends BonusPhase {
  const BonusSponsorWatching({required this.sponsorName, required this.isMe});

  final String sponsorName;
  final bool isMe;
}

/// The ad was completed; waiting for the server-side verification.
final class BonusVerifying extends BonusPhase {
  const BonusVerifying();
}

final class BonusGrantedPhase extends BonusPhase {
  const BonusGrantedPhase({
    required this.sponsorName,
    required this.roundsAdded,
  });

  final String sponsorName;
  final int roundsAdded;
}

final class BonusCancelledPhase extends BonusPhase {
  const BonusCancelledPhase(this.reason);

  final BonusCancelReason reason;
}

final class GameBonusState extends GameUiState {
  const GameBonusState({
    required this.bonusId,
    required this.gameId,
    required this.phase,
  });

  final String bonusId;
  final String? gameId;
  final BonusPhase phase;

  GameBonusState withPhase(BonusPhase phase) =>
      GameBonusState(bonusId: bonusId, gameId: gameId, phase: phase);
}

/// `game.ad_break`: an interstitial may be on screen; otherwise «Считаем
/// очки…» with the optional remove-ads card.
final class GameAdBreakState extends GameUiState {
  const GameAdBreakState({
    required this.gameId,
    required this.showingAd,
    required this.showUpsell,
  });

  final String gameId;
  final bool showingAd;
  final bool showUpsell;
}

final class GameFinishedState extends GameUiState {
  const GameFinishedState({
    required this.gameId,
    required this.standings,
    required this.roundsPlayed,
    required this.bonusUsed,
    required this.isHost,
  });

  final String gameId;
  final List<StandingRow> standings;
  final int roundsPlayed;
  final bool bonusUsed;
  final bool isHost;

  List<StandingRow> get podium => standings.take(3).toList();
}
