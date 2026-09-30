import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/domain/host_playback_coordinator.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

final gameControllerProvider = NotifierProvider<GameController, GameUiState>(
  GameController.new,
);

/// Mutable facts of the round in progress (not UI state).
final class _RoundRuntime {
  _RoundRuntime(this.prepare);

  final RoundPrepare prepare;

  String get roundId => prepare.roundId;

  /// This player is the round's DJ (`you_are_dj`): it got the cue and
  /// reports the start.
  bool get isDj => prepare.youAreDj;

  /// Bumped by every (re)schedule of the unlock timer, so a slower earlier
  /// scheduling cannot overwrite a newer one.
  int unlockSchedule = 0;

  /// Set once the DJ tapped «Музыка играет!».
  bool djTapped = false;

  /// DJ only: `nowMicros()` read when the cue arrived, before «Музыка
  /// играет!» could be shown (a lower bound for its tap); null if that read
  /// failed.
  Future<int?>? cueShownUs;

  /// The input clock could not be read to schedule the unlock: the round
  /// then opens on `round.start`, like a host-reported one.
  bool unlockOnRoundStart = false;

  bool unlockRequested = false;

  /// `nowMicros()` read when the unlock was requested, before the frame
  /// showing enabled buttons was built (a lower bound for the unlock); null
  /// if that read failed.
  Future<int?>? provisionalUnlockUs;

  /// `currentSystemFrameTimeStamp` of the first frame with enabled buttons.
  int? frameUnlockUs;

  String? committedOptionId;
  RoundAnswer? sentAnswer;

  /// True once [sentAnswer] was written to an open socket. While the socket
  /// is reconnecting the WsClient outbox holds it and sends it after the
  /// next `welcome` itself, so it must not be resent on top of that.
  bool answerOnWire = false;
  bool acked = false;
}

/// Turns server messages into [GameUiState] and owns the timing-critical
/// client work (brief §5):
/// - scheduled rounds (and text rounds) unlock with a local timer at
///   `start_at_server_ms` converted with the latest `clock.result` offset
///   (the server's `start_at_mono_us` only before the first result);
///   host-reported rounds unlock on `round.start` (the host or DJ: on its own
///   playback start);
/// - the DJ of an external_player round (A2.2) starts the song in their own
///   music app and reports `round.playback_started{source: dj_tap}` with the
///   pointer-down time of «Музыка играет!» (the DJ is whoever the server
///   names with `you_are_dj`, not necessarily the playback device);
/// - the first pointer down commits and sends `round.answer` with the OS
///   touch time as `tap_mono_us` and the unlock frame time as
///   `unlock_mono_us`;
/// - the end-of-game flow: bonus offer, rewarded ad with SSV, ad break with
///   buffered results (brief §6).
class GameController extends Notifier<GameUiState> {
  RoomSession? _session;
  final List<StreamSubscription<Object?>> _subs = [];
  _RoundRuntime? _round;
  HostPlaybackCoordinator? _host;
  Timer? _unlockTimer;
  Timer? _timeUpTimer;

  /// The last `round.voided` reason while its notice is due
  /// (`void_notice_ms`), and the timer that ends it.
  RoundVoidReason? _voidNotice;
  Timer? _voidNoticeTimer;
  String? _gameId;
  int _roundsTotal = 0;

  /// Rounds of this game that reached `round.reveal` (by id: a catch-up can
  /// repeat the last reveal).
  final Set<String> _revealedRounds = {};
  List<Standing> _standings = const [];
  bool _adOnScreen = false;
  GameResults? _bufferedResults;

  /// Bumped when the session goes away, so async work (ads, clock reads)
  /// that resumes afterwards does not touch a disposed controller.
  int _epoch = 0;

  bool _isStale(int epoch) => !ref.mounted || epoch != _epoch;

  @override
  GameUiState build() {
    final session = ref.watch(roomSessionProvider);
    ref.onDispose(_teardown);
    _session = session;
    if (session != null) {
      _subs
        ..add(session.messages.listen(_onMessage))
        ..add(session.connection.listen(_onConnection));
    }
    return const GameIdle();
  }

  InputClock get _clock => ref.read(inputClockProvider);
  InputClock get inputClock => _clock;
  AdsService get _ads => ref.read(adsServiceProvider);
  RemoteConfigService get _config => ref.read(remoteConfigProvider);

