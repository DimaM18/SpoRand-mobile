import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

/// Delegates to the fake clock until [failing] is set, then throws like a
/// broken platform channel would.
class _FlakySource implements InputClockSource {
  _FlakySource(this._inner);

  final FakeInputClockSource _inner;
  bool failing = false;

  @override
  Future<int> nowOsUs() async {
    if (failing) throw PlatformException(code: 'channel-error');
    return _inner.nowOsUs();
  }
}

void main() {
  GameHarness harness(
    FakeAsync async, {
    String me = Samples.guestId,
    GatedAdsService? ads,
    FakePlaybackAdapter? playback,
  }) {
    final h = GameHarness(
      clock: async.getClock(DateTime(2026, 9, 30)),
      flush: async.flushMicrotasks,
      me: me,
      ads: ads,
      playback: playback,
    );
    addTearDown(h.dispose);
    h.welcome();
    return h;
  }

  test('full round: unlock at start_at, first tap commits with its '
      'timestamp, second tap ignored, reveal updates standings', () {
    fakeAsync((async) {
      final h = harness(async);
      expect(h.state, isA<GameIdle>());

      h.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 10,
          countdownMs: 3000,
        ),
      );
      expect(h.state, isA<GameStartingState>());

      final startAt = h.inputClock.monoNowUs + 2500000;
      h.send(Samples.prepare(startAtMonoUs: startAt));
      final locked = h.state as GameRoundState;
      expect(locked.phase, isA<RoundLocked>());
      expect(locked.round.options.map((o) => o.optionId), [
        'opt-a',
        'opt-b',
        'opt-c',
      ], reason: 'per-player order from the server is kept');
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-c',
          tapMonoUs: startAt - 1,
        ),
        isFalse,
        reason: 'no answers before the unlock',
      );

      async.elapse(const Duration(milliseconds: 2499));
      expect((h.state as GameRoundState).phase, isA<RoundLocked>());
      async.elapse(const Duration(milliseconds: 2));
      expect((h.state as GameRoundState).phase, isA<RoundOpen>());

      // The answer grid reports the frame that first showed the buttons.
      final frameUs = startAt + 8000;
      h.controller.onAnswerButtonsShown('round-1', frameUs);

      async.elapse(const Duration(milliseconds: 700));
      final tapUs = h.inputClock.monoNowUs - 15000;
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-c',
          tapMonoUs: tapUs,
        ),
        isTrue,
      );
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-b',
          tapMonoUs: tapUs + 90000,
        ),
        isFalse,
        reason: 'single tap, no change',
      );
      async.flushMicrotasks();

      final answer = h.received<RoundAnswer>().single;
      expect(answer.roundId, 'round-1');
      expect(answer.nonce, Samples.prepare(startAtMonoUs: 0).nonce);
      expect(answer.optionId, 'opt-c');
      expect(answer.tapMonoUs, tapUs);
      expect(answer.unlockMonoUs, frameUs);
      final answered = (h.state as GameRoundState).phase as RoundAnswered;
      expect(answered.optionId, 'opt-c');
      expect(answered.ack, AnswerAckStatus.pending);

      h.send(const RoundAnswerAck(roundId: 'round-1', accepted: true));
      expect(
        ((h.state as GameRoundState).phase as RoundAnswered).ack,
        AnswerAckStatus.accepted,
      );
      h.send(
        const RoundProgress(
          roundId: 'round-1',
          answeredCount: 2,
          eligibleCount: 2,
        ),
      );
      expect((h.state as GameRoundState).answeredCount, 2);

      h.send(Samples.reveal());
      final reveal = (h.state as GameRevealState).reveal;
      expect(reveal.correct, isTrue);
      expect(reveal.myResult?.points, 986);
      expect(reveal.myOptionId, 'opt-c');
      expect(reveal.correctLabel, 'Celina');
      expect(reveal.ownerNames, ['Celina']);
      expect(reveal.standings.first.name, 'Bartek');
      expect(reveal.standings.first.isMe, isTrue);
      expect(reveal.standings.first.gained, 986);
      expect(h.received<RoundAnswer>(), hasLength(1));
    });
  });

  test('the track owner sees no buttons and cannot answer', () {
    fakeAsync((async) {
      final h = harness(async);
      final startAt = h.inputClock.monoNowUs + 1000000;
      h.send(Samples.prepare(startAtMonoUs: startAt, youAreOwner: true));
      final state = h.state as GameRoundState;
      expect(state.showsButtons, isFalse);
      expect(state.phase, isA<RoundOwnerWatching>());
      async.elapse(const Duration(seconds: 2));
      expect((h.state as GameRoundState).phase, isA<RoundOwnerWatching>());
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-a',
          tapMonoUs: startAt,
        ),
        isFalse,
      );
      async.flushMicrotasks();
      expect(h.received<RoundAnswer>(), isEmpty);
    });
  });

  test('host-reported rounds unlock guests on round.start', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(
        Samples.prepare(
          startAtMonoUs: h.inputClock.monoNowUs + 500000,
          source: AudioStartSource.hostReported,
        ),
      );
      async.elapse(const Duration(seconds: 2));
      expect((h.state as GameRoundState).phase, isA<RoundLocked>());
      h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
      expect((h.state as GameRoundState).phase, isA<RoundOpen>());
    });
  });

  test('a frame timestamp on another clock base falls back safely', () {
    fakeAsync((async) {
      final h = harness(async);
      final startAt = h.inputClock.monoNowUs + 100000;
      h.send(Samples.prepare(startAtMonoUs: startAt));
      async.elapse(const Duration(milliseconds: 100));
      final unlockedAt = h.inputClock.monoNowUs;
      // e.g. a frame clock that kept counting while the device slept.
      h.controller.onAnswerButtonsShown('round-1', unlockedAt + 3600000000);
      async.elapse(const Duration(milliseconds: 500));
      final tapUs = h.inputClock.monoNowUs - 5000;
      h.controller.tap(roundId: 'round-1', optionId: 'opt-a', tapMonoUs: tapUs);
      async.flushMicrotasks();
      final answer = h.received<RoundAnswer>().single;
      expect(answer.unlockMonoUs, unlockedAt);
      expect(answer.tapMonoUs, tapUs);
    });
  });

  test('an unacked answer is sent again after a reconnect', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs));
      async.flushMicrotasks();
      h.controller.tap(
        roundId: 'round-1',
        optionId: 'opt-b',
        tapMonoUs: h.inputClock.monoNowUs,
      );
      async.flushMicrotasks();
      h.server.current.serverClose(1006);
      async.elapse(const Duration(seconds: 1));
      h.send(
        Samples.welcome(room: Samples.room(state: RoomState.roundPlaying)),
      );
      async.flushMicrotasks();
      final answers = h.received<RoundAnswer>();
      expect(answers, hasLength(2), reason: 'once per connection');
      expect(answers.map((a) => a.tapMonoUs).toSet(), hasLength(1));
      // The server has it already: `duplicate` counts as accepted.
      h.send(
        const RoundAnswerAck(
          roundId: 'round-1',
          accepted: false,
          reason: AnswerValidation.duplicate,
        ),
      );
      expect(
        ((h.state as GameRoundState).phase as RoundAnswered).ack,
        AnswerAckStatus.accepted,
      );
    });
  });

  test('an answer given while the socket reconnects is sent exactly once', () {
    // Regression: the WsClient outbox flushed the queued answer after
    // `welcome` and the controller resent it on WsConnected as well.
    fakeAsync((async) {
      final h = harness(async);
      h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs));
      async.flushMicrotasks();
      h.server.current.serverClose(1006);
      async.flushMicrotasks();
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-b',
          tapMonoUs: h.inputClock.monoNowUs,
        ),
        isTrue,
      );
      async.flushMicrotasks();
      expect(h.received<RoundAnswer>(), isEmpty, reason: 'queued offline');

      async.elapse(const Duration(seconds: 1));
      h.send(
        Samples.welcome(room: Samples.room(state: RoomState.roundPlaying)),
      );
      async.flushMicrotasks();
      expect(h.received<RoundAnswer>(), hasLength(1));

      // Still unacked when this connection drops too: sent once more.
      h.server.current.serverClose(1006);
      async.elapse(const Duration(seconds: 1));
      h.send(
        Samples.welcome(room: Samples.room(state: RoomState.roundPlaying)),
      );
      async.flushMicrotasks();
      expect(h.received<RoundAnswer>(), hasLength(2));
      h.send(const RoundAnswerAck(roundId: 'round-1', accepted: true));

      // Acked: a later reconnect sends nothing.
      h.server.current.serverClose(1006);
      async.elapse(const Duration(seconds: 1));
      h.send(
        Samples.welcome(room: Samples.room(state: RoomState.roundPlaying)),
      );
      async.flushMicrotasks();
      expect(h.received<RoundAnswer>(), hasLength(2));
    });
  });

  test('a failing input clock read never loses a committed answer', () {
    // Regression: the answer was built after awaiting the input clock; when
    // that read threw, the tap showed as sent but nothing went out.
    fakeAsync((async) {
      late _FlakySource flaky;
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        gameClock: (inner) => InputClock(
          flaky = _FlakySource(inner.source),
          anchorUs: inner.anchorUs,
        ),
      );
      addTearDown(h.dispose);
      h.welcome();
      h.send(
        Samples.prepare(
          startAtMonoUs: h.inputClock.monoNowUs + 500000,
          source: AudioStartSource.hostReported,
        ),
      );
      async.elapse(const Duration(milliseconds: 600));
      flaky.failing = true;
      h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
      final frameUs = h.inputClock.monoNowUs + 8000;
      h.controller.onAnswerButtonsShown('round-1', frameUs);
      async.elapse(const Duration(milliseconds: 400));
      final tapUs = h.inputClock.monoNowUs - 10000;
      expect(
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-a',
          tapMonoUs: tapUs,
        ),
        isTrue,
      );
      async.flushMicrotasks();

      final answer = h.received<RoundAnswer>().single;
      expect(answer.tapMonoUs, tapUs, reason: 'the OS touch time is kept');
      expect(answer.unlockMonoUs, frameUs);
    });
  });

  test('round.voided shows the banner state and stops playback', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs + 1000000));
      h.send(
        const RoundVoided(
          roundId: 'round-1',
          reason: RoundVoidReason.playbackTimeout,
        ),
      );
      final voided = h.state as GameVoidedState;
      expect(voided.reason, RoundVoidReason.playbackTimeout);
      async.elapse(const Duration(seconds: 2));
      expect(
        h.state,
        isA<GameVoidedState>(),
        reason: 'the timer was cancelled',
      );
      h.send(
        Samples.prepare(
          roundId: 'spare-1',
          startAtMonoUs: h.inputClock.monoNowUs + 1000000,
          kind: RoundKind.spare,
        ),
      );
      expect((h.state as GameRoundState).round.roundId, 'spare-1');
    });
  });

  test('game.results arriving during the interstitial wait for it', () {
    fakeAsync((async) {
      final ads = GatedAdsService();
      final h = harness(async, ads: ads);
      h.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 1,
          countdownMs: 0,
        ),
      );
      h.send(
        const GameAdBreak(
          gameId: Samples.gameId,
          resultsRevealAtServerMs: 1,
          showInterstitial: true,
          showRemoveAdsUpsell: true,
        ),
      );
      expect((h.state as GameAdBreakState).showingAd, isTrue);
      expect(ads.interstitial, isNotNull);

      h.send(Samples.results());
      expect(h.state, isA<GameAdBreakState>(), reason: 'buffered');

      ads.interstitial!.complete(
        const InterstitialOutcome(
          InterstitialResult.shown,
          Duration(milliseconds: 240),
        ),
      );
      async.flushMicrotasks();
      final finished = h.state as GameFinishedState;
      expect(finished.standings.first.name, 'Bartek');
      expect(finished.roundsPlayed, 10);

      final report = h.received<AdInterstitialResult>().single;
      expect(report.result, InterstitialWireResult.shown);
      expect(report.waitMs, 240);
      final event = h.analyticsBackend
          .named(AnalyticsEvents.adInterstitialResult)
          .single;
      expect(event.params, {'result': 'shown', 'wait_ms': 240});
      expect(
        h.analyticsBackend
            .named(AnalyticsEvents.removeAdsUpsellView)
            .single
            .params,
        {'placement': 'ad_break'},
      );
    });
  });

  test('without an interstitial the counting screen shows the upsell', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(
        const GameAdBreak(
          gameId: Samples.gameId,
          resultsRevealAtServerMs: 1,
          showInterstitial: false,
          showRemoveAdsUpsell: true,
        ),
      );
      final adBreak = h.state as GameAdBreakState;
      expect(adBreak.showingAd, isFalse);
      expect(adBreak.showUpsell, isTrue);
      expect(h.received<AdInterstitialResult>(), isEmpty);
      expect(
        h.analyticsBackend
            .named(AnalyticsEvents.adInterstitialResult)
            .single
            .params,
        {'result': 'skipped_not_eligible', 'wait_ms': 0},
      );
      h.send(Samples.results());
      expect(h.state, isA<GameFinishedState>());
    });
  });

  test('bonus: offer, request with a limited-use token, rewarded ad with '
      'SSV options, ad result', () {
    fakeAsync((async) {
      final ads = GatedAdsService();
      final h = harness(async, ads: ads);
      h.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 1,
          countdownMs: 0,
        ),
      );
      h.send(
        const GameBonusOffer(
          bonusId: 'bonus-1',
          expiresAtServerMs: 1,
          eligiblePlayerIds: [Samples.guestId],
        ),
      );
      final offer = (h.state as GameBonusState).phase as BonusOffered;
      expect(offer.canWatch, isTrue);
      expect(
        h.analyticsBackend
            .named(AnalyticsEvents.adRewardedOfferView)
            .single
            .params,
        {'game_id': Samples.gameId},
      );

      h.controller.requestBonus();
      async.flushMicrotasks();
      final request = h.received<BonusRequest>().single;
      expect(request.bonusId, 'bonus-1');
      expect(request.appCheckToken, 'limited-use-token-123');

      h.send(
        const BonusSponsorLocked(
          bonusId: 'bonus-1',
          sponsorPlayerId: Samples.guestId,
          expiresAtServerMs: 1,
        ),
      );
      expect(
        ((h.state as GameBonusState).phase as BonusSponsorWatching).isMe,
        isTrue,
      );
      h.send(
        const BonusNonce(
          bonusId: 'bonus-1',
          rewardNonce: 'nonce_1a2b3c4d5e6f7a8b9c0d',
          ssvUserId: 'ssv_9f8e7d6c5b4a3f2e1d0c',
        ),
      );
      expect(ads.ssvUserId, 'ssv_9f8e7d6c5b4a3f2e1d0c');
      expect(ads.rewardNonce, 'nonce_1a2b3c4d5e6f7a8b9c0d');
      ads.rewarded!.complete(RewardedResult.earned);
      async.flushMicrotasks();

      final result = h.received<BonusAdResult>().single;
      expect(result.status, BonusAdStatus.earned);
      expect((h.state as GameBonusState).phase, isA<BonusVerifying>());
      expect(
        h.analyticsBackend
            .named(AnalyticsEvents.adRewardedResult)
            .single
            .params,
        {'result': 'earned'},
      );

      h.send(
        const BonusGranted(
          bonusId: 'bonus-1',
          sponsorPlayerId: Samples.guestId,
          roundsAdded: 1,
        ),
      );
      final granted = (h.state as GameBonusState).phase as BonusGrantedPhase;
      expect(granted.sponsorName, 'Bartek');
    });
  });

  test('another player sponsoring shows their name; ineligible players '
      'cannot request', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(
        const GameBonusOffer(
          bonusId: 'bonus-1',
          expiresAtServerMs: 1,
          eligiblePlayerIds: [Samples.thirdId],
        ),
      );
      expect(
        ((h.state as GameBonusState).phase as BonusOffered).canWatch,
        isFalse,
      );
      h.controller.requestBonus();
      async.flushMicrotasks();
      expect(h.received<BonusRequest>(), isEmpty);
      h.send(
        const BonusSponsorLocked(
          bonusId: 'bonus-1',
          sponsorPlayerId: Samples.thirdId,
          expiresAtServerMs: 1,
        ),
      );
      final watching =
          (h.state as GameBonusState).phase as BonusSponsorWatching;
      expect(watching.sponsorName, 'Celina');
      expect(watching.isMe, isFalse);
    });
  });

  test('the host plays the clip at start_at and reports it', () {
    fakeAsync((async) {
      final playback = FakePlaybackAdapter(outputLatencyMs: 23);
      final h = harness(async, me: Samples.hostId, playback: playback);
      final startAt = h.inputClock.monoNowUs + 2500000;
      h.send(Samples.prepare(startAtMonoUs: startAt, clip: Samples.urlClip));
      async.flushMicrotasks();
      final clip = playback.prepared.single as UrlRoundClip;
      expect(clip.clipUrl, Samples.urlClip.clipUrl);
      expect(clip.snippetStartMs, 42000);
      expect(playback.playedAt, [startAt]);
      final preloaded = h.received<RoundPreloaded>().single;
      expect(preloaded.ok, isTrue);
      final started = h.received<RoundPlaybackStarted>().single;
      expect(started.audioStartMonoUs, startAt);
      expect(started.outputLatencyMs, 23);
      expect(started.source, PlaybackStartSource.scheduled);
    });
  });

  test('a playback failure is reported to the server', () {
    fakeAsync((async) {
      final playback = FakePlaybackAdapter(prepareOk: false);
      final h = harness(async, me: Samples.hostId, playback: playback);
      h.send(
        Samples.prepare(
          startAtMonoUs: h.inputClock.monoNowUs + 1000,
          clip: Samples.urlClip,
        ),
      );
      async.flushMicrotasks();
      expect(h.received<RoundPreloaded>().single.ok, isFalse);
      expect(
        h.received<RoundPlaybackFailed>().single.reason,
        'clip_load_failed',
      );
      expect(h.received<RoundPlaybackStarted>(), isEmpty);
    });
  });

  test('the last regular round preloads the rewarded ad and interstitial', () {
    fakeAsync((async) {
      final ads = GatedAdsService();
      final h = harness(async, ads: ads);
      h.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 2,
          countdownMs: 0,
        ),
      );
      h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs + 1000));
      expect(ads.rewardedPreloads, 0);
      h.send(
        Samples.prepare(
          roundId: 'round-2',
          roundIndex: 1,
          startAtMonoUs: h.inputClock.monoNowUs + 1000,
        ),
      );
      async.flushMicrotasks();
      expect(ads.rewardedPreloads, 1);
      expect(ads.interstitialPreloads, 1);
    });
  });

  test('round numbers follow play order: a spare takes the voided round\'s '
      'place and a bonus round comes last, whatever their round_index', () {
    // Found by test_e2e: round_index is the plan index, and the server plans
    // spares after every regular round, so the first spare of a 3-round game
    // has round_index 3. It showed «Раунд 4 из 4» and pushed the total to 4,
    // so the real last round (index 2) no longer preloaded the ads.
    fakeAsync((async) {
      final ads = GatedAdsService();
      final h = harness(async, ads: ads);
      h.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 3,
          countdownMs: 0,
        ),
      );
      (int, int) shown() {
        final round = (h.state as GameRoundState).round;
        return (round.number, round.roundsTotal);
      }

      void prepare(String id, int index, RoundKind kind) => h.send(
        Samples.prepare(
          roundId: id,
          roundIndex: index,
          kind: kind,
          startAtMonoUs: h.inputClock.monoNowUs + 1000,
        ),
      );

      prepare('r0', 0, RoundKind.regular);
      expect(shown(), (1, 3));
      h.send(
        const RoundVoided(
          roundId: 'r0',
          reason: RoundVoidReason.playbackTimeout,
        ),
      );
      prepare('spare-3', 3, RoundKind.spare);
      expect(shown(), (1, 3));
      h.send(Samples.reveal(roundId: 'spare-3'));
      prepare('r1', 1, RoundKind.regular);
      expect(shown(), (2, 3));
      h.send(Samples.reveal(roundId: 'r1'));
      expect(ads.rewardedPreloads, 0);
      prepare('r2', 2, RoundKind.regular);
      expect(shown(), (3, 3));
      async.flushMicrotasks();
      expect(ads.rewardedPreloads, 1, reason: 'the last round preloads');
      h.send(Samples.reveal(roundId: 'r2'));

      h.send(
        const BonusGranted(
          bonusId: 'bonus-1',
          sponsorPlayerId: Samples.hostId,
          roundsAdded: 1,
        ),
      );
      prepare('bonus-4', 4, RoundKind.bonus);
      expect(shown(), (4, 4));
    });
  });

  test('back in the lobby (play again) resets to idle', () {
    fakeAsync((async) {
      final h = harness(async);
      h.send(Samples.results());
      expect(h.state, isA<GameFinishedState>());
      h.send(RoomStateMessage(Samples.room()));
      expect(h.state, isA<GameIdle>());
    });
  });
}
