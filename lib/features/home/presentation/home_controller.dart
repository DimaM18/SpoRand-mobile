import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_policy.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';

final homeControllerProvider = Provider<HomeController>(HomeController.new);

class HomeController {
  HomeController(this._ref);

  final Ref _ref;

  /// Normalizes a typed room code (Crockford base32, 6 chars) into the join
  /// route, or null if it cannot be a room code.
  String? joinLocation(String input) {
    final code = DeepLinkParser.normalizeRoomCode(input);
    return code == null ? null : Routes.join(code, via: JoinVia.code.wire);
  }

  /// Returning users whose UMP consent must be renewed see the form once
  /// after boot, never over the splash (brief §3 `consent` step). The answer
  /// is then applied in the same order as in onboarding (brief §7): Firebase
  /// Consent Mode, then ads init, which the boot `ads` step had to skip.
  Future<void> showConsentFormIfRequired() async {
    final consent = _ref.read(consentServiceProvider);
    if (!consent.current.formRequired) return;
    ConsentInfo info;
    try {
      info = await consent.showFormIfRequired();
    } on Object {
      // Ads simply stay off until the next attempt.
      return;
    }
    final prefs = _ref.read(userPrefsProvider);
    final band = prefs.ageBand;
    final analyticsConsent = resolveAnalyticsConsent(
      ageBand: band,
      storedChoice: prefs.analyticsConsent,
      ump: info,
    );
    final adsPersonalized = resolveAdsPersonalized(ageBand: band, ump: info);
    _ref
        .read(consentSyncProvider)
        .schedule(
          analytics: analyticsConsent == AnalyticsConsent.granted,
          adsPersonalized: adsPersonalized,
          source: ConsentSource.ump,
        );
    await _ref
        .read(analyticsProvider)
        .applyConsent(analyticsConsent, adsPersonalized: adsPersonalized);
    await initializeAdsIfAllowed(
      ads: _ref.read(adsServiceProvider),
      flavorAllowsMonetization: _ref.read(appEnvProvider).monetizationAllowed,
      config: _ref.read(remoteConfigProvider),
      ageBand: band,
      consent: info,
    );
  }
}
