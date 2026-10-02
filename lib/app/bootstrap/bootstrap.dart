import 'package:material_ui/material_ui.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show KitAppConfig, KitStringsDelegate, KitThemeSpec, runKitApp;
import 'package:mobile_kit_clock/mobile_kit_clock.dart'
    show MobileKitClockLocalizations, inputClockPreBootHook;

import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/app/bootstrap/warmup/flutter_resource_warmer.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/l10n/kit_strings.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/theme/app_theme.dart';

/// The only way the app starts (R-BOOT): mobile_kit's `runKitApp` installs
/// error handling (buffered until the `crash_reporting` step attaches
/// Crashlytics), builds the DI container, shows the animated splash on the
/// very first frame, reads the input clock's process anchor
/// (`inputClockPreBootHook`, bounded) and runs the boot pipeline
/// (config -> warmup -> sdk_init -> enter_app).
Future<void> bootstrap() => runKitApp(sporandAppConfig);

/// Everything `runKitApp` needs from SpoRand [новое имя — согласовать].
final sporandAppConfig = KitAppConfig(
  title: _title,
  theme: sporandThemeSpec,
  // The full «Neon Night+» theme (PartyColors, GameColors, component
  // themes), carrying the kit's KitBrand and KitShape.
  themeBuilder: _theme,
  contentGuard: sporandContentGuard,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    MobileKitClockLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  kitStrings: const KitStringsDelegate(sporandKitStrings),
  overrides: [
    ...sporandKitOverrides,
    // SpoRand's warm-up (one licence entry per font family); not part of
    // sporandKitOverrides because the test harness fakes this provider.
    resourceWarmerProvider.overrideWith((ref) => FlutterResourceWarmer()),
  ],
  preBootHooks: const [inputClockPreBootHook],
  flavors: Flavor.registry,
  features: sporandFeatures,
);

String _title(BuildContext context) => context.l10n.appTitle;

ThemeData _theme(KitThemeSpec spec, Brightness brightness) =>
    brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light();
