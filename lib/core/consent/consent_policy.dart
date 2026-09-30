import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/privacy/age_band.dart';

/// Effective analytics consent (brief §7): age first, then the user's own
/// choice, then the UMP region signal.
AnalyticsConsent resolveAnalyticsConsent({
  required AgeBand? ageBand,
  required bool? storedChoice,
  required ConsentInfo ump,
}) {
  // Age unknown = onboarding not done: keep buffering until it is.
  if (ageBand == null) return AnalyticsConsent.unknown;
  if (!ageBand.allowsAnalytics) return AnalyticsConsent.disabled;
  if (storedChoice != null) {
    return storedChoice ? AnalyticsConsent.granted : AnalyticsConsent.denied;
  }
  // Outside the EEA/UK consent is not required.
  if (ump.notRequired) return AnalyticsConsent.granted;
  return AnalyticsConsent.unknown;
}

/// Firebase Consent Mode ad signals (`ad_storage`, `ad_user_data`,
/// `ad_personalization`) follow age and UMP.
///
/// Only a region without a consent requirement grants them. UMP status
/// `obtained` means the user answered the form, not that they agreed:
/// "Do not consent" also ends as `obtained` with `canRequestAds() == true`
/// (limited ads). Until the TCF purpose consents (`IABTCF_PurposeConsents`)
/// are read, the signals stay denied in the EEA/UK. AdMob is unaffected: it
/// reads the TCF string itself.
bool resolveAdsPersonalized({
  required AgeBand? ageBand,
  required ConsentInfo ump,
}) =>
    (ageBand?.allowsPersonalizedAds ?? false) &&
    ump.canRequestAds &&
    ump.status == ConsentStatus.notRequired;
