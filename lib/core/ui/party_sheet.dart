import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart' show KitSheet;

/// Opens a modal bottom sheet with the party look (design system §6.10):
/// mobile_kit's [KitSheet.show] (wave 8b), `surfaceContainerHigh`, top
/// radius 32, a drag handle, inside the safe area, scroll-controlled so it
/// can grow with large text.
///
/// [builder] should pin the primary action at the bottom; the sheet adds
/// the gutter and the bottom inset (keyboard or gesture bar).
///
/// Never while the YouTube player is on screen (hard rule 12).
Future<T?> showPartySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) => KitSheet.show<T>(
  context: context,
  builder: builder,
  isDismissible: isDismissible,
);
