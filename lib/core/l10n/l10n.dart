import 'package:flutter/widgets.dart';
import 'package:mobile_kit/mobile_kit.dart' show KitLocales;

import 'package:sporand/core/l10n/gen/app_localizations.dart';

// Wave 8b: `resolveAppLocale` (`MaterialApp.localeListResolutionCallback`:
// the first device language we support, matched by language code in the
// user's order, else English) is mobile_kit's, with the same rule. The
// kit's own strings are `MobileKitLocalizations`, with SpoRand's copy in
// kit_strings.dart.
export 'package:mobile_kit/mobile_kit.dart' show resolveAppLocale;
export 'package:sporand/core/l10n/gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

abstract final class AppLocales {
  /// Used when none of the device languages is supported. Not the `ru` ARB
  /// template: for the Poland soft launch a Ukrainian, German or Czech phone
  /// should get English, not Russian (mobile_kit's `KitLocales.fallback`,
  /// the default fallback of `resolveAppLocale`).
  static const fallback = KitLocales.fallback;
}
