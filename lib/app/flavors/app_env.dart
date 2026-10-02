import 'package:mobile_kit/mobile_kit.dart' as kit;

import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';

/// Everything that differs between builds (wave 8b: mobile_kit's `AppEnv`).
/// Values come from `--dart-define` so that there is exactly one entry point
/// (`main()` -> `bootstrap()`); `runKitApp` reads the kit defines (`FLAVOR`,
/// `API_BASE_URL`, `LINK_HOST`, `FIREBASE_ENABLED`, `REVENUECAT_API_KEY_*`,
/// `ADMOB_*`, `STORE_URL_*`, `TERMS_URL`, `PRIVACY_URL`, `APP_BUNDLE_ID`)
/// with [Flavor.registry]. SpoRand's own defines are read by [SporandEnv]:
/// - `ROOM_PROVIDER`: the provider new rooms request (a `MusicProviderId`
///   wire value), for QA; defaults per flavor (see [SporandEnv.roomProvider]).
/// - `APP_BUNDLE_ID`: the iOS bundle id / Android application id; the
///   embedded YouTube player identifies the app as `https://<bundle id>`
///   (see [SporandEnv.youTubePlayerOrigin]). Defaults to the placeholder id
///   of the native projects ([AppEnv.defaultBundleId]).
///
/// This adapter keeps the old const constructor (tests build the env with
/// explicit values, `roomProvider` included).
class AppEnv extends kit.AppEnv {
  const AppEnv({
    required Flavor super.flavor,
    required super.platform,
    super.apiBaseUrl,
    super.linkHosts,
    super.firebaseEnabled,
    super.revenueCatApiKey,
    super.adUnits,
    super.storeUrl,
    super.termsUrl,
    super.privacyUrl,
    this._roomProvider,
    String super.bundleId = defaultBundleId,
  });

  /// The placeholder id of `android/app/build.gradle.kts` and the Xcode
  /// project (TODO(owner): the real one once the brand exists, Q3).
  static const defaultBundleId = 'dev.brandtbd.sporand';

  /// The kit's env of this build plus SpoRand's defines (what `runKitApp`
  /// builds, as this adapter).
  factory AppEnv.fromEnvironment({required kit.AppPlatform platform}) {
    final base = kit.AppEnv.fromEnvironment(Flavor.registry, platform: platform);
    return AppEnv(
      flavor: base.flavor as Flavor,
      platform: base.platform,
      apiBaseUrl: base.apiBaseUrl,
      linkHosts: base.linkHosts,
      firebaseEnabled: base.firebaseEnabled,
      revenueCatApiKey: base.revenueCatApiKey,
      adUnits: base.adUnits,
      storeUrl: base.storeUrl,
      termsUrl: base.termsUrl,
      privacyUrl: base.privacyUrl,
      roomProvider: _definedRoomProvider,
      bundleId: base.bundleId ?? defaultBundleId,
    );
  }

  final MusicProviderId? _roomProvider;

  @override
  Flavor get flavor => super.flavor as Flavor;

  @override
  String get bundleId => super.bundleId ?? defaultBundleId;
}

/// `ROOM_PROVIDER`, or null when the define is absent.
MusicProviderId? get _definedRoomProvider {
  const raw = String.fromEnvironment('ROOM_PROVIDER');
  if (raw.isEmpty) return null;
  return parseWire(
    MusicProviderId.values,
    raw,
    fallback: MusicProviderId.externalPlayer,
  );
}

/// SpoRand's game getters on any env: the kit's (production, built by
/// `runKitApp`) and the [AppEnv] adapter (tests) [новое имя — согласовать].
extension SporandEnv on kit.AppEnv {
  /// iOS bundle id / Android application id ([AppEnv.defaultBundleId] when
  /// `APP_BUNDLE_ID` is absent).
  String get appBundleId => bundleId ?? AppEnv.defaultBundleId;

  /// The embedded YouTube player's `origin` and Referer: YouTube requires
  /// embeds in apps to identify themselves as `https://<bundle id>`
  /// (without it the player fails with error 153).
  String get youTubePlayerOrigin => 'https://${appBundleId.toLowerCase()}';

  /// The provider `POST /v1/rooms` asks for; the server may still fall back
  /// to its `default_provider` when this one is not enabled for the host's
  /// country. spotifyProto keeps the frozen Spotify prototype, dev keeps the
  /// `test_catalog` clips, and staging/prod request `youtube_embed` (wave 4
  /// owner decision: the official embedded player on the DJ's phone); the
  /// server falls back to its `default_provider` (external_player, BYOP)
  /// where YouTube is not enabled.
  MusicProviderId get roomProvider {
    final self = this;
    final explicit = self is AppEnv
        ? self._roomProvider
        : _definedRoomProvider;
    if (explicit != null) return explicit;
    if (flavor == Flavor.spotifyProto) return MusicProviderId.spotifyAppRemote;
    if (flavor == Flavor.staging || flavor == Flavor.prod) {
      return MusicProviderId.youtubeEmbed;
    }
    return MusicProviderId.testCatalog;
  }

  /// `wss://api.<domain>/v1/ws`, derived from [kit.AppEnv.apiBaseUrl].
  Uri? get realtimeEndpoint {
    final base = apiBaseUrl;
    if (base == null) return null;
    return base.replace(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      path: '/v1/ws',
    );
  }
}
