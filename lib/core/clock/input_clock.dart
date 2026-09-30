import 'package:clock/clock.dart';
import 'package:sporand_native/sporand_native.dart';

/// Raw readings of the device input clock (`os_us`, brief §5 "Clocks"): the
/// clock the OS stamps touch events with.
///
/// Raw values never leave the device. Apple lists `systemUptime` under the
/// required-reason API category SystemBootTime, and reason 35F9.1 forbids
/// sending the value off-device (it also fingerprints the boot time). Only
/// [InputClock] reads a source; everything else gets anchored values.
abstract interface class InputClockSource {
  /// Microseconds on the OS input clock.
  Future<int> nowOsUs();
}

/// `InputClockApi.nowMicros()` over Pigeon (package sporand_native):
/// iOS `ProcessInfo.systemUptime` × 1e6, Android `SystemClock.uptimeMillis()`
/// × 1000.
final class PigeonInputClockSource implements InputClockSource {
  PigeonInputClockSource({InputClockApi? api}) : _api = api ?? InputClockApi();

  final InputClockApi _api;

  @override
  Future<int> nowOsUs() => _api.nowMicros();
}

/// For platforms without the native bridge (desktop dev runs). NOT on the
/// touch clock base: taps are then validated by the fallback rules in
/// `input_timestamps.dart`. Never used on iOS/Android.
final class StopwatchInputClockSource implements InputClockSource {
  StopwatchInputClockSource() : _watch = clock.stopwatch()..start();

  final Stopwatch _watch;

  @override
  Future<int> nowOsUs() async => _watch.elapsedMicroseconds;
}

/// The device input clock as the game uses it: every `*_mono_us` value is
/// OS input-clock time minus the **process anchor** (brief §5 "Process
/// anchor"):
///
/// ```
/// mono_us = os_us − anchor_us
/// ```
///
/// `anchor_us` is read once per process ([init], first thing in
/// `bootstrap()`); if that read failed, the first OS value converted becomes
/// the anchor. This class is the only place that knows it: pointer and frame
/// timestamps go through [fromOs], native player stamps through [fromOsUs],
/// and only the clip player's schedule goes back through [toOsUs].
///
/// The server never learns the anchor and does not need to: the clock
/// offset absorbs any constant shift and reactions are differences. A new
/// process has a new anchor, and the server's clock-jump detector resets its
/// window on the first sample.
///
/// Never use `DateTime.now()` for timing, and on iOS never a `Stopwatch`:
/// it keeps counting while the device sleeps and the touch clock does not.
final class InputClock {
  /// [anchorUs] fixes the anchor up front (tests, tools).
  InputClock(this._source, {this._anchorUs});

  final InputClockSource _source;
  int? _anchorUs;

  bool get isAnchored => _anchorUs != null;

  /// Reads the process anchor. Idempotent; a failed read leaves the anchor
  /// to the first conversion.
  Future<void> init() async {
    if (_anchorUs != null) return;
    final osUs = await _source.nowOsUs();
    _anchorUs ??= osUs;
  }

  /// `PointerEvent.timeStamp` and `currentSystemFrameTimeStamp` -> mono.
  int fromOs(Duration os) => fromOsUs(os.inMicroseconds);

  /// A raw OS input-clock value (native player stamps) -> mono.
  int fromOsUs(int osUs) => osUs - (_anchorUs ??= osUs);

  /// Mono -> raw OS, only for native schedulers (`ClipPlayerApi.playAt`).
  /// Before any anchor exists no mono value can have been produced, so the
  /// value is passed through.
  int toOsUs(int monoUs) => monoUs + (_anchorUs ?? 0);

  /// Now, as mono microseconds (`t2_mono_us`, unlock and playback timers).
  Future<int> nowMicros() async => fromOsUs(await _source.nowOsUs());
}

/// A scripted OS input clock. Optionally follows a [Clock] (e.g.
/// fake_async's or the widget tester's) so timers and the input clock
/// advance together.
final class FakeInputClockSource implements InputClockSource {
  FakeInputClockSource({int startUs = 1000000000, Clock? clock})
    : _baseUs = startUs,
      _clock = clock,
      _origin = clock?.now();

  int _baseUs;
  final Clock? _clock;
  final DateTime? _origin;
  int calls = 0;

  /// Current OS time.
  int get nowUs {
    final c = _clock;
    final origin = _origin;
    if (c == null || origin == null) return _baseUs;
    return _baseUs + c.now().difference(origin).inMicroseconds;
  }

  set nowUs(int value) => _baseUs += value - nowUs;

  void advance(Duration by) => _baseUs += by.inMicroseconds;

  @override
  Future<int> nowOsUs() {
    calls++;
    return Future.value(nowUs);
  }
}

/// Test/dev fake: a [FakeInputClockSource] behind the real anchoring, with
/// a fixed anchor ([anchorUs], 0 by default so mono equals OS time).
final class FakeInputClock extends InputClock {
  factory FakeInputClock({
    int startUs = 1000000000,
    Clock? clock,
    int anchorUs = 0,
  }) => FakeInputClock._(
    FakeInputClockSource(startUs: startUs, clock: clock),
    anchorUs,
  );

  FakeInputClock._(this.source, this.anchorUs)
    : super(source, anchorUs: anchorUs);

  final FakeInputClockSource source;
  final int anchorUs;

  /// Current OS time (what `PointerEvent.timeStamp` would carry).
  int get nowUs => source.nowUs;

  set nowUs(int value) => source.nowUs = value;

  /// Current anchored time (what goes on the wire).
  int get monoNowUs => source.nowUs - anchorUs;

  int get calls => source.calls;

  void advance(Duration by) => source.advance(by);
}