  bool get isHost => _session?.isHost ?? false;

  // --- player actions ---------------------------------------------------------

  /// The first pointer down on an answer commits it (single tap, cannot be
  /// changed). [tapMonoUs] is the pointer event's OS touch time; null for a
  /// screen-reader activation, which has no touch timestamp. Returns true
  /// when this call committed the answer (the UI then plays a haptic).
  bool tap({
    required String roundId,
    required String optionId,
    required int? tapMonoUs,
  }) {
    final runtime = _round;
    final current = state;
    if (runtime == null ||
        runtime.roundId != roundId ||
        runtime.committedOptionId != null ||
        current is! GameRoundState ||
        current.round.roundId != roundId ||
        current.phase is! RoundOpen ||
        !current.round.options.any((o) => o.optionId == optionId)) {
      return false;
    }
    runtime.committedOptionId = optionId;
    _timeUpTimer?.cancel();
    state = current.copyWith(phase: RoundAnswered(optionId: optionId));
    unawaited(_sendAnswer(runtime, optionId, tapMonoUs));
    return true;
  }

  /// Reported by the answer grid from `addPostFrameCallback` of the first
  /// frame that shows enabled buttons.
  void onAnswerButtonsShown(String roundId, int frameTimestampUs) {
    final runtime = _round;
    if (runtime == null || runtime.roundId != roundId) return;
    if (!runtime.unlockRequested) return;
    runtime.frameUnlockUs ??= frameTimestampUs;
  }

  /// «Музыка играет!» (external_player DJ, A2.2): [audioStartMonoUs] is
  /// the pointer-down time of the tap on the anchored input clock (null for
  /// a screen-reader activation, then the input clock is read now). Sends
  /// `round.playback_started{source: dj_tap}` once per round. Returns true
  /// when this call reported the start.
  bool djStarted({required String roundId, required int? audioStartMonoUs}) {
    final runtime = _round;
    final current = state;
    if (runtime == null ||
        runtime.roundId != roundId ||
        !runtime.isDj ||
        runtime.djTapped ||
        current is! GameRoundState ||
        current.round.roundId != roundId ||
        current.phase is! RoundDjCue) {
      return false;
    }
    // Claimed synchronously so a second tap cannot report twice.
    runtime.djTapped = true;
    final view = current.round;
    state = current.copyWith(
      phase: view.youAreOwner
          ? const RoundOwnerWatching()
          : view.djMayAnswer
          ? const RoundLocked()
          : const RoundDjWatching(),
    );
    unawaited(_reportDjStart(runtime, audioStartMonoUs));
    return true;
  }

  Future<void> _reportDjStart(_RoundRuntime runtime, int? tapMonoUs) async {
    final shown = await runtime.cueShownUs;
    final now = await _readMono(_clock.nowMicros());
    // The same plausibility rule as answer taps: a pointer time on another
    // clock base would put the start seconds off (the server clamps an early
    // one to the cue, which lengthens every guest's reaction).
    final start = tapMonoUs == null || now == null
        ? tapMonoUs ?? now
        : MonoTimestamps.resolveTap(
            tapUs: tapMonoUs,
            unlockUs: shown ?? tapMonoUs,
            nowUs: now,
          );
    if (_round != runtime || start == null) return;
    _session?.send(
      RoundPlaybackStarted(
        roundId: runtime.roundId,
        audioStartMonoUs: start,
        // The song plays from another app on the DJ's speaker: its output
        // latency is unknown here and the same for everyone who hears it.
        outputLatencyMs: 0,
        outputRoute: OutputRoute.other,
        source: PlaybackStartSource.djTap,
      ),
    );
    // Host-reported: the DJ unlocks on its own start, guests on round.start.
    _unlock(runtime);
  }

  /// «Открыть в музыкальном приложении»: hands the cue to the DJ's own music
  /// app (never played by us). False when nothing could be opened.
  Future<bool> openCueInMusicApp() async {
    final cue = _round?.prepare.cue;
    if (cue == null) return false;
    try {
      return await ref.read(musicAppLauncherProvider).open(cue);
    } on Object {
      return false;
    }
  }

