import 'dart:async';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';

/// Outcome of [RemoteConfigService.fetchAndActivate].
enum ConfigFetchResult {
  /// Fresh values fetched and activated.
  activated,

  /// Fetched, nothing changed.
  unchanged,

  /// Fetch did not finish within the boot budget; cached/default values stay.
  timedOut,

  /// Fetch failed; cached/default values stay.
  failed,
}

/// Boot timings resolved from Remote Config (brief §4.6, client keys).
final class BootTimings {
  const BootTimings({
    required this.minSplash,
    required this.maxTotal,
    required this.configFetchTimeout,
  });

  static const defaults = BootTimings(
    minSplash: Duration(milliseconds: 800),
    maxTotal: Duration(milliseconds: 8000),
    configFetchTimeout: Duration(milliseconds: 2500),
  );

  final Duration minSplash;
  final Duration maxTotal;
  final Duration configFetchTimeout;
}

/// Typed, range-checked access to the client Remote Config.
///
/// Reads never throw: a missing, malformed or out-of-range value falls back to
/// the bundled default (brief §4.6) or is clamped into its range. The bundled
/// defaults are usable before the SDK is ready, which is what lets the app
/// boot without Firebase config files.
class RemoteConfigService {
  RemoteConfigService({
    required this._backend,
    this._defaultOverrides = const {},
  });

  final RemoteConfigBackend _backend;

  /// Per-flavor default overrides (e.g. `spotify_proto_enabled` in the
  /// spotifyProto flavor). Keyed by Remote Config key name.
  final Map<String, Object> _defaultOverrides;

  /// Every client key with its bundled default, as sent to `setDefaults`.
  Map<String, Object> get bundledDefaults => {
    for (final key in RcKeys.all) key.name: _defaultFor(key),
  };

  T _defaultFor<T extends Object>(RcKey<T> key) =>
      key.coerce(_defaultOverrides[key.name]);

  /// Pushes the bundled defaults into the SDK so that server-side
  /// "use in-app default" works. Reads fall back to the same values anyway.
  Future<void> applyDefaults() async {
    await _backend.ensureReady();
    await _backend.setDefaults(bundledDefaults);
  }

  /// Activates values fetched during a previous run.
  Future<bool> activateCached() async {
    await _backend.ensureReady();
    return _backend.activate();
  }

  /// Fetches fresh values and activates them if the fetch finishes within
  /// [timeout]. A late fetch is not activated now: its values are applied on
  /// the next cold start, so config never changes under a running session.
  Future<ConfigFetchResult> fetchAndActivate({
    required Duration timeout,
  }) async {
    try {
      // One budget for SDK readiness and the network fetch together.
      await Future(() async {
        await _backend.ensureReady();
        await _backend.fetch();
      }).timeout(timeout);
    } on TimeoutException {
      return ConfigFetchResult.timedOut;
    } on Object {
      return ConfigFetchResult.failed;
    }
    final changed = await _backend.activate();
    return changed ? ConfigFetchResult.activated : ConfigFetchResult.unchanged;
  }

  /// Keys changed by a real-time update (already activated).
  Stream<Set<String>> get onUpdated => _backend.onUpdated;

  T get<T extends Object>(RcKey<T> key) {
    final raw = _safeRaw(key.name);
    final parsed = raw == null ? null : key.parse(raw);
    return key.normalize(parsed ?? _defaultFor(key));
  }

  String? _safeRaw(String name) {
    try {
      return _backend.getRaw(name);
    } on Object {
      return null;
    }
  }

  Duration _ms(IntRcKey key) => Duration(milliseconds: get(key));

  // Monetization.
  bool get monetizationEnabled => get(RcKeys.monetizationEnabled);
  bool get rewardedEnabled => get(RcKeys.rewardedEnabled);
  bool get interstitialEnabled => get(RcKeys.interstitialEnabled);
  bool get removeAdsUpsellEnabled => get(RcKeys.removeAdsUpsellEnabled);
  bool get rewardedPreloadEnabled => get(RcKeys.rewardedPreloadEnabled);
  Duration get maxAdWait => _ms(RcKeys.maxAdWaitMs);
  String get paywallVariant => get(RcKeys.paywallVariant);

  /// `modes_enabled` (wave 4): the modes the mode picker offers, in
  /// [GameMode] order.
  List<GameMode> get modesEnabled {
    final items = RcKeys.modesEnabled.itemsOf(get(RcKeys.modesEnabled));
    return [
      for (final mode in GameMode.values)
        if (items.contains(mode.wire)) mode,
    ];
  }

  /// `youtube_player_min_width_dp`: the target width of the embedded player.
  int get youtubePlayerMinWidthDp => get(RcKeys.youtubePlayerMinWidthDp);

  // Features and territories.
  bool get spotifyProtoEnabled => get(RcKeys.spotifyProtoEnabled);
  bool get licensedProviderEnabled => get(RcKeys.licensedProviderEnabled);

  // Operations.
  String get minSupportedAppVersion => get(RcKeys.minSupportedAppVersion);
  bool get maintenanceMode => get(RcKeys.maintenanceMode);
  bool get killSwitchAds => get(RcKeys.killSwitchAds);
  bool get killSwitchPurchases => get(RcKeys.killSwitchPurchases);

  // Boot.
  BootTimings get bootTimings {
    final minSplash = _ms(RcKeys.bootMinSplashMs);
    final maxTotal = _ms(RcKeys.bootMaxTotalMs);
    return BootTimings(
      minSplash: minSplash,
      // The ranges already guarantee min <= max; keep the invariant explicit
      // in case the ranges are edited later.
      maxTotal: maxTotal < minSplash ? minSplash : maxTotal,
      configFetchTimeout: _ms(RcKeys.bootConfigTimeoutMs),
    );
  }
}
