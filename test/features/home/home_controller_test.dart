import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/features/home/presentation/home_controller.dart';

import '../../support/fake_services.dart';

void main() {
  group('HomeController consent renewal', () {
    late FakeServices services;
    late ProviderContainer container;

    setUp(() async {
      // A returning adult in the EEA whose UMP consent has to be renewed:
      // the boot `consent` step saw `required`, so `ads` stayed off.
      services = FakeServices(
        prefs: {
          'age_band': '18_plus',
          'onboarding_completed': true,
          'analytics_consent': true,
        },
      );
      services.consent
        ..statusAfterRefresh = ConsentStatus.required
        ..canRequestAdsAfterRefresh = false;
      container = ProviderContainer.test(
        overrides: [
          appEnvProvider.overrideWithValue(services.env),
          userPrefsProvider.overrideWithValue(services.userPrefs),
          consentServiceProvider.overrideWithValue(services.consent),
          consentApiProvider.overrideWithValue(services.consentApi),
          analyticsProvider.overrideWithValue(services.analytics),
          adsServiceProvider.overrideWithValue(services.ads),
          remoteConfigProvider.overrideWithValue(services.remoteConfig),
        ],
      );
      await services.analytics.initialize();
      await services.consent.refresh(underAgeOfConsent: false);
    });

    test(
      'the renewed choice initializes ads and updates Consent Mode',
      () async {
        // Regression: the form was shown but its outcome was never applied, so
        // ads stayed off for the whole session.
        expect(services.ads.isInitialized, isFalse);

        await container
            .read(homeControllerProvider)
            .showConsentFormIfRequired();

        expect(services.consent.formShownCount, 1);
        expect(services.ads.isInitialized, isTrue);
        expect(services.ads.initOptions?.personalizedAllowed, isTrue);
        expect(services.analytics.consent, AnalyticsConsent.granted);
        expect(services.analyticsBackend.consent?.analyticsStorage, isTrue);

        // The renewed UMP choice is scheduled for PUT /v1/me/consent.
        final pending = container.read(consentSyncProvider).pending;
        expect(pending?.source, ConsentSource.ump);
        expect(pending?.consentAnalytics, isTrue);
      },
    );

    test('nothing happens when no form is required', () async {
      services.consent
        ..statusAfterRefresh = ConsentStatus.notRequired
        ..canRequestAdsAfterRefresh = true;
      await services.consent.refresh(underAgeOfConsent: false);

      await container.read(homeControllerProvider).showConsentFormIfRequired();

      expect(services.consent.formShownCount, 0);
      expect(services.ads.isInitialized, isFalse);
    });
  });
}
