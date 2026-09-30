/// Client Remote Config keys: every `C` and `B` key of brief §4.6 with its
/// type, default and allowed range. `S` keys are server-only; the server
/// sends their frozen values in `welcome.config`.
library;

/// Who reads the key (brief §4.6 "Reader" column).
enum RcReader {
  /// Client template only.
  client,

  /// Both: the server enforces it, the client uses it for UI.
  both,
}

sealed class RcKey<T extends Object> {
  const RcKey(this.name, this.defaultValue, this.reader);

  final String name;
  final T defaultValue;
  final RcReader reader;

  /// Parses a raw backend value; null means "unusable, use the default".
  T? parse(String raw);

  /// Brings a parsed value into the allowed range/set.
  T normalize(T value) => value;

  /// Returns [value] when it has this key's type, otherwise the default.
  /// Uses the reified type argument, so it also works through `RcKey<Object>`.
  T coerce(Object? value) => value is T ? value : defaultValue;
}

final class IntRcKey extends RcKey<int> {
  const IntRcKey(
    super.name,
    super.defaultValue,
    super.reader, {
    required this.min,
    required this.max,
  });

  final int min;
  final int max;

  @override
  int? parse(String raw) {
    final trimmed = raw.trim();
    return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.round();
  }

  @override
  int normalize(int value) => value.clamp(min, max);
}

final class BoolRcKey extends RcKey<bool> {
  const BoolRcKey(super.name, super.defaultValue, super.reader);

  @override
  bool? parse(String raw) => switch (raw.trim().toLowerCase()) {
    'true' || '1' || 'yes' || 'on' => true,
    'false' || '0' || 'no' || 'off' => false,
    _ => null,
  };
}

final class StringRcKey extends RcKey<String> {
  const StringRcKey(
    super.name,
    super.defaultValue,
    super.reader, {
    this.allowed,
  });

  /// Allowed values; null means free text.
  final Set<String>? allowed;

  @override
  String? parse(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final allowedValues = allowed;
    if (allowedValues != null && !allowedValues.contains(value)) return null;
    return value;
  }
}

/// Canonical key catalogue. Names, types, defaults and ranges are binding
/// (brief §4.6); do not change them here without changing the brief.
abstract final class RcKeys {
  // Monetization (B).
  static const monetizationEnabled = BoolRcKey(
    'monetization_enabled',
    true,
    RcReader.both,
  );
  static const rewardedEnabled = BoolRcKey(
    'rewarded_enabled',
    true,
    RcReader.both,
  );
  static const interstitialEnabled = BoolRcKey(
    'interstitial_enabled',
    true,
    RcReader.both,
  );
  static const removeAdsUpsellEnabled = BoolRcKey(
    'remove_ads_upsell_enabled',
    true,
    RcReader.both,
  );

  // Territories and features (B).
  static const spotifyProtoEnabled = BoolRcKey(
    'spotify_proto_enabled',
    false,
    RcReader.both,
  );
  static const licensedProviderEnabled = BoolRcKey(
    'licensed_provider_enabled',
    false,
    RcReader.both,
  );

  // Client-only keys (C).
  static const maxAdWaitMs = IntRcKey(
    'max_ad_wait_ms',
    1500,
    RcReader.client,
    min: 0,
    max: 5000,
  );
  static const rewardedPreloadEnabled = BoolRcKey(
    'rewarded_preload_enabled',
    true,
    RcReader.client,
  );
  static const paywallVariant = StringRcKey(
    'paywall_variant',
    'a',
    RcReader.client,
  );

  /// Semver string. Platform-specific values normally come from Remote
  /// Config platform conditions; a JSON object `{"ios": "...",
  /// "android": "...", "default": "..."}` is also accepted (see VersionGate).
  static const minSupportedAppVersion = StringRcKey(
    'min_supported_app_version',
    '1.0.0',
    RcReader.client,
  );
  static const maintenanceMode = BoolRcKey(
    'maintenance_mode',
    false,
    RcReader.client,
  );
  static const killSwitchAds = BoolRcKey(
    'kill_switch_ads',
    false,
    RcReader.client,
  );
  static const killSwitchPurchases = BoolRcKey(
    'kill_switch_purchases',
    false,
    RcReader.client,
  );
  static const bootConfigTimeoutMs = IntRcKey(
    'boot_config_timeout_ms',
    2500,
    RcReader.client,
    min: 500,
    max: 8000,
  );
  static const bootMinSplashMs = IntRcKey(
    'boot_min_splash_ms',
    800,
    RcReader.client,
    min: 0,
    max: 3000,
  );
  static const bootMaxTotalMs = IntRcKey(
    'boot_max_total_ms',
    8000,
    RcReader.client,
    min: 3000,
    max: 20000,
  );

  static const List<RcKey<Object>> all = [
    monetizationEnabled,
    rewardedEnabled,
    interstitialEnabled,
    removeAdsUpsellEnabled,
    spotifyProtoEnabled,
    licensedProviderEnabled,
    maxAdWaitMs,
    rewardedPreloadEnabled,
    paywallVariant,
    minSupportedAppVersion,
    maintenanceMode,
    killSwitchAds,
    killSwitchPurchases,
    bootConfigTimeoutMs,
    bootMinSplashMs,
    bootMaxTotalMs,
  ];
}
