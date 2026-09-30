// Pigeon definition of the device input clock (brief §5 "Clocks").
//
// Regenerate from apps/mobile:
//   dart run pigeon --input pigeons/input_clock.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'sporand_native',
    dartOut: 'packages/sporand_native/lib/src/input_clock_api.g.dart',
    kotlinOut: 'packages/sporand_native/android/src/main/kotlin/dev/brandtbd/sporand_native/InputClockApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.brandtbd.sporand_native',
      // One error class for the whole Kotlin package; clip_player.dart
      // reuses it with includeErrorClass: false.
      errorClassName: 'NativeBridgeError',
    ),
    swiftOut: 'packages/sporand_native/ios/sporand_native/Sources/sporand_native/InputClockApi.g.swift',
    swiftOptions: SwiftOptions(errorClassName: 'NativeBridgeError'),
  ),
)
/// The OS input clock: the clock that stamps touch events.
@HostApi()
abstract class InputClockApi {
  /// Microseconds on the device input clock.
  ///
  /// - iOS: `ProcessInfo.processInfo.systemUptime * 1e6`, the base of
  ///   `UITouch.timestamp` (stops while the device sleeps).
  /// - Android: `SystemClock.uptimeMillis() * 1000`, the base of
  ///   `MotionEvent.getEventTime()` (1 ms precision).
  int nowMicros();
}
