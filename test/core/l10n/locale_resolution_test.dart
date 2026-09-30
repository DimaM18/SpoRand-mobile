import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/l10n/l10n.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  // Regression: with no match Flutter picked supportedLocales.first, i.e.
  // the ru template, so a Ukrainian or German phone showed Russian.
  test('an unsupported device language falls back to English', () {
    expect(resolveAppLocale(const [Locale('uk', 'UA')], supported), fallback);
    expect(resolveAppLocale(const [Locale('de')], supported), fallback);
    expect(resolveAppLocale(null, supported), fallback);
    expect(resolveAppLocale(const [], supported), fallback);
    expect(fallback, const Locale('en'));
  });

  test('supported languages match by language code, in preference order', () {
    expect(
      resolveAppLocale(const [Locale('pl', 'PL')], supported),
      const Locale('pl'),
    );
    expect(
      resolveAppLocale(const [Locale('de'), Locale('ru', 'RU')], supported),
      const Locale('ru'),
    );
    expect(
      resolveAppLocale(const [Locale('en', 'GB'), Locale('pl')], supported),
      const Locale('en'),
    );
  });
}

const fallback = AppLocales.fallback;
