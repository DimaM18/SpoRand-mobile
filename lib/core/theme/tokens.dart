import 'package:material_ui/material_ui.dart';

export 'package:sporand/core/theme/game_colors.dart';

/// Brand palette: a dark-first "neon party" look (design system
/// "Neon Night+", `docs/DEVELOPMENT.md`). Only the theme and the native
/// launch parity read these directly; widgets use `ColorScheme`,
/// [PartyColors.of] and `GameColors.of`.
abstract final class BrandColors {
  // Brand accents (gradients, glow, equalizer).
  static const violet = Color(0xFF7B61FF);
  static const magenta = Color(0xFFFF4FA3);
  static const cyan = Color(0xFF3DDCFF);
  static const amber = Color(0xFFFFC24B);

  // Backgrounds. Must match the native launch screens exactly
  // (android/app/src/main/res/values*/colors.xml, iOS LaunchBackground).
  static const nightInk = Color(0xFF0E0B1F);
  static const dayMist = Color(0xFFF8F6FF);

  // Vinyl record.
  static const vinyl = Color(0xFF0B0A12);
  static const vinylEdge = Color(0xFF1E1B2E);
}

abstract final class Spacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Screen gutter: 16 below 400 dp of width, else 24.
  static double gutter(double width) => width < 400 ? md : lg;
}

abstract final class Radii {
  /// Chips, toasts, standings rows.
  static const sm = 12.0;

  /// Inputs, the QR tile.
  static const md = 16.0;

  /// Cards and answer tiles.
  static const lg = 24.0;

  /// Hero CTA, banner cards, the top of sheets.
  static const xl = 32.0;
}

/// Icon sizes: inline, default, prominent, hero.
abstract final class IconSizes {
  static const sm = 20.0;
  static const md = 24.0;
  static const lg = 32.0;
  static const xl = 48.0;
}

/// Minimum touch target heights (dp). Anything tappable is at least [min].
abstract final class TapTargets {
  static const min = 48.0;
  static const button = 56.0;
  static const hero = 64.0;

  /// Answer tiles; [answerCompact] when the screen is under
  /// [compactHeight] dp tall, so four tiles stay above the fold.
  static const answer = 88.0;
  static const answerCompact = 76.0;
  static const compactHeight = 700.0;
}

abstract final class Motion {
  /// Pressed feedback (scale 1.0 -> 0.97 + overlay), within 100 ms.
  static const press = Duration(milliseconds: 90);

  /// Chips, fades and all exits.
  static const fast = Duration(milliseconds: 180);

  /// Enters: card swaps, standings reorder, the streak chip scale-in.
  static const medium = Duration(milliseconds: 280);

  /// Reveal celebration, podium rise, points count-up.
  static const slow = Duration(milliseconds: 600);

  /// Per-item delay of staggered entrances (at most [staggerMaxItems]).
  static const stagger = Duration(milliseconds: 40);
  static const staggerMaxItems = 6;

  /// Crossfade that replaces motion under reduce-motion.
  static const reducedCrossfade = Duration(milliseconds: 150);

  /// One turn of the splash vinyl: 33⅓ rpm.
  static const vinylTurn = Duration(milliseconds: 1800);
  static const equalizerLoop = Duration(milliseconds: 2400);
  static const glowBreath = Duration(milliseconds: 3200);

  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  /// True when the platform asks for reduced motion: Android's «Remove
  /// animations» (`MediaQuery.disableAnimationsOf`) or iOS «Reduce Motion»
  /// (`AccessibilityFeatures.reduceMotion`, which never sets that flag).
  /// `ReduceMotionScope` folds the iOS flag into the app's `MediaQuery` and
  /// rebuilds on changes; the direct read covers widgets outside it.
  static bool reduced(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      (View.maybeOf(context)
              ?.platformDispatcher
              .accessibilityFeatures
              .reduceMotion ??
          false);
}

/// Colors the Material scheme has no slot for.
///
/// - [neonGradient] is decorative only (rings, strips, step dots, the boot
///   vinyl arc): never put text on it.
/// - [ctaGradient] is the text-safe hero fill; [onCta] text on it is at
///   least 6.12:1 at every stop.
/// - [headlineGradient] is for `ShaderMask` text of 24 sp or more, at most
///   once per screen (see `GradientHeadline`).
@immutable
class PartyColors extends ThemeExtension<PartyColors> {
  const PartyColors({
    required this.neonGradient,
    required this.ctaGradient,
    required this.onCta,
    required this.headlineGradient,
    required this.glow,
    required this.secondaryGlow,
    required this.launchBackground,
    required this.ringTrack,
  });

