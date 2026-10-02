// Wave 8b: the timed tap target lives in mobile_kit_clock (mobile-template);
// this path stays so existing imports keep working (a shim until 8c). It is
// the only input path for timed taps: answers and the DJ's «Музыка
// играет!» (CLAUDE.md hard rule 6).
export 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show TimedTapBuilder, TimedTapTarget;
