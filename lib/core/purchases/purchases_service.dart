import 'dart:async';

/// Canonical product and entitlement ids (brief §4.7). Binding.
abstract final class ProductIds {
  static const removeAds = 'remove_ads';
  static const premiumMonthly = 'premium_monthly';
  static const premiumYearly = 'premium_yearly';
}

abstract final class EntitlementIds {
  static const noAds = 'no_ads';
  static const premium = 'premium';
}

/// RevenueCat setup (brief §4.7): offering `default`, packages
/// `$rc_monthly`, `$rc_annual` and a custom `remove_ads` package.
abstract final class RevenueCatIds {
  static const offering = 'default';
  static const monthlyPackage = r'$rc_monthly';
  static const annualPackage = r'$rc_annual';
  static const removeAdsPackage = 'remove_ads';
}

final class Entitlements {
  const Entitlements({this.noAds = false, this.premium = false});

  static const none = Entitlements();

  final bool noAds;
  final bool premium;

  /// Premium includes no_ads (brief §6 "Entitlement scope").
  bool get adsRemoved => noAds || premium;

  /// User property `tier`.
  String get tier => premium
      ? 'premium'
      : noAds
      ? 'no_ads'
      : 'free';

  @override
  bool operator ==(Object other) =>
      other is Entitlements && other.noAds == noAds && other.premium == premium;

  @override
  int get hashCode => Object.hash(noAds, premium);
}

enum PaywallProduct { removeAds, premiumMonthly, premiumYearly }

/// A purchasable package as the paywall shows it. Prices are the store's
/// localized strings; we never format prices ourselves.
final class PaywallPackage {
  const PaywallPackage({
    required this.packageId,
    required this.productId,
    required this.product,
    required this.priceLabel,
    this.trialDays,
  });

  final String packageId;
  final String productId;
  final PaywallProduct product;
  final String priceLabel;

  /// Free-trial length in days, when the store offers one.
  final int? trialDays;
}

sealed class PurchaseOutcome {
  const PurchaseOutcome();
}

final class PurchaseSucceeded extends PurchaseOutcome {
  const PurchaseSucceeded(this.entitlements);

  final Entitlements entitlements;
}

final class PurchaseCancelled extends PurchaseOutcome {
  const PurchaseCancelled();
}

final class PurchasePending extends PurchaseOutcome {
  const PurchasePending();
}

final class PurchaseFailed extends PurchaseOutcome {
  const PurchaseFailed(this.code);

  final String code;
}

/// In-app purchases behind an interface (RevenueCat in production).
abstract interface class PurchasesService {
  bool get isConfigured;

  Future<void> configure();

  /// `Purchases.logIn(user_id)`: our `user_id` is RevenueCat's
  /// `app_user_id` (brief §4.7).
  Future<void> logIn(String userId);

  Future<List<PaywallPackage>> loadPaywallPackages();

  Future<PurchaseOutcome> purchase(String packageId);

  Future<Entitlements> restore();

  Entitlements get entitlements;

  Stream<Entitlements> get entitlementChanges;
}

final class FakePurchasesService implements PurchasesService {
  FakePurchasesService({
    List<PaywallPackage>? packages,
    this.nextOutcome,
    this.failConfigure = false,
    Entitlements initial = Entitlements.none,
  }) : packages = packages ?? samplePackages,
       _entitlements = initial;

  static const samplePackages = [
    PaywallPackage(
      packageId: RevenueCatIds.removeAdsPackage,
      productId: ProductIds.removeAds,
      product: PaywallProduct.removeAds,
      priceLabel: r'$3.99',
    ),
    PaywallPackage(
      packageId: RevenueCatIds.monthlyPackage,
      productId: ProductIds.premiumMonthly,
      product: PaywallProduct.premiumMonthly,
      priceLabel: r'$4.99',
    ),
    PaywallPackage(
      packageId: RevenueCatIds.annualPackage,
      productId: ProductIds.premiumYearly,
      product: PaywallProduct.premiumYearly,
      priceLabel: r'$24.99',
      trialDays: 3,
    ),
  ];

  List<PaywallPackage> packages;
  PurchaseOutcome? nextOutcome;
  bool failConfigure;
  Entitlements restorable = Entitlements.none;

  String? loggedInUserId;
  bool _configured = false;
  Entitlements _entitlements;
  final StreamController<Entitlements> _changes =
      StreamController<Entitlements>.broadcast();

  @override
  bool get isConfigured => _configured;

  @override
  Future<void> configure() async {
    if (failConfigure) throw StateError('purchases unavailable');
    _configured = true;
  }

  @override
  Future<void> logIn(String userId) async => loggedInUserId = userId;

  @override
  Future<List<PaywallPackage>> loadPaywallPackages() async => packages;

  @override
  Future<PurchaseOutcome> purchase(String packageId) async {
    final scripted = nextOutcome;
    if (scripted != null) return scripted;
    final package = packages.firstWhere((p) => p.packageId == packageId);
    _set(
      package.product == PaywallProduct.removeAds
          ? Entitlements(noAds: true, premium: _entitlements.premium)
          : const Entitlements(noAds: true, premium: true),
    );
    return PurchaseSucceeded(_entitlements);
  }

  @override
  Future<Entitlements> restore() async {
    _set(restorable);
    return _entitlements;
  }

  void _set(Entitlements value) {
    _entitlements = value;
    _changes.add(value);
  }

  @override
  Entitlements get entitlements => _entitlements;

  @override
  Stream<Entitlements> get entitlementChanges => _changes.stream;
}