  /// «Посмотри рекламу — +1 раунд для всех»: first `bonus.request` wins.
  Future<void> requestBonus() async {
    final current = state;
    if (current is! GameBonusState) return;
    final phase = current.phase;
    if (phase is! BonusOffered || !phase.canWatch) return;
    state = current.withPhase(const BonusRequested());
    // Limited-use App Check token (brief §7). Without App Check (dev, no
    // Firebase) the field is omitted and the server decides by
    // `app_check_mode`.
    final token = await ref.read(appCheckProvider).getLimitedUseToken();
    _session?.send(
      BonusRequest(
        bonusId: current.bonusId,
        appCheckToken: token == null || token.isEmpty ? null : token,
      ),
    );
  }

  /// «Сыграть ещё» (host only; same room, played tracks excluded).
  void playAgain() {
    if (isHost) _session?.send(const GamePlayAgain());
  }

  // --- messages ---------------------------------------------------------------

  void _onMessage(ServerMessage message) {
    switch (message) {
      case Welcome(:final room) || RoomStateMessage(:final room):
        _onRoomSnapshot(room);
      case GameStarting():
        _onGameStarting(message);
      case ClockResult():
        _onClockResult(message);
      case RoundPrepare():
        _onRoundPrepare(message);
      case RoundStart():
        _onRoundStart(message);
      case RoundAnswerAck():
        _onAnswerAck(message);
      case RoundProgress():
        _onProgress(message);
      case RoundVoided():
        _onVoided(message);
      case RoundReveal():
        _onReveal(message);
      case GameBonusOffer():
        _onBonusOffer(message);
      case BonusSponsorLocked():
        _onSponsorLocked(message);
      case BonusNonce():
        unawaited(_onBonusNonce(message));
      case BonusGranted():
        _roundsTotal += message.roundsAdded;
        state = GameBonusState(
          bonusId: message.bonusId,
          gameId: _gameId,
          phase: BonusGrantedPhase(
            sponsorName: _nameOf(message.sponsorPlayerId),
            roundsAdded: message.roundsAdded,
          ),
        );
      case BonusCancelled():
        state = GameBonusState(
          bonusId: message.bonusId,
          gameId: _gameId,
          phase: BonusCancelledPhase(message.reason),
        );
      case GameAdBreak():
        unawaited(_onAdBreak(message));
      case GameResults():
        _onResults(message);
      case RoomClosed():
        _reset();
      default:
        break;
    }
  }

  void _onConnection(WsConnectionState connection) {
    if (connection is! WsConnected) return;
    final runtime = _round;
    final answer = runtime?.sentAnswer;
    if (runtime == null || answer == null || runtime.acked) return;
    // The socket dropped between the answer and its ack: send it again (the
    // server keeps the first one and acks the copy `duplicate`). An answer
    // given while offline was just flushed from the outbox: already sent.
    if (runtime.answerOnWire) _session?.send(answer);
    runtime.answerOnWire = true;
  }

  void _onRoomSnapshot(RoomSnapshot room) {
    switch (room.state) {
      case RoomState.lobby:
        if (state is! GameIdle) _reset();
      case RoomState.paused:
        _cancelTimers();
        _round = null;
        unawaited(_host?.stop());
        state = const GamePausedState();
      default:
        break;
    }
  }

  void _onGameStarting(GameStarting message) {
    _reset();
    _gameId = message.gameId;
    _roundsTotal = message.roundsTotal;
    state = GameStartingState(
      gameId: message.gameId,
      roundsTotal: message.roundsTotal,
      countdownMs: message.countdownMs,
    );
    if (message.prefetch.isNotEmpty) {
      final host = _hostCoordinator();
      if (host != null) unawaited(host.prefetch(message));
    }
  }

