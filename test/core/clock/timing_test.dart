import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/clock/clock_calibration.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/clock/input_timestamps.dart';
import 'package:sporand/core/net/clock_sync.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';

void main() {
  group('tap_mono_us', () {
    test('is the pointer event timestamp in microseconds', () {
      const event = PointerDownEvent(
        timeStamp: Duration(microseconds: 834515687654),
      );
      expect(tapMonoUsFromPointer(event), 834515687654);
    });
  });

  group('MonoTimestamps.resolveUnlock', () {
    test('uses the frame timestamp when it follows the unlock request', () {
      expect(
        MonoTimestamps.resolveUnlock(
          provisionalUs: 1000000,
          frameUs: 1008000,
          nowUs: 1500000,
        ),
        1008000,
      );
    });

    test('tolerates a frame vsync just before the request (clock steps)', () {
      expect(
        MonoTimestamps.resolveUnlock(
          provisionalUs: 1000000,
          frameUs: 995000,
          nowUs: 1500000,
        ),
        995000,
      );
    });

    test('falls back when the frame clock is on another base', () {
      for (final frame in [1000000 + 3600000000, 1000000 - 3600000000, 0]) {
        expect(
          MonoTimestamps.resolveUnlock(
            provisionalUs: 1000000,
            frameUs: frame,
            nowUs: 1500000,
          ),
          1000000,
        );
      }
    });

    test('without a frame report uses the request time', () {
      expect(
        MonoTimestamps.resolveUnlock(
          provisionalUs: 1000000,
          frameUs: null,
          nowUs: 1500000,
        ),
        1000000,
      );
    });
  });

  group('MonoTimestamps.resolveTap', () {
    test('keeps a plausible pointer time exactly', () {
      expect(
        MonoTimestamps.resolveTap(
          tapUs: 1400000,
          unlockUs: 1000000,
          nowUs: 1412000,
        ),
        1400000,
      );
    });

    test('an impossible pointer time falls back to now (never earlier)', () {
      expect(
        MonoTimestamps.resolveTap(tapUs: 5, unlockUs: 1000000, nowUs: 1412000),
        1412000,
      );
      expect(
        MonoTimestamps.resolveTap(
          tapUs: 9000000,
          unlockUs: 1000000,
          nowUs: 1412000,
        ),
        1412000,
      );
    });
  });

  group('ClockModel', () {
    test('converts with device ≈ server + offset', () {
      final model = ClockModel();
      expect(model.serverMsToMonoUs(1000), isNull);
      model.apply(
        const ClockResult(
          offsetUs: -1759000000000000,
          rttMinUs: 24000,
          samples: 8,
          quality: ClockQuality.good,
        ),
      );
      expect(model.isSynced, isTrue);
      expect(model.errorBoundUs, 12000);
      // start_at_server_ms -> start_at_mono_us and back.
      const serverMs = 1759000012345;
      final mono = model.serverMsToMonoUs(serverMs)!;
      expect(mono, 12345000);
      expect(model.monoUsToServerMs(mono), serverMs);
    });

    test('is stale after the app returns to the foreground', () {
      final model = ClockModel()
        ..apply(
          const ClockResult(
            offsetUs: 5,
            rttMinUs: 1000,
            samples: 8,
            quality: ClockQuality.fair,
          ),
        )
        ..markStale();
      expect(model.isSynced, isFalse);
      expect(model.offsetUs, 5, reason: 'still the best guess');
    });
  });

  group('ClockCalibrationRecorder', () {
    test('passes when pointer and frame times share the input clock', () async {
      final clock = FakeInputClock(startUs: 10000000);
      final recorder = ClockCalibrationRecorder(clock);
      for (var i = 0; i < 5; i++) {
        clock.advance(const Duration(milliseconds: 300));
        await recorder.record(
          pointerUs: clock.nowUs - 30000,
          frameUs: clock.nowUs - 6000,
        );
      }
      final summary = recorder.summarize()!;
      expect(summary.samples, 5);
      expect(summary.passed, isTrue);
      expect(summary.pointerLagMedianUs, 30000);
      expect(recorder.report(), contains('passed=true'));
    });

    test('fails when a clock is on another base', () async {
      final clock = FakeInputClock(startUs: 10000000);
      final recorder = ClockCalibrationRecorder(clock);
      await recorder.record(
        pointerUs: clock.nowUs - 20000,
        // e.g. a frame clock that kept counting during sleep.
        frameUs: clock.nowUs + 7200000000,
      );
      final summary = recorder.summarize()!;
      expect(summary.pointerSharesBase, isTrue);
      expect(summary.frameSharesBase, isFalse);
      expect(summary.passed, isFalse);
    });
  });
}
