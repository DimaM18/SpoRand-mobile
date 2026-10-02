import 'package:mobile_kit/mobile_kit.dart'
    show KitAnalyticsEvents, KitAnalyticsParams, KitAnalyticsUserProperties;

export 'package:mobile_kit/mobile_kit.dart'
    show KitAnalyticsEvents, KitAnalyticsParams, KitAnalyticsUserProperties;

/// Canonical client analytics names (brief §4.5). Binding: do not rename.
/// Wave 8b: the kit's events are mobile_kit's [KitAnalyticsEvents]; the
/// game events are SpoRand's.
abstract final class AnalyticsEvents {
  static const appInitStep = KitAnalyticsEvents.appInitStep;
  static const appInitCompleted = KitAnalyticsEvents.appInitCompleted;
  static const onboardingComplete = KitAnalyticsEvents.onboardingComplete;
  static const consentUpdate = KitAnalyticsEvents.consentUpdate;
  static const musicLinkStart = 'music_link_start';
  static const musicLinkResult = 'music_link_result';
  static const musicLinkDisconnect = 'music_link_disconnect';
  static const poolSubmit = 'pool_submit';
  static const picksUpdate = 'picks_update';
  static const roomCreate = 'room_create';
  static const roomJoin = 'room_join';
  static const roomShare = 'room_share';
  static const paywallView = KitAnalyticsEvents.paywallView;
  static const purchaseStart = KitAnalyticsEvents.purchaseStart;
  static const purchaseResult = KitAnalyticsEvents.purchaseResult;
  static const restorePurchases = KitAnalyticsEvents.restorePurchases;
  static const removeAdsUpsellView = 'remove_ads_upsell_view';
  static const adRewardedOfferView = 'ad_rewarded_offer_view';
  static const adRewardedResult = 'ad_rewarded_result';
  static const adInterstitialResult = KitAnalyticsEvents.adInterstitialResult;
  static const reportPlayer = 'report_player';
  static const accountDelete = KitAnalyticsEvents.accountDelete;
}

/// Canonical parameter names used by the client (brief §4.5): the kit's
/// ([KitAnalyticsParams]) and the game's.
abstract final class AnalyticsParams {
  static const step = KitAnalyticsParams.step;
  static const stage = KitAnalyticsParams.stage;
  static const durationMs = KitAnalyticsParams.durationMs;
  static const result = KitAnalyticsParams.result;
  static const totalMs = KitAnalyticsParams.totalMs;
  static const coldStart = KitAnalyticsParams.coldStart;
  static const degradedSteps = KitAnalyticsParams.degradedSteps;
  static const ageBand = KitAnalyticsParams.ageBand;
  static const consentAnalytics = KitAnalyticsParams.consentAnalytics;
  static const consentAds = KitAnalyticsParams.consentAds;
  static const analytics = KitAnalyticsParams.analytics;
  static const adsPersonalized = KitAnalyticsParams.adsPersonalized;
  static const source = KitAnalyticsParams.source;
  static const placement = KitAnalyticsParams.placement;
  static const paywallVariant = KitAnalyticsParams.paywallVariant;
  static const productId = KitAnalyticsParams.productId;
  static const waitMs = KitAnalyticsParams.waitMs;
  static const gameId = 'game_id';
  static const roomId = 'room_id';
  static const mode = 'mode';
  static const provider = 'provider';
  static const audioMode = 'audio_mode';
  static const roundsTotal = 'rounds_total';
  static const hostTier = 'host_tier';
  static const via = 'via';
  static const channel = 'channel';
  static const reason = 'reason';
}

/// User properties (brief §4.5): the kit's ([KitAnalyticsUserProperties])
/// and the game's.
abstract final class AnalyticsUserProperties {
  static const tier = KitAnalyticsUserProperties.tier;
  static const ageBand = KitAnalyticsUserProperties.ageBand;
  static const hasMusicLink = 'has_music_link';
  static const gamesCompletedBucket = 'games_completed_bucket';
}
