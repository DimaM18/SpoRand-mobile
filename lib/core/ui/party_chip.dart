import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';

/// A selectable setting chip (design system §6.5): 40 dp visual inside a
/// 48 dp hit area, stadium. Unselected: `surfaceContainerHigh` + 1 dp
/// `outline`; selected: `secondaryContainer` plus a check icon, so the
/// state never rests on colour alone.
///
/// [locked] (premium) shows a lock icon with [lockedTooltip] and keeps
/// [onSelected] so the caller can open the paywall.
class PartyChip extends StatelessWidget {
  const PartyChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.icon,
    this.locked = false,
    this.lockedTooltip,
  });

  final String label;
  final bool selected;

  /// `null` disables the chip.
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  final bool locked;
  final String? lockedTooltip;

  @override
  Widget build(BuildContext context) {
    final chip = FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: !locked,
      avatar: locked
          ? const Icon(Icons.lock_rounded, size: IconSizes.sm)
          : (icon == null || selected ? null : Icon(icon, size: IconSizes.sm)),
      materialTapTargetSize: MaterialTapTargetSize.padded,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: Spacing.xs,
      ),
    );
    final tooltip = lockedTooltip;
    if (!locked || tooltip == null) return chip;
    return Tooltip(message: tooltip, child: chip);
  }
}

/// A non-interactive status chip (bonus round, streak, trial):
/// `tertiaryContainer` / `onTertiaryContainer` (5.96:1 dark, 13.94:1
/// light) with an icon and a word.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.icon,
    required this.label,
    this.tabular = false,
  });

  final IconData icon;
  final String label;

  /// Tabular figures for labels with changing numbers.
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = scheme.onTertiaryContainer;
    var style = theme.textTheme.labelMedium?.copyWith(color: fg);
    if (tabular) {
      style = style?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
    }
    return Container(
      constraints: const BoxConstraints(minHeight: 32),
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: scheme.tertiaryContainer,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: IconSizes.sm, color: fg),
          ),
          const SizedBox(width: Spacing.xxs),
          Flexible(child: Text(label, style: style)),
        ],
      ),
    );
  }
}
