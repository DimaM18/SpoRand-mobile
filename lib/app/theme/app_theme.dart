import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';

/// Material 3 themes with a hand-tuned scheme (not seed-generated), so the
/// app keeps a distinct identity in both modes.
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
    outline: Color(0xFF6D6594),
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

  static ThemeData dark() => _build(darkScheme, PartyColors.dark);

  static ThemeData light() => _build(lightScheme, PartyColors.light);

  /// Type scale: heavy, tightly tracked display sizes for the party feel;
  /// regular body text for readability. System fonts (no bundled assets).
  static TextTheme _textTheme(ColorScheme scheme) {
    TextStyle style(
      double size,
      FontWeight weight, {
      double height = 1.25,
      double spacing = 0,
    }) => TextStyle(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: scheme.onSurface,
    );

    return TextTheme(
      displayLarge: style(56, FontWeight.w900, height: 1.05, spacing: -1.5),
      displayMedium: style(44, FontWeight.w900, height: 1.08, spacing: -1.0),
      displaySmall: style(36, FontWeight.w800, height: 1.1, spacing: -0.8),
      headlineLarge: style(32, FontWeight.w800, height: 1.15, spacing: -0.6),
      headlineMedium: style(28, FontWeight.w800, height: 1.18, spacing: -0.4),
      headlineSmall: style(24, FontWeight.w700, height: 1.2, spacing: -0.2),
      titleLarge: style(22, FontWeight.w700, height: 1.25),
      titleMedium: style(16, FontWeight.w700, height: 1.35, spacing: 0.1),
      titleSmall: style(14, FontWeight.w600, height: 1.4, spacing: 0.1),
      bodyLarge: style(16, FontWeight.w400, height: 1.5, spacing: 0.15),
      bodyMedium: style(14, FontWeight.w400, height: 1.45, spacing: 0.2),
      bodySmall: style(12, FontWeight.w400, height: 1.4, spacing: 0.3),
      labelLarge: style(15, FontWeight.w700, height: 1.3, spacing: 0.3),
      labelMedium: style(12, FontWeight.w600, height: 1.3, spacing: 0.4),
      labelSmall: style(11, FontWeight.w600, height: 1.3, spacing: 0.5),
    );
  }

  static ThemeData _build(ColorScheme scheme, PartyColors party) {
    final text = _textTheme(scheme);
    const stadium = StadiumBorder();
    final buttonText = text.labelLarge?.copyWith(fontSize: 16);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: scheme.brightness,
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      textTheme: text,
      extensions: [party],
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: stadium,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 56),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: stadium,
          side: BorderSide(color: scheme.outline),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: stadium,
          textStyle: text.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
        minVerticalPadding: Spacing.sm,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(
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
