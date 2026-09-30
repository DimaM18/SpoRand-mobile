import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';

/// `tap_mono_us` from a pointer-down event (brief §5 "Unlocking the answer
/// buttons and capturing the tap").
///
/// Assumption: the Flutter engine forwards the platform's event time
/// unchanged, so `PointerEvent.timeStamp` shares the base of
/// `InputClockApi.nowMicros()`:
/// - iOS: `UITouch.timestamp` (seconds of `systemUptime`) × 1e6;
/// - Android: `MotionEvent` event time (`uptimeMillis` base) in µs.
///
/// Two things would break it, and the device calibration test (brief §9,
/// `ClockCalibrationRecorder`) checks for both: an engine that rebases
/// pointer times, and pointer resampling (`GestureBinding.resamplingEnabled`
/// must stay false, the default), which rewrites timestamps.
int tapMonoUsFromPointer(PointerEvent event) => event.timeStamp.inMicroseconds;

/// `SchedulerBinding.currentSystemFrameTimeStamp` in µs: the vsync time of
/// the frame being built. Read it inside `addPostFrameCallback` of the first
/// frame that shows enabled buttons to get `unlock_mono_us`.
int currentFrameTimestampUs([SchedulerBinding? binding]) =>
    (binding ?? SchedulerBinding.instance)
        .currentSystemFrameTimeStamp
        .inMicroseconds;

/// Sanity rules that keep a clock-base mismatch (engine frame clock or
/// pointer clock not on the input clock, e.g. after device sleep on iOS)
/// from producing answers the server must reject as `too_early`.
///
/// Every fallback is conservative: it can only make the reported unlock or
/// tap later, never earlier, so it cannot be used to gain points.
abstract final class MonoTimestamps {
  /// Tolerance for clock granularity (Android's input clock has 1 ms steps)
  /// and for reading the native clock slightly after the event.
  static const slackUs = 20000;

  /// Resolves `unlock_mono_us`.
  ///
  /// [provisionalUs] is `nowMicros()` read when the unlock was requested,
  /// before the frame that shows the buttons was built, so it is never later
  /// than the real unlock. [frameUs] is that frame's timestamp. The frame is
  /// used when it lies between the request and [nowUs] (a moment after the
  /// buttons were visible); otherwise the frame clock is on another base and
  /// the provisional value is used.
  static int resolveUnlock({
    required int provisionalUs,
    required int? frameUs,
    required int nowUs,
  }) {
    if (frameUs == null) return provisionalUs;
    final plausible =
        frameUs >= provisionalUs - slackUs && frameUs <= nowUs + slackUs;
    return plausible ? frameUs : provisionalUs;
  }

  /// Resolves `tap_mono_us`. A pointer timestamp before the unlock is
  /// impossible (the buttons were disabled) and one after [nowUs] (read
  /// after the event was delivered) is in the future; both mean the pointer
  /// clock is on another base, so the tap falls back to [nowUs].
  static int resolveTap({
    required int tapUs,
    required int unlockUs,
    required int nowUs,
  }) {
    final plausible = tapUs >= unlockUs - slackUs && tapUs <= nowUs + slackUs;
    return plausible ? tapUs : nowUs;
  }
}
