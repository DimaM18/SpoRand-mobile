/// Client Remote Config keys: every `C` and `B` key of brief §4.6 with its
/// type, default and allowed range. `S` keys are server-only; the server
/// sends their frozen values in `welcome.config`.
///
/// Wave 8b: the key types and the kit's keys ([KitRcKeys]) live in
/// mobile_kit (mobile-template); the game keys stay here. [RcKeys.all] is
/// the full client list (`rcKeysProvider` of mobile_kit).
library;

import 'package:mobile_kit/mobile_kit.dart'
    show BoolRcKey, IntRcKey, KitRcKeys, RcKey, RcReader, StringListRcKey;

export 'package:mobile_kit/mobile_kit.dart'
    show
        BoolRcKey,
        IntRcKey,
        KitRcKeys,
        RcKey,
        RcReader,
        StringListRcKey,
        StringRcKey;

/// Canonical key catalogue. Names, types, defaults and ranges are binding
/// (brief §4.6); do not change them here without changing the brief.
abstract final class RcKeys {
  // Monetization (B).
  static const monetizationEnabled = KitRcKeys.monetizationEnabled;
  static const rewardedEnabled = KitRcKeys.rewardedEnabled;
  static const interstitialEnabled = KitRcKeys.interstitialEnabled;
  static const removeAdsUpsellEnabled = KitRcKeys.removeAdsUpsellEnabled;

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

  /// Game modes the lobby offers (wave 4): the mode picker shows only these,
  /// and the server rejects the others. Default: whose_song and emoji_quiz
  /// («Угадай песню»); guess_track is hidden [новое имя — согласовать].
  static const modesEnabled = StringListRcKey(
    'modes_enabled',
    '["emoji_quiz","whose_song"]',
    RcReader.both,
    allowed: {'whose_song', 'guess_track', 'emoji_quiz'},
  );

  // Client-only keys (C).
  static const maxAdWaitMs = KitRcKeys.maxAdWaitMs;
  static const rewardedPreloadEnabled = KitRcKeys.rewardedPreloadEnabled;
  static const paywallVariant = KitRcKeys.paywallVariant;

  /// Semver string. Platform-specific values normally come from Remote
  /// Config platform conditions; a JSON object `{"ios": "...",
  /// "android": "...", "default": "..."}` is also accepted (see VersionGate).
  static const minSupportedAppVersion = KitRcKeys.minSupportedAppVersion;
  static const maintenanceMode = KitRcKeys.maintenanceMode;
  static const killSwitchAds = KitRcKeys.killSwitchAds;
  static const killSwitchPurchases = KitRcKeys.killSwitchPurchases;
  static const bootConfigTimeoutMs = KitRcKeys.bootConfigTimeoutMs;
  static const bootMinSplashMs = KitRcKeys.bootMinSplashMs;

  /// Target width of the embedded YouTube player (16:9, logical px; wave 4)
  /// [новое имя — согласовать].
  static const youtubePlayerMinWidthDp = IntRcKey(
    'youtube_player_min_width_dp',
    480,
    RcReader.client,
    min: 356,
    max: 1200,
  );
  static const bootMaxTotalMs = KitRcKeys.bootMaxTotalMs;

  static const List<RcKey<Object>> all = [
    monetizationEnabled,
    rewardedEnabled,
    interstitialEnabled,
    removeAdsUpsellEnabled,
    spotifyProtoEnabled,
    licensedProviderEnabled,
    modesEnabled,
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
    youtubePlayerMinWidthDp,
  ];
}
