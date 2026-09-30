import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/timed_tap_target.dart';

/// The look of the DJ's «Музыка играет!» (design system §6.2) on a
/// [TimedTapTarget]: a full-width [PartyColors.ctaGradient] panel with a
/// play icon, a headline label and an optional hint in [PartyColors.onCta].
///
/// Heights: 96 dp on the BYOP card, 88 dp under the player in portrait,
/// 72 dp in landscape ([minHeight]). Pressed: scale 0.97 only, inward, and
/// never a glow (it may sit under the YouTube player). After the tap, pass
/// [done] with [doneLabel] (e.g. «Отмечено») for a tonal, non-tappable
/// state instead of a SnackBar.
class TimedCtaButton extends StatelessWidget {
  const TimedCtaButton({
    super.key,
    required this.label,
    required this.clock,
    required this.onCommit,
    this.hint,
    this.icon = Icons.play_circle_rounded,
    this.minHeight = 88,
    this.enabled = true,
    this.done = false,
    this.doneLabel,
  });

  final String label;
  final String? hint;
  final IconData icon;
  final double minHeight;
  final bool enabled;
  final bool done;
  final String? doneLabel;
  final InputClock clock;

  /// See [TimedTapTarget.onCommit].
  final void Function(int? tapMonoUs) onCommit;

  @override
  Widget build(BuildContext context) {
    return TimedTapTarget(
      enabled: enabled && !done,
      clock: clock,
      onCommit: onCommit,
      semanticsLabel: done ? (doneLabel ?? label) : label,
      semanticsHint: done ? null : hint,
      builder: (context, pressed) => _body(context, pressed),
    );
  }

  Widget _body(BuildContext context, bool pressed) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final party = PartyColors.of(context);
    final reduce = Motion.reduced(context);
    final fg = done ? scheme.onPrimaryContainer : party.onCta;
    final showHint = !done && hint != null;
    final landscape = minHeight < 80;
    return AnimatedScale(
      scale: pressed && !reduce ? 0.97 : 1,
      duration: reduce ? Duration.zero : Motion.press,
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.sm,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xl),
          gradient: done ? null : LinearGradient(colors: party.ctaGradient),
          color: done ? scheme.primaryContainer : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              done ? Icons.check_rounded : icon,
              color: fg,
              size: landscape ? IconSizes.lg : 40,
            ),
            const SizedBox(width: Spacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    done ? (doneLabel ?? label) : label,
                    style: theme.textTheme.headlineSmall?.copyWith(color: fg),
                  ),
                  if (showHint)
                    Text(
                      hint!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
