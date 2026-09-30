import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';

/// Whether the ads SDK may be initialized now (brief §3 `ads` step, §6 "Ads
/// consent"): ads enabled by config, UMP `canRequestAds()`, and an age that
/// allows ads. Returns the init options, or null when ads must stay off.
AdsInitOptions? adsInitOptions({
  required bool flavorAllowsMonetization,
  required RemoteConfigService config,
  required AgeBand? ageBand,
  required ConsentInfo? consent,
}) {
  final enabled =
      flavorAllowsMonetization &&
      config.monetizationEnabled &&
      !config.killSwitchAds &&
      (config.interstitialEnabled || config.rewardedEnabled);
  if (!enabled) return null;
  if (ageBand == null || !ageBand.allowsAds) return null;
  if (consent == null || !consent.canRequestAds) return null;
  return AdsInitOptions(
    underAgeOfConsent: ageBand.isUnderAgeOfConsent,
    personalizedAllowed: ageBand.allowsPersonalizedAds,
  );
}

/// Initializes [ads] once [adsInitOptions] allows it (onboarding, or a
/// consent renewed after boot). A failure leaves ads off for this session;
/// nothing user-visible depends on it.
Future<void> initializeAdsIfAllowed({
  required AdsService ads,
  required bool flavorAllowsMonetization,
  required RemoteConfigService config,
  required AgeBand? ageBand,
  required ConsentInfo consent,
  Duration timeout = const Duration(seconds: 3),
}) async {
  if (ads.isInitialized) return;
  final options = adsInitOptions(
    flavorAllowsMonetization: flavorAllowsMonetization,
    config: config,
    ageBand: ageBand,
    consent: consent,
  );
  if (options == null) return;
  try {
    await ads.initialize(options).timeout(timeout);
  } on Object {
    // Ads stay off until the next launch.
  }
}

/// Purchases are available unless the flavor, `monetization_enabled` or
/// `kill_switch_purchases` turn them off.
bool purchasesEnabled({
  required bool flavorAllowsMonetization,
  required RemoteConfigService config,
}) =>
    flavorAllowsMonetization &&
    config.monetizationEnabled &&
    !config.killSwitchPurchases;
