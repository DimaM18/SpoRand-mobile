import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/app_env.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/purchases/purchases_service.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

import 'fake_ws.dart';
import 'protocol_samples.dart';

/// Ads whose full-screen phase lasts until the test completes it.
class GatedAdsService implements AdsService {
  GatedAdsService({this.rewardedReady = true});

  bool rewardedReady;
  Completer<InterstitialOutcome>? interstitial;
  Completer<RewardedResult>? rewarded;
  String? ssvUserId;
  String? rewardNonce;
  int interstitialPreloads = 0;
  int rewardedPreloads = 0;

  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize(AdsInitOptions options) async {}

  @override
  Future<void> preloadInterstitial() async => interstitialPreloads++;

  @override
  Future<void> preloadRewarded() async => rewardedPreloads++;

  @override
  bool get isRewardedReady => rewardedReady;

  @override
  Future<InterstitialOutcome> showInterstitial({required Duration maxWait}) =>
      (interstitial = Completer<InterstitialOutcome>()).future;

  @override
  Future<RewardedResult> showRewarded({
    required String ssvUserId,
    required String rewardNonce,
    Duration maxWait = Duration.zero,
  }) {
    this.ssvUserId = ssvUserId;
    this.rewardNonce = rewardNonce;
    return (rewarded = Completer<RewardedResult>()).future;
  }
}

/// A [RoomSession] over the in-memory WebSocket server, inside a
/// [ProviderContainer] whose SDK-facing providers are fakes.
class GameHarness {
  GameHarness({
    required this.clock,
    required this.flush,
    this.me = Samples.guestId,
    AdsService? ads,
    FakePlaybackAdapter? playback,
    InputClock Function(FakeInputClock clock)? gameClock,
    List<Override> extraOverrides = const [],
  }) : ads = ads ?? GatedAdsService(),
       playback = playback ?? FakePlaybackAdapter(),
       inputClock = FakeInputClock(startUs: 1000000000, clock: clock) {
    ws = WsClient(
      endpoint: Uri.parse('wss://api.example.test/v1/ws'),
      fetchTicket: () async => const WsTicket(ticket: 'wst_test_ticket_0001'),
      clock: inputClock,
      appVersion: '1.0.0',
      platform: AppPlatform.android,
      connector: server.connect,
    );
    session = RoomSession(
      roomId: Samples.roomId,
      playerId: me,
      ws: ws,
      roomCode: '7KQ2MX',
      signals: signals,
    );
    unawaited(analytics.initialize());
    unawaited(analytics.applyConsent(AnalyticsConsent.granted));
    container = ProviderContainer(
      overrides: [
        roomSessionProvider.overrideWithValue(session),
        inputClockProvider.overrideWithValue(
          gameClock?.call(inputClock) ?? inputClock,
        ),
        adsServiceProvider.overrideWithValue(this.ads),
        analyticsProvider.overrideWithValue(analytics),
        remoteConfigProvider.overrideWithValue(
          RemoteConfigService(backend: InMemoryRemoteConfigBackend()),
        ),
        appEnvProvider.overrideWithValue(
          const AppEnv(flavor: Flavor.dev, platform: AppPlatform.android),
        ),
        purchasesServiceProvider.overrideWithValue(purchases),
        playbackAdapterFactoryProvider.overrideWithValue((_) => this.playback),
        appCheckProvider.overrideWithValue(appCheck),
        ...extraOverrides,
      ],
      retry: (_, _) => null,
    );
    container.listen(
      gameControllerProvider,
      (_, next) => states.add(next),
      fireImmediately: true,
    );
    session.start();
    flush();
  }

  final Clock clock;
  final void Function() flush;
  final String me;
  final AdsService ads;
  final FakePlaybackAdapter playback;
  final FakeInputClock inputClock;
  final FakeWsServer server = FakeWsServer();
  final FakeAppSignalSource signals = FakeAppSignalSource();
  final InMemoryAnalyticsBackend analyticsBackend = InMemoryAnalyticsBackend();
  late final AnalyticsService analytics = AnalyticsService(
    backend: analyticsBackend,
  );
  final FakePurchasesService purchases = FakePurchasesService();
  final FakeAppCheckService appCheck = FakeAppCheckService(
    token: 'limited-use-token-123',
  );
  late final WsClient ws;
  late final RoomSession session;
  late final ProviderContainer container;
  final List<GameUiState> states = [];

  GameController get controller =>
      container.read(gameControllerProvider.notifier);

  GameUiState get state => container.read(gameControllerProvider);

  void send(ServerMessage message) {
    server.send(message);
    flush();
  }

  void welcome({String? me}) => send(Samples.welcome(me: me ?? this.me));

  List<T> received<T extends ClientMessage>() => server.receivedOf<T>();

  /// Cancels every timer (controller, socket watchdog) so fake-async and
  /// widget tests end clean.
  void dispose() {
    container.dispose();
    unawaited(session.dispose());
  }
}
