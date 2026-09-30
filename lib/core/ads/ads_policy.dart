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

/// Purchases are available unless the flavor, `monetization_enabled` or
/// `kill_switch_purchases` turn them off.
bool purchasesEnabled({
  required bool flavorAllowsMonetization,
  required RemoteConfigService config,
}) =>
    flavorAllowsMonetization &&
    config.monetizationEnabled &&
    !config.killSwitchPurchases;