  void _onRoundPrepare(RoundPrepare message) {
    _cancelTimers();
    final runtime = _RoundRuntime(message);
    if (runtime.isDj) runtime.cueShownUs = _readMono(_clock.nowMicros());
    _round = runtime;
    _roundsTotal = math.max(_roundsTotal, _positionOf(message));
    final view = _viewOf(message);
    state = GameRoundState(
      round: view,
      phase: view.isDj
          // The DJ starts the song even when it is their own.
          ? const RoundDjCue()
          : message.youAreOwner
          ? const RoundOwnerWatching()
          : const RoundLocked(),
      // A spare round starts while the void notice may still be due.
      voidNotice: _voidNotice,
    );
    _maybePreloadAds(message);

    final host = message.clip == null ? null : _hostCoordinator();
    if (host != null) {
      unawaited(
        host
            .playRound(message, startAtMonoUs: () => _startAtMonoUs(message))
            .then((started) {
              if (started == null || _round != runtime) return;
              final current = state;
              if (started.outputRoute == OutputRoute.airplay &&
                  current is GameRoundState) {
                state = current.copyWith(airplayWarning: true);
              }
              // Host-reported source: the host unlocks on its own playback
              // start instead of waiting for `round.start`.
              if (message.audioStartSource == AudioStartSource.hostReported) {
                _unlock(runtime);
              }
            }),
      );
    }
    if (_unlocksOnSchedule(message)) unawaited(_scheduleUnlock(runtime));
  }

  /// The round's place in the game as played. A regular round's plan index
  /// is its place (a spare takes over a voided round's place, so later
  /// regular rounds keep theirs); a spare or bonus round comes right after
  /// the rounds revealed so far.
  int _positionOf(RoundPrepare message) => message.kind == RoundKind.regular
      ? message.roundIndex + 1
      : _revealedRounds.length + 1;

  RoundView _viewOf(RoundPrepare message) {
    final session = _session;
    final room = session?.room;
    final dj = message.djPlayerId;
    return RoundView.fromPrepare(
      message,
      position: _positionOf(message),
      roundsTotal: _roundsTotal,
      mode: room?.mode,
      externalAudio: room?.capabilities.isExternalApp ?? false,
      guessTrackDjCanAnswer: session?.config.guessTrackDjCanAnswer ?? false,
      whoseSongDjCanAnswer: session?.config.whoseSongDjCanAnswer ?? false,
      djName: dj == null ? null : session?.room?.player(dj)?.displayName,
    );
  }

  /// Scheduled rounds and text rounds (no audio) open at `start_at`.
  static bool _unlocksOnSchedule(RoundPrepare message) =>
      message.audioStartSource == AudioStartSource.scheduled ||
      message.audioStartSource == AudioStartSource.none;

  /// `start_at` on this device's anchored input clock (brief §5):
  /// `start_at_server_ms` × 1000 + the latest `clock.result` offset.
  /// `start_at_mono_us` was converted by the server with the offset it had
  /// when it sent `round.prepare`, which is stale after a reconnect or a
  /// device sleep, so it is only the fallback before the first result.
  int _startAtMonoUs(RoundPrepare prepare, {int? offsetUs}) {
    final offset = offsetUs ?? _session?.clock.offsetUs;
    return offset == null
        ? prepare.startAtMonoUs
        : prepare.startAtServerMs * 1000 + offset;
  }

  /// A newer `clock.result` (e.g. the burst after a reconnect or wake-up)
  /// moves a pending unlock.
  void _onClockResult(ClockResult message) {
    final runtime = _round;
    if (runtime == null ||
        runtime.unlockRequested ||
        !_unlocksOnSchedule(runtime.prepare)) {
      return;
    }
    unawaited(_scheduleUnlock(runtime, offsetUs: message.offsetUs));
  }

  Future<void> _scheduleUnlock(_RoundRuntime runtime, {int? offsetUs}) async {
    final epoch = _epoch;
    final schedule = ++runtime.unlockSchedule;
    final startAt = _startAtMonoUs(runtime.prepare, offsetUs: offsetUs);
    final now = await _readMono(_clock.nowMicros());
    if (_isStale(epoch) ||
        _round != runtime ||
        schedule != runtime.unlockSchedule ||
        runtime.unlockRequested) {
      return;
    }
    if (now == null) {
      runtime.unlockOnRoundStart = true;
      return;
    }
    final delayUs = startAt - now;
    _unlockTimer?.cancel();
    if (delayUs <= 0) {
      _unlock(runtime);
      return;
    }
    _unlockTimer = Timer(
      Duration(microseconds: delayUs),
      () => _unlock(runtime),
    );
  }

