import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/warmup/resource_warmer.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_identity.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/auth/auth_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/security/session_repository.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

/// Every service the boot steps touch, all behind interfaces so tests and
/// the dev flavor can plug in fakes.
final class BootDependencies {
  const BootDependencies({
    required this.env,
    required this.appInfo,
    required this.remoteConfig,
    required this.preferences,
    required this.secureStore,
    required this.userPrefs,
    required this.sessions,
    required this.warmer,
    required this.crashReporter,
    required this.crashGate,
    required this.analytics,
    required this.consent,
    required this.appCheck,
    required this.auth,
    required this.purchases,
    required this.ads,
    required this.playback,
    required this.realtime,
    required this.linkParser,
    this.analyticsIdentity,
  });

  final AppEnv env;
  final AppInfoSource appInfo;
  final RemoteConfigService remoteConfig;
  final PreferencesStore preferences;
  final SecureStore secureStore;
  final UserPrefsRepository userPrefs;
  final SessionRepository sessions;
  final ResourceWarmer warmer;

  /// The vendor reporter (Crashlytics or fake) initialized by
  /// `crash_reporting`.
  final CrashReporter crashReporter;

  /// The buffer that main()'s error handlers write to until then.
  final BufferingCrashReporter crashGate;
  final AnalyticsService analytics;
  final ConsentService consent;
  final AppCheckService appCheck;
  final AuthService auth;
  final PurchasesService purchases;
  final AdsService ads;
  final PlaybackAdapter playback;
  final RealtimeClient realtime;
  final DeepLinkParser linkParser;

  /// Keeps the GA4 user id on the session's `analytics_uid`; without it the
  /// `auth` step sets the boot session's id once.
  final AnalyticsIdentity? analyticsIdentity;
}

/// Shared state of one boot: services plus what earlier steps found out.
final class InitContext {
  InitContext({required this.deps, DeepLinkQueue? deepLinks})
    : deepLinks = deepLinks ?? DeepLinkQueue();

  final BootDependencies deps;

  /// Deep links / push payloads received during boot, handled by `route`.
  final DeepLinkQueue deepLinks;

  /// Set by `version_gate` / `kill_switches`; skips the rest of the boot.
  BootGate? gate;

  AppInfo? appInfo;
  AuthSession? session;
  ConsentInfo? consent;

  /// Set by the `route` step.
  BootDestination? destination;

  /// Current boot timings; re-read after the config stage so fetched
  /// `boot_min_splash_ms` / `boot_max_total_ms` apply to this boot.
  BootTimings get timings => deps.remoteConfig.bootTimings;

  void raiseGate(BootGate gate) => this.gate = gate.strongest(this.gate);
}
