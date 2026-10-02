// Wave 8b: the ads interface, its fake and the ad unit ids live in
// mobile_kit (mobile-template); this path stays so existing imports keep
// working (a shim until 8c). Ads are shown only at the end of a game, never
// over audio and never on launch (brief §6); the kit never shows one by
// itself.
export 'package:mobile_kit/mobile_kit.dart'
    show
        AdUnitIds,
        AdsInitOptions,
        AdsService,
        FakeAdsService,
        InterstitialOutcome,
        InterstitialResult,
        RewardedResult;