  void _onRoundStart(RoundStart message) {
    final runtime = _round;
    if (runtime == null || runtime.roundId != message.roundId) return;
    // Guests of a host-reported round unlock on receipt: about two one-way
    // trips late, below human reaction time (brief §5).
    if (runtime.prepare.audioStartSource == AudioStartSource.hostReported ||
        runtime.unlockOnRoundStart) {
      _unlock(runtime);
    }
  }

  void _unlock(_RoundRuntime runtime) {
    final current = state;
    if (_round != runtime ||
        runtime.unlockRequested ||
        runtime.prepare.youAreOwner ||
        (current is GameRoundState &&
            current.round.isDj &&
            !current.round.djMayAnswer)) {
      return;
    }
    runtime
      ..unlockRequested = true
      ..provisionalUnlockUs = _readMono(_clock.nowMicros());
    if (current is GameRoundState &&
        current.round.roundId == runtime.roundId &&
        current.phase is RoundLocked) {
      state = current.copyWith(phase: const RoundOpen());
    }
    _timeUpTimer?.cancel();
    _timeUpTimer = Timer(
      Duration(milliseconds: runtime.prepare.answerWindowMs),
      () {
        final now = state;
        if (_round == runtime &&
            now is GameRoundState &&
            now.phase is RoundOpen) {
          state = now.copyWith(phase: const RoundTimeUp());
        }
      },
    );
  }

  Future<void> _sendAnswer(
    _RoundRuntime runtime,
    String optionId,
    int? rawTapUs,
  ) async {
    // A committed answer is always sent: if the input clock cannot be read,
    // the pointer and frame timestamps (also OS-stamped) are used as they
    // are, and the server's arrival-time bounds still apply.
    final provisional = await runtime.provisionalUnlockUs;
    final now = await _readMono(_clock.nowMicros());
    final frame = runtime.frameUnlockUs;
    final int? unlock;
    final int? tap;
    if (now != null) {
      unlock = MonoTimestamps.resolveUnlock(
        provisionalUs: provisional ?? frame ?? now,
        frameUs: frame,
        nowUs: now,
      );
      tap = rawTapUs == null
          ? now
          : MonoTimestamps.resolveTap(
              tapUs: rawTapUs,
              unlockUs: unlock,
              nowUs: now,
            );
    } else {
      unlock = frame ?? provisional ?? rawTapUs;
      tap = rawTapUs ?? unlock;
    }
    if (_round != runtime || unlock == null || tap == null) return;
    final answer = RoundAnswer(
      roundId: runtime.roundId,
      nonce: runtime.prepare.nonce,
      optionId: optionId,
      tapMonoUs: tap,
      unlockMonoUs: unlock,
    );
    runtime
      ..sentAnswer = answer
      ..answerOnWire = _session?.ws.isConnected ?? false;
    _session?.send(answer);
  }

  /// An input-clock read, or null when it failed.
  static Future<int?> _readMono(Future<int> read) async {
    try {
      return await read;
    } on Object {
      return null;
    }
  }

  void _onAnswerAck(RoundAnswerAck message) {
    final runtime = _round;
    if (runtime == null || runtime.roundId != message.roundId) return;
    // A resent answer is acked `duplicate`: the server already has it.
    final accepted =
        message.accepted || message.reason == AnswerValidation.duplicate;
    if (runtime.acked && !accepted) return;
    runtime.acked = true;
    final current = state;
    if (current is GameRoundState && current.round.roundId == message.roundId) {
      final phase = current.phase;
      if (phase is RoundAnswered) {
        state = current.copyWith(
          phase: phase.withAck(accepted, accepted ? null : message.reason),
        );
      }
    }
  }

  void _onProgress(RoundProgress message) {
    final current = state;
    if (current is GameRoundState && current.round.roundId == message.roundId) {
      state = current.copyWith(
        answeredCount: message.answeredCount,
        eligibleCount: message.eligibleCount,
      );
    }
  }

  void _onVoided(RoundVoided message) {
    _cancelTimers();
    final current = state;
    _round = null;
    unawaited(_host?.stop());
    // The server waits `void_notice_ms` before the spare's round.prepare;
    // the notice stays up that long even if the spare comes sooner, and
    // never holds the spare back.
    _voidNoticeTimer?.cancel();
    _voidNotice = message.reason;
    _voidNoticeTimer = Timer(
      Duration(milliseconds: _session?.config.voidNoticeMs ?? 1500),
      _endVoidNotice,
    );
    state = GameVoidedState(
      reason: message.reason,
      round: current is GameRoundState ? current.round : null,
    );
  }

