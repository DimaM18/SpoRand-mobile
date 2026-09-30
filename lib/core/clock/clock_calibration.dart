import 'dart:math' as math;

import 'package:sporand/core/clock/input_clock.dart';

/// One tap recorded by the calibration screen: the three timestamps the
/// game relies on, read as close together as possible.
final class ClockCalibrationSample {
  const ClockCalibrationSample({
    required this.pointerUs,
    required this.frameUs,
    required this.nativeNowUs,
  });

  /// `PointerDownEvent.timeStamp` through the anchor (`tap_mono_us`).
  final int pointerUs;

  /// `currentSystemFrameTimeStamp` of the first frame after the event, read
  /// in its post-frame callback exactly like `unlock_mono_us`.
  final int frameUs;

  /// `InputClock.nowMicros()` read right after the event.
  final int nativeNowUs;

  /// Event-to-read delay; small and positive when the pointer clock shares
  /// the input clock base.
  int get pointerLagUs => nativeNowUs - pointerUs;

  /// Frame-to-read delay; small and positive when the frame clock shares it.
  int get frameLagUs => nativeNowUs - frameUs;
}

final class ClockCalibrationSummary {
  const ClockCalibrationSummary({
    required this.samples,
    required this.pointerLagMedianUs,
    required this.pointerLagMaxUs,
    required this.frameLagMedianUs,
    required this.frameLagMaxUs,
    required this.pointerSharesBase,
    required this.frameSharesBase,
  });

  final int samples;
  final int pointerLagMedianUs;
  final int pointerLagMaxUs;
  final int frameLagMedianUs;
  final int frameLagMaxUs;
  final bool pointerSharesBase;
  final bool frameSharesBase;

  bool get passed => pointerSharesBase && frameSharesBase;
}

/// Device calibration test required by brief §5/§9: confirms on a real
/// device that `Listener` pointer timestamps and frame timestamps share the
/// base of `InputClockApi.nowMicros()`.
///
/// Pass criterion: every lag is in `[-tolerance, maxLag]`. A different base
/// shows up as lags of seconds or more (or negative ones).
final class ClockCalibrationRecorder {
  ClockCalibrationRecorder(
    this._clock, {
    this.maxLagUs = 250000,
    this.toleranceUs = 2000,
  });

  final InputClock _clock;

  /// Upper bound for input pipeline + channel latency.
  final int maxLagUs;

  /// Lower bound slack: Android's input clock has 1 ms steps.
  final int toleranceUs;

  final List<ClockCalibrationSample> _samples = [];

  List<ClockCalibrationSample> get samples => List.unmodifiable(_samples);

  /// Call from the post-frame callback of the frame scheduled by the pointer
  /// down; the native clock is read last.
  Future<ClockCalibrationSample> record({
    required int pointerUs,
    required int frameUs,
  }) async {
    final now = await _clock.nowMicros();
    final sample = ClockCalibrationSample(
      pointerUs: pointerUs,
      frameUs: frameUs,
      nativeNowUs: now,
    );
    _samples.add(sample);
    return sample;
  }

  void clear() => _samples.clear();

  ClockCalibrationSummary? summarize() {
    if (_samples.isEmpty) return null;
    final pointer = [for (final s in _samples) s.pointerLagUs]..sort();
    final frame = [for (final s in _samples) s.frameLagUs]..sort();
    bool within(List<int> lags) =>
        lags.first >= -toleranceUs && lags.last <= maxLagUs;
    return ClockCalibrationSummary(
      samples: _samples.length,
      pointerLagMedianUs: pointer[pointer.length ~/ 2],
      pointerLagMaxUs: pointer.reduce(math.max),
      frameLagMedianUs: frame[frame.length ~/ 2],
      frameLagMaxUs: frame.reduce(math.max),
      pointerSharesBase: within(pointer),
      frameSharesBase: within(frame),
    );
  }

  /// Plain-text report for the test log (copy/share from the debug screen).
  String report() {
    final buffer = StringBuffer(
      'pointer_us,frame_us,native_now_us,pointer_lag_us,frame_lag_us\n',
    );
    for (final s in _samples) {
      buffer.writeln(
        '${s.pointerUs},${s.frameUs},${s.nativeNowUs},'
        '${s.pointerLagUs},${s.frameLagUs}',
      );
    }
    final summary = summarize();
    if (summary != null) {
      buffer.writeln(
        '# samples=${summary.samples} '
        'pointer_median_us=${summary.pointerLagMedianUs} '
        'frame_median_us=${summary.frameLagMedianUs} '
        'passed=${summary.passed}',
      );
    }
    return buffer.toString();
  }
}
