import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/consent/youtube_consent.dart';
import 'package:sporand/core/storage/preferences_store.dart';

void main() {
  group('YouTubeConsentGate (YouTube III.E.4.i)', () {
    late InMemoryPreferencesStore prefs;

    setUp(() async {
      prefs = InMemoryPreferencesStore();
      await prefs.open();
    });

    Future<YouTubeConsentGate> gate(ConsentStatus status) async {
      final ump = FakeConsentService(statusAfterRefresh: status);
      await ump.refresh(underAgeOfConsent: false);
      return YouTubeConsentGate(ump: ump, prefs: prefs);
    }

    test('outside the EEA/UK the player loads without asking', () async {
      expect(
        (await gate(ConsentStatus.notRequired)).decision,
        YouTubeConsentDecision.allowed,
      );
    });

    test('EEA/UK and an unknown region ask first', () async {
      expect(
        (await gate(ConsentStatus.required)).decision,
        YouTubeConsentDecision.ask,
      );
      expect(
        (await gate(ConsentStatus.obtained)).decision,
        YouTubeConsentDecision.ask,
        reason: 'an answered UMP form is not consent to the player',
      );
      final unknown = YouTubeConsentGate(
        ump: FakeConsentService(),
        prefs: prefs,
      );
      expect(unknown.decision, YouTubeConsentDecision.ask);
    });

    test('a «yes» is stored; a «no» holds for this app session only', () async {
      final first = await gate(ConsentStatus.required);
      first.decline();
      expect(first.decision, YouTubeConsentDecision.declined);
      expect(prefs.getBool(PrefKeys.youtubePlayerConsent), isNull);
      // Next app launch: asked again.
      expect(
        (await gate(ConsentStatus.required)).decision,
        YouTubeConsentDecision.ask,
      );

      await first.grant();
      expect(first.decision, YouTubeConsentDecision.allowed);
      expect(
        (await gate(ConsentStatus.required)).decision,
        YouTubeConsentDecision.allowed,
      );
    });

    test('an unopened store never throws', () async {
      final closed = YouTubeConsentGate(
        ump: FakeConsentService(),
        prefs: SharedPreferencesStore(),
      );
      await closed.grant();
      expect(closed.decision, YouTubeConsentDecision.ask);
    });
  });
}
