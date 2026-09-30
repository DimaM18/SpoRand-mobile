import 'package:sporand/core/net/api_client.dart';
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
      body: {
        'mode': mode.wire,
        'provider': provider.wire,
        'display_name': ?displayName,
      },
      appCheck: AppCheckUse.limitedUse,
    );
    final config = json['config_snapshot'];
    return CreatedRoom(
      roomId: _str(json, 'room_id'),
      roomCode: _str(json, 'room_code'),
      playerId: _str(json, 'player_id'),
      config: RoomConfig(config is Map<String, Object?> ? config : const {}),
      configVersion: _str(json, 'config_version'),
    );
  }

  @override
  Future<JoinedRoom> joinRoom({
    required String roomCode,
    required String displayName,
  }) async {
    final json = await _client.post(
      '/v1/rooms/join',
      body: {'room_code': roomCode, 'display_name': displayName},
    );
    return JoinedRoom(
      roomId: _str(json, 'room_id'),
      playerId: _str(json, 'player_id'),
    );
  }

  @override
  Future<WsTicket> wsTicket(String roomId) async {
    final json = await _client.post(
      '/v1/rooms/${Uri.encodeComponent(roomId)}/ws-ticket',
    );
    final wsUrl = json['ws_url'];
    return WsTicket(
      ticket: _str(json, 'ticket'),
      wsUrl: wsUrl is String ? Uri.tryParse(wsUrl) : null,
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
      body: {'reported_player_id': playerId, 'reason': reason.wire},
    );
  }

  static String _str(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is String) return value;
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
  int ticketsIssued = 0;
  final List<({String roomId, String playerId, ReportReason reason})> reports =
      [];
  ({String roomCode, String displayName})? lastJoin;

  @override
  Future<CreatedRoom> createRoom({
    required GameMode mode,
    required MusicProviderId provider,
    String? displayName,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    roomsCreated++;
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
}
