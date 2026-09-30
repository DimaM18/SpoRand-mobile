import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/platform/app_platform.dart';

/// Everything that differs between builds. Values come from `--dart-define`
/// so that there is exactly one entry point (`main()` -> `bootstrap()`).
///
/// Supported defines (all optional):
/// - `FLAVOR`: dev | staging | prod | spotifyProto (default dev)
/// - `API_BASE_URL`: e.g. https://api.<domain>. Empty -> offline fake backend.
/// - `LINK_HOST`: the public link domain for `https://<domain>/j/{room_code}`.
/// - `FIREBASE_ENABLED`: true/false. Defaults to false for dev (no
///   GoogleService-Info.plist / google-services.json in the repo) and true for
///   every other flavor.
/// - `REVENUECAT_API_KEY_IOS`, `REVENUECAT_API_KEY_ANDROID`: public SDK keys.
/// - `ADMOB_INTERSTITIAL_IOS|ANDROID`, `ADMOB_REWARDED_IOS|ANDROID`.
/// - `STORE_URL_IOS`, `STORE_URL_ANDROID`, `TERMS_URL`, `PRIVACY_URL`.
final class AppEnv {
  const AppEnv({
    required this.flavor,
    required this.platform,
    this.apiBaseUrl,
    this.linkHosts = const {},
    this.firebaseEnabled = false,
    this.revenueCatApiKey,
    this.adUnits = AdUnitIds.none,
    this.storeUrl,
    this.termsUrl,
    this.privacyUrl,
  });

  factory AppEnv.fromEnvironment({required AppPlatform platform}) {
    const flavorRaw = String.fromEnvironment('FLAVOR', defaultValue: 'dev');
    const apiBaseUrlRaw = String.fromEnvironment('API_BASE_URL');
    // TODO(owner): set LINK_HOST to the public <domain> once chosen (Q3).
    const linkHostRaw = String.fromEnvironment('LINK_HOST');
    const firebaseRaw = String.fromEnvironment('FIREBASE_ENABLED');
    // TODO(owner): RevenueCat public SDK keys (Project settings -> API keys).
    const rcIos = String.fromEnvironment('REVENUECAT_API_KEY_IOS');
    const rcAndroid = String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');
    // TODO(owner): real AdMob ad unit ids for staging/prod.
    const interstitialIos = String.fromEnvironment('ADMOB_INTERSTITIAL_IOS');
    const interstitialAndroid = String.fromEnvironment(
      'ADMOB_INTERSTITIAL_ANDROID',
    );
    const rewardedIos = String.fromEnvironment('ADMOB_REWARDED_IOS');
    const rewardedAndroid = String.fromEnvironment('ADMOB_REWARDED_ANDROID');
    // TODO(owner): store listing URLs once the bundle ids exist (Q3).
    const storeIos = String.fromEnvironment('STORE_URL_IOS');
    const storeAndroid = String.fromEnvironment('STORE_URL_ANDROID');
    const terms = String.fromEnvironment('TERMS_URL');
    const privacy = String.fromEnvironment('PRIVACY_URL');

    final flavor = Flavor.parse(flavorRaw);
    final firebaseEnabled = switch (firebaseRaw.toLowerCase()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => !flavor.isDev,
    };

    final isIos = platform == AppPlatform.ios;
    final configuredUnits = AdUnitIds(
      interstitial: _nonEmpty(isIos ? interstitialIos : interstitialAndroid),
      rewarded: _nonEmpty(isIos ? rewardedIos : rewardedAndroid),
    );
    // Google's public test units are safe for dev/staging; production must
    // never silently fall back to them.
    final adUnits = configuredUnits.isComplete || flavor == Flavor.prod
        ? configuredUnits
        : AdUnitIds.googleTestUnits(platform);

    return AppEnv(
      flavor: flavor,
      platform: platform,
      apiBaseUrl: _parseUri(apiBaseUrlRaw),
      linkHosts: {if (linkHostRaw.isNotEmpty) linkHostRaw.toLowerCase()},
      firebaseEnabled: firebaseEnabled,
      revenueCatApiKey: _nonEmpty(isIos ? rcIos : rcAndroid),
      adUnits: adUnits,
      storeUrl: _parseUri(isIos ? storeIos : storeAndroid),
      termsUrl: _parseUri(terms),
      privacyUrl: _parseUri(privacy),
    );
  }

  final Flavor flavor;
  final AppPlatform platform;

  /// REST base (`https://api.<domain>`); null means the offline fake backend.
  final Uri? apiBaseUrl;

  /// Hosts accepted for absolute `https://<domain>/j/{room_code}` links.
  final Set<String> linkHosts;
  final bool firebaseEnabled;
  final String? revenueCatApiKey;
  final AdUnitIds adUnits;
  final Uri? storeUrl;
  final Uri? termsUrl;
  final Uri? privacyUrl;

  bool get monetizationAllowed => flavor.allowsMonetization;

  /// `wss://api.<domain>/v1/ws` (brief §4.3), derived from [apiBaseUrl].
  Uri? get realtimeEndpoint {
    final base = apiBaseUrl;
    if (base == null) return null;
    return base.replace(
      scheme: base.scheme == 'http' ? 'ws' : 'wss',
      path: '/v1/ws',
    );
  }

  static String? _nonEmpty(String value) => value.isEmpty ? null : value;

  static Uri? _parseUri(String raw) => raw.isEmpty ? null : Uri.tryParse(raw);
}
