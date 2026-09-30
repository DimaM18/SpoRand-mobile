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
    this.mode,
    this.cue,
    this.textPrompt,
    this.emojiPrompt,
    this.youAreDj = false,
    this.djPlayerId,
    this.djName,
    this.externalAudio = false,
    this.djMayAnswer = true,
    this.position,
  });

  /// [mode] is the room mode (the question of a text round); [externalAudio]
  /// is true when the room's audio comes from the DJ's own music app
  /// (`provider_capabilities.audio_source` = external_app);
  /// [guessTrackDjCanAnswer] and [whoseSongDjCanAnswer] are the room config
  /// keys; [djName] is the display name of `dj_player_id`.
  factory RoundView.fromPrepare(
    RoundPrepare m, {
    required int roundsTotal,
    GameMode? mode,
    bool externalAudio = false,
    bool guessTrackDjCanAnswer = false,
    bool whoseSongDjCanAnswer = false,
    String? djName,
    int? position,
  }) => RoundView(
    roundId: m.roundId,
    roundIndex: m.roundIndex,
    roundsTotal: roundsTotal,
    kind: m.kind,
    prompt: m.prompt,
    mode: mode,
    options: m.options,
    youAreOwner: m.youAreOwner,
    answerWindowMs: m.answerWindowMs,
    audioStartSource: m.audioStartSource,
    cue: m.cue,
    textPrompt: m.textPrompt,
    emojiPrompt: m.emojiPrompt,
    youAreDj: m.youAreDj,
    djPlayerId: m.djPlayerId,
    djName: djName,
    externalAudio: externalAudio,
    // The DJ reads the cue before anyone hears the song and reports the
    // start, so by default they do not answer (dj_ineligible) in either
    // mode; each mode has its own key.
    djMayAnswer: switch (m.prompt) {
      RoundPrompt.guessTrack => guessTrackDjCanAnswer,
      RoundPrompt.whoseSong => whoseSongDjCanAnswer,
      RoundPrompt.textRound || RoundPrompt.emojiRound => true,
    },
    position: position,
  );

  final String roundId;
  final int roundIndex;
  final int roundsTotal;
  final RoundKind kind;
  final RoundPrompt prompt;

  /// The room mode, when known (a text round keeps its shape).
  final GameMode? mode;

  /// In the server's per-player order; never re-sorted.
  final List<RoundOption> options;
  final bool youAreOwner;
  final int answerWindowMs;
  final AudioStartSource audioStartSource;

  /// DJ only (external_player): the song to start in their music app.
  final RoundCue? cue;

  /// whose_song text round: the song everyone reads.
  final RoundTextPrompt? textPrompt;

  /// emoji_quiz round: the emoji puzzle.
  final RoundEmojiPrompt? emojiPrompt;

  /// This player is the round's DJ (`round.prepare.you_are_dj`), whatever
  /// the room's playback device is.
  final bool youAreDj;

  /// The round's DJ, when the round has one.
  final String? djPlayerId;

  /// [djPlayerId]'s display name, for «<имя> включает песню…».
  final String? djName;

  /// The room's audio plays from the DJ's own music app.
  final bool externalAudio;

  /// Whether the DJ may answer this round (see [RoundView.fromPrepare]).
  final bool djMayAnswer;

  /// 1-based place in the game as played (set by `GameController`).
  /// `round_index` is the plan index: a spare that replaces a voided round
  /// and a bonus round have indices after every regular round.
  final int? position;

  /// «Раунд N из M».
  int get number => position ?? roundIndex + 1;
  bool get isBonus => kind == RoundKind.bonus;

  /// This player is the round's DJ (`you_are_dj`; the DJ gets the cue).
  bool get isDj => youAreDj;

  /// A round without audio (provider `none`).
  bool get isTextRound => prompt == RoundPrompt.textRound;

  /// An emoji_quiz round (no audio, emoji puzzle).
  bool get isEmojiRound => prompt == RoundPrompt.emojiRound;

  /// Everyone but the DJ of a round the DJ starts: waiting for the song.
  bool get waitsForDj =>
      !isDj &&
      audioStartSource == AudioStartSource.hostReported &&
      (djPlayerId != null || externalAudio);
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

/// The DJ (external_player) must start the song in their own music app and
/// tap «Музыка играет!» (A2.2). [новое имя — согласовать]
final class RoundDjCue extends RoundPhase {
  const RoundDjCue();
}

/// The DJ started the song but may not answer this round
/// (`guess_track_dj_can_answer` / `whose_song_dj_can_answer` = false,
/// `dj_ineligible`): «Ты DJ этого раунда — отвечают остальные».
/// [новое имя — согласовать]
final class RoundDjWatching extends RoundPhase {
  const RoundDjWatching();
}

final class GameRoundState extends GameUiState {
  const GameRoundState({
    required this.round,
    required this.phase,
    this.answeredCount = 0,
    this.eligibleCount = 0,
    this.airplayWarning = false,
    this.voidNotice,
  });

  final RoundView round;
  final RoundPhase phase;
  final int answeredCount;
  final int eligibleCount;

  /// Host only: AirPlay adds ~2 s of latency (brief §5).
  final bool airplayWarning;

  /// «Раунд пропущен: <причина>» over a spare round, until `void_notice_ms`
  /// after `round.voided` passed. [новое имя — согласовать]
  final RoundVoidReason? voidNotice;

  /// No buttons for the track's owner or for a DJ who may not answer; the
  /// DJ sees the cue card instead until the song plays.
  bool get showsButtons =>
      !round.youAreOwner &&
      phase is! RoundDjCue &&
      !(round.isDj && !round.djMayAnswer);
  bool get buttonsEnabled => phase is RoundOpen;

  GameRoundState copyWith({
    RoundPhase? phase,
    int? answeredCount,
    int? eligibleCount,
    bool? airplayWarning,
    bool clearVoidNotice = false,
  }) => GameRoundState(
    round: round,
    phase: phase ?? this.phase,
    answeredCount: answeredCount ?? this.answeredCount,
    eligibleCount: eligibleCount ?? this.eligibleCount,
    airplayWarning: airplayWarning ?? this.airplayWarning,
    voidNotice: clearVoidNotice ? null : voidNotice,
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
