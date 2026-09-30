import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

void main() {
  GameHarness harness(
    FakeAsync async, {
    String me = Samples.guestId,
    GatedAdsService? ads,
    FakePlaybackAdapter? playback,
    Map<String, Object?>? config,
  }) {
    final h = GameHarness(
      clock: async.getClock(DateTime(2026, 9, 30)),
      flush: async.flushMicrotasks,
      me: me,
      ads: ads,
      playback: playback,
    );
    addTearDown(h.dispose);
    if (config == null) {
      h.welcome();
    } else {
      h.send(Samples.welcome(me: me, config: config));
    }
    return h;
  }

  const voided = RoundVoided(
    roundId: 'round-1',
    reason: RoundVoidReason.playbackTimeout,
  );

  group('void notice (void_notice_ms)', () {
    test('a spare that arrives early keeps the notice until void_notice_ms, '
        'and the notice never holds the round back', () {
      fakeAsync((async) {
        final h = harness(async, config: const {'void_notice_ms': 2000});
        h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs));
        h.send(voided);
        async.elapse(const Duration(milliseconds: 300));
        h.send(
          Samples.prepare(
            roundId: 'spare-1',
            kind: RoundKind.spare,
            startAtMonoUs: h.inputClock.monoNowUs + 500000,
          ),
        );
        var state = h.state as GameRoundState;
        expect(state.round.roundId, 'spare-1');
        expect(state.voidNotice, RoundVoidReason.playbackTimeout);

        // The spare opens on schedule under the notice.
        async.elapse(const Duration(milliseconds: 600));
        state = h.state as GameRoundState;
        expect(state.phase, isA<RoundOpen>());
        expect(state.voidNotice, isNotNull);
        expect(
          h.controller.tap(
            roundId: 'spare-1',
            optionId: 'opt-a',
            tapMonoUs: h.inputClock.monoNowUs,
          ),
          isTrue,
        );

        // 2000 ms after round.voided the notice goes; the answer stays.
        async.elapse(const Duration(milliseconds: 1200));
        state = h.state as GameRoundState;
        expect(state.voidNotice, isNull);
        expect(state.phase, isA<RoundAnswered>());
        expect(h.received<RoundAnswer>().single.roundId, 'spare-1');
      });
    });

    test('without the key the notice lasts the default 1500 ms', () {
      fakeAsync((async) {
        final h = harness(async);
        h.send(voided);
        async.elapse(const Duration(milliseconds: 1400));
        h.send(
          Samples.prepare(
            roundId: 'spare-1',
            kind: RoundKind.spare,
            startAtMonoUs: h.inputClock.monoNowUs + 1000000,
          ),
        );
        expect((h.state as GameRoundState).voidNotice, isNotNull);
        async.elapse(const Duration(milliseconds: 150));
        expect((h.state as GameRoundState).voidNotice, isNull);
      });
    });

    test('a spare after the notice ended starts without it', () {
      fakeAsync((async) {
        final h = harness(async, config: const {'void_notice_ms': 500});
        h.send(voided);
        async.elapse(const Duration(milliseconds: 600));
        expect(h.state, isA<GameVoidedState>());
        h.send(
          Samples.prepare(
            roundId: 'spare-1',
            kind: RoundKind.spare,
            startAtMonoUs: h.inputClock.monoNowUs + 1000000,
          ),
        );
        expect((h.state as GameRoundState).voidNotice, isNull);
      });
    });
  });

  group('interstitial', () {
    GameAdBreak adBreak({bool show = true}) => GameAdBreak(
      gameId: Samples.gameId,
      resultsRevealAtServerMs: 1,
      showInterstitial: show,
      showRemoveAdsUpsell: false,
    );

    test('never while the local player is still playing, even when the '
        'server says show_interstitial', () {
      fakeAsync((async) {
        final ads = GatedAdsService();
        final playback = FakePlaybackAdapter()..stopSilences = false;
        final h = harness(
          async,
          me: Samples.hostId,
          ads: ads,
          playback: playback,
        );
        h.send(
          Samples.prepare(
            startAtMonoUs: h.inputClock.monoNowUs,
            clip: Samples.urlClip,
          ),
        );
        async.flushMicrotasks();
        expect(playback.isPlaying, isTrue);

        h.send(adBreak());
        async.flushMicrotasks();
        expect(playback.stops, greaterThan(0), reason: 'it tried to stop');
        expect((h.state as GameAdBreakState).showingAd, isFalse);
        expect(ads.interstitial, isNull);
        expect(h.received<AdInterstitialResult>(), isEmpty);
        expect(
          h.analyticsBackend
              .named(AnalyticsEvents.adInterstitialResult)
              .single
              .params['result'],
          'skipped_not_eligible',
        );
      });
    });

    test('shown once the local player is silent', () {
      fakeAsync((async) {
        final ads = GatedAdsService();
        final playback = FakePlaybackAdapter();
        final h = harness(
          async,
          me: Samples.hostId,
          ads: ads,
          playback: playback,
        );
        h.send(
          Samples.prepare(
            startAtMonoUs: h.inputClock.monoNowUs,
            clip: Samples.urlClip,
          ),
        );
        async.flushMicrotasks();
        h.send(adBreak());
        async.flushMicrotasks();
        expect(playback.isPlaying, isFalse);
        expect((h.state as GameAdBreakState).showingAd, isTrue);
        expect(ads.interstitial, isNotNull);
      });
    });

    test('show_interstitial false (e.g. the BYOP DJ) means no ad', () {
      fakeAsync((async) {
        final ads = GatedAdsService();
        final h = harness(async, me: Samples.hostId, ads: ads);
        h.send(adBreak(show: false));
        async.flushMicrotasks();
        expect((h.state as GameAdBreakState).showingAd, isFalse);
        expect(ads.interstitial, isNull);
      });
    });
  });
}
