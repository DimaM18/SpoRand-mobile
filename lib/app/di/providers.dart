import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/bootstrap/domain/app_initializer.dart';
import 'package:sporand/app/bootstrap/domain/boot_telemetry.dart';
import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/app/bootstrap/warmup/flutter_resource_warmer.dart';
import 'package:sporand/app/bootstrap/warmup/resource_warmer.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/ads/admob_ads_service.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_identity.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/analytics/firebase_analytics_backend.dart';
import 'package:sporand/core/auth/age_band_sync.dart';
import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/auth/auth_service.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/consent/consent_sync.dart';
import 'package:sporand/core/consent/ump_consent_service.dart';
import 'package:sporand/core/consent/youtube_consent.dart';
import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/crash/firebase_crash_reporter.dart';
import 'package:sporand/core/firebase/firebase_core_gate.dart';
import 'package:sporand/core/links/external_link_launcher.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/net/ws_connection.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/playback/clip_player_adapter.dart';
import 'package:sporand/core/playback/music_app_launcher.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/playback/spotify_remote_playback_adapter.dart';
import 'package:sporand/core/playback/youtube/iframe_youtube_player.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/purchases/entitlement_sync_api.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/purchases/revenuecat_purchases_service.dart';
import 'package:sporand/core/remote_config/firebase_remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/security/session_repository.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

/// Composition root. Every provider below picks the real adapter or a fake
/// from [AppEnv]; tests override any of them with `ProviderScope.overrides`.
///
/// Builds without Firebase config (the dev flavor by default) get in-memory
/// fakes for Firebase-backed services, so the app boots in degraded mode
/// instead of crashing.

final appEnvProvider = Provider<AppEnv>(
  (ref) =>
      throw UnimplementedError('appEnvProvider is overridden in bootstrap()'),
);

/// The buffer main()'s error handlers write to (overridden in bootstrap).
final crashGateProvider = Provider<BufferingCrashReporter>(
  (ref) => BufferingCrashReporter(),
);

final firebaseCoreGateProvider = Provider<FirebaseCoreGate>(
  (ref) => FirebaseCoreGate(),
);

void _debugLog(String line) {
  if (kDebugMode) debugPrint(line);
}

final crashReporterProvider = Provider<CrashReporter>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.firebaseEnabled) {
    return FakeCrashReporter(onError: (e) => _debugLog('[crash] ${e.error}'));
  }
  return FirebaseCrashReporter(ref.watch(firebaseCoreGateProvider));
});

/// Per-flavor client defaults (brief §4.6): the spotifyProto project turns
/// the prototype on and monetization off.
Map<String, Object> flavorConfigDefaults(Flavor flavor) => switch (flavor) {
  Flavor.spotifyProto => {
    RcKeys.spotifyProtoEnabled.name: true,
    RcKeys.monetizationEnabled.name: false,
  },
  _ => const {},
};

final remoteConfigBackendProvider = Provider<RemoteConfigBackend>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.firebaseEnabled) return InMemoryRemoteConfigBackend();
  return FirebaseRemoteConfigBackend(
    firebase: ref.watch(firebaseCoreGateProvider),
    // Client template: 12 h fetch interval (brief §9 S8); fast in dev.
    minimumFetchInterval: env.flavor.isDev
        ? const Duration(minutes: 1)
        : const Duration(hours: 12),
  );
});

final remoteConfigProvider = Provider<RemoteConfigService>((ref) {
  final env = ref.watch(appEnvProvider);
  return RemoteConfigService(
    backend: ref.watch(remoteConfigBackendProvider),
    defaultOverrides: flavorConfigDefaults(env.flavor),
  );
});

final analyticsBackendProvider = Provider<AnalyticsBackend>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.firebaseEnabled) return InMemoryAnalyticsBackend(onEvent: _debugLog);
  return FirebaseAnalyticsBackend(ref.watch(firebaseCoreGateProvider));
});

final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(backend: ref.watch(analyticsBackendProvider)),
);

final consentServiceProvider = Provider<ConsentService>((ref) {
  final env = ref.watch(appEnvProvider);
  // No ads in spotifyProto, so there is no ads consent to collect.
  if (!env.monetizationAllowed) {
    return FakeConsentService(canRequestAdsAfterRefresh: false);
  }
  return UmpConsentService();
});

final adsServiceProvider = Provider<AdsService>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.monetizationAllowed || !env.adUnits.isComplete) {
    return FakeAdsService(interstitialLoaded: false, rewardedLoaded: false);
  }
  return AdMobAdsService(units: env.adUnits);
});

final purchasesServiceProvider = Provider<PurchasesService>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.monetizationAllowed) return FakePurchasesService(packages: const []);
  // Dev builds without a RevenueCat key get a demo paywall.
  if (env.revenueCatApiKey == null && env.flavor.isDev) {
    return FakePurchasesService();
  }
  return RevenueCatPurchasesService(apiKey: env.revenueCatApiKey);
});

