import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart' show KitLoader;

import 'package:sporand/core/ui/equalizer_bars.dart';

export 'package:mobile_kit/mobile_kit.dart' show InlineSpinner, SkeletonRow;

/// Full-screen wait (design system §6.11): mobile_kit's [KitLoader] (wave
/// 8b) with the equalizer as its indicator (static under reduce-motion) and
/// a text status in a live region.
///
/// Never on a screen that shows the YouTube player: there, pass
/// `animate: false` or do not show it.
class PartyLoader extends KitLoader {
  const PartyLoader({super.key, required super.status, super.animate})
    : super(indicator: _equalizer);

  static Widget _equalizer(bool animate) =>
      EqualizerBars(animate: animate, width: 96, height: 32);
}
