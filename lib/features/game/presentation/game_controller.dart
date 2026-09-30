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

  bool unlockRequested = false;

  /// `nowMicros()` read when the unlock was requested, before the frame
  /// showing enabled buttons was built (a lower bound for the unlock).
  Future<int>? provisionalUnlockUs;

  /// `currentSystemFrameTimeStamp` of the first frame with enabled buttons.
  int? frameUnlockUs;

  String? committedOptionId;
  RoundAnswer? sentAnswer;
  bool acked = false;
}

/// Turns server messages into [GameUiState] and owns the timing-critical
/// client work (brief §5):
/// - scheduled rounds unlock with a local timer at `start_at_mono_us`;
///   host-reported rounds unlock on `round.start` (the host: on its own
///   playback start);
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
  String? _gameId;
  int _roundsTotal = 0;
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

  /// «Посмотри рекламу — +1 раунд для всех»: first `bonus.request` wins.
  Future<void> requestBonus() async {
    final current = state;
    if (current is! GameBonusState) return;
    final phase = current.phase;
    if (phase is! BonusOffered || !phase.canWatch) return;
    state = current.withPhase(const BonusRequested());
    // Limited-use App Check token (brief §7).
    final token = await ref.read(appCheckProvider).getLimitedUseToken();
    // TODO(protocol): the schema requires a token; without App Check (dev,
    // no Firebase) an empty one is sent and the server decides by
    // app_check_mode.
    _session?.send(
      BonusRequest(bonusId: current.bonusId, appCheckToken: token ?? ''),
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
    // The socket dropped between the answer and its ack: send it again. A
    // duplicate is harmless (first answer wins; ack `duplicate`).
    final runtime = _round;
    final answer = runtime?.sentAnswer;
    if (runtime != null && answer != null && !runtime.acked) {
      _session?.send(answer);
    }
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
    _round = runtime;
    _roundsTotal = math.max(_roundsTotal, message.roundIndex + 1);
    state = GameRoundState(
      round: RoundView.fromPrepare(message, roundsTotal: _roundsTotal),
      phase: message.youAreOwner
          ? const RoundOwnerWatching()
          : const RoundLocked(),
    );
    _maybePreloadAds(message);

    final host = message.clip == null ? null : _hostCoordinator();
    if (host != null) {
      unawaited(
        host.playRound(message).then((started) {
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
    if (message.audioStartSource == AudioStartSource.scheduled) {
      unawaited(_scheduleUnlock(runtime));
    }
  }

  Future<void> _scheduleUnlock(_RoundRuntime runtime) async {
    final epoch = _epoch;
    final now = await _clock.nowMicros();
    if (_isStale(epoch) || _round != runtime) return;
    final delayUs = runtime.prepare.startAtMonoUs - now;
    if (delayUs <= 0) {
      _unlock(runtime);
      return;
    }
    _unlockTimer?.cancel();
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
    if (runtime.prepare.audioStartSource == AudioStartSource.hostReported) {
      _unlock(runtime);
    }
  }

  void _unlock(_RoundRuntime runtime) {
    if (_round != runtime ||
        runtime.unlockRequested ||
        runtime.prepare.youAreOwner) {
      return;
    }
    runtime
      ..unlockRequested = true
      ..provisionalUnlockUs = _clock.nowMicros();
    final current = state;
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
    final clock = _clock;
    final provisional =
        await (runtime.provisionalUnlockUs ?? clock.nowMicros());
    final now = await clock.nowMicros();
    final unlock = MonoTimestamps.resolveUnlock(
      provisionalUs: provisional,
      frameUs: runtime.frameUnlockUs,
      nowUs: now,
    );
    final tap = rawTapUs == null
        ? now
        : MonoTimestamps.resolveTap(
            tapUs: rawTapUs,
            unlockUs: unlock,
            nowUs: now,
          );
    if (_round != runtime) return;
    final answer = RoundAnswer(
      roundId: runtime.roundId,
      nonce: runtime.prepare.nonce,
      optionId: optionId,
      tapMonoUs: tap,
      unlockMonoUs: unlock,
    );
    runtime.sentAnswer = answer;
    _session?.send(answer);
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
    state = GameVoidedState(
      reason: message.reason,
      round: current is GameRoundState ? current.round : null,
    );
  }

  void _onReveal(RoundReveal message) {
    _cancelTimers();
    final runtime = _round?.roundId == message.roundId ? _round : null;
    final current = state;
    final view =
        current is GameRoundState && current.round.roundId == message.roundId
        ? current.round
        : runtime != null
        ? RoundView.fromPrepare(runtime.prepare, roundsTotal: _roundsTotal)
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
    state = GameRevealState(
      RevealView(
        round:
            view ??
            RoundView(
              roundId: message.roundId,
              roundIndex: 0,
              roundsTotal: _roundsTotal,
              kind: RoundKind.regular,
              prompt: GameMode.whoseSong,
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
    await _host?.stop();
    if (_isStale(epoch)) return;
    final adsRemoved = ref
        .read(purchasesServiceProvider)
        .entitlements
        .adsRemoved;
    final interstitialAllowed =
        _monetizationAllowed &&
        _config.interstitialEnabled &&
        (_session?.config.interstitialEnabled ?? true) &&
        _ads.isInitialized &&
        !adsRemoved;
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
        (session?.room?.provider.allowsMonetization ?? true);
  }

  bool get _rewardedAllowed =>
      _monetizationAllowed &&
      _config.rewardedEnabled &&
      (_session?.config.rewardedEnabled ?? true) &&
      _ads.isInitialized;

  /// The last regular round: preload a rewarded ad and an interstitial
  /// (brief §6 step 1). Nothing is shown during the round.
  void _maybePreloadAds(RoundPrepare message) {
    if (message.kind != RoundKind.regular ||
        message.roundIndex != _roundsTotal - 1 ||
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

  void _reset() {
    _cancelTimers();
    _round = null;
    _gameId = null;
    _roundsTotal = 0;
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
    _round = null;
    _gameId = null;
    _roundsTotal = 0;
    _standings = const [];
    _bufferedResults = null;
    _adOnScreen = false;
    final host = _host;
    _host = null;
    if (host != null) unawaited(host.dispose());
  }
}
