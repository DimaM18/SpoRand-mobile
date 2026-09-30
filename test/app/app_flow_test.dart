import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/features/home/presentation/home_page.dart';

import '../support/app_harness.dart';
import '../support/fake_services.dart';

void main() {
  testWidgets('first launch: splash -> age gate -> consent -> home', (
    tester,
  ) async {
    final services = FakeServices();
    await launch(tester, services);

    expect(find.text('Год рождения'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '1990');
    await tester.tap(find.text('Продолжить'));
    await tester.pumpAndSettle();

    expect(find.text('Твоя приватность'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Начать игру'));
    await tester.pumpAndSettle();

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.text('Чья это песня?'), findsOneWidget);
    expect(services.userPrefs.onboardingCompleted, isTrue);
    expect(services.ads.isInitialized, isTrue);

    // The onboarding choice reaches the server after the debounce, without
    // having held up the way home.
    expect(services.consentApi.sent, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    expect(services.consentApi.sent, hasLength(1));
    final sent = services.consentApi.sent.single;
    expect(sent.source, ConsentSource.onboarding);
    expect(sent.consentAnalytics, isTrue);
    // Outside the EEA (the fake UMP says not required) ads may personalize.
    expect(sent.consentAdsPersonalized, isTrue);
  });

  testWidgets('returning user: a link queued during boot opens after it', (
    tester,
  ) async {
    final services = FakeServices(
      prefs: {
        'age_band': '18_plus',
        'onboarding_completed': true,
        'analytics_consent': true,
      },
    );
    services.deepLinks.enqueue(
      UriLink(Uri.parse('https://$testLinkHost/j/7k2m9q')),
    );
    await launch(tester, services);

    expect(find.text('Комната 7K2M9Q'), findsOneWidget);
  });

  testWidgets('maintenance mode shows the maintenance screen', (tester) async {
    final services = FakeServices(remoteConfig: {'maintenance_mode': 'true'});
    await launch(tester, services);
    expect(find.text('Небольшой перерыв'), findsOneWidget);
  });

  testWidgets('home rejects malformed room codes', (tester) async {
    final services = FakeServices(
      prefs: {'age_band': '18_plus', 'onboarding_completed': true},
    );
    await launch(tester, services);
    await tester.enterText(find.byType(TextField), 'UUU');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Код состоит из 6 букв и цифр'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'hjk-234');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Комната HJK234'), findsOneWidget);
  });
}
