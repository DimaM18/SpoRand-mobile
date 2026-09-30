import 'dart:async';

import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/init_context.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/bootstrap/domain/version_gate.dart';
import 'package:sporand/app/bootstrap/warmup/resource_warmer.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/consent/consent_policy.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';

/// Canonical step ids (brief §3 "Boot pipeline"); they are the values of
/// the `app_init_step.step` parameter.
abstract final class StepIds {
  static const configDefaults = 'config_defaults';
  static const configActivateCached = 'config_activate_cached';
  static const configFetch = 'config_fetch';
  static const versionGate = 'version_gate';
  static const killSwitches = 'kill_switches';

  static const storageOpen = 'storage_open';
  static const sessionRestore = 'session_restore';
  static const precacheImages = 'precache_images';
  static const fonts = 'fonts';
  static const sfx = 'sfx';
  static const animations = 'animations';
  static const shaderWarmup = 'shader_warmup';

  static const crashReporting = 'crash_reporting';
  static const analytics = 'analytics';
  static const consent = 'consent';
  static const auth = 'auth';
  static const purchases = 'purchases';
  static const ads = 'ads';
  static const musicProvider = 'music_provider';
  static const realtime = 'realtime';

  static const route = 'route';
}

Duration _ms(int value) => Duration(milliseconds: value);

