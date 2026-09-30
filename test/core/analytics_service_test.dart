import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_policy.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/privacy/age_band.dart';

void main() {
  late InMemoryAnalyticsBackend backend;
  late AnalyticsService analytics;

  setUp(() {
    backend = InMemoryAnalyticsBackend();
    analytics = AnalyticsService(backend: backend);
  });

  group('Spotify Terms IV.2.5 guard', () {
    for (final name in [
      'track_id',
      'artist',
      'song_title',
      'playlist_name',
      'spotify_uri',
      'TrackName',
    ]) {
      test('rejects parameter "$name"', () {
        expect(
          () => analytics.logEvent('room_create', {name: 'x'}),
          throwsA(isA<AssertionError>()),
        );
      });
    }

    test('allows the canonical track_count_bucket', () {
      expect(AnalyticsService.isAllowedParamName('track_count_bucket'), isTrue);
    });

    test('rejects reserved and malformed event names', () {
      expect(() => analytics.logEvent('error'), throwsA(isA<AssertionError>()));
      expect(
        () => analytics.logEvent('firebase_x'),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => analytics.logEvent('RoomCreate'),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  test('sanitizes values for GA4', () {
    final params = AnalyticsService.sanitizeParams({
      'cold_start': true,
      'total_ms': 12,
      'skipped': null,
      'placement': 'x' * 150,
    });
    expect(params, {'cold_start': 1, 'total_ms': 12, 'placement': 'x' * 100});
  });

  group('consent gating', () {
    test('buffers until consent is granted, then flushes in order', () async {
      await analytics.initialize();
      await analytics.logEvent('app_init_step', {'step': 'a'});
      await analytics.logEvent('app_init_step', {'step': 'b'});
      expect(backend.events, isEmpty);
      expect(backend.consent?.analyticsStorage, isFalse);

      await analytics.applyConsent(AnalyticsConsent.granted);
      expect(backend.events.map((e) => e.params['step']), ['a', 'b']);
      expect(backend.consent?.analyticsStorage, isTrue);
      await analytics.logEvent('room_share', {'channel': 'qr'});
      expect(backend.events, hasLength(3));
    });

    test('drops everything when denied', () async {
      await analytics.initialize();
      await analytics.logEvent('room_share');
      await analytics.applyConsent(AnalyticsConsent.denied);
      await analytics.logEvent('room_share');
      expect(backend.events, isEmpty);
      expect(backend.collectionEnabled, isFalse);
      expect(analytics.bufferedCount, 0);
    });

    test('events before SDK init are kept until init + consent', () async {
      await analytics.logEvent('room_share');
      await analytics.applyConsent(AnalyticsConsent.granted);
      expect(backend.events, isEmpty);
      await analytics.setUserId('a-1');
      await analytics.initialize();
      expect(backend.events, hasLength(1));
      expect(backend.userId, 'a-1');
    });
  });

  group('consent policy', () {
    const eea = ConsentInfo(
      status: ConsentStatus.required,
      canRequestAds: false,
    );
    const outside = ConsentInfo(
      status: ConsentStatus.notRequired,
      canRequestAds: true,
    );

    test('unknown age keeps analytics pending', () {
      expect(
        resolveAnalyticsConsent(
          ageBand: null,
          storedChoice: true,
          ump: outside,
        ),
        AnalyticsConsent.unknown,
      );
    });

    test('13-15 is always disabled', () {
      expect(
        resolveAnalyticsConsent(
          ageBand: AgeBand.age13to15,
          storedChoice: true,
          ump: outside,
        ),
        AnalyticsConsent.disabled,
      );
    });

    test('the stored choice wins; otherwise the UMP region decides', () {
      expect(
        resolveAnalyticsConsent(
          ageBand: AgeBand.adult,
          storedChoice: false,
          ump: outside,
        ),
        AnalyticsConsent.denied,
      );
      expect(
        resolveAnalyticsConsent(
          ageBand: AgeBand.adult,
          storedChoice: null,
          ump: outside,
        ),
        AnalyticsConsent.granted,
      );
      expect(
        resolveAnalyticsConsent(
          ageBand: AgeBand.adult,
          storedChoice: null,
          ump: eea,
        ),
        AnalyticsConsent.unknown,
      );
    });

    test('a UMP choice is not consent to personalized ads', () {
      // Regression: status `obtained` only means the user answered the form;
      // "Do not consent" also yields obtained + canRequestAds (limited ads).
      const answered = ConsentInfo(
        status: ConsentStatus.obtained,
        canRequestAds: true,
      );
      expect(
        resolveAdsPersonalized(ageBand: AgeBand.adult, ump: answered),
        isFalse,
      );
      expect(
        resolveAdsPersonalized(ageBand: AgeBand.adult, ump: outside),
        isTrue,
        reason: 'no consent requirement outside the EEA/UK',
      );
      expect(
        resolveAdsPersonalized(ageBand: AgeBand.age13to15, ump: outside),
        isFalse,
      );
      expect(resolveAdsPersonalized(ageBand: AgeBand.adult, ump: eea), isFalse);
    });
  });

  group('BufferingCrashReporter', () {
    test('buffers errors until attached, then forwards in order', () async {
      final gate = BufferingCrashReporter();
      await gate.recordError(StateError('one'), null, fatal: true);
      await gate.log('booting');
      await gate.setUserId('a-1');
      final real = FakeCrashReporter();
      await gate.attach(real);
      await gate.recordError(StateError('two'), null);

      expect(real.errors.map((e) => (e.error as StateError).message), [
        'one',
        'two',
      ]);
      expect(real.errors.first.fatal, isTrue);
      expect(real.logs, ['booting']);
      expect(real.userId, 'a-1');
    });

    test('is bounded', () async {
      final gate = BufferingCrashReporter(capacity: 3);
      for (var i = 0; i < 10; i++) {
        await gate.recordError(i, null);
      }
      expect(gate.pendingErrors.map((e) => e.error), [7, 8, 9]);
    });
  });
}
