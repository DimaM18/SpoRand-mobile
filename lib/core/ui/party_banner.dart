import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';

/// The fill of a [PartyBanner].
enum PartyBannerTone {
  /// `secondaryContainer`: reconnecting and other transient states.
  info,

  /// `errorContainer`: something failed and may need the user.
  error,
}

/// An in-layout status banner (design system §6.10): icon + text in a
/// live region. It takes space in the layout instead of floating over the
/// screen, so it can never cover the YouTube player or an answer.
class PartyBanner extends StatelessWidget {
  const PartyBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = PartyBannerTone.info,
    this.action,
  });

  final IconData icon;
  final String message;
  final PartyBannerTone tone;

  /// An optional recovery action (e.g. a [TextButton]).
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (fill, on) = switch (tone) {
      PartyBannerTone.info => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      PartyBannerTone.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    final action = this.action;
    return Semantics(
      liveRegion: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: TapTargets.min),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, color: on, size: IconSizes.md),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: on),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: Spacing.xs),
              TextButtonTheme(
                data: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: on),
                ),
                child: action,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows a floating toast (a themed [SnackBar]: `inverseSurface`, radius
/// 12), replacing the current one so at most one is visible.
///
/// Never while the YouTube player is on screen (hard rule 12): the player
/// screen clears SnackBars when it mounts, and callers there must not
/// show new ones.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showPartyToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      action: actionLabel != null && onAction != null
          ? SnackBarAction(label: actionLabel, onPressed: onAction)
          : null,
    ),
  );
}
