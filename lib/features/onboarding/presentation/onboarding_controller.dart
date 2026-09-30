import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/consent/consent_policy.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/features/onboarding/domain/age_gate.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

final class OnboardingState {
  const OnboardingState({
    this.ageBand,
    this.blocked = false,
    this.completed = false,
    this.analyticsOptIn = false,
    this.busy = false,
  });

  final AgeBand? ageBand;
  final bool blocked;
  final bool completed;

  /// GDPR: opt-in, never pre-ticked.
  final bool analyticsOptIn;
  final bool busy;

  /// 13-15 year olds are not asked (analytics stays off, brief §7).
  bool get canChooseAnalytics => ageBand?.allowsAnalytics ?? false;

  OnboardingState copyWith({
    AgeBand? ageBand,
    bool? blocked,
    bool? completed,
    bool? analyticsOptIn,
    bool? busy,
  }) => OnboardingState(
    ageBand: ageBand ?? this.ageBand,
    blocked: blocked ?? this.blocked,
    completed: completed ?? this.completed,
    analyticsOptIn: analyticsOptIn ?? this.analyticsOptIn,
    busy: busy ?? this.busy,
  );
}

/// First-launch flow (brief §7 consent order): age gate -> UMP -> Firebase
/// consent -> ads init.
class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    // Preferences open during the warmup stage; re-read once boot is done.
    ref.watch(bootControllerProvider.select((state) => state is BootCompleted));
    final prefs = ref.watch(userPrefsProvider);
    return OnboardingState(
      ageBand: prefs.ageBand,
      blocked: prefs.ageGateBlocked,
      completed: prefs.onboardingCompleted,
    );
  }

  Future<AgeGateResult> submitBirthYear(String input) async {
    final result = AgeGate(currentYear: clock.now().year).evaluate(input);
    final prefs = ref.read(userPrefsProvider);
    switch (result) {
      case AgeGateInvalid():
        break;
      case AgeGateBlocked():
        await prefs.saveAgeBand(AgeBand.under13);
        state = state.copyWith(ageBand: AgeBand.under13, blocked: true);
      case AgeGateAccepted(:final band):
        await prefs.saveAgeBand(band);
        state = state.copyWith(ageBand: band);
    }
    return result;
  }

  void setAnalyticsOptIn(bool value) {
    state = state.copyWith(analyticsOptIn: value);
  }

  /// Shows the UMP form if required, applies the analytics choice,
  /// initializes ads if now allowed and returns where to go next (the deep
  /// link that waited for onboarding, or home).
  Future<String> complete() async {
    final band = state.ageBand;
    if (band == null || band.isBlocked) return Routes.onboarding;
    state = state.copyWith(busy: true);

    final consent = ref.read(consentServiceProvider);
    ConsentInfo info;
    try {
      await consent.refresh(underAgeOfConsent: band.isUnderAgeOfConsent);
      info = await consent.showFormIfRequired();
    } on Object {
      // UMP unavailable: ads stay off (canRequestAds stays false).
      info = consent.current;
    }

    final prefs = ref.read(userPrefsProvider);
    final analyticsChoice = band.allowsAnalytics && state.analyticsOptIn;
    if (band.allowsAnalytics) await prefs.saveAnalyticsConsent(analyticsChoice);
    final adsPersonalized = resolveAdsPersonalized(ageBand: band, ump: info);
    final analytics = ref.read(analyticsProvider);
    await analytics.applyConsent(
      resolveAnalyticsConsent(
        ageBand: band,
        storedChoice: band.allowsAnalytics ? analyticsChoice : null,
        ump: info,
      ),
      adsPersonalized: adsPersonalized,
    );
    await _initAdsIfAllowed(band, info);
    await prefs.markOnboardingCompleted();

    unawaited(
      analytics.logEvent(AnalyticsEvents.onboardingComplete, {
        AnalyticsParams.ageBand: band.wireName,
        AnalyticsParams.consentAnalytics: analyticsChoice,
        AnalyticsParams.consentAds: adsPersonalized,
      }),
    );
    unawaited(
      analytics.setUserProperty(AnalyticsUserProperties.ageBand, band.wireName),
    );

    state = state.copyWith(completed: true, busy: false);
    return ref.read(deepLinkQueueProvider).takeDeferred()?.location ??
        Routes.home;
  }

  Future<void> _initAdsIfAllowed(AgeBand band, ConsentInfo info) async {
    final ads = ref.read(adsServiceProvider);
    if (ads.isInitialized) return;
    final options = adsInitOptions(
      flavorAllowsMonetization: ref.read(appEnvProvider).monetizationAllowed,
      config: ref.read(remoteConfigProvider),
      ageBand: band,
      consent: info,
    );
    if (options == null) return;
    try {
      await ads.initialize(options).timeout(const Duration(seconds: 3));
    } on Object {
      // Ads stay off for this session; nothing user-visible depends on it.
    }
  }
}
