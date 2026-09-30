import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

import '../support/app_harness.dart';
import '../support/fake_services.dart';
import '../support/fake_ws.dart';
import '../support/protocol_samples.dart';

/// Home -> create room -> lobby -> a round -> reveal -> ad break -> results
/// -> play again, through the real router and screens, against an
/// in-memory server.
void main() {
  testWidgets('a host plays a whole game against a stub server', (
    tester,
  ) async {
    // A tall phone, so the lobby's player list is laid out.
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final services = FakeServices(
      prefs: {
        'age_band': '18_plus',
        'onboarding_completed': true,
        'analytics_consent': true,
      },
      // guess_track is hidden unless modes_enabled lists it (wave 4).
      cachedConfig: {
        'modes_enabled': '["emoji_quiz","guess_track","whose_song"]',
      },
    );
    final server = FakeWsServer();
    final rooms = FakeRoomsApi();
    final playback = FakePlaybackAdapter();
    final clock = FakeInputClock(clock: tester.binding.clock);
    final container = await launch(
      tester,
      services,
      extra: [
        roomsApiProvider.overrideWithValue(rooms),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(clock),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
        playbackAdapterFactoryProvider.overrideWithValue((_) => playback),
        shareServiceProvider.overrideWithValue(FakeShareService()),
      ],
    );

    // Home -> create room sheet.
    await tester.tap(find.text('Создать комнату'));
    await tester.pumpAndSettle();
    expect(find.text('Новая комната'), findsOneWidget);
    await tester.tap(find.text('Угадай трек'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Твоё имя в игре'),
      'Ania',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать комнату').last);
    // The "connecting" spinner never settles; pump through the transition.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Lobby: connecting until welcome.
    expect(rooms.roomsCreated, 1);
    expect(find.text('Подключаемся к комнате…'), findsOneWidget);
    expect(server.current.sentMessages.single, isA<Hello>());
    server.send(Samples.welcome(me: Samples.hostId, room: Samples.room()));
    await tester.pumpAndSettle();
    expect(find.text('7KQ2MX'), findsWidgets);
    expect(find.text('Bartek'), findsOneWidget);
    await tester.tap(find.text('Начать игру'));
    await tester.pump();
    expect(server.current.sent<GameStart>(), hasLength(1));

    // The server starts the game: the app moves to the round screen.
    server.send(
      const GameStarting(
        gameId: Samples.gameId,
        roundsTotal: 1,
        countdownMs: 3000,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Приготовься!'), findsOneWidget);

    final startAt = clock.nowUs + 200000;
    server.send(Samples.prepare(startAtMonoUs: startAt, clip: Samples.urlClip));
    await tester.pumpAndSettle();
    expect(find.text('Раунд 1 из 1'), findsOneWidget);
    expect(playback.playedAt, [startAt], reason: 'the host plays the clip');
    expect(server.current.sent<RoundPlaybackStarted>(), hasLength(1));

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();
    final tapUs = clock.nowUs - 8000;
    final finger = TestPointer(1);
    await tester.sendEventToBinding(
      finger.down(
        tester.getCenter(find.text('Celina')),
        timeStamp: Duration(microseconds: tapUs),
      ),
    );
    await tester.sendEventToBinding(finger.up());
    await tester.pumpAndSettle();
    final answer = server.current.sent<RoundAnswer>().single;
    expect(answer.optionId, 'opt-c');
    expect(answer.tapMonoUs, tapUs);

    server.send(Samples.reveal());
    await tester.pumpAndSettle();
    expect(find.text('Таблица'), findsOneWidget);
    expect(find.text('Это трек: Celina'), findsOneWidget);

    // End of game: no interstitial for this player, upsell on the counter.
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
    expect(find.text(r'Играть без рекламы — $3.99'), findsOneWidget);

    server.send(Samples.results());
    await tester.pumpAndSettle();
    expect(find.text('Итоги'), findsOneWidget);
    await tester.tap(find.text('Сыграть ещё'));
    await tester.pump();
    expect(server.current.sent<GamePlayAgain>(), hasLength(1));

    // Same room, back to the lobby.
    server.send(RoomStateMessage(Samples.room()));
    await tester.pumpAndSettle();
    expect(find.text('Начать игру'), findsOneWidget);

    // Not awaited directly: in a widget test only pumps run its microtasks.
    unawaited(container.read(activeRoomProvider.notifier).leave());
    await tester.pump();
    await tester.pumpAndSettle();
    expect(server.current.sent<RoomLeave>(), hasLength(1));
  });

  testWidgets('a guest who is kicked returns home with a message', (
    tester,
  ) async {
    final services = FakeServices(
      prefs: {'age_band': '18_plus', 'onboarding_completed': true},
    );
    final server = FakeWsServer();
    await launch(
      tester,
      services,
      extra: [
        roomsApiProvider.overrideWithValue(FakeRoomsApi()),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(
          FakeInputClock(clock: tester.binding.clock),
        ),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
      ],
    );
    await tester.enterText(find.byType(TextField), '7kq2mx');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    expect(find.text('Комната 7KQ2MX'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Bartek');
    await tester.tap(find.text('Войти в комнату'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    server.send(Samples.welcome());
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'На старте'), findsOneWidget);

    server.current.serverClose(4403);
    await tester.pumpAndSettle();
    expect(find.text('Ведущий удалил тебя из комнаты'), findsOneWidget);
    expect(find.text('Чья это песня?'), findsOneWidget);
    // Let the snackbar time out so no timer is left behind.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('a guest adds «Мои песни» to a BYOP room after the consent '
      '«Эти песни будут показаны комнате как твои»', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final services = FakeServices(
      prefs: {'age_band': '18_plus', 'onboarding_completed': true},
    );
    final server = FakeWsServer();
    final rooms = FakeRoomsApi();
    final mySongs = FakeMySongsApi(
      picks: [
        for (final (i, song) in FakeMySongsApi.sampleSongs.take(5).indexed)
          SongPick(position: i + 1, song: song),
      ],
    );
    final container = await launch(
      tester,
      services,
      extra: [
        roomsApiProvider.overrideWithValue(rooms),
        mySongsApiProvider.overrideWithValue(mySongs),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(
          FakeInputClock(clock: tester.binding.clock),
        ),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
      ],
    );
    await tester.enterText(find.byType(TextField), '7kq2mx');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bartek');
    await tester.tap(find.text('Войти в комнату'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    server.send(
      Samples.welcome(room: Samples.byopRoom(state: RoomState.lobby)),
    );
    await tester.pumpAndSettle();
    expect(find.text('5 песен'), findsWidgets, reason: 'pool_track_count');

    await tester.tap(find.byKey(const ValueKey('lobby-add-my-songs')));
    await tester.pumpAndSettle();
    expect(find.text('Что увидят друзья'), findsOneWidget);
    expect(
      find.text('Эти песни будут показаны комнате как твои'),
      findsOneWidget,
    );
    expect(find.text('Northern Lights — Test Artist'), findsOneWidget);
    expect(rooms.pools, isEmpty, reason: 'nothing is sent before consent');

    await tester.tap(find.byKey(const ValueKey('pool-consent-confirm')));
    await tester.pumpAndSettle();
    final pool = rooms.pools.single.pool;
    expect(pool.tracks.whereType<SongPoolTrack>(), hasLength(5));
    expect(find.text('Твои песни в игре'), findsOneWidget);
    // Let the snackbar time out and leave, so no timer is left behind.
    await tester.pump(const Duration(seconds: 5));
    unawaited(container.read(activeRoomProvider.notifier).leave());
    await tester.pump();
    await tester.pumpAndSettle();
  });

  testWidgets('a host creates an emoji quiz and picks markets and '
      'difficulty; no pools, no DJ', (tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final services = FakeServices(
      prefs: {'age_band': '18_plus', 'onboarding_completed': true},
    );
    final server = FakeWsServer();
    final rooms = FakeRoomsApi();
    final container = await launch(
      tester,
      services,
      extra: [
        roomsApiProvider.overrideWithValue(rooms),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(
          FakeInputClock(clock: tester.binding.clock),
        ),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
      ],
    );

    await tester.tap(find.text('Создать комнату'));
    await tester.pumpAndSettle();
    expect(
      find.text('Угадай песню по эмодзи — музыка не нужна'),
      findsOneWidget,
    );
    // modes_enabled (default): whose_song and the emoji quiz, which the UI
    // calls «Угадай песню» since wave 4; the audio guess_track is hidden.
    expect(find.byKey(const ValueKey('create-mode-whose_song')), findsOne);
    expect(find.byKey(const ValueKey('create-mode-guess_track')), findsNothing);
    expect(find.text('Угадай трек'), findsNothing);
    await tester.tap(find.text('Угадай песню'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Твоё имя в игре'),
      'Ania',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Создать комнату').last);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(rooms.lastCreatedMode, GameMode.emojiQuiz);

    server.send(
      Samples.welcome(
        me: Samples.hostId,
        room: Samples.room(mode: GameMode.emojiQuiz),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Без музыки: хватит телефонов'), findsOneWidget);
    expect(find.text('Международные'), findsOneWidget);
    expect(find.text('Польские'), findsOneWidget);
    expect(find.byKey(const ValueKey('lobby-add-my-songs')), findsNothing);
    expect(find.byKey(const ValueKey('lobby-can-dj')), findsNothing);

    await tester.tap(find.text('Международные'));
    await tester.pump();
    await tester.tap(find.text('Лёгкие'));
    await tester.pump();
    final sent = server.current.sent<LobbyUpdateSettings>();
    expect(sent.first.mode, GameMode.emojiQuiz);
    expect(sent.first.emojiMarkets, [EmojiMarket.pl]);
    expect(sent.last.emojiMaxDifficulty, 1);

    unawaited(container.read(activeRoomProvider.notifier).leave());
    await tester.pump();
    await tester.pumpAndSettle();
  });

  testWidgets('a BYOP guest opts in to the DJ role and gets the DJ badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final services = FakeServices(
      prefs: {'age_band': '18_plus', 'onboarding_completed': true},
    );
    final server = FakeWsServer();
    final container = await launch(
      tester,
      services,
      extra: [
        roomsApiProvider.overrideWithValue(FakeRoomsApi()),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(
          FakeInputClock(clock: tester.binding.clock),
        ),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
      ],
    );
    await tester.enterText(find.byType(TextField), '7kq2mx');
    await tester.tap(find.text('Войти'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bartek');
    await tester.tap(find.text('Войти в комнату'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    server.send(
      Samples.welcome(room: Samples.byopRoom(state: RoomState.lobby)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Могу включать музыку'), findsOneWidget);
    expect(
      find.textContaining('Ведущий · DJ'),
      findsOneWidget,
      reason: 'the host',
    );
    await tester.tap(find.text('Могу включать музыку'));
    await tester.pump();
    expect(server.current.sent<LobbySetCanDj>().single.canDj, isTrue);

    server.send(
      RoomPlayerUpdated(Samples.player(Samples.guestId, 'Bartek', canDj: true)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Ты · DJ'), findsOneWidget);
    final toggle = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('lobby-can-dj')),
    );
    expect(toggle.value, isTrue);

    unawaited(container.read(activeRoomProvider.notifier).leave());
    await tester.pump();
    await tester.pumpAndSettle();
  });
}
