import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/tokens.dart';

/// The hero action, one per screen: «Создать комнату», «Начать игру»,
/// «Сыграть ещё» (design system §6.3).
///
/// A stadium on [PartyColors.ctaGradient] with [PartyColors.onCta] text
/// (at least 6.12:1), 64 dp tall (56 dp with [compact], e.g. in sheets).
/// Pressed: scale 0.97 (dropped under reduce-motion) plus a 12% black
/// overlay. Disabled: `surfaceContainerHighest` with `onSurface` at 38%.
/// [loading] keeps the width, swaps the icon for a 20 dp spinner and
/// disables the button; screen readers hear «Загрузка…» (a live value).
///
/// Not timed input, so a [FilledButton] core (`onPressed`) is fine. Never
/// use it for answers or the DJ tap: those are `TimedTapTarget`s.
class PartyButton extends StatefulWidget {
  const PartyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.compact = false,
    this.glow = false,
  });

  final String label;

  /// `null` disables the button.
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool compact;

  /// The screen's single glow. Never on a screen with the YouTube player.
  final bool glow;

  @override
  State<PartyButton> createState() => _PartyButtonState();
}

class _PartyButtonState extends State<PartyButton> {
  final _states = WidgetStatesController();
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _states.addListener(_onStates);
  }

  void _onStates() {
    final pressed = _states.value.contains(WidgetState.pressed);
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  void dispose() {
    _states
      ..removeListener(_onStates)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final party = PartyColors.of(context);
    final loading = widget.loading;
    final active = widget.onPressed != null && !loading;
    // Loading keeps the hero look; only a real disable greys it out.
    final looksEnabled = widget.onPressed != null;
    final foreground = looksEnabled
        ? party.onCta
        : scheme.onSurface.withValues(alpha: 0.38);
    final height = widget.compact ? TapTargets.button : TapTargets.hero;
    final reduce = Motion.reduced(context);

    final Widget? leading = loading
        ? SizedBox.square(
            dimension: IconSizes.sm,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : widget.icon == null
        ? null
        : Icon(widget.icon, size: IconSizes.md, color: foreground);

    final button = FilledButton(
      statesController: _states,
      onPressed: active ? widget.onPressed : null,
      style: ButtonStyle(
        minimumSize: WidgetStatePropertyAll(Size(64, height)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
        ),
        shape: const WidgetStatePropertyAll(StadiumBorder()),
        backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStatePropertyAll(foreground),
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.pressed)
              ? Colors.black.withValues(alpha: 0.12)
              : states.contains(WidgetState.hovered) ||
                    states.contains(WidgetState.focused)
              ? Colors.black.withValues(alpha: 0.08)
              : null,
        ),
        elevation: const WidgetStatePropertyAll(0),
        textStyle: WidgetStatePropertyAll(theme.textTheme.labelLarge),
        splashFactory: NoSplash.splashFactory,
      ),
      // Busy is more than "disabled": the spinner's meaning, read live.
      child: Semantics(
        value: loading ? context.l10n.commonLoading : null,
        liveRegion: loading,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: leading),
              const SizedBox(width: Spacing.xs),
            ],
            Flexible(
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );

    return AnimatedScale(
      scale: _pressed && !reduce ? 0.97 : 1,
      duration: reduce ? Duration.zero : Motion.press,
      curve: Curves.easeOut,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shape: const StadiumBorder(),
          gradient: looksEnabled
              ? LinearGradient(colors: party.ctaGradient)
              : null,
          color: looksEnabled ? null : scheme.surfaceContainerHighest,
          shadows: widget.glow && looksEnabled
              ? [BoxShadow(color: party.glow, blurRadius: 24)]
              : null,
        ),
        child: button,
      ),
    );
  }
}
