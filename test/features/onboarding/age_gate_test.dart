import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/features/onboarding/domain/age_gate.dart';
import 'package:sporand/features/onboarding/presentation/onboarding_controller.dart';

import '../../support/fake_services.dart';

void main() {
  group('AgeGate (current year 2026)', () {
    const gate = AgeGate(currentYear: 2026);

    AgeBand? band(String year) => switch (gate.evaluate(year)) {
      AgeGateAccepted(:final band) => band,
      AgeGateBlocked() => AgeBand.under13,
      AgeGateInvalid() => null,
    };

    test('uses the youngest possible age for the year', () {
      expect(gate.minimumAge(2000), 25);
      expect(band('2013'), AgeBand.under13, reason: '12 or 13 -> blocked');
      expect(band('2012'), AgeBand.age13to15);
      expect(band('2010'), AgeBand.age13to15, reason: '15 or 16 -> 13_15');
      expect(band('2009'), AgeBand.age16to17);
      expect(band('2008'), AgeBand.age16to17);
      expect(band('2007'), AgeBand.adult);
      expect(band(' 1990 '), AgeBand.adult);
    });

    test('under 13 is blocked', () {
      expect(gate.evaluate('2020'), isA<AgeGateBlocked>());
      expect(gate.evaluate('2026'), isA<AgeGateBlocked>());
    });

    test('rejects anything that is not a plausible year', () {
      for (final input in [
        '',
        '20',
        '20a6',
        '12345',
        '2027',
        '1900',
        '-2000',
      ]) {
        expect(gate.evaluate(input), isA<AgeGateInvalid>(), reason: input);
      }
    });

    test('band policy', () {
      expect(AgeBand.age13to15.allowsAnalytics, isFalse);
      expect(AgeBand.age13to15.isUnderAgeOfConsent, isTrue);
      expect(AgeBand.age13to15.allowsAds, isTrue);
      expect(AgeBand.age16to17.allowsAnalytics, isTrue);
      expect(AgeBand.under13.allowsAds, isFalse);
      expect(AgeBand.fromWire('18_plus'), AgeBand.adult);
    });
  });

  group('OnboardingController', () {
    late FakeServices services;
    late ProviderContainer container;

    setUp(() {
      services = FakeServices();
      container = ProviderContainer.test(
        overrides: [
          appEnvProvider.overrideWithValue(services.env),
          userPrefsProvider.overrideWithValue(services.userPrefs),
          consentServiceProvider.overrideWithValue(services.consent),
          analyticsProvider.overrideWithValue(services.analytics),
          adsServiceProvider.overrideWithValue(services.ads),
          remoteConfigProvider.overrideWithValue(services.remoteConfig),
          deepLinkQueueProvider.overrideWithValue(services.deepLinks),
        ],
      );
      services.analytics.initialize();
    });

    Future<T> in2026<T>(Future<T> Function() body) =>
        withClock(Clock.fixed(DateTime(2026, 9, 30)), body);

    OnboardingController controller() =>
        container.read(onboardingControllerProvider.notifier);

    test('an under-13 answer blocks and is remembered', () async {
      final result = await in2026(() => controller().submitBirthYear('2016'));
      expect(result, isA<AgeGateBlocked>());
      expect(container.read(onboardingControllerProvider).blocked, isTrue);
      expect(services.userPrefs.ageGateBlocked, isTrue);
      expect(services.userPrefs.ageBand, AgeBand.under13);
    });

    test('an invalid answer changes nothing', () async {
      final result = await in2026(() => controller().submitBirthYear('abcd'));
      expect(result, isA<AgeGateInvalid>());
      expect(services.userPrefs.ageBand, isNull);
    });

    test('adult with analytics opt-in: consent, ads and event', () async {
      await in2026(() => controller().submitBirthYear('1990'));
      controller().setAnalyticsOptIn(true);
      final next = await controller().complete();

      expect(next, Routes.home);
      expect(services.userPrefs.onboardingCompleted, isTrue);
      expect(services.userPrefs.analyticsConsent, isTrue);
      expect(services.analytics.consent, AnalyticsConsent.granted);
      expect(services.ads.initOptions?.personalizedAllowed, isTrue);
      final event = services.analyticsBackend
          .named(AnalyticsEvents.onboardingComplete)
          .single;
      expect(event.params, {
        'age_band': '18_plus',
        'consent_analytics': 1,
        'consent_ads': 1,
      });
      expect(container.read(onboardingControllerProvider).completed, isTrue);
    });

    test('analytics is opt-in (off unless chosen)', () async {
      await in2026(() => controller().submitBirthYear('1990'));
      await controller().complete();
      expect(services.userPrefs.analyticsConsent, isFalse);
      expect(services.analytics.consent, AnalyticsConsent.denied);
    });

    test('13-15: not asked about analytics, age-restricted ads', () async {
      await in2026(() => controller().submitBirthYear('2011'));
      expect(
        container.read(onboardingControllerProvider).canChooseAnalytics,
        isFalse,
      );
      controller().setAnalyticsOptIn(true);
      await controller().complete();
      expect(services.userPrefs.analyticsConsent, isNull);
      expect(services.analytics.consent, AnalyticsConsent.disabled);
      expect(services.consent.lastUnderAgeOfConsent, isTrue);
      expect(services.ads.initOptions?.underAgeOfConsent, isTrue);
    });

    test('returns the deep link that waited for onboarding', () async {
      services.deepLinks.defer(const JoinRoomLink('7K2M9Q'));
      await in2026(() => controller().submitBirthYear('1990'));
      expect(await controller().complete(), '/j/7K2M9Q');
      expect(services.deepLinks.deferred, isNull);
    });
  });
}
