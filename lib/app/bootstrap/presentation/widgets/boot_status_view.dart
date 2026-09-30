import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/boot_backdrop.dart';
import 'package:sporand/app/theme/tokens.dart';

/// Icon badge + title + message + action: the shared layout of the retry,
/// force-update and maintenance screens (same visual language as the
/// splash: gradient ring, glow backdrop).
class BootStatusView extends StatelessWidget {
  const BootStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final party = PartyColors.of(context);
    final label = actionLabel;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [...party.gradient, party.gradient.first],
                ),
                boxShadow: [BoxShadow(color: party.glow, blurRadius: 32)],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.surfaceContainerLow,
                ),
                child: Icon(icon, size: 44, color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: Spacing.xl),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (label != null) ...[
              const SizedBox(height: Spacing.xl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: onAction, child: Text(label)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full screen with the boot backdrop behind a [BootStatusView].
class BootStatusScaffold extends StatelessWidget {
  const BootStatusScaffold({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: PartyColors.of(context).launchBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          BootBackdrop(animate: animate),
          SafeArea(
            child: Center(child: SingleChildScrollView(child: child)),
          ),
        ],
      ),
    );
  }
}
