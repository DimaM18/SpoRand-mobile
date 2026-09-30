// The boot `purchases` step skips Purchases.logIn when it has no session
// (or fails); purchases and restores must then log in first, so nothing is
// bought under an anonymous RevenueCat user (brief §4.7).
import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/security/session_repository.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_controller.dart';
import 'package:sporand/features/settings/presentation/settings_controller.dart';

import '../../support/app_harness.dart';
import '../../support/fake_services.dart';

void main() {
  late FakeServices s;
  late ProviderContainer container;

  setUp(() {
    s = FakeServices();
    container = ProviderContainer(overrides: fakeOverrides(s));
    addTearDown(container.dispose);
  });

  Future<PaywallController> paywall() async {
    final provider = paywallControllerProvider(PaywallPlacement.settings);
    container.listen(provider, (_, _) {});
    await pumpEventQueue();
    final controller = container.read(provider.notifier);
    controller.select(RevenueCatIds.removeAdsPackage);
    return controller;
  }

  Future<void> restoredSession(String userId) => s.sessions.save(
    AuthSession(
      userId: userId,
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: clock.now().add(const Duration(minutes: 10)),
    ),
  );

  test('ensurePurchasesUser configures, then logs in once per user', () async {
    final purchases = FakePurchasesService();
    Future<String> user() async => 'u-1';
    await ensurePurchasesUser(purchases, userId: user);
    await ensurePurchasesUser(purchases, userId: user);
    expect(purchases.calls, ['configure', 'logIn:u-1']);
    await ensurePurchasesUser(purchases, userId: () async => 'u-2');
    expect(purchases.calls.last, 'logIn:u-2');
  });

  test('a purchase after a degraded boot logs in as the stored user '
      'first', () async {
    await restoredSession('user-42');
    final controller = await paywall();
    final outcome = await controller.purchaseSelected();
    expect(outcome, isA<PurchaseSucceeded>());
    expect(s.purchases.calls, [
      'configure',
      'logIn:user-42',
      'purchase:remove_ads',
    ]);
  });

  test('already logged in: no second logIn', () async {
    await restoredSession('user-42');
    await s.purchases.logIn('user-42');
    final controller = await paywall();
    await controller.purchaseSelected();
    expect(s.purchases.calls.where((c) => c.startsWith('logIn')), [
      'logIn:user-42',
    ]);
    expect(s.purchases.calls.last, 'purchase:remove_ads');
  });

  test('a failed logIn buys nothing', () async {
    await restoredSession('user-42');
    s.purchases.logInFailWith = StateError('RevenueCat unavailable');
    final controller = await paywall();
    final outcome = await controller.purchaseSelected();
    expect(outcome, isA<PurchaseFailed>());
    expect(s.purchases.calls.where((c) => c.startsWith('purchase')), isEmpty);
  });

  test('restore logs in first', () async {
    await restoredSession('user-7');
    final outcome = await container
        .read(settingsControllerProvider.notifier)
        .restorePurchases();
    expect(outcome, RestoreOutcome.nothingFound);
    expect(s.purchases.calls, ['configure', 'logIn:user-7', 'restore']);
  });
}
