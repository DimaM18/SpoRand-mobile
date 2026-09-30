import 'dart:async';

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;

import 'package:sporand/core/purchases/purchases_service.dart';

/// RevenueCat adapter (purchases_flutter 10.x). Receipts are validated by
/// RevenueCat; our backend learns about entitlements through the RevenueCat
/// webhook and `POST /v1/me/entitlements/sync` (brief §6).
final class RevenueCatPurchasesService implements PurchasesService {
  RevenueCatPurchasesService({required this._apiKey});

  final String? _apiKey;
  bool _configured = false;
  String? _appUserId;
  Entitlements _entitlements = Entitlements.none;
  final Map<String, rc.Package> _packages = {};
  final StreamController<Entitlements> _changes =
      StreamController<Entitlements>.broadcast();

  @override
  bool get isConfigured => _configured;

  @override
  Future<void> configure() async {
    if (_configured) return;
    final apiKey = _apiKey;
    if (apiKey == null) {
      // TODO(owner): pass REVENUECAT_API_KEY_IOS/ANDROID via --dart-define.
      throw StateError('RevenueCat API key is not configured');
    }
    await rc.Purchases.configure(rc.PurchasesConfiguration(apiKey));
    rc.Purchases.addCustomerInfoUpdateListener(_onCustomerInfo);
    _configured = true;
  }

  void _onCustomerInfo(rc.CustomerInfo info) {
    final next = _map(info);
    if (next == _entitlements) return;
    _entitlements = next;
    _changes.add(next);
  }

  static Entitlements _map(rc.CustomerInfo info) {
    final active = info.entitlements.active;
    final premium = active.containsKey(EntitlementIds.premium);
    return Entitlements(
      noAds: premium || active.containsKey(EntitlementIds.noAds),
      premium: premium,
    );
  }

  @override
  Future<void> logIn(String userId) async {
    final result = await rc.Purchases.logIn(userId);
    _appUserId = userId;
    _onCustomerInfo(result.customerInfo);
  }

  @override
  String? get appUserId => _appUserId;

  @override
  Future<List<PaywallPackage>> loadPaywallPackages() async {
    final offerings = await rc.Purchases.getOfferings();
    final offering = offerings.all[RevenueCatIds.offering] ?? offerings.current;
    if (offering == null) return const [];
    _packages.clear();
    final result = <PaywallPackage>[];
    for (final package in offering.availablePackages) {
      final product = switch (package.identifier) {
        RevenueCatIds.removeAdsPackage => PaywallProduct.removeAds,
        RevenueCatIds.monthlyPackage => PaywallProduct.premiumMonthly,
        RevenueCatIds.annualPackage => PaywallProduct.premiumYearly,
        _ => null,
      };
      if (product == null) continue;
      _packages[package.identifier] = package;
      final intro = package.storeProduct.introductoryPrice;
      result.add(
        PaywallPackage(
          packageId: package.identifier,
          productId: package.storeProduct.identifier,
          product: product,
          priceLabel: package.storeProduct.priceString,
          trialDays: intro != null && intro.price == 0
              ? _periodInDays(intro.periodUnit, intro.periodNumberOfUnits)
              : null,
        ),
      );
    }
    return result;
  }

  static int _periodInDays(rc.PeriodUnit unit, int count) => switch (unit) {
    rc.PeriodUnit.day => count,
    rc.PeriodUnit.week => count * 7,
    rc.PeriodUnit.month => count * 30,
    rc.PeriodUnit.year => count * 365,
    rc.PeriodUnit.unknown => count,
  };

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    final package = _packages[packageId];
    if (package == null) return const PurchaseFailed('unknown_package');
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.package(package),
      );
      _onCustomerInfo(result.customerInfo);
      return PurchaseSucceeded(_entitlements);
    } on PlatformException catch (e) {
      return switch (rc.PurchasesErrorHelper.getErrorCode(e)) {
        rc.PurchasesErrorCode.purchaseCancelledError =>
          const PurchaseCancelled(),
        rc.PurchasesErrorCode.paymentPendingError => const PurchasePending(),
        final code => PurchaseFailed(code.name),
      };
    }
  }

  @override
  Future<Entitlements> restore() async {
    final info = await rc.Purchases.restorePurchases();
    _onCustomerInfo(info);
    return _entitlements;
  }

  @override
  Entitlements get entitlements => _entitlements;

  @override
  Stream<Entitlements> get entitlementChanges => _changes.stream;
}
