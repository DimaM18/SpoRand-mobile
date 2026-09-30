import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/consent/consent_sync.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/features/settings/presentation/settings_controller.dart';

import '../../support/fake_services.dart';

void main() {
  group('ConsentSync', () {
    test('debounced: a burst sends only the latest state, once', () {
      fakeAsync((async) {
        final api = FakeConsentApi();
        final sync = ConsentSync(api: api);
        sync
          ..schedule(
            analytics: true,
            adsPersonalized: false,
            source: ConsentSource.onboarding,
          )
          ..schedule(
            analytics: false,
            adsPersonalized: false,
            source: ConsentSource.settings,
          );
        async.elapse(const Duration(milliseconds: 400));
        expect(api.calls, 0);
        async.elapse(const Duration(milliseconds: 200));
        expect(api.sent, hasLength(1));
        expect(api.sent.single.toJson(), {
          'consent_analytics': false,
          'consent_ads_personalized': false,
          'source': 'settings',
        });
        async.elapse(const Duration(seconds: 10));
        expect(api.calls, 1);
      });
    });

    test('a failure is retried once, then given up until the next change', () {
      fakeAsync((async) {
        final api = FakeConsentApi(failures: 5);
        final sync = ConsentSync(api: api);
        sync.schedule(
          analytics: true,
          adsPersonalized: true,
          source: ConsentSource.ump,
        );
        async.elapse(const Duration(seconds: 1));
        expect(api.calls, 1);
        async.elapse(const Duration(seconds: 3));
        expect(api.calls, 2);
        async.elapse(const Duration(minutes: 1));
        expect(api.calls, 2);
        expect(api.sent, isEmpty);
      });
    });

    test('the retry succeeds', () {
      fakeAsync((async) {
        final api = FakeConsentApi(failures: 1);
        ConsentSync(api: api).schedule(
          analytics: true,
          adsPersonalized: false,
          source: ConsentSource.settings,
        );
        async.elapse(const Duration(seconds: 5));
        expect(api.calls, 2);
        expect(api.sent.single.consentAnalytics, isTrue);
      });
    });

    test('a newer state replaces a pending retry', () {
      fakeAsync((async) {
        final api = FakeConsentApi(failures: 1);
        final sync = ConsentSync(api: api)
          ..schedule(
            analytics: true,
            adsPersonalized: false,
            source: ConsentSource.settings,
          );
        async.elapse(const Duration(seconds: 1));
        expect(api.calls, 1);
        sync.schedule(
          analytics: false,
          adsPersonalized: false,
          source: ConsentSource.settings,
        );
        async.elapse(const Duration(seconds: 5));
        expect(api.sent.map((r) => r.consentAnalytics), [false]);
        expect(api.calls, 2, reason: 'the stale retry never ran');
      });
    });

    test('never throws to the caller and stops after dispose', () {
      fakeAsync((async) {
        final api = FakeConsentApi();
        ConsentSync(api: api)
          ..schedule(
            analytics: true,
            adsPersonalized: false,
            source: ConsentSource.settings,
          )
          ..dispose();
        async.elapse(const Duration(seconds: 5));
        expect(api.calls, 0);
      });
    });
  });

  group('settings', () {
    late FakeServices services;
    late ProviderContainer container;

    setUp(() async {
      services = FakeServices(
        prefs: {
          'age_band': '18_plus',
          'onboarding_completed': true,
          'analytics_consent': true,
        },
      );
      container = ProviderContainer.test(
        overrides: [
          appEnvProvider.overrideWithValue(services.env),
          userPrefsProvider.overrideWithValue(services.userPrefs),
          consentServiceProvider.overrideWithValue(services.consent),
          consentApiProvider.overrideWithValue(services.consentApi),
          analyticsProvider.overrideWithValue(services.analytics),
          remoteConfigProvider.overrideWithValue(services.remoteConfig),
        ],
      );
      await services.analytics.initialize();
      await services.consent.refresh(underAgeOfConsent: false);
    });

    test('the analytics toggle and the UMP privacy options sync consent', () {
      fakeAsync((async) {
        final settings = container.read(settingsControllerProvider.notifier);
        settings.setAnalyticsEnabled(false);
        async.elapse(const Duration(seconds: 1));
        expect(services.consentApi.sent.single.toJson(), {
          'consent_analytics': false,
          'consent_ads_personalized': true,
          'source': 'settings',
        });

        services.consent.statusAfterRefresh = ConsentStatus.obtained;
        services.consent.refresh(underAgeOfConsent: false);
        settings.openPrivacyOptions();
        async.elapse(const Duration(seconds: 1));
        expect(services.consentApi.sent.last.toJson(), {
          'consent_analytics': false,
          // An answered form is not consent to personalized ads.
          'consent_ads_personalized': false,
          'source': 'ump',
        });
      });
    });
  });
}
