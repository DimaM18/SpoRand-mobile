// Wave 8b: pointer and frame timestamps on the input clock live in
// mobile_kit_clock (mobile-template); this path stays so existing imports
// keep working (a shim until 8c).
export 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show MonoTimestamps, currentFrameMonoUs, tapMonoUsFromPointer;
