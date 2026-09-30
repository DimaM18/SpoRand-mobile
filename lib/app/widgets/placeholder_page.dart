import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/core/l10n/l10n.dart';

/// Minimal screen for unknown locations (the router's error page).
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title, this.detail});

  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final detail = this.detail;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 56,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.md),
              if (detail != null) ...[
                Text(detail, style: theme.textTheme.titleLarge),
                const SizedBox(height: Spacing.xs),
              ],
              Text(
                context.l10n.placeholderBody,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
