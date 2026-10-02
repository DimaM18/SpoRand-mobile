// Wave 8b: crash reporting lives in mobile_kit (mobile-template); this path
// stays so existing imports keep working (a shim until 8c).
export 'package:mobile_kit/mobile_kit.dart'
    show
        BufferingCrashReporter,
        CrashReporter,
        FakeCrashReporter,
        RecordedError;
