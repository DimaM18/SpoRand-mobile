import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/app.dart';
import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/di/providers.dart';

import 'fake_services.dart';

/// Every SDK-facing provider replaced by the shared fakes.
List<Override> fakeOverrides(FakeServices s) => [
  appEnvProvider.overrideWithValue(s.env),
  crashGateProvider.overrideWithValue(s.crashGate),
  crashReporterProvider.overrideWithValue(s.crashReporter),
  remoteConfigProvider.overrideWithValue(s.remoteConfig),
  analyticsProvider.overrideWithValue(s.analytics),
  consentServiceProvider.overrideWithValue(s.consent),
  adsServiceProvider.overrideWithValue(s.ads),
  purchasesServiceProvider.overrideWithValue(s.purchases),
  secureStoreProvider.overrideWithValue(s.secureStore),
  preferencesStoreProvider.overrideWithValue(s.preferences),
  userPrefsProvider.overrideWithValue(s.userPrefs),
  sessionRepositoryProvider.overrideWithValue(s.sessions),
  appCheckProvider.overrideWithValue(s.appCheck),
  appInfoSourceProvider.overrideWithValue(s.appInfo),
  authServiceProvider.overrideWithValue(s.auth),
  entitlementSyncProvider.overrideWithValue(s.entitlementSync),
  playbackAdapterProvider.overrideWithValue(s.playback),
  realtimeClientProvider.overrideWithValue(s.realtime),
  resourceWarmerProvider.overrideWithValue(s.warmer),
  deepLinkQueueProvider.overrideWithValue(s.deepLinks),
  deepLinkParserProvider.overrideWithValue(s.linkParser),
];

Future<ProviderContainer> launch(
  WidgetTester tester,
  FakeServices s, {
  List<Override> extra = const [],
}) async {
  // Reduced motion keeps pumpAndSettle usable (the loader loops otherwise).
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.platformDispatcher.localesTestValue = const [Locale('ru')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final container = ProviderContainer(
    overrides: [...fakeOverrides(s), ...extra],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const SporandApp()),
  );
  unawaited(container.read(bootControllerProvider.notifier).start());
  // Advance fake time through the pipeline and boot_min_splash_ms, then let
  // the hand-off navigation settle.
  await tester.pump(const Duration(seconds: 3));
  await tester.pumpAndSettle();
  return container;
}
