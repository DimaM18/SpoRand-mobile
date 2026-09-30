import 'dart:async';

import 'package:clock/clock.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

import 'package:sporand/core/ads/ads_service.dart';

/// AdMob adapter (google_mobile_ads 9.x).
///
/// TODO(owner): replace the sample AdMob app ids in AndroidManifest.xml
/// (`com.google.android.gms.ads.APPLICATION_ID`) and Info.plist
/// (`GADApplicationIdentifier`) and pass real ad unit ids via --dart-define.
final class AdMobAdsService implements AdsService {
  AdMobAdsService({required this._units});

  final AdUnitIds _units;
  bool _initialized = false;
  AdsInitOptions _options = const AdsInitOptions(
    underAgeOfConsent: true,
    personalizedAllowed: false,
  );

  gma.InterstitialAd? _interstitial;
  Future<gma.InterstitialAd?>? _interstitialLoading;
  gma.RewardedAd? _rewarded;
  Future<gma.RewardedAd?>? _rewardedLoading;

  @override
  bool get isInitialized => _initialized;

  @override
  Future<void> initialize(AdsInitOptions options) async {
    _options = options;
    await gma.MobileAds.instance.updateRequestConfiguration(
      gma.RequestConfiguration(
        maxAdContentRating: gma.MaxAdContentRating.t,
        // google_mobile_ads 9 replaced `tagForUnderAgeOfConsent` with
        // `ageRestrictedTreatment`; UMP still receives the TFUA flag.
        ageRestrictedTreatment: options.underAgeOfConsent
            ? gma.AgeRestrictedTreatment.teen
            : null,
      ),
    );
    await gma.MobileAds.instance.initialize();
    _initialized = true;
  }

  gma.AdRequest get _request => gma.AdRequest(
    nonPersonalizedAds: _options.personalizedAllowed ? null : true,
  );

  @override
  Future<void> preloadInterstitial() async {
    await _loadInterstitial();
  }

  Future<gma.InterstitialAd?> _loadInterstitial() {
    final loaded = _interstitial;
    final unit = _units.interstitial;
    if (loaded != null) return Future.value(loaded);
    if (!_initialized || unit == null) return Future.value();
    return _interstitialLoading ??=
        _load<gma.InterstitialAd>((done) {
          return gma.InterstitialAd.load(
            adUnitId: unit,
            request: _request,
            adLoadCallback: gma.InterstitialAdLoadCallback(
              onAdLoaded: done,
              onAdFailedToLoad: (_) => done(null),
            ),
          );
        }).then((ad) {
          _interstitialLoading = null;
          return _interstitial = ad;
        });
  }

  @override
  Future<InterstitialOutcome> showInterstitial({
    required Duration maxWait,
  }) async {
    final waited = clock.stopwatch()..start();
    final ad =
        _interstitial ??
        await _loadInterstitial().timeout(maxWait, onTimeout: () => null);
    waited.stop();
    if (ad == null) {
      return InterstitialOutcome(
        InterstitialResult.skippedNotLoaded,
        waited.elapsed,
      );
    }
    _interstitial = null;
    final result = Completer<InterstitialResult>();
    ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!result.isCompleted) result.complete(InterstitialResult.shown);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!result.isCompleted) {
          result.complete(InterstitialResult.failedToShow);
        }
      },
    );
    try {
      await ad.show();
    } on Object {
      return InterstitialOutcome(
        InterstitialResult.failedToShow,
        waited.elapsed,
      );
    }
    return InterstitialOutcome(await result.future, waited.elapsed);
  }

  @override
  Future<void> preloadRewarded() async {
    await _loadRewarded();
  }

  @override
  bool get isRewardedReady => _rewarded != null;

  Future<gma.RewardedAd?> _loadRewarded() {
    final loaded = _rewarded;
    final unit = _units.rewarded;
    if (loaded != null) return Future.value(loaded);
    if (!_initialized || unit == null) return Future.value();
    return _rewardedLoading ??=
        _load<gma.RewardedAd>((done) {
          return gma.RewardedAd.load(
            adUnitId: unit,
            request: _request,
            rewardedAdLoadCallback: gma.RewardedAdLoadCallback(
              onAdLoaded: done,
              onAdFailedToLoad: (_) => done(null),
            ),
          );
        }).then((ad) {
          _rewardedLoading = null;
          return _rewarded = ad;
        });
  }

  @override
  Future<RewardedResult> showRewarded({
    required String ssvUserId,
    required String rewardNonce,
    Duration maxWait = Duration.zero,
  }) async {
    final ad =
        _rewarded ??
        await _loadRewarded().timeout(maxWait, onTimeout: () => null);
    if (ad == null) return RewardedResult.failedToLoad;
    _rewarded = null;
    await ad.setServerSideOptions(
      gma.ServerSideVerificationOptions(
        userId: ssvUserId,
        customData: rewardNonce,
      ),
    );
    var earned = false;
    final result = Completer<RewardedResult>();
    ad.fullScreenContentCallback = gma.FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        unawaited(ad.dispose());
        if (!result.isCompleted) {
          result.complete(
            earned ? RewardedResult.earned : RewardedResult.dismissed,
          );
        }
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        unawaited(ad.dispose());
        if (!result.isCompleted) result.complete(RewardedResult.failedToShow);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) => earned = true);
    } on Object {
      return RewardedResult.failedToShow;
    }
    return result.future;
  }

  /// Bridges the callback-style load API to a Future. Load errors resolve to
  /// null: a missing ad is an expected outcome, not a failure.
  static Future<T?> _load<T extends Object>(
    Future<void> Function(void Function(T? ad) done) start,
  ) {
    final completer = Completer<T?>();
    void done(T? ad) {
      if (!completer.isCompleted) completer.complete(ad);
    }

    unawaited(start(done).catchError((Object _) => done(null)));
    return completer.future;
  }
}
