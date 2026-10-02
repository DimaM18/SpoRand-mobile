// Wave 8b: the device clock calibration (brief §5, §9) lives in
// mobile_kit_clock (mobile-template); this path stays so existing imports
// keep working (a shim until 8c).
export 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show
        ClockCalibrationRecorder,
        ClockCalibrationSample,
        ClockCalibrationSummary;
