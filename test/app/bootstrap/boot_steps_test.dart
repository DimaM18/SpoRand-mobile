import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/bootstrap/domain/app_initializer.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/boot_telemetry.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';

import '../../support/fake_services.dart';

const returningAdult = <String, Object>{
  'age_band': '18_plus',
  'onboarding_completed': true,
  'analytics_consent': true,
};

/// Runs the production step list against [services] under fake time.
(BootOutcome, AppInitializer) boot(
  FakeServices services, {
  void Function(FakeServices s)? before,
  Duration elapse = const Duration(seconds: 30),
}) {
  late (BootOutcome, AppInitializer) result;
  fakeAsync((async) {
    before?.call(services);
    final init = AppInitializer(
      steps: buildBootSteps(),
      context: services.context(),
      telemetry: AnalyticsBootTelemetry(services.analytics),
    );
    BootOutcome? outcome;
    unawaited(init.run().then((o) => outcome = o));
    async.elapse(elapse);
    result = (outcome!, init);
  });
  return result;
}

void main() {
  test('the production pipeline declares every canonical step in order', () {
    expect(buildBootSteps().map((s) => s.id), [
      'config_defaults',
      'config_activate_cached',
      'config_fetch',
      'version_gate',
      'kill_switches',
      'storage_open',
      'session_restore',
      'precache_images',
      'fonts',
      'sfx',
      'animations',
      'shader_warmup',
      'crash_reporting',
      'analytics',
      'consent',
      'auth',
      'purchases',
      'ads',
      'music_provider',
      'realtime',
      'route',
    ]);
  });

  test('first launch: all steps succeed and the app goes to onboarding', () {
    final services = FakeServices();
    services.crashGate.recordError(StateError('early'), null).ignore();
    final (outcome, _) = boot(services);

    final success = outcome as BootSucceeded;
    expect(success.destination, isA<OnboardingDestination>());
    expect(success.report.degradedStepIds, isEmpty);
    // crash_reporting attached the real reporter and flushed early errors.
    expect(services.crashGate.isAttached, isTrue);
    expect(services.crashReporter.errors.single.error, isA<StateError>());
    // auth -> purchases logIn(user_id).
    expect(services.purchases.loggedInUserId, 'guest-1');
    // Age unknown: ads wait for onboarding; analytics waits for consent.
    expect(services.ads.isInitialized, isFalse);
    expect(services.analytics.consent, AnalyticsConsent.unknown);
    expect(services.analyticsBackend.events, isEmpty);
    expect(services.analytics.bufferedCount, greaterThan(0));
    expect(services.consent.lastUnderAgeOfConsent, isTrue);
    // realtime is only configured, never connected.
    expect(
      services.realtime.endpoint.toString(),
      'wss://api.example.test/v1/ws',
    );
  });

  test(
    'returning adult with consent: home, ads initialized, telemetry sent',
    () {
      final services = FakeServices(prefs: returningAdult);
      final (outcome, _) = boot(services);

      expect((outcome as BootSucceeded).destination, isA<HomeDestination>());
      expect(services.ads.initOptions?.personalizedAllowed, isTrue);
      expect(services.analyticsBackend.userId, 'a-guest-1');
      final steps = services.analyticsBackend
          .named(AnalyticsEvents.appInitStep)
          .map((e) => e.params['step'])
          .toList();
      expect(steps, hasLength(buildBootSteps().length));
      final completed = services.analyticsBackend
          .named(AnalyticsEvents.appInitCompleted)
          .single;
      // Booleans are converted to 1/0 for GA4.
      expect(completed.params['cold_start'], 1);
      expect(completed.params['degraded_steps'], '');
    },
  );

  test('a 13-15 user gets no analytics and age-restricted ads', () {
    final services = FakeServices(
      prefs: {'age_band': '13_15', 'onboarding_completed': true},
    );
    boot(services);
    expect(services.analytics.consent, AnalyticsConsent.disabled);
    expect(services.analyticsBackend.collectionEnabled, isFalse);
    expect(services.ads.initOptions?.underAgeOfConsent, isTrue);
    expect(services.ads.initOptions?.personalizedAllowed, isFalse);
  });

  group('deep links queued during boot', () {
    test('are delivered by the route step', () {
      final services = FakeServices(prefs: returningAdult);
      services.deepLinks.enqueue(
        UriLink(Uri.parse('https://$testLinkHost/j/abc-234')),
      );
      final (outcome, _) = boot(services);
      final destination = (outcome as BootSucceeded).destination;
      expect(destination, isA<DeepLinkDestination>());
      expect(destination.location, '/j/ABC234');
      expect(services.deepLinks.isEmpty, isTrue);
    });

    test('wait for onboarding on first launch', () {
      final services = FakeServices();
      services.deepLinks.enqueue(const PushLink({'room_code': 'xyz789'}));
      final (outcome, _) = boot(services);
      final destination = (outcome as BootSucceeded).destination;
      expect(destination, isA<OnboardingDestination>());
      expect(
        (destination as OnboardingDestination).pendingLink,
        const JoinRoomLink('XYZ789'),
      );
      expect(services.deepLinks.deferred, const JoinRoomLink('XYZ789'));
    });

    test('from foreign hosts are ignored', () {
      final services = FakeServices(prefs: returningAdult);
      services.deepLinks.enqueue(
        UriLink(Uri.parse('https://evil.example/j/ABC234')),
      );
      final (outcome, _) = boot(services);
      expect((outcome as BootSucceeded).destination, isA<HomeDestination>());
    });
  });

  group('config gates', () {
    test('maintenance_mode routes to maintenance and skips SDKs except crash '
        'reporting', () {
      final services = FakeServices(
        prefs: returningAdult,
        remoteConfig: {'maintenance_mode': 'true'},
      );
      final (outcome, init) = boot(services);
      final success = outcome as BootSucceeded;
      expect(success.destination, isA<MaintenanceDestination>());
      expect(services.crashReporter.initialized, isTrue);
      expect(services.ads.isInitialized, isFalse);
      expect(services.purchases.isConfigured, isFalse);
      expect(services.preferences.isOpen, isFalse);
      expect(init.currentProgress.value, 1.0);
    });

    test('min_supported_app_version above the installed version forces an '
        'update', () {
      final services = FakeServices(
        appVersion: '1.4.2',
        remoteConfig: {'min_supported_app_version': '1.5.0'},
      );
      final (outcome, _) = boot(services);
      expect(
        (outcome as BootSucceeded).destination,
        isA<ForceUpdateDestination>(),
      );
    });

    test('force update wins over maintenance', () {
      final services = FakeServices(
        remoteConfig: {
          'maintenance_mode': 'true',
          'min_supported_app_version': '9.0.0',
        },
      );
      final (outcome, _) = boot(services);
      expect(
        (outcome as BootSucceeded).destination,
        isA<ForceUpdateDestination>(),
      );
    });

    test('a slow config fetch times out and falls back to cached values', () {
      final services = FakeServices(
        prefs: returningAdult,
        cachedConfig: {'paywall_variant': 'b'},
        remoteConfig: {'paywall_variant': 'c'},
      )..rcBackend.fetchDelay = const Duration(seconds: 5);
      final (outcome, _) = boot(services);
      final success = outcome as BootSucceeded;
      final fetch = success.report.records.firstWhere(
        (r) => r.stepId == StepIds.configFetch,
      );
      expect(fetch.result, StepResult.timeout);
      expect(services.remoteConfig.paywallVariant, 'b');
      expect(success.destination, isA<HomeDestination>());
    });
  });

  test('a failing prefs store is a critical failure with retry', () {
    final services = FakeServices(prefs: returningAdult);
    services.preferences.failOpen = true;
    fakeAsync((async) {
      final init = AppInitializer(
        steps: buildBootSteps(),
        context: services.context(),
        telemetry: AnalyticsBootTelemetry(services.analytics),
      );
      BootOutcome? outcome;
      unawaited(init.run().then((o) => outcome = o));
      async.elapse(const Duration(seconds: 10));
      expect((outcome! as BootCriticalFailure).stepId, StepIds.storageOpen);

      services.preferences.failOpen = false;
      unawaited(init.retry().then((o) => outcome = o));
      async.elapse(const Duration(seconds: 10));
      expect(outcome, isA<BootSucceeded>());
      expect(services.rcBackend.fetchCount, 1, reason: 'config not re-run');
    });
  });
}
