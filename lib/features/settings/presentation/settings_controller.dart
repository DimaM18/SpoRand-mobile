import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_policy.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/purchases/entitlement_sync_api.dart';

final appInfoProvider = FutureProvider<AppInfo>(
  (ref) => ref.watch(appInfoSourceProvider).load(),
);

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(SettingsController.new);

enum RestoreOutcome { restored, nothingFound, failed }

final class SettingsState {
  const SettingsState({
    required this.analyticsEnabled,
    required this.analyticsAvailable,
    required this.privacyOptionsRequired,
    required this.purchasesAvailable,
    required this.degradedSteps,
    this.busy = false,
  });

  final bool analyticsEnabled;

  /// False for 13-15 year olds (analytics stays off, brief §7).
  final bool analyticsAvailable;
  final bool privacyOptionsRequired;
  final bool purchasesAvailable;

  /// Boot steps that degraded (diagnostics, shown only when non-empty).
  final List<String> degradedSteps;
  final bool busy;

  SettingsState copyWith({bool? analyticsEnabled, bool? busy, bool? privacy}) =>
      SettingsState(
        analyticsEnabled: analyticsEnabled ?? this.analyticsEnabled,
        analyticsAvailable: analyticsAvailable,
        privacyOptionsRequired: privacy ?? privacyOptionsRequired,
        purchasesAvailable: purchasesAvailable,
        degradedSteps: degradedSteps,
        busy: busy ?? this.busy,
      );
}

class SettingsController extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(userPrefsProvider);
    final band = prefs.ageBand;
    final boot = ref.watch(bootControllerProvider);
    return SettingsState(
      analyticsEnabled: prefs.analyticsConsent ?? false,
      analyticsAvailable: band?.allowsAnalytics ?? false,
      privacyOptionsRequired: ref
          .watch(consentServiceProvider)
          .current
          .privacyOptionsRequired,
      purchasesAvailable: purchasesEnabled(
        flavorAllowsMonetization: ref.watch(appEnvProvider).monetizationAllowed,
        config: ref.watch(remoteConfigProvider),
      ),
      degradedSteps: boot is BootCompleted
          ? boot.report.degradedStepIds
          : const [],
    );
  }

  Future<void> setAnalyticsEnabled(bool enabled) async {
    if (!state.analyticsAvailable) return;
    state = state.copyWith(analyticsEnabled: enabled);
    final prefs = ref.read(userPrefsProvider);
    await prefs.saveAnalyticsConsent(enabled);
    final consent = ref.read(consentServiceProvider).current;
    final adsPersonalized = resolveAdsPersonalized(
      ageBand: prefs.ageBand,
      ump: consent,
    );
    final analytics = ref.read(analyticsProvider);
    // Logged before a revocation takes effect, after a grant: the event is
    // only ever sent while consent is granted.
    Future<void> log() => analytics.logEvent(AnalyticsEvents.consentUpdate, {
      AnalyticsParams.analytics: enabled,
      AnalyticsParams.adsPersonalized: adsPersonalized,
      AnalyticsParams.source: 'settings',
    });
    if (!enabled) await log();
    await analytics.applyConsent(
      enabled ? AnalyticsConsent.granted : AnalyticsConsent.denied,
      adsPersonalized: adsPersonalized,
    );
    if (enabled) await log();
  }

  Future<void> openPrivacyOptions() async {
    try {
      final info = await ref.read(consentServiceProvider).showPrivacyOptions();
      state = state.copyWith(privacy: info.privacyOptionsRequired);
    } on Object {
      // Nothing to show; UMP is unavailable.
    }
  }

  Future<RestoreOutcome> restorePurchases() async {
    state = state.copyWith(busy: true);
    RestoreOutcome outcome;
    try {
      final purchases = ref.read(purchasesServiceProvider);
      if (!purchases.isConfigured) await purchases.configure();
      final entitlements = await purchases.restore();
      outcome = entitlements.adsRemoved
          ? RestoreOutcome.restored
          : RestoreOutcome.nothingFound;
      unawaited(_sync(ref.read(entitlementSyncProvider)));
    } on Object {
      outcome = RestoreOutcome.failed;
    }
    unawaited(
      ref.read(analyticsProvider).logEvent(AnalyticsEvents.restorePurchases, {
        AnalyticsParams.result: switch (outcome) {
          RestoreOutcome.restored => 'success',
          RestoreOutcome.nothingFound => 'nothing_found',
          RestoreOutcome.failed => 'error',
        },
      }),
    );
    if (ref.mounted) state = state.copyWith(busy: false);
    return outcome;
  }

  static Future<void> _sync(EntitlementSyncApi api) async {
    try {
      await api.sync();
    } on Object {
      // The RevenueCat webhook reaches the server anyway.
    }
  }
}
