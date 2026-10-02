// Wave 8b: the ads init policy (config, kill switches, age, UMP
// `canRequestAds`) and the purchases switch live in mobile_kit
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c). SpoRand uses the standard `AgePolicy`.
export 'package:mobile_kit/mobile_kit.dart'
    show adsInitOptions, initializeAdsIfAllowed, purchasesEnabled;
