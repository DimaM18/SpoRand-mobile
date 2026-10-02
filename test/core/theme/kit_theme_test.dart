import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show KitBrand, KitShape, KitThemeContext;
import 'package:mobile_kit/testing.dart';

import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';

void expectBrandOf(KitBrand? brand, PartyColors party) {
  expect(brand, isNotNull);
  expect(brand!.ctaGradient, party.ctaGradient);
  expect(brand.onGradient, party.onCta);
  expect(brand.headlineGradient, party.headlineGradient);
  expect(brand.accentGradient, party.neonGradient);
  expect(brand.glow, party.glow);
  expect(brand.launchBackground, party.launchBackground);
}

void main() {
  test('both themes carry the kit brand and shape with SpoRand\'s values', () {
    for (final (theme, party) in [
      (AppTheme.dark(), PartyColors.dark),
      (AppTheme.light(), PartyColors.light),
    ]) {
      expectBrandOf(theme.extension<KitBrand>(), party);
      final shape = theme.extension<KitShape>()!;
      expect(
        [shape.sm, shape.md, shape.lg, shape.xl],
        [Radii.sm, Radii.md, Radii.lg, Radii.xl],
      );
    }
  });

  testWidgets('kit widgets read them from the theme', (tester) async {
    late KitBrand brand;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            brand = context.kitBrand;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expectBrandOf(brand, PartyColors.light);
  });

  test('sporandThemeSpec is the «Neon Night+» look', () {
    final spec = sporandThemeSpec;
    expect(spec.light.scheme, same(AppTheme.lightScheme));
    expect(spec.dark.scheme, same(AppTheme.darkScheme));
    expectBrandOf(spec.brand, PartyColors.light);
    expectBrandOf(spec.darkBrand, PartyColors.dark);
    expect(spec.fonts.display, AppFonts.display);
    expect(spec.fonts.body, AppFonts.body);
    expect(spec.fonts.licenceAssets, AppFonts.licenses.values);
    // The native launch screens equal the brand's launch background.
    expect(spec.brand.launchBackground, BrandColors.dayMist);
    expect(spec.darkBrand!.launchBackground, BrandColors.nightInk);
  });

  test('sporandThemeSpec passes the kit contrast check in both modes', () {
    expectReadableContrast(sporandThemeSpec);
  });

  test('tokens: the kit values plus SpoRand\'s own', () {
    expect(TapTargets.min, 48);
    expect(TapTargets.button, 56);
    expect(TapTargets.hero, 64);
    expect(Motion.vinylTurn, const Duration(milliseconds: 1800));
    expect(Motion.reducedCrossfade, const Duration(milliseconds: 150));
    expect(Spacing.xxl, 48);
    expect(Radii.xl, 32);
  });
}
