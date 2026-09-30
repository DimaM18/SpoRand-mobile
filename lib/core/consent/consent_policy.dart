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

/// Firebase Consent Mode ad signals follow UMP and age.
bool resolveAdsPersonalized({
  required AgeBand? ageBand,
  required ConsentInfo ump,
}) =>
    (ageBand?.allowsPersonalizedAds ?? false) &&
    ump.canRequestAds &&
    (ump.status == ConsentStatus.obtained ||
        ump.status == ConsentStatus.notRequired);