  static const _cta = [Color(0xFF5B3DF5), Color(0xFFB0177A)];

  static const dark = PartyColors(
    neonGradient: [BrandColors.cyan, BrandColors.violet, BrandColors.magenta],
    ctaGradient: _cta,
    onCta: Color(0xFFFFFFFF),
    headlineGradient: [
      BrandColors.cyan,
      BrandColors.violet,
      BrandColors.magenta,
    ],
    glow: Color(0x807B61FF),
    secondaryGlow: Color(0x4DFF4FA3),
    launchBackground: BrandColors.nightInk,
    ringTrack: Color(0x1FFFFFFF),
  );

  static const light = PartyColors(
    neonGradient: [Color(0xFF00A3CC), Color(0xFF5B3DF5), Color(0xFFD6247E)],
    ctaGradient: _cta,
    onCta: Color(0xFFFFFFFF),
    headlineGradient: [Color(0xFF00718F), Color(0xFF5B3DF5), Color(0xFFC2186B)],
    glow: Color(0x4D7B61FF),
    secondaryGlow: Color(0x33FF4FA3),
    launchBackground: BrandColors.dayMist,
    ringTrack: Color(0x1F17132E),
  );

  final List<Color> neonGradient;
  final List<Color> ctaGradient;
  final Color onCta;
  final List<Color> headlineGradient;

  /// At most one glowing element per screen; never on the player screen.
  final Color glow;
  final Color secondaryGlow;
  final Color launchBackground;
  final Color ringTrack;

  /// The pre-wave-6 name of [neonGradient]. Decorative only: call sites
  /// that put text on it move to [ctaGradient] or [headlineGradient].
  List<Color> get gradient => neonGradient;

  static PartyColors of(BuildContext context) =>
      Theme.of(context).extension<PartyColors>() ?? dark;

  @override
  PartyColors copyWith({
    List<Color>? neonGradient,
    List<Color>? ctaGradient,
    Color? onCta,
    List<Color>? headlineGradient,
    Color? glow,
    Color? secondaryGlow,
    Color? launchBackground,
    Color? ringTrack,
  }) => PartyColors(
    neonGradient: neonGradient ?? this.neonGradient,
    ctaGradient: ctaGradient ?? this.ctaGradient,
    onCta: onCta ?? this.onCta,
    headlineGradient: headlineGradient ?? this.headlineGradient,
    glow: glow ?? this.glow,
    secondaryGlow: secondaryGlow ?? this.secondaryGlow,
    launchBackground: launchBackground ?? this.launchBackground,
    ringTrack: ringTrack ?? this.ringTrack,
  );

  @override
  PartyColors lerp(PartyColors? other, double t) {
    if (other == null) return this;
    return PartyColors(
      neonGradient: lerpColorList(neonGradient, other.neonGradient, t),
      ctaGradient: lerpColorList(ctaGradient, other.ctaGradient, t),
      onCta: Color.lerp(onCta, other.onCta, t)!,
      headlineGradient: lerpColorList(
        headlineGradient,
        other.headlineGradient,
        t,
      ),
      glow: Color.lerp(glow, other.glow, t)!,
      secondaryGlow: Color.lerp(secondaryGlow, other.secondaryGlow, t)!,
      launchBackground: Color.lerp(
        launchBackground,
        other.launchBackground,
        t,
      )!,
      ringTrack: Color.lerp(ringTrack, other.ringTrack, t)!,
    );
  }
}

/// Lerps two color lists pairwise; a length mismatch snaps at t = 0.5.
List<Color> lerpColorList(List<Color> a, List<Color> b, double t) {
  if (a.length != b.length) return t < 0.5 ? a : b;
  return [for (var i = 0; i < a.length; i++) Color.lerp(a[i], b[i], t)!];
}
