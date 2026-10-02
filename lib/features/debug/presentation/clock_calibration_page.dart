// Wave 8b: the device timing calibration page lives in mobile_kit_clock
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c). It records, per tap, the pointer timestamp, the next
// frame's timestamp and `InputClockApi.nowMicros()`, all through the process
// anchor of `inputClockProvider`. Reachable from Settings in non-production
// builds (`/debug/clock`).
export 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show ClockCalibrationPage;
