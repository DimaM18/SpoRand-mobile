import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/playback/music_app_launcher.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

import 'e2e_env.dart';
import 'phone_clock.dart';
import 'rest_tap.dart';
import 'wire_tap.dart';

/// One simulated phone running the app's real client stack against the real
/// server: `ApiClient` + `AuthService` + `HttpRoomsApi` + `HttpMySongsApi`
/// over HTTP, `WsClient` over a real WebSocket, the hand-written protocol
/// DTOs, and the Riverpod controllers the screens use
/// (`ActiveRoomController`, `LobbyController`, `GameController`).
///
/// Only what needs a device is replaced: the OS input clock (simulated, on
/// this phone's own base), secure storage and preferences (in memory), App
/// Check (no token, like a device without it), ads, purchases, analytics
/// and the music-app launcher (the lib fakes). Widgets are not built: a test
/// does what a widget would, e.g. `GameController.tap(...)` with the pointer
/// time from this phone's input clock.
final class E2ePhone {
  E2ePhone({
    required this.name,
    required Uri apiBaseUrl,
    required int uptimeAtZeroUs,
    required int anchorUs,
    MusicProviderId roomProvider = MusicProviderId.externalPlayer,
    AgeBand ageBand = AgeBand.adult,
    AdsService? ads,
    ConsentService? consent,
  }) : clock = PhoneClock(uptimeAtZeroUs: uptimeAtZeroUs, anchorUs: anchorUs),
       wire = WireTap(name),
       rest = RestTap(name),
       analyticsBackend = InMemoryAnalyticsBackend() {
    analytics = AnalyticsService(backend: analyticsBackend);
    container = ProviderContainer(
      overrides: [
        // The app's own ApiClient wiring, over a recording http.Client.
        authApiClientProvider.overrideWith((ref) {
          final client = ApiClient(
            baseUrl: apiBaseUrl,
            httpClient: rest,
            appCheck: ref.watch(appCheckProvider),
          );
          ref.onDispose(client.close);
          return client;
        }),
        apiClientProvider.overrideWith((ref) {
          final client = ApiClient(
            baseUrl: apiBaseUrl,
            httpClient: rest,
            tokens: ref.watch(authServiceProvider),
            appCheck: ref.watch(appCheckProvider),
          );
          ref.onDispose(client.close);
          return client;
        }),
        appEnvProvider.overrideWithValue(
          AppEnv(
            flavor: Flavor.dev,
            platform: AppPlatform.android,
            apiBaseUrl: apiBaseUrl,
            roomProvider: roomProvider,
          ),
        ),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        // Onboarding is done: the age gate answer is stored on the device.
        preferencesStoreProvider.overrideWithValue(
          InMemoryPreferencesStore(
            initial: {
              PrefKeys.ageBand: ageBand.wireName,
              PrefKeys.onboardingCompleted: true,
            },
          ),
        ),
        appInfoSourceProvider.overrideWithValue(
          const FakeAppInfoSource(
            AppInfo(
              version: '1.0.0',
              buildNumber: '1',
              platform: AppPlatform.android,
              osVersion: 'e2e',
            ),
          ),
        ),
        appCheckProvider.overrideWithValue(FakeAppCheckService(token: null)),
        inputClockProvider.overrideWithValue(clock.input),
        wsConnectorProvider.overrideWithValue(wire.connect),
        appSignalSourceProvider.overrideWithValue(signals),
        adsServiceProvider.overrideWithValue(
          ads ??
              FakeAdsService(interstitialLoaded: false, rewardedLoaded: false),
        ),
        purchasesServiceProvider.overrideWithValue(FakePurchasesService()),
        analyticsProvider.overrideWithValue(analytics),
        remoteConfigProvider.overrideWithValue(
          RemoteConfigService(backend: InMemoryRemoteConfigBackend()),
        ),
        musicAppLauncherProvider.overrideWithValue(musicApp),
        // UMP needs the platform SDK; a suite that needs the consent state
        // (the YouTube player gate) passes a scripted one.
        if (consent != null) consentServiceProvider.overrideWithValue(consent),
      ],
      retry: (_, _) => null,
    );
    // Keep the controllers alive and record every game state, like the
    // screens that watch them.
    container
      ..listen(activeRoomProvider, (_, _) {}, fireImmediately: true)
      ..listen(lobbyControllerProvider, (_, _) {}, fireImmediately: true)
      ..listen(gameControllerProvider, (_, next) {
        gameStates.add((atUs: e2eNowUs(), state: next));
        _reportButtonsFrame(next);
      }, fireImmediately: true);
  }

