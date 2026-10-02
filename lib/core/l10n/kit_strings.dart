import 'dart:ui' show Locale;

import 'package:mobile_kit/mobile_kit.dart'
    show
        MobileKitLocalizations,
        MobileKitLocalizationsEn,
        MobileKitLocalizationsPl,
        MobileKitLocalizationsRu;

import 'package:sporand/core/l10n/gen/app_localizations.dart';
import 'package:sporand/core/l10n/gen/app_localizations_en.dart';
import 'package:sporand/core/l10n/gen/app_localizations_pl.dart';
import 'package:sporand/core/l10n/gen/app_localizations_ru.dart';

/// SpoRand's copy of the mobile_kit strings whose kit text differs (wave 8b;
/// mobile_kit README, "Kit strings that differ from the first consumer
/// app"). The texts come from the app's own ARB ([appStrings]), so the kit's
/// screens and widgets say exactly what SpoRand's do; every other kit key
/// already has SpoRand's text. The app gets them as
/// `KitStringsDelegate(sporandKitStrings)` [новое имя — согласовать].
mixin SporandKitStrings on MobileKitLocalizations {
  /// The app's strings of the same language.
  AppLocalizations get appStrings;

  @override
  String get forceUpdateBody => appStrings.forceUpdateBody;

  /// SpoRand's text names the threshold of the standard `AgePolicy` (13).
  @override
  String onboardingBlockedBody(int age) => appStrings.onboardingBlockedBody;

  @override
  String get onboardingConsentBody => appStrings.onboardingConsentBody;

  /// SpoRand's text names the threshold of the standard `AgePolicy` (16).
  @override
  String onboardingConsentMinorNote(int age) =>
      appStrings.onboardingConsentMinorNote;

  @override
  String get onboardingConsentStart => appStrings.onboardingConsentStart;

  @override
  String get settingsAnalyticsSubtitle => appStrings.settingsAnalyticsSubtitle;

  /// SpoRand's text names the threshold of the standard `AgePolicy` (16).
  @override
  String settingsAnalyticsUnavailable(int age) =>
      appStrings.settingsAnalyticsUnavailable;

  @override
  String get paywallTitle => appStrings.paywallTitle;

  @override
  String get paywallSubtitle => appStrings.paywallSubtitle;
}

/// The kit strings in Russian with SpoRand's copy.
class SporandKitStringsRu extends MobileKitLocalizationsRu
    with SporandKitStrings {
  @override
  final AppLocalizations appStrings = AppLocalizationsRu();
}

/// The kit strings in English with SpoRand's copy.
class SporandKitStringsEn extends MobileKitLocalizationsEn
    with SporandKitStrings {
  @override
  final AppLocalizations appStrings = AppLocalizationsEn();
}

/// The kit strings in Polish with SpoRand's copy.
class SporandKitStringsPl extends MobileKitLocalizationsPl
    with SporandKitStrings {
  @override
  final AppLocalizations appStrings = AppLocalizationsPl();
}

/// The kit strings of [locale] with SpoRand's copy: its language when the app
/// ships it (ru, en, pl), else English, as the kit's own `lookupKitStrings`
/// does. The lookup of `KitStringsDelegate(sporandKitStrings)`
/// [новое имя — согласовать].
MobileKitLocalizations sporandKitStrings(Locale locale) =>
    switch (locale.languageCode) {
      'ru' => SporandKitStringsRu(),
      'pl' => SporandKitStringsPl(),
      _ => SporandKitStringsEn(),
    };
