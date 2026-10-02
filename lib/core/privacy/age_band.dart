// Wave 8b: `AgeBand` and its policy live in mobile_kit (mobile-template);
// this path stays so existing imports keep working (a shim until 8c).
// SpoRand uses the standard policy (blocked under 13, consent from 16).
export 'package:mobile_kit/mobile_kit.dart' show AgeBand, AgePolicy;
