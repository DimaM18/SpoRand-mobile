import 'dart:async';

import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/clock_sync.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/ws_client.dart';

/// One joined room: its WebSocket, clock sync and the latest snapshot.
/// Lobby, game and results all read from the same session.
class RoomSession {
  RoomSession({
    required this.roomId,
    required this._playerId,
    required this.ws,
    this.roomCode,
    ClockModel? clock,
    this._signals,
    RoomConfig? config,
  }) : clock = clock ?? ClockModel(),
       _config = config ?? RoomConfig.defaults;

  final String roomId;
  String? roomCode;
  final WsClient ws;
  final ClockModel clock;
  final AppSignalSource? _signals;

  String _playerId;
  RoomSnapshot? _room;
  RoomConfig _config;
  String? _configVersion;
  RoomClosedReason? _closedReason;
  StreamSubscription<ServerMessage>? _messagesSub;
  StreamSubscription<AppStateSignal>? _signalsSub;
  final StreamController<RoomSnapshot> _roomChanges =
      StreamController<RoomSnapshot>.broadcast();
  final StreamController<ServerError> _errors =
      StreamController<ServerError>.broadcast();
  final StreamController<RoomClosedReason> _closed =
      StreamController<RoomClosedReason>.broadcast();
  bool _started = false;

  String get playerId => _playerId;
  RoomSnapshot? get room => _room;

  /// Frozen room config from `welcome.config` (brief §4.6 S/B keys).
  RoomConfig get config => _config;
  String? get configVersion => _configVersion;
  RoomClosedReason? get closedReason => _closedReason;

  Stream<ServerMessage> get messages => ws.messages;
  Stream<WsConnectionState> get connection => ws.states;
  Stream<RoomSnapshot> get roomChanges => _roomChanges.stream;
  Stream<ServerError> get errors => _errors.stream;
  Stream<RoomClosedReason> get closed => _closed.stream;

  PlayerSnapshot? get me => _room?.player(_playerId);

  bool get isHost => _room?.hostPlayerId == _playerId;

  /// In the MVP the host is always the playback device (brief §2 "Rooms").
  bool get isPlaybackDevice => me?.isPlaybackDevice ?? isHost;

  String nameOf(String playerId) => _room?.player(playerId)?.displayName ?? '—';

  void start() {
    if (_started) return;
    _started = true;
    _messagesSub = ws.messages.listen(_onMessage);
    _signalsSub = _signals?.signals.listen(_onSignal);
    unawaited(ws.connect());
  }

  bool send(ClientMessage message) => ws.send(message);

  /// `room.leave`, then closes the socket.
  Future<void> leave() async {
    ws.send(const RoomLeave());
    await dispose();
  }

  Future<void> dispose() async {
    // Stops reconnects and timers synchronously, before any await.
    final closing = ws.close();
    unawaited(_messagesSub?.cancel());
    unawaited(_signalsSub?.cancel());
    await closing;
    await _roomChanges.close();
    await _errors.close();
    await _closed.close();
  }

  void _onSignal(AppStateSignal signal) {
    // After the device sleeps the offset is invalid until the next burst.
    if (signal == AppStateSignal.foreground) clock.markStale();
    ws.notifyAppState(signal);
  }

  void _onMessage(ServerMessage message) {
    switch (message) {
      case Welcome():
        _playerId = message.playerId;
        _config = message.config;
        _configVersion = message.configVersion;
        roomCode ??= message.room.roomCode;
        _setRoom(message.room);
      case RoomStateMessage(:final room):
        _setRoom(room);
      case RoomPlayerJoined(:final player) || RoomPlayerUpdated(:final player):
        _upsertPlayer(player);
      case RoomPlayerLeft(:final playerId):
        final room = _room;
        if (room != null) {
          _setRoom(
            room.copyWith(
              players: [
                for (final p in room.players)
                  if (p.playerId != playerId) p,
              ],
            ),
          );
        }
      case PlayerEntitlementsUpdated():
        final player = _room?.player(message.playerId);
        if (player != null) {
          _upsertPlayer(
            player.copyWith(
              entitlements: EntitlementsSnapshot(
                noAds: message.noAds,
                premium: message.premium,
              ),
            ),
          );
        }
      case ClockResult():
        clock.apply(message);
      case RoomClosed(:final reason):
        _closedReason = reason;
        if (!_closed.isClosed) _closed.add(reason);
      case ServerError():
        if (!_errors.isClosed) _errors.add(message);
      default:
        break;
    }
  }

  void _upsertPlayer(PlayerSnapshot player) {
    final room = _room;
    if (room == null) return;
    final players = [...room.players];
    final index = players.indexWhere((p) => p.playerId == player.playerId);
    if (index < 0) {
      players.add(player);
    } else {
      players[index] = player;
    }
    _setRoom(room.copyWith(players: players));
  }

  void _setRoom(RoomSnapshot room) {
    _room = room;
    if (!_roomChanges.isClosed) _roomChanges.add(room);
  }
}