final entitlementsProvider = StreamProvider<Entitlements>((ref) async* {
  final purchases = ref.watch(purchasesServiceProvider);
  yield purchases.entitlements;
  yield* purchases.entitlementChanges;
});

final secureStoreProvider = Provider<SecureStore>(
  (ref) => FlutterSecureStore(),
);

final preferencesStoreProvider = Provider<PreferencesStore>(
  (ref) => SharedPreferencesStore(),
);

final userPrefsProvider = Provider<UserPrefsRepository>(
  (ref) => UserPrefsRepository(ref.watch(preferencesStoreProvider)),
);

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(secureStoreProvider)),
);

final appCheckProvider = Provider<AppCheckService>((ref) {
  final env = ref.watch(appEnvProvider);
  if (!env.firebaseEnabled) return FakeAppCheckService(token: null);
  return FirebaseAppCheckService(
    ref.watch(firebaseCoreGateProvider),
    useDebugProviders: env.flavor.isDev,
  );
});

final appInfoSourceProvider = Provider<AppInfoSource>(
  (ref) => PackageInfoAppInfoSource(ref.watch(appEnvProvider).platform),
);

/// Unauthenticated client for `/v1/auth/*` (the calls that obtain tokens).
final authApiClientProvider = Provider<ApiClient?>((ref) {
  final baseUrl = ref.watch(appEnvProvider).apiBaseUrl;
  if (baseUrl == null) return null;
  final client = ApiClient(
    baseUrl: baseUrl,
    appCheck: ref.watch(appCheckProvider),
  );
  ref.onDispose(client.close);
  return client;
});

/// Authenticated client (Bearer + single-flight refresh on 401). Null when
/// no `API_BASE_URL` is configured: the app then uses offline fakes.
final apiClientProvider = Provider<ApiClient?>((ref) {
  final baseUrl = ref.watch(appEnvProvider).apiBaseUrl;
  if (baseUrl == null) return null;
  final client = ApiClient(
    baseUrl: baseUrl,
    tokens: ref.watch(authServiceProvider),
    appCheck: ref.watch(appCheckProvider),
  );
  ref.onDispose(client.close);
  return client;
});

final authApiProvider = Provider<AuthApi>((ref) {
  final client = ref.watch(authApiClientProvider);
  return client == null ? FakeAuthApi() : HttpAuthApi(client);
});

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(
    api: ref.watch(authApiProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    appInfo: ref.watch(appInfoSourceProvider),
    localeTag: () => PlatformDispatcher.instance.locale.toLanguageTag(),
  ),
);

/// Sends the age gate's band to the server before a room is created or
/// joined (`PATCH /v1/me`); a no-op without a backend.
final ageBandSyncProvider = Provider<AgeBandSync>(
  (ref) => AgeBandSync(
    client: ref.watch(apiClientProvider),
    prefs: ref.watch(userPrefsProvider),
    currentUserId: () => ref.read(authServiceProvider).currentUserId(),
  ),
);

/// `PUT /v1/me/consent`; records only without a backend.
final consentApiProvider = Provider<ConsentApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return client == null ? FakeConsentApi() : HttpConsentApi(client);
});

/// Debounced consent sync after onboarding, settings and UMP changes.
final consentSyncProvider = Provider<ConsentSync>((ref) {
  final sync = ConsentSync(api: ref.watch(consentApiProvider));
  ref.onDispose(sync.dispose);
  return sync;
});

/// The GA4 user id follows the session's `analytics_uid` (S8.6).
final analyticsIdentityProvider = Provider<AnalyticsIdentity>((ref) {
  final client = ref.watch(apiClientProvider);
  final crash = ref.watch(crashGateProvider);
  final identity = AnalyticsIdentity(
    analytics: ref.watch(analyticsProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    fetchAnalyticsUid: client == null
        ? null
        : () async {
            try {
              return MeResponse.fromJson(await client.get('/v1/me'))
                  .user
                  .analyticsUid;
            } on ProtocolFormatException {
              return null;
            }
          },
    onUserId: crash.setUserId,
  );
  ref.onDispose(identity.dispose);
  return identity;
});

final entitlementSyncProvider = Provider<EntitlementSyncApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return client == null
      ? FakeEntitlementSyncApi()
      : HttpEntitlementSyncApi(client);
});

/// The anchored input clock (brief §5). One per process: its anchor is read
/// in `bootstrap()`. Desktop dev runs have no native bridge.
final inputClockProvider = Provider<InputClock>((ref) {
  final platform = ref.watch(appEnvProvider).platform;
  return InputClock(
    platform == AppPlatform.other
        ? StopwatchInputClockSource()
        : PigeonInputClockSource(),
  );
});

/// Adapter for the provider new rooms request ([AppEnv.roomProvider]); the
/// boot `music_provider` step initializes it.
final playbackAdapterProvider = Provider<PlaybackAdapter>(
  (ref) => ref.watch(playbackAdapterFactoryProvider)(
    ref.watch(appEnvProvider).roomProvider,
  ),
);

