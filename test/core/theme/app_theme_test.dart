import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

// The pre-wave-6 import paths must keep working.
import 'package:sporand/app/bootstrap/presentation/widgets/equalizer_bars.dart'
    as legacy_eq;
import 'package:sporand/app/theme/app_theme.dart' as legacy_theme;
import 'package:sporand/app/theme/tokens.dart' as legacy_tokens;
import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/equalizer_bars.dart';

void main() {
  test('both themes register PartyColors and GameColors and keep the '
      'launch backgrounds', () {
    for (final (theme, party, game) in [
      (AppTheme.dark(), PartyColors.dark, GameColors.dark),
      (AppTheme.light(), PartyColors.light, GameColors.light),
    ]) {
      expect(theme.extension<PartyColors>(), same(party));
      expect(theme.extension<GameColors>(), same(game));
      expect(theme.scaffoldBackgroundColor, party.launchBackground);
      expect(theme.textTheme.bodyLarge?.fontFamily, AppFonts.body);
    }
    expect(PartyColors.dark.launchBackground, BrandColors.nightInk);
    expect(PartyColors.light.launchBackground, BrandColors.dayMist);
  });

  test('the legacy gradient name is the decorative neon gradient', () {
    expect(PartyColors.dark.gradient, PartyColors.dark.neonGradient);
    expect(PartyColors.light.gradient, PartyColors.light.neonGradient);
  });

  test('extensions lerp and copy', () {
    final mid = GameColors.dark.lerp(GameColors.light, 0.5);
    expect(mid.answers, hasLength(GameColors.slots));
    expect(
      mid.correct,
      Color.lerp(GameColors.dark.correct, GameColors.light.correct, 0.5),
    );
    expect(GameColors.dark.lerp(null, 0.5), same(GameColors.dark));
    expect(
      GameColors.dark.copyWith(gold: const Color(0xFF000000)).gold,
      const Color(0xFF000000),
    );
    final party = PartyColors.dark.lerp(PartyColors.light, 1);
    expect(party.headlineGradient, PartyColors.light.headlineGradient);
    expect(
      PartyColors.dark.copyWith(onCta: const Color(0xFF000000)).onCta,
      const Color(0xFF000000),
    );
    expect(GameColors.dark.answer(7), GameColors.dark.answer(1));
  });

  test('buttons are at least 56 dp, text and icon buttons 48 dp', () {
    final theme = AppTheme.dark();
    Size? min(ButtonStyle? style) => style?.minimumSize?.resolve({});
    expect(min(theme.filledButtonTheme.style)?.height, 56);
    expect(min(theme.outlinedButtonTheme.style)?.height, 56);
    expect(min(theme.textButtonTheme.style)?.height, 48);
    expect(min(theme.iconButtonTheme.style)?.height, 48);
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);
    expect(theme.listTileTheme.minTileHeight, 56);
  });

  test('app bars are opaque on the page colour and gain a surfaceContainer '
      'edge when content scrolls under them', () {
    for (final theme in [AppTheme.dark(), AppTheme.light()]) {
      final scheme = theme.colorScheme;
      final color = theme.appBarTheme.backgroundColor!;
      expect(WidgetStateProperty.resolveAs(color, {}), scheme.surface);
      expect(
        WidgetStateProperty.resolveAs(color, {WidgetState.scrolledUnder}),
        scheme.surfaceContainer,
      );
    }
  });

  test('tokens: motion, spacing and targets', () {
    expect(Motion.press, lessThanOrEqualTo(const Duration(milliseconds: 100)));
    expect(Motion.medium, const Duration(milliseconds: 280));
    expect(Motion.stagger, const Duration(milliseconds: 40));
    expect(Spacing.gutter(360), 16);
    expect(Spacing.gutter(412), 24);
    expect(TapTargets.answer, 88);
    expect(TapTargets.answerCompact, 76);
    expect(IconSizes.xl, 48);
  });

  test('the legacy import paths re-export the same types', () {
    expect(legacy_tokens.PartyColors.dark, same(PartyColors.dark));
    expect(legacy_theme.AppTheme.darkScheme, same(AppTheme.darkScheme));
    expect(const legacy_eq.EqualizerBars(animate: false), isA<EqualizerBars>());
  });

  testWidgets('Motion.reduced follows MediaQuery.disableAnimations', (
    tester,
  ) async {
    late bool reduced;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            reduced = Motion.reduced(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(reduced, isTrue);
  });
}
