import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/theme/tokens.dart';

/// Opens a modal bottom sheet with the party look (design system §6.10):
/// `surfaceContainerHigh`, top radius 32, a drag handle, inside the safe
/// area, scroll-controlled so it can grow with large text.
///
/// [builder] should pin the primary action at the bottom; the sheet adds
/// the gutter and the bottom inset (keyboard or gesture bar).
///
/// Never while the YouTube player is on screen (hard rule 12).
Future<T?> showPartySheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    isDismissible: isDismissible,
    builder: (context) {
      final media = MediaQuery.of(context);
      final gutter = Spacing.gutter(media.size.width);
      return Padding(
        padding: EdgeInsets.fromLTRB(
          gutter,
          0,
          gutter,
          Spacing.md + media.viewInsets.bottom,
        ),
        child: builder(context),
      );
    },
  );
}
