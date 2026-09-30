import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';

/// `POST /v1/rooms` response.
final class CreatedRoom {
  const CreatedRoom({
    required this.roomId,
    required this.roomCode,
    required this.playerId,
    required this.config,
    required this.configVersion,
  });

  final String roomId;
  final String roomCode;
  final String playerId;
  final RoomConfig config;
  final String configVersion;
}

/// `POST /v1/rooms/join` response.
final class JoinedRoom {
  const JoinedRoom({required this.roomId, required this.playerId});

  final String roomId;
  final String playerId;
}

/// `Report.reason` values from packages/protocol [новое имя — согласовать]
/// (the brief names only the field).
enum ReportReason {
  offensiveName('offensive_name'),
  cheating('cheating'),
  harassment('harassment'),
  spam('spam'),
  other('other');

  const ReportReason(this.wire);

  final String wire;
}

/// Rooms endpoints (brief §4.2 "Rooms").
abstract interface class RoomsApi {
  /// Needs a limited-use App Check token.
  Future<CreatedRoom> createRoom({
    required GameMode mode,
    required MusicProviderId provider,
    String? displayName,
  });

  Future<JoinedRoom> joinRoom({
    required String roomCode,
    required String displayName,
  });

  /// Single-use WebSocket ticket, valid 30 s.
  Future<WsTicket> wsTicket(String roomId);

  Future<void> reportPlayer({
    required String roomId,
    required String playerId,
    required ReportReason reason,
  });

  /// `PUT /v1/rooms/{room_id}/pool`: this player's pool for the room
  /// (replaces an earlier one). The server answers with what it stored.
  Future<PoolContributionView> submitPool({
    required String roomId,
    required PoolPutRequest pool,
  });
}

final class HttpRoomsApi implements RoomsApi {
  HttpRoomsApi(this._client);

  final ApiClient _client;

  @override
  Future<CreatedRoom> createRoom({
    required GameMode mode,
    required MusicProviderId provider,
    String? displayName,
  }) async {
    final json = await _client.post(
      '/v1/rooms',
      body: RoomCreateRequest(
        mode: mode,
        provider: provider,
        displayName: displayName,
      ).toJson(),
      appCheck: AppCheckUse.limitedUse,
    );
    final created = _parse(json, RoomCreateResponse.fromJson);
    return CreatedRoom(
      roomId: created.roomId,
      roomCode: created.roomCode,
      playerId: created.playerId,
      config: created.config,
      configVersion: created.configVersion,
    );
  }

  @override
  Future<JoinedRoom> joinRoom({
    required String roomCode,
    required String displayName,
  }) async {
    final json = await _client.post(
      '/v1/rooms/join',
      body: RoomJoinRequest(
        roomCode: roomCode,
        displayName: displayName,
      ).toJson(),
    );
    final joined = _parse(json, RoomJoinResponse.fromJson);
    return JoinedRoom(roomId: joined.roomId, playerId: joined.playerId);
  }

  @override
  Future<WsTicket> wsTicket(String roomId) async {
    final json = await _client.post(
      '/v1/rooms/${Uri.encodeComponent(roomId)}/ws-ticket',
    );
    final ticket = _parse(json, WsTicketResponse.fromJson);
    final wsUrl = ticket.wsUrl;
    return WsTicket(
      ticket: ticket.ticket,
      wsUrl: wsUrl == null ? null : Uri.tryParse(wsUrl),
    );
  }

  @override
  Future<void> reportPlayer({
    required String roomId,
    required String playerId,
    required ReportReason reason,
  }) async {
    await _client.post(
      '/v1/rooms/${Uri.encodeComponent(roomId)}/reports',
      body: ReportCreateRequest(
        reportedPlayerId: playerId,
        reason: reason.wire,
      ).toJson(),
    );
  }

  @override
  Future<PoolContributionView> submitPool({
    required String roomId,
    required PoolPutRequest pool,
  }) async {
    final json = await _client.put(
      '/v1/rooms/${Uri.encodeComponent(roomId)}/pool',
      body: pool.toJson(),
    );
    return _parse(json, PoolContributionView.fromJson);
  }
}

/// A 2xx body that does not match the contract is an invalid response.
T _parse<T>(JsonMap json, T Function(JsonMap json) fromJson) {
  try {
    return fromJson(json);
  } on ProtocolFormatException {
    throw const ApiError(code: ApiError.invalidResponse);
  }
}

/// Offline stand-in when no API base URL is configured (dev without a
/// backend) and in tests.
final class FakeRoomsApi implements RoomsApi {
  FakeRoomsApi({this.failWith});

  /// Thrown by create/join (e.g. `ApiError(code: 'room_full')`).
  Object? failWith;
  int roomsCreated = 0;
  GameMode? lastCreatedMode;
  int ticketsIssued = 0;
  final List<({String roomId, String playerId, ReportReason reason})> reports =
      [];
  ({String roomCode, String displayName})? lastJoin;
  final List<({String roomId, PoolPutRequest pool})> pools = [];

  /// Thrown by [submitPool].
  Object? poolFailWith;

  @override
  Future<CreatedRoom> createRoom({
    required GameMode mode,
    required MusicProviderId provider,
    String? displayName,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    roomsCreated++;
    lastCreatedMode = mode;
    return CreatedRoom(
      roomId: 'room-$roomsCreated',
      roomCode: '7KQ2MX',
      playerId: 'p-host',
      config: RoomConfig.defaults,
      configVersion: '0000000000000000',
    );
  }

  @override
  Future<JoinedRoom> joinRoom({
    required String roomCode,
    required String displayName,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    lastJoin = (roomCode: roomCode, displayName: displayName);
    return const JoinedRoom(roomId: 'room-joined', playerId: 'p-guest');
  }

  @override
  Future<WsTicket> wsTicket(String roomId) async {
    ticketsIssued++;
    return WsTicket(ticket: 'wst_fake_ticket_$ticketsIssued');
  }

  @override
  Future<void> reportPlayer({
    required String roomId,
    required String playerId,
    required ReportReason reason,
  }) async {
    reports.add((roomId: roomId, playerId: playerId, reason: reason));
  }

  @override
  Future<PoolContributionView> submitPool({
    required String roomId,
    required PoolPutRequest pool,
  }) async {
    final error = poolFailWith;
    if (error != null) throw error;
    pools.add((roomId: roomId, pool: pool));
    return PoolContributionView(
      poolId: 'pool-${pools.length}',
      roomId: roomId,
      playerId: 'p-me',
      provider: MusicProviderId.externalPlayer,
      poolSource: pool.poolSource,
      entries: [
        for (final (index, track) in pool.tracks.indexed)
          PoolEntry(
            trackRefId: 'ref-$index',
            rank: track.rank ?? index + 1,
            title: 'Track ${index + 1}',
            artists: const ['Artist'],
            primaryArtist: 'Artist',
          ),
      ],
      hiddenTrackRefIds: const [],
      submittedAt: '2026-09-30T11:00:00Z',
      expiresAt: '2026-09-30T14:00:00Z',
    );
  }
}