/// The production pipeline. Order inside `sdk_init` is binding.
List<InitStep> buildBootSteps() => [
  // --- config -------------------------------------------------------------
  InitStep(
    id: StepIds.configDefaults,
    stage: InitStage.config,
    timeout: _ms(2000),
    critical: true,
    weight: 4,
    body: _configDefaults,
  ),
  InitStep(
    id: StepIds.configActivateCached,
    stage: InitStage.config,
    timeout: _ms(1500),
    weight: 4,
    body: (ctx) async {
      await ctx.deps.remoteConfig.activateCached();
      return null;
    },
  ),
  InitStep(
    id: StepIds.configFetch,
    stage: InitStage.config,
    timeout: _ms(2750),
    // The service enforces boot_config_timeout_ms itself and falls back to
    // cached/default values; the step timeout is only a safety margin.
    resolveTimeout: (ctx) => ctx.timings.configFetchTimeout + _ms(250),
    weight: 12,
    dependsOn: const {StepIds.configDefaults, StepIds.configActivateCached},
    body: (ctx) async {
      final result = await ctx.deps.remoteConfig.fetchAndActivate(
        timeout: ctx.timings.configFetchTimeout,
      );
      return switch (result) {
        ConfigFetchResult.activated || ConfigFetchResult.unchanged => null,
        ConfigFetchResult.timedOut => StepResult.timeout,
        ConfigFetchResult.failed => StepResult.degraded,
      };
    },
  ),
  InitStep(
    id: StepIds.versionGate,
    stage: InitStage.config,
    timeout: _ms(1000),
    weight: 3,
    dependsOn: const {StepIds.configFetch},
    body: (ctx) async {
      final info = ctx.appInfo = await ctx.deps.appInfo.load();
      if (VersionGate.requiresUpdate(
        minSupportedRaw: ctx.deps.remoteConfig.minSupportedAppVersion,
        currentVersion: info.version,
        platform: info.platform,
      )) {
        ctx.raiseGate(BootGate.forceUpdate);
      }
      return null;
    },
  ),
  InitStep(
    id: StepIds.killSwitches,
    stage: InitStage.config,
    timeout: _ms(500),
    weight: 2,
    dependsOn: const {StepIds.configFetch},
    body: (ctx) {
      // kill_switch_ads / kill_switch_purchases are read by their own steps.
      if (ctx.deps.remoteConfig.maintenanceMode) {
        ctx.raiseGate(BootGate.maintenance);
      }
      return null;
    },
  ),

  // --- warmup -------------------------------------------------------------
  InitStep(
    id: StepIds.storageOpen,
    stage: InitStage.warmup,
    timeout: _ms(3000),
    critical: true,
    weight: 6,
    body: (ctx) async {
      await ctx.deps.preferences.open();
      try {
        await ctx.deps.secureStore.open();
      } on Object {
        // Without secure storage we cannot keep a session, but the app can
        // still run with an in-memory one.
        return StepResult.degraded;
      }
      return null;
    },
  ),
  InitStep(
    id: StepIds.sessionRestore,
    stage: InitStage.warmup,
    timeout: _ms(1500),
    weight: 3,
    dependsOn: const {StepIds.storageOpen},
    body: (ctx) async {
      ctx.session = await ctx.deps.sessions.restore();
      return null;
    },
  ),
  _warmup(StepIds.precacheImages, 5, _ms(2000), (w) => w.precacheImages()),
  _warmup(StepIds.fonts, 3, _ms(1000), (w) => w.loadFonts()),
  _warmup(StepIds.sfx, 3, _ms(1500), (w) => w.loadSoundEffects()),
  _warmup(StepIds.animations, 2, _ms(1500), (w) => w.loadAnimations()),
  _warmup(StepIds.shaderWarmup, 3, _ms(1000), (w) => w.warmUpShaders()),

  // --- sdk_init (strict order) --------------------------------------------
  InitStep(
    id: StepIds.crashReporting,
    stage: InitStage.sdkInit,
    timeout: _ms(2000),
    weight: 4,
    runsWhenGated: true,
    body: (ctx) async {
      final deps = ctx.deps;
      await deps.crashReporter.initialize(
        collectionEnabled: !deps.env.flavor.isDev,
      );
      await deps.crashGate.attach(deps.crashReporter);
      return null;
    },
  ),
  InitStep(
    id: StepIds.analytics,
    stage: InitStage.sdkInit,
    timeout: _ms(2000),
    weight: 5,
    body: (ctx) async {
      // Consent Mode defaults to "denied" until the consent step decides.
      await ctx.deps.analytics.initialize();
      return null;
    },
  ),
  InitStep(
    id: StepIds.consent,
    stage: InitStage.sdkInit,
    timeout: _ms(3000),
    weight: 6,
    body: _consent,
  ),
  InitStep(
    id: StepIds.auth,
    stage: InitStage.sdkInit,
    timeout: _ms(4000),
    weight: 9,
    body: _auth,
  ),
  InitStep(
    id: StepIds.purchases,
    stage: InitStage.sdkInit,
    timeout: _ms(3000),
    weight: 6,
    body: (ctx) async {
      final deps = ctx.deps;
      if (!purchasesEnabled(
        flavorAllowsMonetization: deps.env.monetizationAllowed,
        config: deps.remoteConfig,
      )) {
        return null;
      }
      await deps.purchases.configure();
      final session = ctx.session ?? deps.sessions.current;
      if (session == null) return StepResult.degraded;
      await deps.purchases.logIn(session.userId);
      return null;
    },
  ),
  InitStep(
    id: StepIds.ads,
    stage: InitStage.sdkInit,
    timeout: _ms(3000),
    weight: 6,
    body: (ctx) async {
      final deps = ctx.deps;
      final options = adsInitOptions(
        flavorAllowsMonetization: deps.env.monetizationAllowed,
        config: deps.remoteConfig,
        ageBand: deps.userPrefs.ageBand,
        consent: ctx.consent,
      );
      // Not allowed (yet): first launch initializes ads after onboarding.
      if (options == null) return null;
      await deps.ads.initialize(options);
      return null;
    },
  ),
  InitStep(
    id: StepIds.musicProvider,
    stage: InitStage.sdkInit,
    timeout: _ms(1500),
    weight: 4,
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
    body: (ctx) {
      // Lazy: only remembers the endpoint; the socket opens in a room.
      ctx.deps.realtime.configure(endpoint: ctx.deps.env.realtimeEndpoint);
      return null;
    },
  ),

  // --- enter_app ----------------------------------------------------------
  InitStep(
    id: StepIds.route,
    stage: InitStage.enterApp,
    timeout: _ms(1000),
    critical: true,
    weight: 8,
    body: (ctx) {
      ctx.destination = resolveDestination(ctx);
      return null;
    },
  ),
];

