import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/domain/display_name.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import '../../support/fake_ws.dart';
import '../../support/protocol_samples.dart';

class _Lobby {
  _Lobby(this.async) {
    final analytics = AnalyticsService(backend: events);
    analytics.initialize();
    analytics.applyConsent(AnalyticsConsent.granted);
    final realtime = LazyRealtimeClient()
      ..configure(endpoint: Uri.parse('wss://api.example.test/v1/ws'));
    container = ProviderContainer(
      overrides: [
        appEnvProvider.overrideWithValue(
          const AppEnv(
            flavor: Flavor.dev,
            platform: AppPlatform.android,
            linkHosts: {'play.example.test'},
          ),
        ),
        roomsApiProvider.overrideWithValue(rooms),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(
          FakeInputClock(clock: async.getClock(DateTime(2026))),
        ),
        appInfoSourceProvider.overrideWithValue(
          const FakeAppInfoSource(
            AppInfo(
              version: '1.0.0',
              buildNumber: '1',
              platform: AppPlatform.android,
            ),
          ),
        ),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
        analyticsProvider.overrideWithValue(analytics),
        userPrefsProvider.overrideWithValue(UserPrefsRepository(prefs)),
        purchasesServiceProvider.overrideWithValue(FakePurchasesService()),
        remoteConfigProvider.overrideWithValue(
          RemoteConfigService(backend: InMemoryRemoteConfigBackend()),
        ),
        realtimeClientProvider.overrideWithValue(realtime),
        shareServiceProvider.overrideWithValue(share),
      ],
    );
    container.listen(lobbyControllerProvider, (_, _) {});
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final FakeRoomsApi rooms = FakeRoomsApi();
  final FakeWsServer server = FakeWsServer();
  final InMemoryAnalyticsBackend events = InMemoryAnalyticsBackend();
  final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
  final FakeShareService share = FakeShareService();
  late final ProviderContainer container;

  ActiveRoomController get active =>
      container.read(activeRoomProvider.notifier);
  LobbyController get lobby => container.read(lobbyControllerProvider.notifier);
  LobbyUiState get state => container.read(lobbyControllerProvider);
  LobbyView get view => (state as LobbyLoaded).view;

  RoomOpenResult? join({JoinVia via = JoinVia.code}) {
    RoomOpenResult? result;
    active
        .join(roomCode: '7KQ2MX', displayName: 'Bartek', via: via)
        .then((value) => result = value);
    async.flushMicrotasks();
    return result;
  }

  void send(ServerMessage message) {
    server.send(message);
    async.flushMicrotasks();
  }
}

void main() {
  test('join: REST, room_join analytics, WebSocket hello, lobby view', () {
    fakeAsync((async) {
      final t = _Lobby(async);
      final result = t.join(via: JoinVia.qr);
      expect(result, isA<RoomOpened>());
      expect(t.rooms.lastJoin?.displayName, 'Bartek');
      expect(t.events.named(AnalyticsEvents.roomJoin).single.params, {
        'result': 'ok',
        'via': 'qr',
      });
      expect(t.prefs.getString(PrefKeys.displayName), 'Bartek');
      expect(t.server.current.sentEnvelopes.single.type, WsClientMessage.hello);
      expect(t.state, isA<LobbyConnecting>());

      t.send(Samples.welcome());
      final view = t.view;
      expect(view.roomCode, '7KQ2MX');
      expect(view.joinLink.toString(), 'https://play.example.test/j/7KQ2MX');
      expect(
        view.qrLink.toString(),
        'https://play.example.test/j/7KQ2MX?via=qr',
      );
      expect(view.isHost, isFalse);
      expect(view.players.first.isHost, isTrue);
      expect(view.players.map((p) => p.name), contains('Bartek'));
      t.container.dispose();
    });
  });

  test('join failures map to room_join results', () {
    fakeAsync((async) {
      final t = _Lobby(async);
      t.rooms.failWith = const ApiError(code: 'room_full', status: 409);
      final result = t.join();
      expect((result! as RoomOpenFailed).error, RoomOpenError.full);
      t.rooms.failWith = const ApiError(code: ApiError.network);
      expect((t.join()! as RoomOpenFailed).error, RoomOpenError.network);
      expect(t.events.named(AnalyticsEvents.roomJoin).map((e) => e.params), [
        {'result': 'full', 'via': 'code'},
      ], reason: 'network errors are not a room_join result');
      expect(t.server.connections, isEmpty);
      t.container.dispose();
    });
  });

  test('create logs room_create with the canonical parameters', () {
    fakeAsync((async) {
      final t = _Lobby(async);
      t.active.create(mode: GameMode.guessTrack, displayName: 'Ania');
      async.flushMicrotasks();
      expect(t.events.named(AnalyticsEvents.roomCreate).single.params, {
        'mode': 'guess_track',
        'provider': 'test_catalog',
        'audio_mode': 'host_device',
        'rounds_total': 10,
        'host_tier': 'free',
      });
      expect(t.container.read(activeRoomProvider), isA<RoomActive>());
      t.container.dispose();
    });
  });

  test('host settings: premium rounds are locked for a free host', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome(me: Samples.hostId));
      final view = t.view;
      expect(view.isHost, isTrue);
      expect(
        {for (final c in view.roundChoices) c.rounds: c.locked},
        {5: false, 10: false, 15: true, 25: true, 50: true},
      );
      expect(t.lobby.setRounds(25), isFalse, reason: 'opens the paywall');
      expect(t.lobby.setRounds(5), isTrue);
      t.lobby.setMode(GameMode.whoseSong);
      t.lobby.startGame();
      t.lobby.kick(Samples.guestId);
      async.flushMicrotasks();
      final sent = t.server.current.sentMessages;
      final settings = sent.whereType<LobbyUpdateSettings>().toList();
      expect(settings.first.roundsTotal, 5);
      expect(settings.last.mode, GameMode.whoseSong);
      expect(settings.last.poolSources, [PoolSource.catalogPicks]);
      expect(sent.whereType<GameStart>(), hasLength(1));
      expect(sent.whereType<LobbyKick>().single.playerId, Samples.guestId);
      t.container.dispose();
    });
  });

  test('a premium host gets every rounds option', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(tier: HostTier.premium),
        ),
      );
      expect(t.view.roundChoices.every((c) => !c.locked), isTrue);
      t.container.dispose();
    });
  });

  test('start is blocked until enough players are present', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(players: [Samples.players().first]),
        ),
      );
      expect(t.view.startBlocker, isA<NeedMorePlayers>());
      expect(t.view.canStart, isFalse);
      t.lobby.startGame();
      async.flushMicrotasks();
      expect(t.server.current.sent<GameStart>(), isEmpty);
      t.send(RoomPlayerJoined(Samples.players()[1]));
      expect(t.view.canStart, isTrue);
      t.container.dispose();
    });
  });

  test('guests toggle ready; share and copy are logged', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome());
      t.lobby.toggleReady();
      t.lobby.share('join!');
      t.lobby.linkCopied();
      async.flushMicrotasks();
      expect(t.server.current.sent<LobbyReady>().single.ready, isFalse);
      expect(t.share.shared, ['join!']);
      expect(
        t.events
            .named(AnalyticsEvents.roomShare)
            .map((e) => e.params['channel']),
        unorderedEquals(['share_sheet', 'copy_link']),
      );
      t.container.dispose();
    });
  });

  test('reporting a player logs report_player', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome());
      t.lobby.report(Samples.thirdId, ReportReason.offensiveName);
      async.flushMicrotasks();
      expect(t.rooms.reports.single.reason, ReportReason.offensiveName);
      expect(t.events.named(AnalyticsEvents.reportPlayer).single.params, {
        'reason': 'offensive_name',
      });
      t.container.dispose();
    });
  });

  test('a 4403 close ends the room as kicked', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome());
      t.server.current.serverClose(WsCloseCode.forbidden);
      async.flushMicrotasks();
      expect(
        (t.container.read(activeRoomProvider) as RoomEnded).reason,
        RoomEndReason.kicked,
      );
      expect(t.state, isA<LobbyNoRoom>());
      t.container.dispose();
    });
  });

  test('room.closed ends the room', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome());
      t.send(const RoomClosed(RoomClosedReason.hostLeft));
      expect(
        (t.container.read(activeRoomProvider) as RoomEnded).reason,
        RoomEndReason.closed,
      );
      t.container.dispose();
    });
  });

  group('DisplayName', () {
    test('strips invisible characters and checks the length', () {
      expect(DisplayName.validate('  Ania\u200B '), 'Ania');
      expect(DisplayName.validate('A'), isNull);
      expect(DisplayName.validate('x' * 21), isNull);
      expect(DisplayName.validate('\u202EAnia\u202C'), 'Ania');
    });
  });

  group('deep links carry room_join.via', () {
    const parser = DeepLinkParser(allowedHosts: {'play.example.test'});

    test('a QR link is via=qr, a plain link via=link', () {
      final qr =
          parser.parseUri(
                Uri.parse('https://play.example.test/j/7kq2mx?via=qr'),
              )!
              as JoinRoomLink;
      expect(qr.roomCode, '7KQ2MX');
      expect(qr.via, JoinVia.qr);
      expect(qr.location, '/j/7KQ2MX?via=qr');
      final plain =
          parser.parseUri(Uri.parse('https://play.example.test/j/7KQ2MX'))!
              as JoinRoomLink;
      expect(plain.via, JoinVia.link);
      expect(plain.location, '/j/7KQ2MX');
    });
  });
}
