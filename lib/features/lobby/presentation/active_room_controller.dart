import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/core/analytics/analytics_events.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/domain/room_session.dart';

/// Why the player is no longer in the room.
enum RoomEndReason {
  left,
  kicked,
  closed,

  /// Another connection of this player took over (4409).
  replaced,
  versionUnsupported,
  connectionLost,
}

sealed class ActiveRoomState {
  const ActiveRoomState();
}

final class NoActiveRoom extends ActiveRoomState {
  const NoActiveRoom();
}

final class RoomActive extends ActiveRoomState {
  const RoomActive(this.session);

  final RoomSession session;
}

/// The room ended without the player choosing to leave; the UI shows why,
/// then calls [ActiveRoomController.acknowledgeEnd].
final class RoomEnded extends ActiveRoomState {
  const RoomEnded(this.reason);

  final RoomEndReason reason;
}

/// Failure of create/join, mapped from the problem `code`.
enum RoomOpenError {
  notFound('not_found'),
  full('full'),
  locked('locked'),
  rateLimited('rate_limited'),
  network('network'),
  other('other');

  const RoomOpenError(this.wire);

  /// `room_join.result` value (brief §4.5) for the canonical ones.
  final String wire;
}

sealed class RoomOpenResult {
  const RoomOpenResult();
}

final class RoomOpened extends RoomOpenResult {
  const RoomOpened(this.roomId);

  final String roomId;
}

final class RoomOpenFailed extends RoomOpenResult {
  const RoomOpenFailed(this.error);

  final RoomOpenError error;
}

final activeRoomProvider =
    NotifierProvider<ActiveRoomController, ActiveRoomState>(
      ActiveRoomController.new,
    );

/// The session of the room the player is in (null otherwise).
final roomSessionProvider = Provider<RoomSession?>(
  (ref) => switch (ref.watch(activeRoomProvider)) {
    RoomActive(:final session) => session,
    _ => null,
  },
);

/// Owns the current [RoomSession]: create/join over REST, then the
/// WebSocket; ends it on leave, kick, close or a terminal close code.
class ActiveRoomController extends Notifier<ActiveRoomState> {
  StreamSubscription<WsConnectionState>? _connectionSub;
  StreamSubscription<RoomClosedReason>? _closedSub;

  /// Mirrors [RoomActive.session]; `state` may not be read while the
  /// provider is being disposed.
  RoomSession? _session;

  @override
  ActiveRoomState build() {
    ref.onDispose(() => unawaited(_teardown()));
    return const NoActiveRoom();
  }

  /// `POST /v1/rooms`, then connect. Logs `room_create`.
  Future<RoomOpenResult> create({
    required GameMode mode,
    required String displayName,
  }) async {
    if (_endpoint() == null) return const RoomOpenFailed(RoomOpenError.network);
    final env = ref.read(appEnvProvider);
    final provider = env.flavor == Flavor.spotifyProto
        ? MusicProviderId.spotifyAppRemote
        : MusicProviderId.testCatalog;
    final CreatedRoom created;
    try {
      created = await ref
          .read(roomsApiProvider)
          .createRoom(mode: mode, provider: provider, displayName: displayName);
    } on ApiError catch (e) {
      return RoomOpenFailed(_errorOf(e));
    }
    await ref.read(userPrefsProvider).saveDisplayName(displayName);
    final premium = ref.read(purchasesServiceProvider).entitlements.premium;
    unawaited(
      ref.read(analyticsProvider).logEvent(AnalyticsEvents.roomCreate, {
        AnalyticsParams.mode: mode.wire,
        AnalyticsParams.provider: provider.wire,
        AnalyticsParams.audioMode: AudioMode.hostDevice.wire,
        AnalyticsParams.roundsTotal: premium
            ? created.config.roundsPremiumDefault
            : created.config.roundsFreeDefault,
        AnalyticsParams.hostTier:
            (premium ? HostTier.premium : HostTier.free).wire,
      }),
    );
    await _open(
      roomId: created.roomId,
      playerId: created.playerId,
      roomCode: created.roomCode,
      config: created.config,
    );
    return RoomOpened(created.roomId);
  }

