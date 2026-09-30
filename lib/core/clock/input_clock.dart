import 'package:clock/clock.dart';
import 'package:sporand_native/sporand_native.dart';

/// The device input clock (brief §5 "Clocks"): the clock the OS stamps touch
/// events with. Every `*_mono_us` value on the wire is on this clock.
///
/// Never use `DateTime.now()` for timing, and on iOS never a `Stopwatch`:
/// it keeps counting while the device sleeps and the touch clock does not.
abstract interface class InputClock {
  /// Microseconds on the input clock.
  Future<int> nowMicros();
}

/// `InputClockApi.nowMicros()` over Pigeon (package sporand_native):
/// iOS `ProcessInfo.systemUptime` × 1e6, Android `SystemClock.uptimeMillis()`
/// × 1000.
final class PigeonInputClock implements InputClock {
  PigeonInputClock({InputClockApi? api}) : _api = api ?? InputClockApi();

  final InputClockApi _api;

  @override
  Future<int> nowMicros() => _api.nowMicros();
}

/// For platforms without the native bridge (desktop dev runs). NOT on the
/// touch clock base: taps are then validated by the fallback rules in
/// `input_timestamps.dart`. Never used on iOS/Android.
final class StopwatchInputClock implements InputClock {
  StopwatchInputClock() : _watch = clock.stopwatch()..start();

  final Stopwatch _watch;

  @override
  Future<int> nowMicros() async => _watch.elapsedMicroseconds;
}

/// Test/dev fake. Optionally follows a [Clock] (e.g. fake_async's or the
/// widget tester's) so timers and the input clock advance together.
final class FakeInputClock implements InputClock {
  FakeInputClock({int startUs = 1000000000, Clock? clock})
    : _baseUs = startUs,
      _clock = clock,
      _origin = clock?.now();

  int _baseUs;
  final Clock? _clock;
  final DateTime? _origin;
  int calls = 0;

  int get nowUs {
    final c = _clock;
    final origin = _origin;
    if (c == null || origin == null) return _baseUs;
    return _baseUs + c.now().difference(origin).inMicroseconds;
  }

  set nowUs(int value) => _baseUs += value - nowUs;

  void advance(Duration by) => _baseUs += by.inMicroseconds;

  @override
  Future<int> nowMicros() {
    calls++;
    return Future.value(nowUs);
  }
}
