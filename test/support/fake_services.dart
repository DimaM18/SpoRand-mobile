import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/warmup/resource_warmer.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/auth/auth_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/consent/consent_sync.dart';
import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/purchases/entitlement_sync_api.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/security/session_repository.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

const testLinkHost = 'play.example.test';

/// One fake for every SDK the app touches, wired like production.
class FakeServices {
  FakeServices({
    Map<String, String>? cachedConfig,
    Map<String, String>? remoteConfig,
    Map<String, Object>? prefs,
    this.appVersion = '1.0.0',
    this.platform = AppPlatform.android,
    this.flavor = Flavor.dev,
  }) : rcBackend = InMemoryRemoteConfigBackend(
         cached: cachedConfig,
         remote: remoteConfig,
       ),
       preferences = InMemoryPreferencesStore(initial: prefs);

  final String appVersion;
  final AppPlatform platform;
  final Flavor flavor;

  final InMemoryRemoteConfigBackend rcBackend;
  late final RemoteConfigService remoteConfig = RemoteConfigService(
    backend: rcBackend,
  );
  final InMemoryPreferencesStore preferences;
  final InMemorySecureStore secureStore = InMemorySecureStore();
  late final UserPrefsRepository userPrefs = UserPrefsRepository(preferences);
  late final SessionRepository sessions = SessionRepository(secureStore);
  final FakeResourceWarmer warmer = FakeResourceWarmer();
  final FakeCrashReporter crashReporter = FakeCrashReporter();
  final BufferingCrashReporter crashGate = BufferingCrashReporter();
  final InMemoryAnalyticsBackend analyticsBackend = InMemoryAnalyticsBackend();
  late final AnalyticsService analytics = AnalyticsService(
    backend: analyticsBackend,
  );
  final FakeConsentService consent = FakeConsentService();
  final FakeConsentApi consentApi = FakeConsentApi();
  final FakeAppCheckService appCheck = FakeAppCheckService();
  final FakeAuthApi authApi = FakeAuthApi();
  late final FakeAppInfoSource appInfo = FakeAppInfoSource(
    AppInfo(version: appVersion, buildNumber: '1', platform: platform),
  );
  late final AuthService auth = AuthService(
    api: authApi,
    sessions: sessions,
    appInfo: appInfo,
  );
  final FakePurchasesService purchases = FakePurchasesService();
  final FakeEntitlementSyncApi entitlementSync = FakeEntitlementSyncApi();
  final FakeAdsService ads = FakeAdsService();
  final FakePlaybackAdapter playback = FakePlaybackAdapter();
  final LazyRealtimeClient realtime = LazyRealtimeClient();
  final DeepLinkQueue deepLinks = DeepLinkQueue();
  final DeepLinkParser linkParser = const DeepLinkParser(
    allowedHosts: {testLinkHost},
  );

  late final AppEnv env = AppEnv(
    flavor: flavor,
    platform: platform,
    apiBaseUrl: Uri.parse('https://api.example.test'),
    linkHosts: const {testLinkHost},
  );

  BootDependencies get deps => BootDependencies(
    env: env,
    appInfo: appInfo,
    remoteConfig: remoteConfig,
    preferences: preferences,
    secureStore: secureStore,
    userPrefs: userPrefs,
    sessions: sessions,
    warmer: warmer,
    crashReporter: crashReporter,
    crashGate: crashGate,
    analytics: analytics,
    consent: consent,
    appCheck: appCheck,
    auth: auth,
    purchases: purchases,
    ads: ads,
    playback: playback,
    realtime: realtime,
    linkParser: linkParser,
  );

  InitContext context() => InitContext(deps: deps, deepLinks: deepLinks);
}
