import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show FontSpec, KitPalette, KitShape, KitThemeSpec;

import 'package:sporand/core/theme/app_fonts.dart';
import 'package:sporand/core/theme/tokens.dart';

/// Material 3 themes with a hand-tuned scheme (not seed-generated), so the
/// app keeps a distinct identity in both modes. Design system
/// "Neon Night+": the schemes are unchanged from wave 5; wave 6 adds the
/// bundled fonts, the type scale, component themes and [GameColors].
///
/// Wave 8b: mobile_kit builds the app's `ThemeData` with these
/// (`KitAppConfig.themeBuilder`); besides [PartyColors] and [GameColors]
/// they carry the kit's `KitBrand` and `KitShape` with SpoRand's values,
/// which the kit's widgets and screens read.
abstract final class AppTheme {
  static const darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFA594FF),
    onPrimary: Color(0xFF1B1045),
    primaryContainer: Color(0xFF4A33C9),
    onPrimaryContainer: Color(0xFFEAE5FF),
    secondary: Color(0xFFFF5CA8),
    onSecondary: Color(0xFF3B0020),
    secondaryContainer: Color(0xFF8A1553),
    onSecondaryContainer: Color(0xFFFFD9E8),
    tertiary: BrandColors.cyan,
    onTertiary: Color(0xFF002733),
    tertiaryContainer: Color(0xFF005E78),
    onTertiaryContainer: Color(0xFFBFF0FF),
    error: Color(0xFFFF8A80),
    onError: Color(0xFF3A0000),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: BrandColors.nightInk,
    onSurface: Color(0xFFF4F1FF),
    onSurfaceVariant: Color(0xFFB9B2D9),
    surfaceContainerLowest: Color(0xFF0A0817),
    surfaceContainerLow: Color(0xFF15122B),
    surfaceContainer: Color(0xFF1B1735),
    surfaceContainerHigh: Color(0xFF241F44),
    surfaceContainerHighest: Color(0xFF2E2854),
    // 3:1 or more against every surface container up to the text-field
    // fill (WCAG 1.4.11): field edges, the off switch, step pills.
    outline: Color(0xFF7C74A2),
    outlineVariant: Color(0xFF3A3360),
    inverseSurface: Color(0xFFF4F1FF),
    onInverseSurface: Color(0xFF1B1733),
    inversePrimary: Color(0xFF5B3DF5),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static const lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF5B3DF5),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE6E0FF),
    onPrimaryContainer: Color(0xFF1B0E66),
    secondary: Color(0xFFC2186B),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFFD9E8),
    onSecondaryContainer: Color(0xFF3E0021),
    tertiary: Color(0xFF00718F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFBFF0FF),
    onTertiaryContainer: Color(0xFF001F29),
    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: BrandColors.dayMist,
    onSurface: Color(0xFF17132E),
    onSurfaceVariant: Color(0xFF4B4570),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF3F0FF),
    surfaceContainer: Color(0xFFEDE9FC),
    surfaceContainerHigh: Color(0xFFE6E1F8),
    surfaceContainerHighest: Color(0xFFDFD9F3),
    outline: Color(0xFF7A7399),
    outlineVariant: Color(0xFFCBC4E6),
    inverseSurface: Color(0xFF2B2548),
    onInverseSurface: Color(0xFFF4F1FF),
    inversePrimary: Color(0xFFA594FF),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
  );

  static ThemeData dark() =>
      _build(darkScheme, PartyColors.dark, GameColors.dark);

  static ThemeData light() =>
      _build(lightScheme, PartyColors.light, GameColors.light);

  /// Type scale (design system §3.3). Unbounded for short display strings,
  /// Nunito for the rest; sizes stay the same as wave 5 or grow. Scores and
  /// the room code use [PartyTextStyles.tabular].
  static TextTheme textTheme(ColorScheme scheme) {
    TextStyle style(
      String family,
      double size,
      FontWeight weight, {
      double height = 1.25,
      double spacing = 0,
      bool tabular = false,
    }) => TextStyle(
      fontFamily: family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: scheme.onSurface,
      fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
    );

    const d = AppFonts.display;
    const b = AppFonts.body;
    return TextTheme(
      displayLarge: style(
        d,
        56,
        FontWeight.w800,
        height: 1.05,
        spacing: -0.5,
        tabular: true,
      ),
      displayMedium: style(d, 40, FontWeight.w800, height: 1.08, spacing: -0.5),
      displaySmall: style(
        d,
        36,
        FontWeight.w700,
        height: 1.1,
        spacing: 2,
        tabular: true,
      ),
      headlineLarge: style(d, 30, FontWeight.w700, height: 1.15),
      headlineMedium: style(d, 26, FontWeight.w700, height: 1.2),
      headlineSmall: style(b, 24, FontWeight.w900, height: 1.2),
      titleLarge: style(b, 22, FontWeight.w800, height: 1.25),
      titleMedium: style(b, 18, FontWeight.w700, height: 1.35),
      titleSmall: style(b, 15, FontWeight.w700, height: 1.4),
      bodyLarge: style(b, 16, FontWeight.w500, height: 1.5),
      bodyMedium: style(b, 15, FontWeight.w500, height: 1.45),
      bodySmall: style(b, 13, FontWeight.w600, height: 1.4),
      labelLarge: style(b, 18, FontWeight.w800, height: 1.2),
      labelMedium: style(b, 13, FontWeight.w700, height: 1.3, spacing: 0.2),
      labelSmall: style(b, 12, FontWeight.w700, height: 1.3, spacing: 0.3),
    );
  }

  static ThemeData _build(
    ColorScheme scheme,
    PartyColors party,
    GameColors game,
  ) {
    final text = textTheme(scheme);
    const stadium = StadiumBorder();
    final buttonText = text.labelLarge;
    const buttonPadding = EdgeInsets.symmetric(
      horizontal: Spacing.lg,
      vertical: Spacing.sm,
    );
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
    );
    OutlineInputBorder inputBorder(BorderSide side) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(Radii.md),
      borderSide: side,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      fontFamily: AppFonts.body,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: [party, game, party.kitBrand, KitShape.standard],
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashFactory: InkSparkle.splashFactory,
      iconTheme: IconThemeData(color: scheme.onSurface, size: IconSizes.md),
      appBarTheme: AppBarTheme(
        // Opaque (so the status bar icons follow the theme) and a visible
        // edge once content scrolls under the bar.
        backgroundColor: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.scrolledUnder)
              ? scheme.surfaceContainer
              : scheme.surface,
        ),
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, TapTargets.button),
          padding: buttonPadding,
          shape: stadium,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, TapTargets.button),
          padding: buttonPadding,
          shape: stadium,
          side: BorderSide(color: scheme.outline, width: 1.5),
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, TapTargets.button),
          padding: buttonPadding,
          shape: stadium,
          elevation: 0,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(TapTargets.min, TapTargets.min),
          shape: stadium,
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(TapTargets.min, TapTargets.min),
          iconSize: IconSizes.md,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: cardShape,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.secondaryContainer,
        disabledColor: scheme.surfaceContainer,
        checkmarkColor: scheme.onSecondaryContainer,
        showCheckmark: true,
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(size: IconSizes.sm, color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.xs,
          vertical: Spacing.xxs,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? BorderSide(color: scheme.secondaryContainer)
              : BorderSide(color: scheme.outline),
        ),
        shape: stadium,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        hintStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        // A visible edge (WCAG 1.4.11): the fill alone is only 1.1–1.4:1
        // against cards, sheets and dialogs.
        border: inputBorder(BorderSide(color: scheme.outline)),
        enabledBorder: inputBorder(BorderSide(color: scheme.outline)),
        focusedBorder: inputBorder(BorderSide(color: scheme.primary, width: 2)),
        errorBorder: inputBorder(BorderSide(color: scheme.error, width: 2)),
        focusedErrorBorder: inputBorder(
          BorderSide(color: scheme.error, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        minVerticalPadding: Spacing.sm,
        minTileHeight: TapTargets.button,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              // 6.4:1 or more on the off track (outline was 2.55:1 dark).
              : scheme.onSurfaceVariant,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: party.ringTrack,
        circularTrackColor: Colors.transparent,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        actionTextColor: scheme.inversePrimary,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        modalBackgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: cardShape,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// The «Neon Night+» look as mobile_kit's theme spec (wave 8b): the hand-tuned
/// schemes of [AppTheme], the brand of [PartyColors] in each mode, the
/// standard radii ([Radii]) and the bundled fonts ([AppFonts]). It is
/// `KitAppConfig.theme` (the kit's default warm-up and contrast check read
/// it); the `ThemeData` itself comes from [AppTheme] (`themeBuilder`)
/// [новое имя — согласовать].
final sporandThemeSpec = KitThemeSpec(
  light: const KitPalette(
    seed: BrandColors.violet,
    scheme: AppTheme.lightScheme,
  ),
  dark: const KitPalette(seed: BrandColors.violet, scheme: AppTheme.darkScheme),
  brand: PartyColors.light.kitBrand,
  darkBrand: PartyColors.dark.kitBrand,
  fonts: FontSpec(
    display: AppFonts.display,
    body: AppFonts.body,
    displayWeights: AppFonts.displayWeights,
    bodyWeights: AppFonts.bodyWeights,
    licenceAssets: AppFonts.licenses.values.toList(growable: false),
  ),
);

/// Style helpers on top of the theme's [TextTheme].
extension PartyTextStyles on TextStyle {
  /// Tabular figures for every changing number (scores, timers, the room
  /// code, counters, reaction times), so digits never shift sideways.
  TextStyle get tabular => copyWith(
    fontFeatures: [
      ...?fontFeatures?.where((f) => f.feature != 'tnum'),
      const FontFeature.tabularFigures(),
    ],
  );
}