  /// `POST /v1/rooms/join`, then connect. Logs `room_join`.
  Future<RoomOpenResult> join({
    required String roomCode,
    required String displayName,
    required JoinVia via,
  }) async {
    if (_endpoint() == null) return const RoomOpenFailed(RoomOpenError.network);
    final analytics = ref.read(analyticsProvider);
    void log(String result) => unawaited(
      analytics.logEvent(AnalyticsEvents.roomJoin, {
        AnalyticsParams.result: result,
        AnalyticsParams.via: via.wire,
      }),
    );
    final JoinedRoom joined;
    try {
      joined = await ref
          .read(roomsApiProvider)
          .joinRoom(roomCode: roomCode, displayName: displayName);
    } on ApiError catch (e) {
      final error = _errorOf(e);
      // Only the canonical `room_join.result` values are logged.
      if (error != RoomOpenError.network && error != RoomOpenError.other) {
        log(error.wire);
      }
      return RoomOpenFailed(error);
    }
    log('ok');
    await ref.read(userPrefsProvider).saveDisplayName(displayName);
    await _open(
      roomId: joined.roomId,
      playerId: joined.playerId,
      roomCode: roomCode,
    );
    return RoomOpened(joined.roomId);
  }

  /// Sends `room.leave` and closes the socket.
  Future<void> leave() async {
    final session = _session;
    _session = null;
    await _unsubscribe();
    state = const NoActiveRoom();
    await session?.leave();
  }

  void acknowledgeEnd() {
    if (state is RoomEnded) state = const NoActiveRoom();
  }

  Future<void> _open({
    required String roomId,
    required String playerId,
    required String roomCode,
    RoomConfig? config,
  }) async {
    // Joining another room leaves the current one.
    await _teardown(leave: true);
    final info = await ref.read(appInfoSourceProvider).load();
    final rooms = ref.read(roomsApiProvider);
    final ws = WsClient(
      endpoint: _endpoint()!,
      fetchTicket: () => rooms.wsTicket(roomId),
      clock: ref.read(inputClockProvider),
      appVersion: info.version,
      platform: info.platform,
      connector: ref.read(wsConnectorProvider),
      log: kDebugMode ? (line) => debugPrint('[ws] $line') : null,
    );
    final session = RoomSession(
      roomId: roomId,
      playerId: playerId,
      ws: ws,
      roomCode: roomCode,
      signals: ref.read(appSignalSourceProvider),
      config: config,
    );
    _connectionSub = ws.states.listen((connection) {
      if (connection is WsClosed &&
          connection.reason != WsCloseReason.closedByClient) {
        unawaited(_end(_endReasonOf(connection.reason)));
      }
    });
    _closedSub = session.closed.listen(
      (_) => unawaited(_end(RoomEndReason.closed)),
    );
    session.start();
    _session = session;
    state = RoomActive(session);
  }

  Future<void> _end(RoomEndReason reason) async {
    final session = _session;
    if (session == null) return;
    _session = null;
    await _unsubscribe();
    state = RoomEnded(reason);
    await session.dispose();
  }

  Future<void> _unsubscribe() async {
    unawaited(_connectionSub?.cancel());
    unawaited(_closedSub?.cancel());
    _connectionSub = null;
    _closedSub = null;
  }

  Future<void> _teardown({bool leave = false}) async {
    final session = _session;
    _session = null;
    await _unsubscribe();
    if (session == null) return;
    if (leave) {
      await session.leave();
    } else {
      await session.dispose();
    }
  }

  /// `wss://api.<domain>/v1/ws`; null when no backend is configured (dev
  /// without API_BASE_URL), in which case rooms cannot be opened.
  Uri? _endpoint() =>
      ref.read(realtimeClientProvider).endpoint ??
      ref.read(appEnvProvider).realtimeEndpoint;

  static RoomEndReason _endReasonOf(WsCloseReason reason) => switch (reason) {
    WsCloseReason.kicked => RoomEndReason.kicked,
    WsCloseReason.replaced => RoomEndReason.replaced,
    WsCloseReason.versionUnsupported => RoomEndReason.versionUnsupported,
    WsCloseReason.roomGone => RoomEndReason.closed,
    WsCloseReason.unauthorized ||
    WsCloseReason.closedByClient => RoomEndReason.connectionLost,
  };

  static RoomOpenError _errorOf(ApiError e) {
    if (e.isNetwork) return RoomOpenError.network;
    return switch (e.code) {
      ErrorCodes.roomNotFound || 'not_found' => RoomOpenError.notFound,
      ErrorCodes.roomFull => RoomOpenError.full,
      ErrorCodes.roomLocked => RoomOpenError.locked,
      ErrorCodes.rateLimited => RoomOpenError.rateLimited,
      _ => RoomOpenError.other,
    };
  }
}

final roomsApiProvider = Provider<RoomsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return client == null ? FakeRoomsApi() : HttpRoomsApi(client);
});