  void _endVoidNotice() {
    _voidNoticeTimer?.cancel();
    _voidNoticeTimer = null;
    _voidNotice = null;
    final current = state;
    if (current is GameRoundState && current.voidNotice != null) {
      state = current.copyWith(clearVoidNotice: true);
    }
  }

  void _onReveal(RoundReveal message) {
    _cancelTimers();
    final runtime = _round?.roundId == message.roundId ? _round : null;
    final current = state;
    final view =
        current is GameRoundState && current.round.roundId == message.roundId
        ? current.round
        : runtime != null
        ? _viewOf(runtime.prepare)
        : null;
    final me = _session?.playerId;
    RoundResult? myResult;
    for (final result in message.results) {
      if (result.playerId == me) myResult = result;
    }
    final rows = _standingRows(
      message.standings,
      gained: {for (final r in message.results) r.playerId: r.points},
    );
    _standings = message.standings;
    _round = null;
    _revealedRounds.add(message.roundId);
    state = GameRevealState(
      RevealView(
        round:
            view ??
            RoundView(
              roundId: message.roundId,
              roundIndex: 0,
              roundsTotal: _roundsTotal,
              kind: RoundKind.regular,
              prompt: RoundPrompt.whoseSong,
              options: const [],
              youAreOwner: false,
              answerWindowMs: 0,
              audioStartSource: AudioStartSource.scheduled,
            ),
        correctOptionIds: message.correctOptionIds,
        track: message.track,
        ownerNames: [for (final id in message.ownerPlayerIds) _nameOf(id)],
        standings: rows,
        myOptionId: runtime?.committedOptionId ?? myResult?.optionId,
        myResult: myResult,
      ),
    );
  }

  // --- end of game (brief §6) ---------------------------------------------------

  void _onBonusOffer(GameBonusOffer message) {
    final session = _session;
    final eligible =
        session != null && message.eligiblePlayerIds.contains(session.playerId);
    final canWatch = eligible && _rewardedAllowed && _ads.isRewardedReady;
    if (canWatch) {
      unawaited(
        ref.read(analyticsProvider).logEvent(
          AnalyticsEvents.adRewardedOfferView,
          {AnalyticsParams.gameId: _gameId},
        ),
      );
    }
    state = GameBonusState(
      bonusId: message.bonusId,
      gameId: _gameId,
      phase: BonusOffered(canWatch: canWatch),
    );
  }

  void _onSponsorLocked(BonusSponsorLocked message) {
    state = GameBonusState(
      bonusId: message.bonusId,
      gameId: _gameId,
      phase: BonusSponsorWatching(
        sponsorName: _nameOf(message.sponsorPlayerId),
        isMe: message.sponsorPlayerId == _session?.playerId,
      ),
    );
  }

  /// Sent to the sponsor only: show the rewarded ad with SSV options. The
  /// client reward callback is informational; the round is granted only
  /// after the server verifies the SSV callback.
  Future<void> _onBonusNonce(BonusNonce message) async {
    final epoch = _epoch;
    final analytics = ref.read(analyticsProvider);
    final ads = _ads;
    final maxWait = _config.maxAdWait;
    _adOnScreen = true;
    await _host?.stop();
    RewardedResult result;
    try {
      result = await ads.showRewarded(
        ssvUserId: message.ssvUserId,
        rewardNonce: message.rewardNonce,
        maxWait: maxWait,
      );
    } on Object {
      result = RewardedResult.failedToShow;
    }
    _adOnScreen = false;
    unawaited(
      analytics.logEvent(AnalyticsEvents.adRewardedResult, {
        AnalyticsParams.result: result.wireName,
      }),
    );
    if (_isStale(epoch)) return;
    _session?.send(
      BonusAdResult(
        bonusId: message.bonusId,
        status: switch (result) {
          RewardedResult.earned => BonusAdStatus.earned,
          RewardedResult.dismissed => BonusAdStatus.dismissed,
          RewardedResult.failedToLoad => BonusAdStatus.failedToLoad,
          RewardedResult.failedToShow => BonusAdStatus.failedToShow,
        },
      ),
    );
    final current = state;
    if (result == RewardedResult.earned &&
        current is GameBonusState &&
        current.bonusId == message.bonusId &&
        current.phase is BonusSponsorWatching) {
      state = current.withPhase(const BonusVerifying());
    }
    _flushBufferedResults();
  }