  String? _buttonsShownFor;

  /// What the answer grid does: in a post-frame callback of the first frame
  /// with enabled buttons it reports that frame's time (here: the next
  /// event-loop turn, read from this phone's input clock).
  void _reportButtonsFrame(GameUiState state) {
    if (state is! GameRoundState || state.phase is! RoundOpen) return;
    final roundId = state.round.roundId;
    if (_buttonsShownFor == roundId) return;
    _buttonsShownFor = roundId;
    Timer.run(() => game.onAnswerButtonsShown(roundId, clock.nowMonoUs));
  }

  /// Display name (also the whose_song option label for this player).
  final String name;
  final PhoneClock clock;
  final WireTap wire;
  final RestTap rest;
  final FakeMusicAppLauncher musicApp = FakeMusicAppLauncher();

  /// The app's GA4 wrapper over an in-memory backend (what GA4 would get).
  final InMemoryAnalyticsBackend analyticsBackend;
  late final AnalyticsService analytics;

  /// App lifecycle and connectivity changes (`app.state`).
  final FakeAppSignalSource signals = FakeAppSignalSource();
  late final ProviderContainer container;

  /// Every [GameUiState] the controller produced, with its e2e time.
  final List<({int atUs, GameUiState state})> gameStates = [];

  String? userId;

  ActiveRoomState get activeRoom => container.read(activeRoomProvider);

  RoomSession get session {
    final session = container.read(roomSessionProvider);
    if (session == null) throw StateError('$name is not in a room');
    return session;
  }

  String get playerId => session.playerId;
  GameController get game => container.read(gameControllerProvider.notifier);
  GameUiState get gameState => container.read(gameControllerProvider);
  LobbyController get lobby => container.read(lobbyControllerProvider.notifier);
  LobbyUiState get lobbyState => container.read(lobbyControllerProvider);

  // --- REST ------------------------------------------------------------------

  /// `POST /v1/auth/guest` through `AuthService` (what the boot `auth` step
  /// does on first launch).
  Future<void> signIn() async {
    userId = (await container.read(authServiceProvider).ensureSession()).userId;
  }

  /// «Могу включать музыку» in the lobby (`lobby.set_can_dj`).
  void setCanDj(bool canDj) => lobby.setCanDj(canDj);

  Future<List<Song>> searchSongs(String query, {int limit = 25}) =>
      container.read(mySongsApiProvider).search(query, limit: limit);

  /// «Мои песни» → Save (`PUT /v1/me/picks` with `song_ids`, or
  /// `song_picks` when [videos] links YouTube videos).
  Future<List<CatalogPick>> savePicks(
    List<String> songIds, {
    Map<String, String> videos = const {},
  }) => container.read(mySongsApiProvider).savePicks(songIds, videos: videos);

  /// `POST /v1/rooms` (the provider comes from [AppEnv.roomProvider]), then
  /// the WebSocket.
  Future<void> createRoom(GameMode mode) async {
    final result = await tryCreateRoom(mode);
    if (result is! RoomOpened) {
      throw StateError('$name: create failed: $result');
    }
  }

  /// Like [createRoom], but returns the controller's result (a refused
  /// create is a [RoomOpenFailed]).
  Future<RoomOpenResult> tryCreateRoom(GameMode mode) => container
      .read(activeRoomProvider.notifier)
      .create(mode: mode, displayName: name);

  /// `POST /v1/rooms/join` by code, then the WebSocket.
  Future<void> joinRoom(String roomCode) async {
    final result = await container
        .read(activeRoomProvider.notifier)
        .join(roomCode: roomCode, displayName: name, via: JoinVia.code);
    if (result is RoomOpenFailed) {
      throw StateError('$name: join failed: ${result.error}');
    }
  }

  /// «Добавить мои песни» → consent → `PUT /v1/rooms/{id}/pool`.
  Future<int> addMySongsToRoom() async {
    final draft = await lobby.preparePool();
    if (draft is! PoolReady) throw StateError('$name: pool draft $draft');
    if (!await lobby.submitPool(draft)) {
      throw StateError('$name: PUT /v1/rooms/{id}/pool failed');
    }
    return draft.picks.length;
  }

  // --- the game screen ---------------------------------------------------------

