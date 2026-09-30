import Foundation

/// The device input clock (brief §5 "Clocks").
///
/// `systemUptime` is seconds since boot, excluding time asleep; it is the
/// base of `UITouch.timestamp`, which the Flutter engine forwards as
/// `PointerEvent.timeStamp`. Never use a clock that keeps counting during
/// sleep (e.g. CLOCK_MONOTONIC_RAW), or taps and this clock drift apart.
final class InputClockHost: InputClockApi {
  func nowMicros() throws -> Int64 {
    return Int64((ProcessInfo.processInfo.systemUptime * 1_000_000).rounded())
  }
}
