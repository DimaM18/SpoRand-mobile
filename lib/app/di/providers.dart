import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:mobile_kit/mobile_kit.dart'
    show
        FlavorSpec,
        appEnvProvider,
        bootStepsProvider,
        consentServiceProvider,
        externalLinkLauncherProvider,
        kitFeaturesProvider,
        kitPagesProvider,
        linkMatchersProvider,
        paywallConfigProvider,
        prefKeysProvider,
        preferencesStoreProvider,
        projectBootServicesProvider,
        projectRoutesProvider,
        rcKeysProvider,
        splashVisualProvider;
import 'package:mobile_kit_clock/mobile_kit_clock.dart' show inputClockProvider;

import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/presentation/boot_splash_page.dart';
import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/consent/youtube_consent.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/net/ws_connection.dart';
import 'package:sporand/core/playback/clip_player_adapter.dart';
import 'package:sporand/core/playback/music_app_launcher.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/playback/spotify_remote_playback_adapter.dart';
import 'package:sporand/core/playback/youtube/iframe_youtube_player.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/features/paywall/presentation/paywall_page.dart';

// Composition root (wave 8b): mobile_kit's providers (mobile-template) pick
// the real adapter or a fake from the `AppEnv`; builds without Firebase
// config (the dev flavor by default) get in-memory fakes for Firebase-backed
// services, so the app boots in degraded mode instead of crashing. Tests
// override any of them with `ProviderScope.overrides`. SpoRand adds the
// game providers below and fills the kit's extension providers with
// [sporandKitOverrides].
export 'package:mobile_kit/mobile_kit.dart'
    show
        adsServiceProvider,
        ageBandSyncProvider,
        analyticsBackendProvider,
        analyticsIdentityProvider,
        analyticsProvider,
        apiClientProvider,
        appCheckProvider,
        appEnvProvider,
        appInfoSourceProvider,
        appInitializerProvider,
        appSignalSourceProvider,
        authApiClientProvider,
        authApiProvider,
        authServiceProvider,
        bootDependenciesProvider,
        consentApiProvider,
        consentServiceProvider,
        consentSyncProvider,
        crashGateProvider,
        crashReporterProvider,
        deepLinkParserProvider,
        deepLinkQueueProvider,
        entitlementSyncProvider,
        entitlementsProvider,
        externalLinkLauncherProvider,
        firebaseCoreGateProvider,
        preferencesStoreProvider,
        purchasesServiceProvider,
        remoteConfigBackendProvider,
        remoteConfigProvider,
        resourceWarmerProvider,
        secureStoreProvider,
        sessionRepositoryProvider,
        userPrefsProvider;
// The anchored input clock of mobile_kit_clock: one per process, its anchor
// is read by `inputClockPreBootHook` before the boot; desktop dev runs have
// no native bridge. Tests override it from here.
export 'package:mobile_kit_clock/mobile_kit_clock.dart' show inputClockProvider;

// The game getters on the kit's env, config and preferences.
export 'package:sporand/app/flavors/app_env.dart' show SporandEnv;
export 'package:sporand/core/remote_config/remote_config_service.dart'
    show SporandConfig;
export 'package:sporand/core/storage/user_prefs_repository.dart'
    show SporandPrefs;

/// Per-flavor client defaults: the spotifyProto project turns the prototype
/// on and monetization off ([FlavorSpec.configDefaults]; mobile_kit's
/// `remoteConfigProvider` applies them).
Map<String, Object> flavorConfigDefaults(FlavorSpec flavor) =>
    flavor.configDefaults;

/// Adapter for the provider new rooms request ([SporandEnv.roomProvider]);
/// the boot `music_provider` step initializes it.
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

final shareServiceProvider = Provider<ShareService>(
  (ref) => const SharePlusShareService(),
);

final realtimeClientProvider = Provider<RealtimeClient>(
  (ref) => LazyRealtimeClient(),
);

/// SpoRand's values of mobile_kit's extension providers: its config and
/// preference keys, link matchers, boot steps and their game services, the
/// game routes, its own screens on the kit routes, the splash artwork and
/// the paywall. `KitAppConfig.overrides` and the test harness take the same
/// list; it holds none of the SDK-facing providers the harness fakes (a
/// second override of one provider is an error) and never
/// `kitAppConfigProvider` (`runKitApp` sets it) [новое имя — согласовать].
final List<Override> sporandKitOverrides = [
  rcKeysProvider.overrideWithValue(RcKeys.all),
  prefKeysProvider.overrideWithValue(PrefKeys.all),
  linkMatchersProvider.overrideWithValue(sporandLinkMatchers),
  projectBootServicesProvider.overrideWith(
    (ref) => SporandBootServices(
      playback: ref.watch(playbackAdapterProvider),
      realtime: ref.watch(realtimeClientProvider),
    ),
  ),
  bootStepsProvider.overrideWith(
    (ref) => buildBootSteps(features: ref.watch(kitFeaturesProvider)),
  ),
  projectRoutesProvider.overrideWith((ref) => sporandRoutes()),
  kitPagesProvider.overrideWithValue(sporandKitPages),
  splashVisualProvider.overrideWithValue(sporandSplashVisual),
  paywallConfigProvider.overrideWithValue(sporandPaywallConfig),
];