  /// «Музыка играет!» (the DJ of an external_player round). The pointer-down
  /// time comes from this phone's input clock, like `tapMonoUsFromPointer`;
  /// returns it once `round.playback_started` is on the wire (the controller
  /// first checks the time against the input clock), or null when the
  /// controller did not accept the tap.
  Future<int?> djTap(String roundId) async {
    final atMonoUs = clock.nowMonoUs;
    if (!game.djStarted(roundId: roundId, audioStartMonoUs: atMonoUs)) {
      return null;
    }
    await waitFor(
      'round.playback_started',
      () => wire
          .sentOf('round.playback_started')
          .where((f) => f.payload['round_id'] == roundId)
          .lastOrNull,
    );
    return atMonoUs;
  }

  /// A pointer down on the answer [optionId], stamped with this phone's
  /// input clock; returns the tap time, or null when nothing was committed.
  int? tapAnswer(String roundId, String optionId) {
    final atMonoUs = clock.nowMonoUs;
    return game.tap(roundId: roundId, optionId: optionId, tapMonoUs: atMonoUs)
        ? atMonoUs
        : null;
  }

  // --- waiting ---------------------------------------------------------------

  /// Polls [probe] until it returns non-null.
  Future<T> waitFor<T extends Object>(
    String what,
    T? Function() probe, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final deadline = e2eNowUs() + timeout.inMicroseconds;
    while (true) {
      final value = probe();
      if (value != null) return value;
      if (e2eNowUs() > deadline) {
        throw TimeoutException(
          '$name: no $what within $timeout; game state: $gameState; '
          'last frames: ${wire.received.reversed.take(8).toList()}',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
  }

  /// Welcome received, socket up and the first clock burst answered.
  Future<void> waitSynced() => waitFor('welcome + clock.result', () {
    final s = container.read(roomSessionProvider);
    return s != null && s.ws.state is WsConnected && s.clock.isSynced
        ? true
        : null;
  });

  Future<S> waitGame<S extends GameUiState>(
    String what, {
    bool Function(S state)? where,
    Duration timeout = const Duration(seconds: 15),
  }) => waitFor(what, () {
    final state = gameState;
    return state is S && (where?.call(state) ?? true) ? state : null;
  }, timeout: timeout);

  /// Like [waitGame], but also matches states the controller has already
  /// left: some last only briefly (`round.voided` is followed by the
  /// spare's `round.prepare` after `void_notice_ms`, which may be 0).
  Future<S> waitGameSeen<S extends GameUiState>(
    String what, {
    bool Function(S state)? where,
    Duration timeout = const Duration(seconds: 15),
  }) => waitFor(what, () {
    for (final entry in gameStates) {
      final state = entry.state;
      if (state is S && (where?.call(state) ?? true)) return state;
    }
    return null;
  }, timeout: timeout);

  /// The round [index] as this phone sees it once `round.prepare` arrived.
  Future<GameRoundState> waitRound(int index) => waitGame<GameRoundState>(
    'round.prepare #$index',
    where: (s) => s.round.roundIndex == index,
  );

  /// The first server message of type [T] received after [sinceUs].
  Future<T> waitMessage<T extends ServerMessage>(
    String type, {
    int sinceUs = 0,
    bool Function(WireFrame frame)? where,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final frame = await waitFor('$type frame', () {
      for (final f in wire.received) {
        if (f.type == type && f.atUs >= sinceUs && (where?.call(f) ?? true)) {
          return f;
        }
      }
      return null;
    }, timeout: timeout);
    return ServerMessage.fromJson(type, frame.payload) as T;
  }

  /// The last frames in both directions, for failure reports.
  String wireSummary({int last = 60}) {
    final frames = [
      for (final f in wire.sent) ('>>', f),
      for (final f in wire.received) ('<<', f),
      for (final f in wire.lost) ('xx', f),
    ]..sort((a, b) => a.$2.atUs.compareTo(b.$2.atUs));
    final shown = frames.length > last
        ? frames.sublist(frames.length - last)
        : frames;
    return [
      '--- $name: last ${shown.length} of ${frames.length} frames '
          '(>> sent, << received, xx lost) ---',
      for (final (dir, f) in shown) '$dir $f',
    ].join('\n');
  }

  Future<void> dispose() async {
    try {
      await container.read(activeRoomProvider.notifier).leave();
    } on Object {
      // Already gone.
    }
    container.dispose();
    rest.shutdown();
  }
}
