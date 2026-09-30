import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/home/presentation/create_room_sheet.dart';
import 'package:sporand/features/home/presentation/home_page.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

import '../support/app_harness.dart';
import '../support/fake_services.dart';
import '../support/fake_ws.dart';
import '../support/protocol_samples.dart';

/// Every screen through the real router at the design system's check sizes
/// (§7): a small phone, the same with text scale 2.0, and landscape. Any
/// overflow fails the test, so this guards the "no clipping" rule.
const _screens = [
  ('360x640', Size(360, 640), 1.0),
  ('360x640 at text scale 2.0', Size(360, 640), 2.0),
  ('844x390 landscape', Size(844, 390), 1.0),
];

void _useScreen(WidgetTester tester, Size size, double textScale) {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Scrolls the first scrollable until [finder] is built and on screen.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      120,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _reveal(tester, finder);
  await tester.tap(finder);
}

/// Scrolls the screen's main list to its end, so every row is laid out
/// (an overflow anywhere fails the test).
Future<void> _scrollThrough(WidgetTester tester) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < 12; i++) {
    await tester.drag(list, const Offset(0, -300));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final (label, size, textScale) in _screens) {
    testWidgets('onboarding lays out at $label', (tester) async {
      _useScreen(tester, size, textScale);
      final services = FakeServices();
      await launch(tester, services);
      expect(find.text('Год рождения'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '1990');
      await _tap(tester, find.text('Продолжить'));
      await tester.pumpAndSettle();
      expect(find.text('Твоя приватность'), findsOneWidget);
      await _tap(tester, find.byType(Switch));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Начать игру'));
      await tester.pumpAndSettle();
      expect(services.userPrefs.onboardingCompleted, isTrue);
      // Let the consent sync debounce run out.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('the maintenance screen lays out at $label', (tester) async {
      _useScreen(tester, size, textScale);
      await launch(
        tester,
        FakeServices(remoteConfig: {'maintenance_mode': 'true'}),
      );
      expect(find.text('Небольшой перерыв'), findsOneWidget);
    });

    testWidgets('home, create room, join, settings, «Мои песни» and the '
        'paywall lay out at $label', (tester) async {
      _useScreen(tester, size, textScale);
      final container = await launch(
        tester,
        FakeServices(
          prefs: {'age_band': '18_plus', 'onboarding_completed': true},
        ),
        extra: [
          mySongsApiProvider.overrideWithValue(
            FakeMySongsApi(
              picks: [
                for (final (i, song)
                    in FakeMySongsApi.sampleSongs.take(3).indexed)
                  SongPick(position: i + 1, song: song),
              ],
            ),
          ),
        ],
      );
      expect(find.text('Чья это песня?'), findsOneWidget);
      expect(
        MediaQuery.textScalerOf(tester.element(find.byType(HomePage)))
            .scale(10),
        10 * textScale,
        reason: 'the platform text scale reaches the screens',
      );
      await _reveal(tester, find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'UUU');
      await _tap(tester, find.text('Войти'));
      await tester.pumpAndSettle();
      expect(find.text('Код состоит из 6 букв и цифр'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      await _tap(tester, find.text('Создать комнату'));
      await tester.pumpAndSettle();
      expect(find.text('Новая комната'), findsOneWidget);
      Navigator.of(tester.element(find.byType(CreateRoomSheet))).pop();
      await tester.pumpAndSettle();

      final router = container.read(routerProvider);
      for (final (location, title) in [
        (Routes.join('7KQ2MX'), 'Комната 7KQ2MX'),
        (Routes.settings, 'Настройки'),
        (Routes.mySongs, 'Выбрано 3 из 10'),
        (Routes.paywallFor('settings'), 'Играй без границ'),
      ]) {
        unawaited(router.push(location));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await _reveal(tester, find.text(title));
        expect(find.text(title), findsOneWidget, reason: location);
        await _scrollThrough(tester);
        router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('lobby, countdown, round, reveal, bonus, ad break and results '
        'lay out at $label', (tester) async {
      _useScreen(tester, size, textScale);
      final server = FakeWsServer();
      final clock = FakeInputClock(clock: tester.binding.clock);
      final container = await launch(
        tester,
        FakeServices(
          prefs: {
            'age_band': '18_plus',
            'onboarding_completed': true,
            'analytics_consent': true,
          },
        ),
        extra: [
          roomsApiProvider.overrideWithValue(FakeRoomsApi()),
          wsConnectorProvider.overrideWithValue(server.connect),
          inputClockProvider.overrideWithValue(clock),
          appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
          playbackAdapterFactoryProvider.overrideWithValue(
            (_) => FakePlaybackAdapter(),
          ),
          shareServiceProvider.overrideWithValue(FakeShareService()),
        ],
      );

      await _tap(tester, find.text('Создать комнату'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Твоё имя в игре'),
        'Ania',
      );
      await _tap(
        tester,
        find.widgetWithText(FilledButton, 'Создать комнату').last,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Подключаемся к комнате…'), findsOneWidget);

      server.send(Samples.welcome(me: Samples.hostId, room: Samples.room()));
      await tester.pumpAndSettle();
      expect(find.text('Начать игру'), findsOneWidget);
      await _scrollThrough(tester);

      server.send(
        const GameStarting(
          gameId: Samples.gameId,
          roundsTotal: 3,
          countdownMs: 3000,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Приготовься!'), findsOneWidget);

      server.send(
        Samples.prepare(
          startAtMonoUs: clock.nowUs + 200000,
          clip: Samples.urlClip,
          options: const [
            ...Samples.options,
            RoundOption(optionId: 'opt-d', label: 'Dominik'),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump();
      expect(
        container
            .read(gameControllerProvider.notifier)
            .tap(
              roundId: 'round-1',
              optionId: 'opt-a',
              tapMonoUs: clock.monoNowUs,
            ),
        isTrue,
      );
      await tester.pumpAndSettle();

      server.send(
        Samples.reveal(
          results: const [
            RoundResult(
              playerId: Samples.hostId,
              optionId: 'opt-a',
              correct: false,
              reactionMs: 900,
              points: 0,
              streak: 0,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Таблица'));
      await _scrollThrough(tester);

      server.send(
        const GameBonusOffer(
          bonusId: 'bonus-1',
          expiresAtServerMs: 1759212360000,
          eligiblePlayerIds: [Samples.hostId],
        ),
      );
      await tester.pumpAndSettle();
      server.send(
        const BonusCancelled(
          bonusId: 'bonus-1',
          reason: BonusCancelReason.ssvTimeout,
        ),
      );
      await tester.pumpAndSettle();

      server.send(
        const GameAdBreak(
          gameId: Samples.gameId,
          resultsRevealAtServerMs: 1,
          showInterstitial: false,
          showRemoveAdsUpsell: true,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Считаем очки…'), findsOneWidget);

      server.send(Samples.results());
      await tester.pumpAndSettle();
      expect(find.text('Итоги'), findsOneWidget);
      await _scrollThrough(tester);

      unawaited(container.read(activeRoomProvider.notifier).leave());
      await tester.pump();
      await tester.pumpAndSettle();
    });
  }
}