  Future<void> _onAdBreak(GameAdBreak message) async {
    final epoch = _epoch;
    _cancelTimers();
    _round = null;
    // Ads never play over audio (brief §6).
    try {
      await _host?.stop();
    } on Object {
      // Checked below: a player that could not be stopped means no ad.
    }
    if (_isStale(epoch)) return;
    final adsRemoved = ref
        .read(purchasesServiceProvider)
        .entitlements
        .adsRemoved;
    // `show_interstitial` is the server's per-player decision (it already
    // leaves out, e.g., the BYOP DJ whose music app may still play); on top
    // of it this device never shows one while its own player is playing.
    final localAudio = _host?.adapter.isPlaying ?? false;
    final interstitialAllowed =
        _monetizationAllowed &&
        _config.interstitialEnabled &&
        (_session?.config.interstitialEnabled ?? true) &&
        _ads.isInitialized &&
        !adsRemoved &&
        !localAudio;
    final analytics = ref.read(analyticsProvider);
    if (message.showInterstitial && interstitialAllowed) {
      state = GameAdBreakState(
        gameId: message.gameId,
        showingAd: true,
        showUpsell: false,
      );
      _adOnScreen = true;
      InterstitialOutcome outcome;
      try {
        outcome = await _ads.showInterstitial(maxWait: _config.maxAdWait);
      } on Object {
        outcome = const InterstitialOutcome(
          InterstitialResult.failedToShow,
          Duration.zero,
        );
      }
      _adOnScreen = false;
      if (_isStale(epoch)) return;
      final wire = switch (outcome.result) {
        InterstitialResult.shown => InterstitialWireResult.shown,
        InterstitialResult.skippedNotLoaded =>
          InterstitialWireResult.skippedNotLoaded,
        InterstitialResult.failedToShow => InterstitialWireResult.failedToShow,
        InterstitialResult.skippedNotEligible => null,
      };
      if (wire != null) {
        _session?.send(
          AdInterstitialResult(
            gameId: message.gameId,
            result: wire,
            waitMs: outcome.wait.inMilliseconds,
          ),
        );
      }
      unawaited(
        analytics.logEvent(AnalyticsEvents.adInterstitialResult, {
          AnalyticsParams.result: outcome.result.wireName,
          AnalyticsParams.waitMs: outcome.wait.inMilliseconds,
        }),
      );
    } else {
      unawaited(
        analytics.logEvent(AnalyticsEvents.adInterstitialResult, {
          AnalyticsParams.result:
              InterstitialResult.skippedNotEligible.wireName,
          AnalyticsParams.waitMs: 0,
        }),
      );
    }

    final showUpsell =
        message.showRemoveAdsUpsell &&
        !adsRemoved &&
        _config.removeAdsUpsellEnabled &&
        (_session?.config.removeAdsUpsellEnabled ?? true) &&
        purchasesEnabled(
          flavorAllowsMonetization: ref
              .read(appEnvProvider)
              .monetizationAllowed,
          config: _config,
        );
    if (showUpsell) {
      unawaited(
        analytics.logEvent(AnalyticsEvents.removeAdsUpsellView, {
          AnalyticsParams.placement: 'ad_break',
        }),
      );
    }
    if (_bufferedResults != null) {
      _flushBufferedResults();
      return;
    }
    state = GameAdBreakState(
      gameId: message.gameId,
      showingAd: false,
      showUpsell: showUpsell,
    );
  }

  void _onResults(GameResults message) {
    // A client still inside an ad shows the results when it closes.
    if (_adOnScreen) {
      _bufferedResults = message;
      return;
    }
    _finish(message);
  }

  void _flushBufferedResults() {
    final buffered = _bufferedResults;
    if (buffered == null || _adOnScreen) return;
    _bufferedResults = null;
    _finish(buffered);
  }

