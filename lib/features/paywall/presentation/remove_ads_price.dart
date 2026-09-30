import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/purchases/purchases_service.dart';

/// The store's localized `remove_ads` price for the upsell card («Играть
/// без рекламы — <цена>»); null when the store is unreachable.
final removeAdsPriceProvider = FutureProvider.autoDispose<String?>((ref) async {
  final purchases = ref.watch(purchasesServiceProvider);
  try {
    if (!purchases.isConfigured) await purchases.configure();
    final packages = await purchases.loadPaywallPackages();
    for (final package in packages) {
      if (package.product == PaywallProduct.removeAds) {
        return package.priceLabel;
      }
    }
  } on Object {
    // The card then shows without a price.
  }
  return null;
});
