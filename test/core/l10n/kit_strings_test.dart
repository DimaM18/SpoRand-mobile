import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show KitStringsDelegate, MobileKitLocalizations;

import 'package:sporand/core/l10n/kit_strings.dart';
import 'package:sporand/core/l10n/l10n.dart';

void main() {
  test('one subclass per language; other languages get English', () {
    expect(sporandKitStrings(const Locale('ru')), isA<SporandKitStringsRu>());
    expect(sporandKitStrings(const Locale('en')), isA<SporandKitStringsEn>());
    expect(
      sporandKitStrings(const Locale('pl', 'PL')),
      isA<SporandKitStringsPl>(),
    );
    expect(sporandKitStrings(const Locale('de')), isA<SporandKitStringsEn>());
  });

  test('the delegate loads them for every locale', () async {
    const delegate = KitStringsDelegate(sporandKitStrings);
    expect(delegate.isSupported(const Locale('uk')), isTrue);
    expect(await delegate.load(const Locale('ru')), isA<SporandKitStringsRu>());
  });

  for (final language in ['ru', 'en', 'pl']) {
    test('$language: the kit strings that differ keep SpoRand\'s copy', () {
      final locale = Locale(language);
      final MobileKitLocalizations kit = sporandKitStrings(locale);
      final app = lookupAppLocalizations(locale);
      expect(kit.forceUpdateBody, app.forceUpdateBody);
      expect(kit.onboardingBlockedBody(13), app.onboardingBlockedBody);
      expect(kit.onboardingConsentBody, app.onboardingConsentBody);
      expect(
        kit.onboardingConsentMinorNote(16),
        app.onboardingConsentMinorNote,
      );
      expect(kit.onboardingConsentStart, app.onboardingConsentStart);
      expect(kit.settingsAnalyticsSubtitle, app.settingsAnalyticsSubtitle);
      expect(
        kit.settingsAnalyticsUnavailable(16),
        app.settingsAnalyticsUnavailable,
      );
      expect(kit.paywallTitle, app.paywallTitle);
      expect(kit.paywallSubtitle, app.paywallSubtitle);
      // Renamed in the kit, same text.
      expect(kit.errorNetwork, app.roomErrorNetwork);
      expect(kit.errorTryAgain, app.roomErrorOther);
    });
  }
}
