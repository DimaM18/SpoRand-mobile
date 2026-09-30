// Timing rules of brief §5 on the client: the process anchor never changes
// what the server computes, and `start_at` follows the latest clock offset.
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

/// The server's clock (`server_us`), advancing with fake time; the device's
/// input clock follows the same fake time until a test makes it sleep.
final class _ServerClock {
  _ServerClock(this.async) : _origin = async.elapsed;

  static const startUs = 1759212345000000;

  final FakeAsync async;
  final Duration _origin;

  int get nowUs => startUs + (async.elapsed - _origin).inMicroseconds;

  int get nowMs => nowUs ~/ 1000;
}

ClockResult _result(int offsetUs) => ClockResult(
  offsetUs: offsetUs,
  rttMinUs: 20000,
  samples: 8,
  quality: ClockQuality.good,
);

RoundPhase _phase(GameHarness h) => (h.state as GameRoundState).phase;

final class _BrokenSource implements InputClockSource {
  @override
  Future<int> nowOsUs() async => throw StateError('input clock unavailable');
}

void main() {
  test('the server clock math is invariant to the process anchor '
      '(same reaction and unlock for any anchor)', () {
    final outcomes = <int, (int, int)>{};
    final wireTaps = <int>{};
    // The harness OS clock starts at 1000 s; the anchor is read earlier.
    for (final anchorUs in [0, GameHarness.defaultAnchorUs, 999000000]) {
      fakeAsync((async) {
        final h = GameHarness(
          clock: async.getClock(DateTime(2026, 9, 30)),
          flush: async.flushMicrotasks,
          anchorUs: anchorUs,
        );
        addTearDown(h.dispose);
        h.welcome();
        final server = _ServerClock(async);

        // Clock sync as the server runs it (brief §5.3):
        // offset = t2 − (t1 + t4) / 2, with t4 stamped on receipt.
        final t1 = server.nowUs;
        h.send(ClockPing(pingId: 'ping-1', t1ServerUs: t1));
        final pong = h.received<ClockPong>().single;
        final t4 = server.nowUs;
        final offsetUs = pong.t2MonoUs - (t1 + t4) ~/ 2;
        h.send(_result(offsetUs));

        final startAtServerMs = server.nowMs + 2500;
        h.send(
          Samples.prepare(
            startAtServerMs: startAtServerMs,
            startAtMonoUs: startAtServerMs * 1000 + offsetUs,
          ),
        );
        async.elapse(const Duration(milliseconds: 2500));
        expect(_phase(h), isA<RoundOpen>());
        // The answer grid reports the frame that showed the buttons.
        h.controller.onAnswerButtonsShown('round-1', h.inputClock.monoNowUs);

        // The OS stamped the touch 15 ms before Flutter handled it, 700 ms
        // after the start; the pointer time goes through the anchor.
        async.elapse(const Duration(milliseconds: 700));
        final tapMonoUs = h.inputClock.fromOsUs(h.inputClock.nowUs - 15000);
        h.controller.tap(
          roundId: 'round-1',
          optionId: 'opt-a',
          tapMonoUs: tapMonoUs,
        );
        async.flushMicrotasks();
        final answer = h.received<RoundAnswer>().single;
        wireTaps.add(answer.tapMonoUs);

        // Server side (brief §5.7): device times -> server time.
        int toServerMs(int monoUs) => ((monoUs - offsetUs) / 1000).round();
        outcomes[anchorUs] = (
          toServerMs(answer.tapMonoUs) - startAtServerMs,
          toServerMs(answer.unlockMonoUs) - startAtServerMs,
        );
      });
    }
    expect(wireTaps, hasLength(3), reason: 'the anchor changes wire values');
    expect(outcomes.values.toSet(), {(685, 0)});
  });

  test('without a clock.result the server start_at_mono_us is used', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
      );
      addTearDown(h.dispose);
      h.welcome();
      h.send(
        Samples.prepare(
          startAtServerMs: 1,
          startAtMonoUs: h.inputClock.monoNowUs + 1000000,
        ),
      );
      async.elapse(const Duration(milliseconds: 999));
      expect(_phase(h), isA<RoundLocked>());
      async.elapse(const Duration(milliseconds: 2));
      expect(_phase(h), isA<RoundOpen>());
    });
  });

  test('unlock follows start_at_server_ms + the latest clock.result offset: '
      'after a sleep and reconnect the new offset moves a pending unlock', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
      );
      addTearDown(h.dispose);
      h.welcome();
      final server = _ServerClock(async);
      final offsetBefore = h.inputClock.monoNowUs - server.nowUs;
      h.send(_result(offsetBefore));

      // The device sleeps for 5 s: its input clock stops, the server's does
      // not, so the true offset shrinks by 5 s. The socket drops meanwhile.
      h.server.current.serverClose(1006);
      h.inputClock.advance(const Duration(seconds: -5));
      async.elapse(const Duration(seconds: 5));
      h.send(
        Samples.welcome(room: Samples.room(state: RoomState.roundPlaying)),
      );
      final offsetAfter = h.inputClock.monoNowUs - server.nowUs;
      expect(offsetBefore - offsetAfter, 5000000);

      // round.prepare arrives before the re-sync burst finished: both the
      // server's start_at_mono_us and the client's last offset are stale.
      final startAtServerMs = server.nowMs + 2500;
      h.send(
        Samples.prepare(
          startAtServerMs: startAtServerMs,
          startAtMonoUs: startAtServerMs * 1000 + offsetBefore,
        ),
      );
      async.elapse(const Duration(milliseconds: 100));
      h.send(_result(offsetAfter));

      // Opens 2.5 s after prepare in server time, not 5 s later.
      async.elapse(const Duration(milliseconds: 2399));
      expect(_phase(h), isA<RoundLocked>());
      async.elapse(const Duration(milliseconds: 2));
      expect(_phase(h), isA<RoundOpen>());
    });
  });

  test('the host plays the clip at start_at_server_ms + the latest offset', () {
    fakeAsync((async) {
      final playback = FakePlaybackAdapter();
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        me: Samples.hostId,
        playback: playback,
      );
      addTearDown(h.dispose);
      h.welcome();
      final server = _ServerClock(async);
      final offsetUs = h.inputClock.monoNowUs - server.nowUs;
      h.send(_result(offsetUs));
      final startAtServerMs = server.nowMs + 2500;
      h.send(
        Samples.prepare(
          startAtServerMs: startAtServerMs,
          // Stale by 3 s (converted before the latest burst).
          startAtMonoUs: startAtServerMs * 1000 + offsetUs + 3000000,
          clip: Samples.urlClip,
        ),
      );
      async.flushMicrotasks();
      expect(playback.playedAt, [startAtServerMs * 1000 + offsetUs]);
      expect(
        h.received<RoundPlaybackStarted>().single.audioStartMonoUs,
        startAtServerMs * 1000 + offsetUs,
      );
    });
  });

  test('a DJ may answer guess_track when guess_track_dj_can_answer is on', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        me: Samples.hostId,
      );
      addTearDown(h.dispose);
      h.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.byopRoom(mode: GameMode.guessTrack),
          config: const {'guess_track_dj_can_answer': true},
        ),
      );
      h.send(
        Samples.djPrepare(
          startAtMonoUs: h.inputClock.monoNowUs,
          prompt: RoundPrompt.guessTrack,
        ),
      );
      expect(_phase(h), isA<RoundDjCue>());
      expect((h.state as GameRoundState).showsButtons, isFalse);
      // The DJ starts the song in their app, then taps (after the cue came).
      async.elapse(const Duration(seconds: 2));
      final startMonoUs = h.inputClock.monoNowUs - 30000;
      expect(
        h.controller.djStarted(
          roundId: 'round-1',
          audioStartMonoUs: startMonoUs,
        ),
        isTrue,
      );
      expect(
        h.controller.djStarted(
          roundId: 'round-1',
          audioStartMonoUs: startMonoUs + 1,
        ),
        isFalse,
        reason: 'reported once',
      );
      async.flushMicrotasks();
      final started = h.received<RoundPlaybackStarted>().single;
      expect(started.audioStartMonoUs, startMonoUs);
      expect((h.state as GameRoundState).showsButtons, isTrue);
      expect(_phase(h), isA<RoundOpen>());
    });
  });

  test('a screen-reader activation of «Музыка играет!» stamps the input '
      'clock', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        me: Samples.hostId,
      );
      addTearDown(h.dispose);
      h.welcome(me: Samples.hostId, room: Samples.byopRoom());
      h.send(Samples.djPrepare(startAtMonoUs: h.inputClock.monoNowUs));
      async.elapse(const Duration(seconds: 4));
      final now = h.inputClock.monoNowUs;
      h.controller.djStarted(roundId: 'round-1', audioStartMonoUs: null);
      async.flushMicrotasks();
      expect(h.received<RoundPlaybackStarted>().single.audioStartMonoUs, now);
    });
  });

  test('bonus.request omits app_check_token when the device has none', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        appCheck: FakeAppCheckService(token: null),
      );
      addTearDown(h.dispose);
      h.welcome();
      h.send(
        const GameBonusOffer(
          bonusId: 'bonus-1',
          expiresAtServerMs: 1,
          eligiblePlayerIds: [Samples.guestId],
        ),
      );
      h.controller.requestBonus();
      async.flushMicrotasks();
      final request = h.received<BonusRequest>().single;
      expect(request.appCheckToken, isNull);
      expect(request.toJson().containsKey('app_check_token'), isFalse);
    });
  });

  test('without a readable input clock a scheduled round opens on '
      'round.start, never early', () {
    fakeAsync((async) {
      final h = GameHarness(
        clock: async.getClock(DateTime(2026, 9, 30)),
        flush: async.flushMicrotasks,
        gameClock: (inner) => InputClock(_BrokenSource()),
      );
      addTearDown(h.dispose);
      h.welcome();
      h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs + 1000000));
      async.elapse(const Duration(seconds: 3));
      expect(_phase(h), isA<RoundLocked>());
      h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
      expect(_phase(h), isA<RoundOpen>());
    });
  });
}
