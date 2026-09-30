import 'package:sporand/core/platform/app_platform.dart';

/// `ad_interstitial_result.result` / `ad.interstitial_result.result`.
enum InterstitialResult {
  shown('shown'),
  skippedNotLoaded('skipped_not_loaded'),
  skippedNotEligible('skipped_not_eligible'),
  failedToShow('failed_to_show');

  const InterstitialResult(this.wireName);

  final String wireName;
}

final class InterstitialOutcome {
  const InterstitialOutcome(this.result, this.wait);

  final InterstitialResult result;

  /// How long we waited for the ad to load before showing or skipping
  /// (`wait_ms`).
  final Duration wait;
}

/// `bonus.ad_result.status` / `ad_rewarded_result.result`.
enum RewardedResult {
  earned('earned'),
  dismissed('dismissed'),
  failedToLoad('failed_to_load'),
  failedToShow('failed_to_show');

  const RewardedResult(this.wireName);

  final String wireName;
}

final class AdsInitOptions {
  const AdsInitOptions({
    required this.underAgeOfConsent,
    required this.personalizedAllowed,
  });

  /// 13-15 year olds (brief §7): age-restricted, non-personalized ads.
  final bool underAgeOfConsent;
  final bool personalizedAllowed;
}

final class AdUnitIds {
  const AdUnitIds({this.interstitial, this.rewarded});

  static const none = AdUnitIds();

  /// Google's public sample ad units (safe for dev/staging only).
  static AdUnitIds googleTestUnits(AppPlatform platform) => switch (platform) {
    AppPlatform.ios => const AdUnitIds(
      interstitial: 'ca-app-pub-3940256099942544/4411468910',
      rewarded: 'ca-app-pub-3940256099942544/1712485313',
    ),
    AppPlatform.android => const AdUnitIds(
      interstitial: 'ca-app-pub-3940256099942544/1033173712',
      rewarded: 'ca-app-pub-3940256099942544/5224354917',
    ),
    AppPlatform.other => none,
  };

  final String? interstitial;
  final String? rewarded;

  bool get isComplete => interstitial != null && rewarded != null;
}

/// Ads behind an interface (AdMob in production). Ads are shown only at the
/// end of a game, never over audio and never on launch (brief §6).
abstract interface class AdsService {
  bool get isInitialized;

  /// Call only when UMP `canRequestAds()` is true and age allows ads.
  Future<void> initialize(AdsInitOptions options);

  Future<void> preloadInterstitial();

  /// Shows the interstitial if it is loaded or loads within [maxWait]
  /// (`max_ad_wait_ms`); otherwise skips it.
  Future<InterstitialOutcome> showInterstitial({required Duration maxWait});

  Future<void> preloadRewarded();

  bool get isRewardedReady;

  /// Shows a rewarded ad with server-side verification: `ssvUserId` is the
  /// opaque `ssv_user_id` and `rewardNonce` travels as `custom_data`. The
  /// client-side reward callback is informational only (brief §6 step 6).
  Future<RewardedResult> showRewarded({
    required String ssvUserId,
    required String rewardNonce,
    Duration maxWait = Duration.zero,
  });
}

/// Scriptable fake for tests and builds without the ads SDK.
final class FakeAdsService implements AdsService {
  FakeAdsService({
    this.interstitialLoaded = true,
    this.rewardedLoaded = true,
    this.rewardedResult = RewardedResult.earned,
    this.failInitialize = false,
  });

  bool interstitialLoaded;
  bool rewardedLoaded;
  RewardedResult rewardedResult;
  bool failInitialize;

  AdsInitOptions? initOptions;
  String? lastSsvUserId;
  String? lastRewardNonce;
  int interstitialsShown = 0;

  bool _initialized = false;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(AdsInitOptions options) async {
    if (failInitialize) throw StateError('ads SDK unavailable');
    initOptions = options;
    _initialized = true;
  }

  @override
  Future<void> preloadInterstitial() async {}

  @override
  Future<InterstitialOutcome> showInterstitial({
    required Duration maxWait,
  }) async {
    if (!_initialized || !interstitialLoaded) {
      return InterstitialOutcome(InterstitialResult.skippedNotLoaded, maxWait);
    }
    interstitialsShown++;
    return const InterstitialOutcome(InterstitialResult.shown, Duration.zero);
  }

  @override
  Future<void> preloadRewarded() async {}

  @override
  bool get isRewardedReady => _initialized && rewardedLoaded;

  @override
  Future<RewardedResult> showRewarded({
    required String ssvUserId,
    required String rewardNonce,
    Duration maxWait = Duration.zero,
  }) async {
    if (!isRewardedReady) return RewardedResult.failedToLoad;
    lastSsvUserId = ssvUserId;
    lastRewardNonce = rewardNonce;
    return rewardedResult;
  }
}
