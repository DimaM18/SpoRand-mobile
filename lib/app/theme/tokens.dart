import 'package:material_ui/material_ui.dart';

/// Brand palette: a dark-first "neon party" look. Text/background pairs are
/// chosen for WCAG AA contrast (>= 4.5:1 for body text).
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
}

abstract final class Radii {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  /// One turn of the splash vinyl: 33⅓ rpm.
  static const vinylTurn = Duration(milliseconds: 1800);
  static const equalizerLoop = Duration(milliseconds: 2400);
  static const glowBreath = Duration(milliseconds: 3200);

  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
}

/// Colors the Material scheme has no slot for.
@immutable
class PartyColors extends ThemeExtension<PartyColors> {
  const PartyColors({
    required this.gradient,
    required this.glow,
    required this.secondaryGlow,
    required this.launchBackground,
    required this.ringTrack,
  });

  static const dark = PartyColors(
    gradient: [BrandColors.cyan, BrandColors.violet, BrandColors.magenta],
    glow: Color(0x807B61FF),
    secondaryGlow: Color(0x4DFF4FA3),
    launchBackground: BrandColors.nightInk,
    ringTrack: Color(0x1FFFFFFF),
  );

  static const light = PartyColors(
    gradient: [Color(0xFF00A3CC), Color(0xFF5B3DF5), Color(0xFFD6247E)],
    glow: Color(0x4D7B61FF),
    secondaryGlow: Color(0x33FF4FA3),
    launchBackground: BrandColors.dayMist,
    ringTrack: Color(0x1F17132E),
  );

  final List<Color> gradient;
  final Color glow;
  final Color secondaryGlow;
  final Color launchBackground;
  final Color ringTrack;

  static PartyColors of(BuildContext context) =>
      Theme.of(context).extension<PartyColors>() ?? dark;

  @override
  PartyColors copyWith({
    List<Color>? gradient,
    Color? glow,
    Color? secondaryGlow,
    Color? launchBackground,
    Color? ringTrack,
  }) => PartyColors(
    gradient: gradient ?? this.gradient,
    glow: glow ?? this.glow,
    secondaryGlow: secondaryGlow ?? this.secondaryGlow,
    launchBackground: launchBackground ?? this.launchBackground,
    ringTrack: ringTrack ?? this.ringTrack,
  );

  @override
  PartyColors lerp(PartyColors? other, double t) {
    if (other == null) return this;
    return PartyColors(
      gradient: [
        for (var i = 0; i < gradient.length; i++)
          Color.lerp(gradient[i], other.gradient[i], t)!,
      ],
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
