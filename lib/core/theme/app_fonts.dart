import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The two bundled font families (SIL OFL 1.1, variable `wght`), declared
/// in `pubspec.yaml`. Never fetched at runtime and no `google_fonts`.
///
/// - [display]: Unbounded, for short big strings only (numbers, the room
///   code, «Раунд 3», a short prompt); never in buttons, answer tiles,
///   chips, inputs or Russian sentences.
/// - [body]: Nunito, for everything else. Its default figures are already
///   tabular (every digit advances 600 units at every weight).
///
/// `FontWeight` drives the variable `wght` axis (dart:ui `FontWeight` docs,
/// Flutter 3.47), so styles set only `fontWeight`: an explicit
/// `fontVariations` would pin the weight and silently ignore a later
/// `copyWith(fontWeight: …)`.
abstract final class AppFonts {
  static const display = 'Unbounded';
  static const body = 'Nunito';

  /// Family -> its licence text asset.
  static const licenses = <String, String>{
    display: 'assets/fonts/unbounded/OFL.txt',
    body: 'assets/fonts/nunito/OFL.txt',
  };

  /// Family -> its font asset.
  static const files = <String, String>{
    display: 'assets/fonts/unbounded/Unbounded[wght].ttf',
    body: 'assets/fonts/nunito/Nunito[wght].ttf',
  };

  /// Weights the UI uses; the warm-up lays text out at each of them.
  static const displayWeights = [FontWeight.w700, FontWeight.w800];
  static const bodyWeights = [
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
    FontWeight.w800,
    FontWeight.w900,
  ];

  static bool _licensesRegistered = false;

  /// Adds both OFL texts to the [LicenseRegistry] (shown by
  /// `showLicensePage`). Synchronous and idempotent: the texts are read
  /// lazily when the licence page asks for them, so a warm-up timeout can
  /// never skip the registration.
  static void registerLicenses({AssetBundle? bundle}) {
    if (_licensesRegistered) return;
    _licensesRegistered = true;
    LicenseRegistry.addLicense(() => licenseEntries(bundle ?? rootBundle));
  }

  /// The licence entries, one per family.
  static Stream<LicenseEntry> licenseEntries(AssetBundle bundle) async* {
    for (final MapEntry(key: family, value: path) in licenses.entries) {
      yield LicenseEntryWithLineBreaks([family], await bundle.loadString(path));
    }
  }

  @visibleForTesting
  static void debugResetLicenses() => _licensesRegistered = false;
}