  void _finish(GameResults message) {
    _cancelTimers();
    _round = null;
    unawaited(_host?.stop());
    final rows = _standingRows(message.standings, gained: const {});
    _standings = message.standings;
    state = GameFinishedState(
      gameId: message.gameId,
      standings: rows,
      roundsPlayed: message.roundsPlayed,
      bonusUsed: message.bonusUsed,
      isHost: isHost,
    );
  }

  // --- helpers ---------------------------------------------------------------

  bool get _monetizationAllowed {
    final session = _session;
    return ref.read(appEnvProvider).monetizationAllowed &&
        _config.monetizationEnabled &&
        !_config.killSwitchAds &&
        (session?.config.monetizationEnabled ?? true) &&
        (session?.room?.capabilities.allowsMonetization ?? true);
  }

  bool get _rewardedAllowed =>
      _monetizationAllowed &&
      _config.rewardedEnabled &&
      (_session?.config.rewardedEnabled ?? true) &&
      _ads.isInitialized;

  /// The last planned round (the last regular one, or the spare that took
  /// its place): preload a rewarded ad and an interstitial (brief §6 step
  /// 1). Nothing is shown during the round.
  void _maybePreloadAds(RoundPrepare message) {
    if (message.kind == RoundKind.bonus ||
        _positionOf(message) != _roundsTotal ||
        !_monetizationAllowed ||
        !_ads.isInitialized) {
      return;
    }
    if (_rewardedAllowed && _config.rewardedPreloadEnabled) {
      unawaited(_ads.preloadRewarded());
    }
    final adsRemoved = ref
        .read(purchasesServiceProvider)
        .entitlements
        .adsRemoved;
    if (_config.interstitialEnabled && !adsRemoved) {
      unawaited(_ads.preloadInterstitial());
    }
  }

  HostPlaybackCoordinator? _hostCoordinator() {
    final session = _session;
    if (session == null || !session.isPlaybackDevice) return null;
    final provider = session.room?.provider ?? MusicProviderId.testCatalog;
    return _host ??= HostPlaybackCoordinator(
      adapter: ref.read(playbackAdapterFactoryProvider)(provider),
      send: session.send,
      log: kDebugMode ? (line) => debugPrint('[playback] $line') : null,
    );
  }

  List<StandingRow> _standingRows(
    List<Standing> standings, {
    required Map<String, int> gained,
  }) {
    final previousRank = {for (final s in _standings) s.playerId: s.rank};
    final me = _session?.playerId;
    final sorted = [...standings]
      ..sort((a, b) {
        final byRank = a.rank.compareTo(b.rank);
        return byRank != 0 ? byRank : b.points.compareTo(a.points);
      });
    return [
      for (final s in sorted)
        StandingRow(
          playerId: s.playerId,
          name: _nameOf(s.playerId),
          rank: s.rank,
          points: s.points,
          gained: gained[s.playerId] ?? 0,
          isMe: s.playerId == me,
          previousRank: previousRank[s.playerId],
          correctCount: s.correctCount,
        ),
    ];
  }

  String _nameOf(String playerId) => _session?.nameOf(playerId) ?? '—';

  void _cancelTimers() {
    _unlockTimer?.cancel();
    _timeUpTimer?.cancel();
    _unlockTimer = null;
    _timeUpTimer = null;
  }

  void _cancelVoidNotice() {
    _voidNoticeTimer?.cancel();
    _voidNoticeTimer = null;
    _voidNotice = null;
  }

  void _reset() {
    _cancelTimers();
    _cancelVoidNotice();
    _round = null;
    _gameId = null;
    _roundsTotal = 0;
    _revealedRounds.clear();
    _standings = const [];
    _bufferedResults = null;
    unawaited(_host?.stop());
    state = const GameIdle();
  }

  void _teardown() {
    _epoch++;
    for (final sub in _subs) {
      unawaited(sub.cancel());
    }
    _subs.clear();
    _cancelTimers();
    _cancelVoidNotice();
    _round = null;
    _gameId = null;
    _roundsTotal = 0;
    _revealedRounds.clear();
    _standings = const [];
    _bufferedResults = null;
    _adOnScreen = false;
    final host = _host;
    _host = null;
    if (host != null) unawaited(host.dispose());
  }
}
