import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/ads/ads_policy.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';

sealed class PaywallState {
  const PaywallState();
}

final class PaywallLoading extends PaywallState {
  const PaywallLoading();
}

/// Purchases are off (spotifyProto, monetization_enabled=false,
/// kill_switch_purchases) or the store is unreachable.
final class PaywallUnavailable extends PaywallState {
  const PaywallUnavailable();
}

final class PaywallLoadFailed extends PaywallState {
  const PaywallLoadFailed();
}

final class PaywallReady extends PaywallState {
  const PaywallReady({
    required this.packages,
    required this.selectedPackageId,
    this.purchasing = false,
  });

  final List<PaywallPackage> packages;
  final String selectedPackageId;
  final bool purchasing;

  PaywallPackage get selected =>
      packages.firstWhere((p) => p.packageId == selectedPackageId);

  PaywallReady copyWith({String? selectedPackageId, bool? purchasing}) =>
      PaywallReady(
        packages: packages,
        selectedPackageId: selectedPackageId ?? this.selectedPackageId,
        purchasing: purchasing ?? this.purchasing,
      );
}

final paywallControllerProvider = NotifierProvider.autoDispose
    .family<PaywallController, PaywallState, PaywallPlacement>(
      PaywallController.new,
    );

class PaywallController extends Notifier<PaywallState> {
  PaywallController(this.placement);

  final PaywallPlacement placement;

  @override
  PaywallState build() {
    unawaited(Future.microtask(load));
    return const PaywallLoading();
  }

  Future<void> load() async {
    final purchases = ref.read(purchasesServiceProvider);
    final config = ref.read(remoteConfigProvider);
    if (!purchasesEnabled(
      flavorAllowsMonetization: ref.read(appEnvProvider).monetizationAllowed,
      config: config,
    )) {
      state = const PaywallUnavailable();
      return;
    }
    state = const PaywallLoading();
    try {
      if (!purchases.isConfigured) await purchases.configure();
      final packages = await purchases.loadPaywallPackages();
      if (!ref.mounted) return;
      if (packages.isEmpty) {
        state = const PaywallUnavailable();
        return;
      }
      // Default to the yearly plan (trial) when offered.
      final preferred = packages.firstWhere(
        (p) => p.product == PaywallProduct.premiumYearly,
        orElse: () => packages.first,
      );
      state = PaywallReady(
        packages: packages,
        selectedPackageId: preferred.packageId,
      );
      unawaited(
        ref.read(analyticsProvider).logEvent(AnalyticsEvents.paywallView, {
          AnalyticsParams.placement: placement.wireName,
          AnalyticsParams.paywallVariant: config.paywallVariant,
        }),
      );
    } on Object {
      if (ref.mounted) state = const PaywallLoadFailed();
    }
  }

  void select(String packageId) {
    final current = state;
    if (current is PaywallReady && !current.purchasing) {
      state = current.copyWith(selectedPackageId: packageId);
    }
  }

  Future<PurchaseOutcome?> purchaseSelected() async {
    final current = state;
    if (current is! PaywallReady || current.purchasing) return null;
    final package = current.selected;
    state = current.copyWith(purchasing: true);
    final analytics = ref.read(analyticsProvider);
    unawaited(
      analytics.logEvent(AnalyticsEvents.purchaseStart, {
        AnalyticsParams.productId: package.productId,
        AnalyticsParams.placement: placement.wireName,
      }),
    );
    PurchaseOutcome outcome;
    try {
      final purchases = ref.read(purchasesServiceProvider);
      // The boot step may have degraded before logIn (brief §4.7).
      await ensurePurchasesUser(
        purchases,
        userId: ref.read(authServiceProvider).currentUserId,
      );
      outcome = await purchases.purchase(package.packageId);
    } on Object catch (e) {
      outcome = PurchaseFailed('$e');
    }
    unawaited(
      analytics.logEvent(AnalyticsEvents.purchaseResult, {
        AnalyticsParams.productId: package.productId,
        AnalyticsParams.result: switch (outcome) {
          PurchaseSucceeded() => 'success',
          PurchaseCancelled() => 'cancel',
          PurchasePending() => 'pending',
          PurchaseFailed() => 'error',
        },
      }),
    );
    if (outcome is PurchaseSucceeded) {
      // The server re-reads RevenueCat (brief §6); the webhook is the backup.
      unawaited(ref.read(entitlementSyncProvider).sync().catchError((_) {}));
    }
    if (ref.mounted) state = current.copyWith(purchasing: false);
    return outcome;
  }
}
