import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';

/// The fill of a [PartyCard].
enum PartyCardTone {
  /// `surfaceContainer`, radius 24, no shadow.
  surface,

  /// A raised level for content on a card or in a sheet
  /// (`surfaceContainerHigh`).
  raised,

  /// The text-safe hero fill ([PartyColors.ctaGradient], radius 32) for
  /// banner cards such as «Это твой трек!» and the bonus offer. Content
  /// colours default to [PartyColors.onCta].
  cta,
}

/// A flat, tonal card (design system §6.4). Elevation is tonal, never a
/// shadow. Not tappable by itself: put buttons inside.
class PartyCard extends StatelessWidget {
  const PartyCard({
    super.key,
    required this.child,
    this.tone = PartyCardTone.surface,
    this.padding = const EdgeInsets.all(Spacing.md),
  });

  final Widget child;
  final PartyCardTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final party = PartyColors.of(context);
    final cta = tone == PartyCardTone.cta;
    final foreground = cta ? party.onCta : scheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (tone) {
          PartyCardTone.surface => scheme.surfaceContainer,
          PartyCardTone.raised => scheme.surfaceContainerHigh,
          PartyCardTone.cta => null,
        },
        gradient: cta ? LinearGradient(colors: party.ctaGradient) : null,
        borderRadius: BorderRadius.circular(cta ? Radii.xl : Radii.lg),
      ),
      child: Padding(
        padding: padding,
        child: IconTheme.merge(
          data: IconThemeData(color: foreground),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: foreground),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Headline text through [PartyColors.headlineGradient] (at least 4.60:1
/// on the dark surface and 5.22:1 on the light one at every stop).
///
/// Only for text of 24 sp or more and at most once per screen; screen
/// readers get the plain [text].
class GradientHeadline extends StatelessWidget {
  const GradientHeadline(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
  });

  final String text;

  /// Defaults to `displayMedium`.
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final party = PartyColors.of(context);
    final base = style ?? Theme.of(context).textTheme.displayMedium;
    // The shader spans the mask's box, so the box must hug the glyphs: the
    // Align loosens a list's tight width and `longestLine` sizes the text to
    // its longest line. A wrapped headline then reaches every stop.
    return Semantics(
      header: true,
      label: text,
      excludeSemantics: true,
      child: Align(
        alignment: switch (textAlign) {
          TextAlign.center => Alignment.center,
          TextAlign.right => Alignment.centerRight,
          TextAlign.end => AlignmentDirectional.centerEnd,
          _ => AlignmentDirectional.centerStart,
        },
        widthFactor: 1,
        child: ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) =>
              LinearGradient(colors: party.headlineGradient)
                  .createShader(bounds),
          child: Text(
            text,
            textAlign: textAlign,
            maxLines: maxLines,
            textWidthBasis: TextWidthBasis.longestLine,
            style: base?.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
