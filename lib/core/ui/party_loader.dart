import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/equalizer_bars.dart';

/// Full-screen wait (design system §6.11): the equalizer (static under
/// reduce-motion) and a text status in a live region.
///
/// Never on a screen that shows the YouTube player: there, pass
/// `animate: false` or do not show it.
class PartyLoader extends StatelessWidget {
  const PartyLoader({super.key, required this.status, this.animate});

  final String status;

  /// Defaults to "unless reduce-motion is on".
  final bool? animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animate = (this.animate ?? true) && !Motion.reduced(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: EqualizerBars(animate: animate, width: 96, height: 32),
            ),
            const SizedBox(height: Spacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                status,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 20 dp circular indicator for buttons and inline waits.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: IconSizes.sm,
    child: CircularProgressIndicator(strokeWidth: 2.5, color: color),
  );
}

/// A static skeleton row for lists while they load (no shimmer, so it is
/// the same with and without reduce-motion).
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.height = 60, this.leading = true});

  final double height;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    final fill = Theme.of(context).colorScheme.surfaceContainerHigh;
    Widget bar(double widthFactor, double barHeight) => FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(barHeight / 2),
        ),
      ),
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            if (leading) ...[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
              ),
              const SizedBox(width: Spacing.sm),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  bar(0.7, 14),
                  const SizedBox(height: Spacing.xs),
                  bar(0.4, 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
