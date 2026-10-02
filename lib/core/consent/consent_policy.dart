// Wave 8b: the consent policy (age first, then the user's choice, then the
// UMP region signal) lives in mobile_kit (mobile-template); this path stays
// so existing imports keep working (a shim until 8c). SpoRand uses the
// standard `AgePolicy` (the default of both functions).
export 'package:mobile_kit/mobile_kit.dart'
    show resolveAdsPersonalized, resolveAnalyticsConsent;