InitStep _warmup(
  String id,
  double weight,
  Duration timeout,
  Future<void> Function(ResourceWarmer warmer) work,
) => InitStep(
  id: id,
  stage: InitStage.warmup,
  timeout: timeout,
  weight: weight,
  body: (ctx) async {
    await work(ctx.deps.warmer);
    return null;
  },
);

Future<StepResult?> _configDefaults(InitContext ctx) async {
  // Reads already fall back to the bundled defaults, so this step cannot
  // leave the app without config; pushing them into the SDK is best effort.
  try {
    await ctx.deps.remoteConfig.applyDefaults().timeout(_ms(1500));
    return null;
  } on Object {
    return StepResult.degraded;
  }
}

Future<StepResult?> _consent(InitContext ctx) async {
  final deps = ctx.deps;
  final ageBand = deps.userPrefs.ageBand;
  var degraded = false;
  ConsentInfo info;
  try {
    // Unknown age is treated as under the age of consent until the gate runs.
    // The consent form itself is never shown here: on first launch it
    // belongs to onboarding (age gate first, then consent).
    info = await deps.consent.refresh(
      underAgeOfConsent: ageBand?.isUnderAgeOfConsent ?? true,
    );
  } on Object {
    info = deps.consent.current;
    degraded = true;
  }
  ctx.consent = info;
  await deps.analytics.applyConsent(
    resolveAnalyticsConsent(
      ageBand: ageBand,
      storedChoice: deps.userPrefs.analyticsConsent,
      ump: info,
    ),
    adsPersonalized: resolveAdsPersonalized(ageBand: ageBand, ump: info),
  );
  return degraded ? StepResult.degraded : null;
}

Future<StepResult?> _auth(InitContext ctx) async {
  final deps = ctx.deps;
  var degraded = false;
  try {
    await deps.appCheck.activate();
  } on Object {
    // The server runs App Check in `monitor` mode first (brief §7).
    degraded = true;
  }
  final session = ctx.session = await deps.auth.ensureSession();
  final identity = deps.analyticsIdentity;
  final analyticsUid = session.analyticsUid;
  if (identity != null) {
    final attached = identity.attach(session);
    // A restored session without an id asks `/v1/me`, which must not hold
    // up the boot.
    if (analyticsUid == null) {
      unawaited(attached);
    } else {
      await attached;
    }
  } else if (analyticsUid != null) {
    await deps.analytics.setUserId(analyticsUid);
    await deps.crashGate.setUserId(analyticsUid);
  }
  return degraded ? StepResult.degraded : null;
}

/// `route` (enter_app): gate screens first, then the age gate/onboarding,
/// then the most recent queued deep link, then home.
BootDestination resolveDestination(InitContext ctx) {
  switch (ctx.gate) {
    case BootGate.forceUpdate:
      return const ForceUpdateDestination();
    case BootGate.maintenance:
      return const MaintenanceDestination();
    case null:
      break;
  }
  AppLink? link;
  for (final incoming in ctx.deepLinks.drain()) {
    link = ctx.deps.linkParser.parse(incoming) ?? link;
  }
  final prefs = ctx.deps.userPrefs;
  if (prefs.ageGateBlocked) return const AgeBlockedDestination();
  if (!prefs.onboardingCompleted) {
    if (link != null) ctx.deepLinks.defer(link);
    return OnboardingDestination(pendingLink: link);
  }
  if (link != null) return DeepLinkDestination(link);
  return const HomeDestination();
}
