/// Canonical client analytics names (brief §4.5). Binding: do not rename.
abstract final class AnalyticsEvents {
  static const appInitStep = 'app_init_step';
  static const appInitCompleted = 'app_init_completed';
  static const onboardingComplete = 'onboarding_complete';
  static const consentUpdate = 'consent_update';
  static const musicLinkStart = 'music_link_start';
  static const musicLinkResult = 'music_link_result';
  static const musicLinkDisconnect = 'music_link_disconnect';
  static const poolSubmit = 'pool_submit';
  static const picksUpdate = 'picks_update';
  static const roomCreate = 'room_create';
  static const roomJoin = 'room_join';
  static const roomShare = 'room_share';
  static const paywallView = 'paywall_view';
  static const purchaseStart = 'purchase_start';
  static const purchaseResult = 'purchase_result';
  static const restorePurchases = 'restore_purchases';
  static const removeAdsUpsellView = 'remove_ads_upsell_view';
  static const adRewardedOfferView = 'ad_rewarded_offer_view';
  static const adRewardedResult = 'ad_rewarded_result';
  static const adInterstitialResult = 'ad_interstitial_result';
  static const reportPlayer = 'report_player';
  static const accountDelete = 'account_delete';
}

/// Canonical parameter names used by the client (brief §4.5).
abstract final class AnalyticsParams {
  static const step = 'step';
  static const stage = 'stage';
  static const durationMs = 'duration_ms';
  static const result = 'result';
  static const totalMs = 'total_ms';
  static const coldStart = 'cold_start';
  static const degradedSteps = 'degraded_steps';
  static const ageBand = 'age_band';
  static const consentAnalytics = 'consent_analytics';
  static const consentAds = 'consent_ads';
  static const analytics = 'analytics';
  static const adsPersonalized = 'ads_personalized';
  static const source = 'source';
  static const placement = 'placement';
  static const paywallVariant = 'paywall_variant';
  static const productId = 'product_id';
  static const waitMs = 'wait_ms';
  static const gameId = 'game_id';
}

/// User properties (brief §4.5).
abstract final class AnalyticsUserProperties {
  static const tier = 'tier';
  static const ageBand = 'age_band';
  static const hasMusicLink = 'has_music_link';
  static const gamesCompletedBucket = 'games_completed_bucket';
}
