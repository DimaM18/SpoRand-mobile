import 'package:sporand/core/clock/input_clock.dart';

import 'e2e_env.dart';

/// A simulated phone's OS input clock (brief §5 `os_us`): real time from the
/// shared e2e clock, on this phone's own base (its uptime). Every phone runs
/// at the same rate, but the bases differ by hours or days, so a phone's
/// `*_mono_us` values mean nothing to another phone or to the server until
/// clock sync relates them.
final class SimulatedOsClock implements InputClockSource {
  SimulatedOsClock(this.uptimeAtZeroUs);

  /// OS uptime when [e2eNowUs] was 0.
  final int uptimeAtZeroUs;

  int get nowUs => uptimeAtZeroUs + e2eNowUs();

  @override
  Future<int> nowOsUs() async => nowUs;
}

/// The clocks of one simulated phone: the OS clock and the app's anchored
/// [InputClock] (`mono_us = os_us − anchor_us`), plus conversions to the
/// shared e2e time line so a test can compute the true time of any
/// `*_mono_us` value the phone put on the wire.
final class PhoneClock {
  PhoneClock({required int uptimeAtZeroUs, required this.anchorUs})
    : assert(anchorUs <= uptimeAtZeroUs, 'mono_us must not be negative'),
      os = SimulatedOsClock(uptimeAtZeroUs) {
    input = InputClock(os, anchorUs: anchorUs);
  }

  final SimulatedOsClock os;

  /// The process anchor of the simulated app.
  final int anchorUs;
  late final InputClock input;

  /// Now, as this phone's `*_mono_us`.
  int get nowMonoUs => input.fromOsUs(os.nowUs);

  /// The e2e time at which this phone's clock read [monoUs].
  int e2eUsOf(int monoUs) => monoUs + anchorUs - os.uptimeAtZeroUs;
}
