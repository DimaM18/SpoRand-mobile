// Wave 8b: the anchored input clock lives in mobile_kit_clock
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c). Every `*_mono_us` value is OS input-clock time minus the
// process anchor (brief §5); raw uptime never leaves the device. The app's
// one clock is `inputClockProvider` (re-exported by app/di/providers.dart).
export 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show
        FakeInputClock,
        FakeInputClockSource,
        InputClock,
        InputClockSource,
        PigeonInputClockSource,
        StopwatchInputClockSource;