/// Builds the playback adapter for a room's provider (playback device only).
final playbackAdapterFactoryProvider =
    Provider<PlaybackAdapter Function(MusicProviderId provider)>((ref) {
      final clock = ref.watch(inputClockProvider);
      return (provider) => switch (provider) {
        MusicProviderId.testCatalog || MusicProviderId.licensedClips =>
          ClipPlayerAdapter(provider, clock: clock),
        // TODO(owner, Q1): a real bridge once SpotifyRemoteApi exists.
        MusicProviderId.spotifyAppRemote => SpotifyRemotePlaybackAdapter(
          bridge: const UnavailableSpotifyRemoteBridge(),
          clock: clock,
        ),
        // A2: the app never plays audio for these providers.
        // youtube_embed: the embedded player on the DJ's round screen plays
        // the video (YouTubeRoundPlayer), never a PlaybackAdapter.
        MusicProviderId.externalPlayer ||
        MusicProviderId.youtubeEmbed ||
        MusicProviderId.none => NoAudioPlaybackAdapter(provider),
      };
    });

/// Creates the embedded YouTube player of a youtube_embed round (DJ only).
/// Tests override it with [FakeYouTubePlayerFactory]: there is no WebView
/// in `flutter test`.
final youTubePlayerFactoryProvider = Provider<YouTubePlayerFactory>(
  (ref) => const IframeYouTubePlayerFactory(),
);

/// Consent to load the YouTube player where consent applies (EU/EEA,
/// III.E.4.i) [новое имя — согласовать].
final youTubeConsentProvider = Provider<YouTubeConsentGate>(
  (ref) => YouTubeConsentGate(
    ump: ref.watch(consentServiceProvider),
    prefs: ref.watch(preferencesStoreProvider),
  ),
);

/// Hands the DJ's cue to their own music app (external_player, A2.2).
final musicAppLauncherProvider = Provider<MusicAppLauncher>(
  (ref) => NativeMusicAppLauncher(
    platform: ref.watch(appEnvProvider).platform,
    links: ref.watch(externalLinkLauncherProvider),
  ),
);

final wsConnectorProvider = Provider<WsConnector>(
  (ref) => ChannelWsConnection.connect,
);

/// Lifecycle + connectivity changes for `app.state` (created lazily when
/// the first room opens).
final appSignalSourceProvider = Provider<AppSignalSource>((ref) {
  final source = FlutterAppSignalSource();
  ref.onDispose(source.dispose);
  return source;
});

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusShareService(),
);

final realtimeClientProvider = Provider<RealtimeClient>(
  (ref) => LazyRealtimeClient(),
);

final resourceWarmerProvider = Provider<ResourceWarmer>(
  (ref) => FlutterResourceWarmer(),
);

final deepLinkQueueProvider = Provider<DeepLinkQueue>((ref) => DeepLinkQueue());

final deepLinkParserProvider = Provider<DeepLinkParser>(
  (ref) => DeepLinkParser(allowedHosts: ref.watch(appEnvProvider).linkHosts),
);

final externalLinkLauncherProvider = Provider<ExternalLinkLauncher>(
  (ref) => const UrlLauncherExternalLinkLauncher(),
);

final bootDependenciesProvider = Provider<BootDependencies>(
  (ref) => BootDependencies(
    env: ref.watch(appEnvProvider),
    appInfo: ref.watch(appInfoSourceProvider),
    remoteConfig: ref.watch(remoteConfigProvider),
    preferences: ref.watch(preferencesStoreProvider),
    secureStore: ref.watch(secureStoreProvider),
    userPrefs: ref.watch(userPrefsProvider),
    sessions: ref.watch(sessionRepositoryProvider),
    warmer: ref.watch(resourceWarmerProvider),
    crashReporter: ref.watch(crashReporterProvider),
    crashGate: ref.watch(crashGateProvider),
    analytics: ref.watch(analyticsProvider),
    consent: ref.watch(consentServiceProvider),
    appCheck: ref.watch(appCheckProvider),
    auth: ref.watch(authServiceProvider),
    analyticsIdentity: ref.watch(analyticsIdentityProvider),
    purchases: ref.watch(purchasesServiceProvider),
    ads: ref.watch(adsServiceProvider),
    playback: ref.watch(playbackAdapterProvider),
    realtime: ref.watch(realtimeClientProvider),
    linkParser: ref.watch(deepLinkParserProvider),
  ),
);

/// A fresh initializer per boot attempt chain; `BootController.restart()`
/// invalidates it (e.g. "check again" on the maintenance screen).
final appInitializerProvider = Provider<AppInitializer>((ref) {
  final deps = ref.watch(bootDependenciesProvider);
  final initializer = AppInitializer(
    steps: buildBootSteps(),
    context: InitContext(
      deps: deps,
      deepLinks: ref.watch(deepLinkQueueProvider),
    ),
    telemetry: AnalyticsBootTelemetry(deps.analytics),
    onStepError: (stepId, error, stack) => deps.crashGate
        .recordError(error, stack, reason: 'boot step $stepId')
        .ignore(),
  );
  ref.onDispose(initializer.dispose);
  return initializer;
});
