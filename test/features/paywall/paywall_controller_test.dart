import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/purchases/entitlement_sync_api.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_controller.dart';

void main() {
  late FakePurchasesService purchases;
  late FakeEntitlementSyncApi sync;
  late InMemoryAnalyticsBackend events;
  late ProviderContainer container;

  setUp(() async {
    purchases = FakePurchasesService();
    sync = FakeEntitlementSyncApi();
    events = InMemoryAnalyticsBackend();
    final analytics = AnalyticsService(backend: events);
    await analytics.initialize();
    await analytics.applyConsent(AnalyticsConsent.granted);
    container = ProviderContainer(
      overrides: [
        purchasesServiceProvider.overrideWithValue(purchases),
        entitlementSyncProvider.overrideWithValue(sync),
        analyticsProvider.overrideWithValue(analytics),
        remoteConfigProvider.overrideWithValue(
          RemoteConfigService(backend: InMemoryRemoteConfigBackend()),
        ),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: Flavor.dev, platform: AppPlatform.ios),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<PaywallController> open(PaywallPlacement placement) async {
    final provider = paywallControllerProvider(placement);
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
    expect(container.read(provider), isA<PaywallReady>());
    return container.read(provider.notifier);
  }

  test('a successful purchase calls POST /v1/me/entitlements/sync', () async {
    final controller = await open(PaywallPlacement.adBreak);
    controller.select(RevenueCatIds.removeAdsPackage);
    final outcome = await controller.purchaseSelected();
    await pumpEventQueue();

    expect(outcome, isA<PurchaseSucceeded>());
    expect(purchases.entitlements.noAds, isTrue);
    expect(sync.calls, 1);
    expect(events.named(AnalyticsEvents.paywallView).single.params, {
      'placement': 'ad_break',
      'paywall_variant': 'a',
    });
    expect(events.named(AnalyticsEvents.purchaseStart).single.params, {
      'product_id': 'remove_ads',
      'placement': 'ad_break',
    });
    expect(events.named(AnalyticsEvents.purchaseResult).single.params, {
      'product_id': 'remove_ads',
      'result': 'success',
    });
  });

  test('premium defaults to the yearly plan with the trial', () async {
    final controller = await open(PaywallPlacement.lobbyRounds);
    final ready = container.read(
      paywallControllerProvider(PaywallPlacement.lobbyRounds),
    ) as PaywallReady;
    expect(ready.selected.productId, ProductIds.premiumYearly);
    await controller.purchaseSelected();
    await pumpEventQueue();
    expect(purchases.entitlements.premium, isTrue);
    expect(sync.calls, 1);
  });

  test('a cancelled purchase does not sync', () async {
    purchases.nextOutcome = const PurchaseCancelled();
    final controller = await open(PaywallPlacement.settings);
    await controller.purchaseSelected();
    await pumpEventQueue();
    expect(sync.calls, 0);
    expect(
      events.named(AnalyticsEvents.purchaseResult).single.params['result'],
      'cancel',
    );
  });

  test('a failing sync does not fail the purchase', () async {
    sync.failWith = StateError('offline');
    final controller = await open(PaywallPlacement.settings);
    final outcome = await controller.purchaseSelected();
    await pumpEventQueue();
    expect(outcome, isA<PurchaseSucceeded>());
    expect(sync.calls, 1);
  });
}
