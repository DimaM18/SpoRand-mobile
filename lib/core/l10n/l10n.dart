import 'package:flutter/widgets.dart';

import 'package:sporand/core/l10n/gen/app_localizations.dart';

export 'package:sporand/core/l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

abstract final class AppLocales {
  /// Used when none of the device languages is supported. Not the `ru` ARB
  /// template: for the Poland soft launch a Ukrainian, German or Czech phone
  /// should get English, not Russian.
  static const fallback = Locale('en');
}

/// `MaterialApp.localeListResolutionCallback`: the first device language we
/// support (matched by language code, in the user's order), else
/// [AppLocales.fallback].
Locale resolveAppLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final locale in preferred ?? const <Locale>[]) {
    for (final candidate in supported) {
      if (candidate.languageCode == locale.languageCode) return candidate;
    }
  }
  return AppLocales.fallback;
}
