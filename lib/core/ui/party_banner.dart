import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show KitBanner, KitBannerTone, KitToast;

/// An in-layout status banner (design system §6.10): mobile_kit's
/// [KitBanner] (wave 8b). It takes space in the layout instead of floating
/// over the screen, so it can never cover the YouTube player or an answer.
typedef PartyBanner = KitBanner;

/// The fill of a [PartyBanner].
typedef PartyBannerTone = KitBannerTone;

/// Shows a floating toast (a themed [SnackBar]: `inverseSurface`, radius
/// 12), replacing the current one so at most one is visible
/// ([KitToast.show]).
///
/// Never while the YouTube player is on screen (hard rule 12): the player
/// screen clears SnackBars when it mounts, and callers there must not
/// show new ones.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showPartyToast(
  BuildContext context,
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
}) => KitToast.show(
  context,
  message,
  actionLabel: actionLabel,
  onAction: onAction,
);
