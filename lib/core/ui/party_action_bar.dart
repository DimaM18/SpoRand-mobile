import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';

/// The bottom action bar of a scrolling screen (lobby, results): its own
/// `surfaceContainer` band with a 1 dp `outlineVariant` top edge, so the
/// list above ends at a visible edge instead of a hard cut of a half row.
/// Children are stacked full width inside the safe area.
/// [новое имя — согласовать]
class PartyActionBar extends StatelessWidget {
  const PartyActionBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gutter = Spacing.gutter(MediaQuery.sizeOf(context).width);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutter, Spacing.sm, gutter, Spacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}
