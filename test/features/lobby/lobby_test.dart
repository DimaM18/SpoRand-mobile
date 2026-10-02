import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/auth/age_band_sync.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/net/realtime_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/domain/display_name.dart';
import 'package:sporand/features/lobby/domain/game_modes.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

import '../../support/fake_ws.dart';
import '../../support/protocol_samples.dart';

class _Tokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'access-1';

  @override
  Future<String?> refreshAfterUnauthorized(String rejectedToken) async => null;
}

class _Lobby {
  _Lobby(this.async, {List<Override> extra = const []}) {
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
        mySongsApiProvider.overrideWith((ref) => mySongs),
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
        ...extra,
      ],
    );
    container.listen(lobbyControllerProvider, (_, _) {});
    async.flushMicrotasks();
  }

  final FakeAsync async;
  final FakeRoomsApi rooms = FakeRoomsApi();
  FakeMySongsApi mySongs = FakeMySongsApi();
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

  group('create and join first tell the server the age gate band', () {
    // Found by test_e2e: the app never sent it, so the server knew no one's
    // age, forced the explicit filter for everyone and never offered the
    // rewarded bonus or an interstitial.
    ({_Lobby lobby, List<String> log}) harness(FakeAsync async) {
      final log = <String>[];
      late final _Lobby t;
      t = _Lobby(
        async,
        extra: [
          ageBandSyncProvider.overrideWith(
            (ref) => AgeBandSync(
              client: ApiClient(
                baseUrl: Uri.parse('https://api.example.test'),
                tokens: _Tokens(),
                httpClient: MockClient((request) async {
                  log.add(
                    '${request.method} ${request.url.path} ${request.body} '
                    '(rooms created: ${t.rooms.roomsCreated}, '
                    'joined: ${t.rooms.lastJoin != null})',
                  );
                  return http.Response('{}', 200);
                }),
              ),
              prefs: ref.watch(userPrefsProvider),
              currentUserId: () async => 'user-1',
            ),
          ),
        ],
      );
      t.prefs.values[PrefKeys.ageBand] = AgeBand.age16to17.wireName;
      return (lobby: t, log: log);
    }

    test('PATCH /v1/me before POST /v1/rooms', () {
      fakeAsync((async) {
        final (:lobby, :log) = harness(async);
        lobby.active.create(mode: GameMode.whoseSong, displayName: 'Ania');
        async.flushMicrotasks();
        expect(lobby.container.read(activeRoomProvider), isA<RoomActive>());
        expect(log, [
          'PATCH /v1/me {"age_band":"16_17"} (rooms created: 0, joined: false)',
        ]);
        lobby.container.dispose();
      });
    });

    test('PATCH /v1/me before POST /v1/rooms/join', () {
      fakeAsync((async) {
        final (:lobby, :log) = harness(async);
        expect(lobby.join(), isA<RoomOpened>());
        expect(log, [
          'PATCH /v1/me {"age_band":"16_17"} (rooms created: 0, joined: false)',
        ]);
        lobby.container.dispose();
      });
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

  List<CatalogPick> songPicks(int count) => [
    for (final (i, song) in FakeMySongsApi.sampleSongs.take(count).indexed)
      SongPick(position: i + 1, song: song),
  ];

  PoolDraft? prepare(_Lobby t) {
    PoolDraft? draft;
    t.lobby.preparePool().then((value) => draft = value);
    t.async.flushMicrotasks();
    return draft;
  }

  test('my songs into a BYOP room: consent draft, then PUT pool with song '
      'ids in order', () {
    fakeAsync((async) {
      final t = _Lobby(async)..mySongs = FakeMySongsApi(picks: songPicks(6));
      t.join();
      t.send(
        Samples.welcome(
          room: Samples.byopRoom(state: RoomState.lobby),
          config: const {'pool_min_tracks_per_contributor': 5},
        ),
      );
      expect(t.view.collectsPools, isTrue);

      final draft = prepare(t)! as PoolReady;
      expect(draft.picks.map((p) => p.title), [
        for (final song in FakeMySongsApi.sampleSongs.take(6)) song.title,
      ]);
      bool? sent;
      t.lobby.submitPool(draft).then((value) => sent = value);
      async.flushMicrotasks();
      expect(sent, isTrue);
      final pool = t.rooms.pools.single;
      expect(pool.roomId, 'room-joined');
      expect(pool.pool.poolSource, PoolSource.catalogPicks);
      expect(pool.pool.toJson()['tracks'], [
        for (final (i, song) in FakeMySongsApi.sampleSongs.take(6).indexed)
          {'song_id': song.songId, 'rank': i + 1},
      ]);

      // The server then reports the new count.
      t.send(
        RoomPlayerUpdated(
          Samples.player(Samples.guestId, 'Bartek', poolTrackCount: 6),
        ),
      );
      expect(t.view.myPoolTrackCount, 6);
      t.container.dispose();
    });
  });

  test('too few usable picks asks for «Мои песни» first', () {
    fakeAsync((async) {
      final t = _Lobby(async)..mySongs = FakeMySongsApi(picks: songPicks(3));
      t.join();
      t.send(Samples.welcome(room: Samples.byopRoom(state: RoomState.lobby)));
      expect((prepare(t)! as PoolNeedsPicks).minimum, 5);

      // Song picks cannot feed a legacy catalogue room.
      t.mySongs = FakeMySongsApi(picks: songPicks(6));
      t.container.invalidate(mySongsApiProvider);
      t.send(RoomStateMessage(Samples.room()));
      expect(prepare(t), isA<PoolNeedsPicks>());
      expect(t.rooms.pools, isEmpty);
      t.container.dispose();
    });
  });

  test('start needs enough pools: whose_song contributors and pool sizes', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(
            mode: GameMode.whoseSong,
            players: [
              Samples.player(
                Samples.hostId,
                'Ania',
                role: PlayerRole.host,
                playbackDevice: true,
              ),
              Samples.player(Samples.guestId, 'Bartek'),
              Samples.player(Samples.thirdId, 'Celina', poolTrackCount: 2),
            ],
          ),
        ),
      );
      final blocker = t.view.startBlocker! as PoolTooSmall;
      expect(blocker.name, 'Celina');
      expect(blocker.minimum, 5);
      expect(t.view.contributorsNeeded, 1);
      expect(t.view.canStart, isFalse);

      t.send(
        RoomPlayerUpdated(
          Samples.player(Samples.thirdId, 'Celina', poolTrackCount: 5),
        ),
      );
      expect(t.view.startBlocker, isNull);
      expect(t.view.canStart, isTrue);
      t.container.dispose();
    });
  });

  test('guess_track from player pools needs at least one pool', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(
            players: [
              Samples.player(
                Samples.hostId,
                'Ania',
                role: PlayerRole.host,
                playbackDevice: true,
                contributor: false,
              ),
              Samples.player(Samples.guestId, 'Bartek', contributor: false),
            ],
          ),
        ),
      );
      expect(t.view.startBlocker, isA<NeedAnyPool>());
      t.send(RoomPlayerUpdated(Samples.player(Samples.guestId, 'Bartek')));
      expect(t.view.canStart, isTrue);
      t.container.dispose();
    });
  });

  test('the host of a BYOP room is told they are the DJ', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.byopRoom(state: RoomState.lobby),
        ),
      );
      expect(t.view.isDjHost, isTrue);
      t.send(RoomStateMessage(Samples.room()));
      expect(t.view.isDjHost, isFalse);
      t.container.dispose();
    });
  });

  test('BYOP: «Могу включать музыку» sends lobby.set_can_dj; the echo moves '
      'the toggle and the DJ badge', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome(room: Samples.byopRoom(state: RoomState.lobby)));
      var view = t.view;
      expect(view.showsDj, isTrue);
      expect(view.meCanDj, isFalse, reason: 'guests default to false');
      expect(
        {for (final p in view.players) p.playerId: p.canDj},
        {Samples.hostId: true, Samples.guestId: false, Samples.thirdId: false},
      );

      t.lobby.setCanDj(true);
      async.flushMicrotasks();
      expect(t.server.current.sent<LobbySetCanDj>().single.canDj, isTrue);
      expect(t.view.meCanDj, isFalse, reason: 'the server decides');

      t.send(
        RoomPlayerUpdated(
          Samples.player(Samples.guestId, 'Bartek', canDj: true),
        ),
      );
      view = t.view;
      expect(view.meCanDj, isTrue);
      expect(view.players.singleWhere((p) => p.isMe).canDj, isTrue);
      t.container.dispose();
    });
  });

  test('with byop_dj_rotation the host is not always the DJ', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.byopRoom(state: RoomState.lobby),
          config: const {'byop_dj_rotation': true},
        ),
      );
      expect(t.view.isDjHost, isFalse);
      expect(t.view.showsDj, isTrue);
      t.container.dispose();
    });
  });

  test('emoji_quiz: 2 players and no pools; markets and difficulty go out '
      'with the settings; the last market cannot be turned off', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(
            mode: GameMode.emojiQuiz,
            players: [
              Samples.player(
                Samples.hostId,
                'Ania',
                role: PlayerRole.host,
                playbackDevice: true,
                contributor: false,
              ),
            ],
            emojiMarkets: const [EmojiMarket.pl, EmojiMarket.intl],
            emojiMaxDifficulty: 2,
          ),
        ),
      );
      var view = t.view;
      expect(view.isEmojiQuiz, isTrue);
      expect(view.collectsPools, isFalse);
      expect(view.showsDj, isFalse);
      expect(view.emojiMarkets, [EmojiMarket.pl, EmojiMarket.intl]);
      expect(view.emojiMaxDifficulty, 2);
      expect(view.startBlocker, isA<NeedMorePlayers>());
      t.send(
        RoomPlayerJoined(
          Samples.player(Samples.guestId, 'Bartek', contributor: false),
        ),
      );
      view = t.view;
      expect(view.startBlocker, isNull, reason: 'no pools needed');

      t.lobby.toggleEmojiMarket(EmojiMarket.pl);
      t.lobby.setEmojiMaxDifficulty(1);
      t.lobby.setEmojiMaxDifficulty(7);
      async.flushMicrotasks();
      final sent = t.server.current.sent<LobbyUpdateSettings>();
      expect(sent, hasLength(2), reason: 'difficulty 7 is not sent');
      expect(sent.first.mode, GameMode.emojiQuiz);
      expect(sent.first.emojiMarkets, [EmojiMarket.intl]);
      expect(sent.first.emojiMaxDifficulty, 2);
      expect(sent.last.emojiMarkets, [EmojiMarket.pl, EmojiMarket.intl]);
      expect(sent.last.emojiMaxDifficulty, 1);
      for (final settings in sent) {
        // What the server would parse (strict, like packages/protocol).
        expect(
          LobbyUpdateSettings.fromJson(settings.toJson()).toJson(),
          settings.toJson(),
        );
      }

      t.send(
        RoomStateMessage(
          Samples.room(
            mode: GameMode.emojiQuiz,
            emojiMarkets: const [EmojiMarket.intl],
          ),
        ),
      );
      t.lobby.toggleEmojiMarket(EmojiMarket.intl);
      async.flushMicrotasks();
      expect(
        t.server.current.sent<LobbyUpdateSettings>(),
        hasLength(2),
        reason: 'at least one market stays on',
      );
      t.container.dispose();
    });
  });

  test('wave 9: «СНГ» is an opt-in market, «Ретро» is off by default and '
      'labelled with the room\'s emoji_min_year', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(
        Samples.welcome(
          me: Samples.hostId,
          room: Samples.room(mode: GameMode.emojiQuiz),
          config: const {'emoji_min_year': 1985},
        ),
      );
      var view = t.view;
      // No markets from the server: the locale defaults, never cis.
      expect(view.emojiMarkets, [EmojiMarket.intl, EmojiMarket.pl]);
      expect(view.emojiRetro, isFalse);
      expect(view.emojiMinYear, 1985);

      t.lobby.toggleEmojiMarket(EmojiMarket.cis);
      t.lobby.setEmojiRetro(true);
      async.flushMicrotasks();
      final sent = t.server.current.sent<LobbyUpdateSettings>();
      expect(sent, hasLength(2));
      expect(sent.first.emojiMarkets, [
        EmojiMarket.intl,
        EmojiMarket.pl,
        EmojiMarket.cis,
      ]);
      expect(sent.last.emojiRetro, isTrue);
      expect(sent.last.toJson()['emoji_retro'], isTrue);
      for (final settings in sent) {
        expect(
          LobbyUpdateSettings.fromJson(settings.toJson()).toJson(),
          settings.toJson(),
        );
      }

      t.send(
        RoomStateMessage(
          Samples.room(
            mode: GameMode.emojiQuiz,
            emojiMarkets: const [EmojiMarket.cis],
            emojiRetro: true,
          ),
        ),
      );
      view = t.view;
      expect(view.emojiMarkets, [EmojiMarket.cis]);
      expect(view.emojiRetro, isTrue);
      // Leaving emoji_quiz drops «Ретро» like the other emoji fields.
      t.lobby.setMode(GameMode.whoseSong);
      async.flushMicrotasks();
      final back = t.server.current.sent<LobbyUpdateSettings>().last;
      expect(back.toJson().containsKey('emoji_retro'), isFalse);
      t.container.dispose();
    });
  });

  test('switching to emoji_quiz sends the mode; switching away drops the '
      'emoji fields', () {
    fakeAsync((async) {
      final t = _Lobby(async)..join();
      t.send(Samples.welcome(me: Samples.hostId));
      t.lobby.setMode(GameMode.emojiQuiz);
      async.flushMicrotasks();
      final toEmoji = t.server.current.sent<LobbyUpdateSettings>().single;
      expect(toEmoji.mode, GameMode.emojiQuiz);
      expect(toEmoji.emojiMarkets, isNull, reason: 'server locale default');

      t.send(
        RoomStateMessage(
          Samples.room(
            mode: GameMode.emojiQuiz,
            emojiMarkets: const [EmojiMarket.pl],
            emojiMaxDifficulty: 1,
          ),
        ),
      );
      t.lobby.setMode(GameMode.whoseSong);
      async.flushMicrotasks();
      final back = t.server.current.sent<LobbyUpdateSettings>().last;
      expect(back.mode, GameMode.whoseSong);
      expect(back.toJson().containsKey('emoji_markets'), isFalse);
      expect(back.toJson().containsKey('emoji_max_difficulty'), isFalse);
      t.container.dispose();
    });
  });

  group('modes_enabled (wave 4)', () {
    LobbyView view(_Lobby t) => (t.lobby.state as LobbyLoaded).view;

    test('the picker offers only enabled modes; guess_track is hidden by '
        'default and cannot be chosen', () {
      fakeAsync((async) {
        final t = _Lobby(async)..join();
        t.send(
          Samples.welcome(
            me: Samples.hostId,
            room: Samples.room(mode: GameMode.whoseSong),
          ),
        );
        expect(view(t).modeChoices, [GameMode.whoseSong, GameMode.emojiQuiz]);
        t.lobby.setMode(GameMode.guessTrack);
        async.flushMicrotasks();
        expect(t.server.current.sent<LobbyUpdateSettings>(), isEmpty);
        t.container.dispose();
      });
    });

    test("the room's frozen config wins; the current mode always shows", () {
      fakeAsync((async) {
        final t = _Lobby(async)..join();
        t.send(
          Samples.welcome(
            me: Samples.hostId,
            room: Samples.room(mode: GameMode.guessTrack),
            config: const {
              'modes_enabled': ['emoji_quiz'],
            },
          ),
        );
        expect(view(t).modeChoices, [GameMode.guessTrack, GameMode.emojiQuiz]);
        t.send(
          Samples.welcome(
            me: Samples.hostId,
            room: Samples.room(mode: GameMode.emojiQuiz),
            config: const {
              'modes_enabled': ['guess_track', 'whose_song', 'emoji_quiz'],
            },
          ),
        );
        expect(view(t).modeChoices, GameMode.values);
        t.lobby.setMode(GameMode.guessTrack);
        async.flushMicrotasks();
        expect(
          t.server.current.sent<LobbyUpdateSettings>().single.mode,
          GameMode.guessTrack,
        );
        t.container.dispose();
      });
    });

    test('selectableModes keeps GameMode order and is never empty', () {
      expect(selectableModes(enabled: const [GameMode.emojiQuiz]), [
        GameMode.emojiQuiz,
      ]);
      expect(selectableModes(enabled: const []), defaultEnabledModes);
      expect(
        selectableModes(
          enabled: const [GameMode.emojiQuiz, GameMode.whoseSong],
          current: GameMode.guessTrack,
        ),
        GameMode.values,
      );
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
