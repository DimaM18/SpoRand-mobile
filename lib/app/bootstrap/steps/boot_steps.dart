import 'package:mobile_kit/mobile_kit.dart'
    show KitFeatures, KitStepIds, kitBootSteps, mergeInitSteps;

import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/core/ads/ads_policy.dart';

// Wave 8b: the kit steps and the `route` step's destination rules are
// mobile_kit's (mobile-template); SpoRand adds `music_provider` and
// `realtime` after `ads` and keeps its own `ads` step (see [buildBootSteps]).
export 'package:mobile_kit/mobile_kit.dart' show resolveDestination;

/// Canonical step ids; they are the values of the `app_init_step.step`
/// parameter: mobile_kit's [KitStepIds] plus the game's.
abstract final class StepIds {
  static const configDefaults = KitStepIds.configDefaults;
  static const configActivateCached = KitStepIds.configActivateCached;
  static const configFetch = KitStepIds.configFetch;
  static const versionGate = KitStepIds.versionGate;
  static const killSwitches = KitStepIds.killSwitches;

  static const storageOpen = KitStepIds.storageOpen;
  static const sessionRestore = KitStepIds.sessionRestore;
  static const precacheImages = KitStepIds.precacheImages;
  static const fonts = KitStepIds.fonts;
  static const sfx = KitStepIds.sfx;
  static const animations = KitStepIds.animations;
  static const shaderWarmup = KitStepIds.shaderWarmup;

  static const crashReporting = KitStepIds.crashReporting;
  static const analytics = KitStepIds.analytics;
  static const consent = KitStepIds.consent;
  static const auth = KitStepIds.auth;
  static const purchases = KitStepIds.purchases;
  static const ads = KitStepIds.ads;
  static const musicProvider = 'music_provider';
  static const realtime = 'realtime';

  static const route = KitStepIds.route;
}

/// SpoRand's monetization features: purchases, interstitial and rewarded
/// ads (the server knows `purchases` and `rewardedAds`)
/// [новое имя — согласовать].
const sporandFeatures = KitFeatures();

Duration _ms(int value) => Duration(milliseconds: value);

/// The game's boot steps, anchored in `sdk_init` after `ads`
/// [новое имя — согласовать].
List<InitStep> sporandInitSteps() => [
  InitStep(
    id: StepIds.musicProvider,
    stage: InitStage.sdkInit,
    timeout: _ms(1500),
    weight: 4,
    after: StepIds.ads,
    body: (ctx) async {
      await ctx.deps.playback.initialize();
      return null;
    },
  ),
  InitStep(
    id: StepIds.realtime,
    stage: InitStage.sdkInit,
    timeout: _ms(500),
    weight: 2,
    after: StepIds.musicProvider,
    body: (ctx) {
      // Lazy: only remembers the endpoint; the socket opens in a room.
      ctx.deps.realtime.configure(endpoint: ctx.deps.env.realtimeEndpoint);
      return null;
    },
  ),
];

/// The production pipeline: mobile_kit's steps with [sporandInitSteps]
/// merged in. Order inside `sdk_init` is binding.
///
/// The `ads` step stays SpoRand's: it initializes the ads SDK when the
/// policy allows and, as before 8b, does not report missing ad unit ids as
/// a degraded step (a format without a unit simply stays unloaded).
List<InitStep> buildBootSteps({KitFeatures features = sporandFeatures}) => [
  for (final step in mergeInitSteps(
    kitBootSteps(features: features),
    sporandInitSteps(),
  ))
    step.id == StepIds.ads ? _ads(step, features) : step,
];

InitStep _ads(InitStep kitStep, KitFeatures features) => InitStep(
  id: kitStep.id,
  stage: kitStep.stage,
  timeout: kitStep.timeout,
  weight: kitStep.weight,
  body: (ctx) async {
    if (!features.ads) return StepResult.skipped;
    final deps = ctx.deps;
    final options = adsInitOptions(
      flavorAllowsMonetization: deps.env.monetizationAllowed,
      config: deps.remoteConfig,
      ageBand: deps.userPrefs.ageBand,
      consent: ctx.consent,
      policy: deps.agePolicy,
    );
    // Not allowed (yet): first launch initializes ads after onboarding.
    if (options == null) return null;
    await deps.ads.initialize(options);
    return null;
  },
);
