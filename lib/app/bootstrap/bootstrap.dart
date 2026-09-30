import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/app.dart';
import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/platform/app_platform.dart';

/// The only way the app starts (R-BOOT): installs error handling, builds the
/// DI container, shows the animated splash on the very first frame and runs
/// the boot pipeline (config -> warmup -> sdk_init -> enter_app).
Future<void> bootstrap() async {
  // Errors are buffered here until the `crash_reporting` step attaches
  // Crashlytics, so crashes during early boot are not lost.
  final crashGate = BufferingCrashReporter(
    onBufferedError: kDebugMode
        ? (e) => debugPrint('[crash:buffered] ${e.error}')
        : null,
  );

  await runZonedGuarded<Future<void>>(
    () async {
      // Must run in the same zone as runApp.
      final binding = WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        crashGate
            .recordError(
              details.exception,
              details.stack,
              reason: details.context?.toDescription(),
            )
            .ignore();
      };
      binding.platformDispatcher.onError = (error, stack) {
        crashGate.recordError(error, stack, fatal: true).ignore();
        return true;
      };

      final env = AppEnv.fromEnvironment(platform: _platform());
      final container = ProviderContainer(
        overrides: [
          appEnvProvider.overrideWithValue(env),
          crashGateProvider.overrideWithValue(crashGate),
        ],
        // Boot handles its own retries; Riverpod's automatic provider retry
        // would re-run failing SDK calls behind our back.
        retry: (_, _) => null,
      );

      runApp(
        UncontrolledProviderScope(
          container: container,
          child: const SporandApp(),
        ),
      );
      unawaited(container.read(bootControllerProvider.notifier).start());
    },
    (error, stack) => crashGate.recordError(error, stack, fatal: true).ignore(),
  );
}

AppPlatform _platform() {
  if (kIsWeb) return AppPlatform.other;
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => AppPlatform.ios,
    TargetPlatform.android => AppPlatform.android,
    _ => AppPlatform.other,
  };
}
