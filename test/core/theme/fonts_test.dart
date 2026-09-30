import 'package:flutter/foundation.dart' show LicenseRegistry;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/warmup/flutter_resource_warmer.dart';
import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/app_theme.dart';

/// Width of [text] laid out in [style].
double _width(String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

Future<void> _loadBundledFonts() async {
  for (final MapEntry(key: family, value: path) in AppFonts.files.entries) {
    await (FontLoader(family)..addFont(rootBundle.load(path))).load();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both families are bundled with their OFL texts', () async {
    for (final family in [AppFonts.display, AppFonts.body]) {
      final font = await rootBundle.load(AppFonts.files[family]!);
      expect(font.lengthInBytes, greaterThan(100000), reason: family);
      final licence = await rootBundle.loadString(AppFonts.licenses[family]!);
      expect(licence, contains('SIL OPEN FONT LICENSE Version 1.1'));
      expect(licence, contains('The $family Project Authors'));
    }
  });

  test('the fonts warm-up step registers both licences before it awaits '
      'anything', () async {
    AppFonts.debugResetLicenses();
    // Not awaited: the registration must already be done synchronously.
    final warmup = FlutterResourceWarmer().loadFonts();
    final entries = await LicenseRegistry.licenses.toList();
    await warmup;
    final packages = {for (final e in entries) ...e.packages};
    expect(packages, containsAll([AppFonts.display, AppFonts.body]));
    final nunito = entries.firstWhere((e) => e.packages.contains('Nunito'));
    expect(
      nunito.paragraphs.map((p) => p.text).join(' '),
      contains('SIL OPEN FONT LICENSE'),
    );
    // Idempotent: a second warm-up does not add duplicates.
    await FlutterResourceWarmer().loadFonts();
    final again = await LicenseRegistry.licenses.toList();
    expect(again.where((e) => e.packages.contains('Unbounded')), hasLength(1));
  });

  test('every glyph of the Russian and Polish sample comes from the bundled '
      'fonts, and FontWeight drives the variable wght axis', () async {
    await _loadBundledFonts();
    const size = 40.0;
    const sample = 'ЧьяэтопесняёйЁЙąćęłńóśźżĄĆĘŁŃÓŚŹŻ0123456789';
    for (final family in [AppFonts.display, AppFonts.body]) {
      for (final char in sample.characters) {
        // The test fallback font draws every glyph exactly 1 em wide.
        final width = _width(
          char,
          TextStyle(fontFamily: family, fontSize: size),
        );
        expect(width, isNot(size), reason: '$family lacks "$char"');
      }
      // Strictly wider at every step: a static instance or synthetic bold
      // (one step at w600) could not do that.
      const words = 'Чья это песня? Czyja to piosenka?';
      final widths = [
        for (final weight in const [
          FontWeight.w400,
          FontWeight.w500,
          FontWeight.w700,
          FontWeight.w900,
        ])
          _width(
            words,
            TextStyle(fontFamily: family, fontSize: size, fontWeight: weight),
          ),
      ];
      for (var k = 1; k < widths.length; k++) {
        expect(widths[k], greaterThan(widths[k - 1]), reason: '$family $k');
      }
    }
  });

  test('Nunito figures are tabular without tnum; Unbounded has tnum', () async {
    await _loadBundledFonts();
    const style = TextStyle(fontFamily: AppFonts.body, fontSize: 30);
    final widths = {for (final d in '0123456789'.characters) _width(d, style)};
    expect(widths, hasLength(1));
    final display = const TextStyle(
      fontFamily: AppFonts.display,
      fontSize: 30,
    ).tabular;
    final tabularWidths = {
      for (final d in '0123456789'.characters) _width(d, display),
    };
    expect(tabularWidths, hasLength(1));
  });

  test('display family only on short display roles', () {
    final text = AppTheme.textTheme(AppTheme.darkScheme);
    final display = {
      text.displayLarge,
      text.displayMedium,
      text.displaySmall,
      text.headlineLarge,
      text.headlineMedium,
    };
    for (final style in display) {
      expect(style?.fontFamily, AppFonts.display);
    }
    for (final style in [
      text.headlineSmall,
      text.titleLarge,
      text.titleMedium,
      text.titleSmall,
      text.bodyLarge,
      text.bodyMedium,
      text.bodySmall,
      text.labelLarge,
      text.labelMedium,
      text.labelSmall,
    ]) {
      expect(style?.fontFamily, AppFonts.body);
      expect(style?.fontSize, greaterThanOrEqualTo(12));
      // Weights come from fontWeight only, so copyWith(fontWeight:) works.
      expect(style?.fontVariations, isNull);
    }
    expect(text.titleLarge?.fontSize, 22);
    expect(text.labelLarge?.fontSize, 18);
  });
}
