import 'dart:async';
import 'dart:convert';

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/net/ws_connection.dart';

/// One in-memory socket; the test plays the server's side.
class FakeWsConnection implements WsConnection {
  FakeWsConnection(this.uri);

  final Uri uri;
  final StreamController<Object?> _incoming = StreamController<Object?>();
  final Completer<void> _ready = Completer<void>();
  final List<String> sentFrames = [];
  int? _closeCode;
  String? _closeReason;
  bool closedByClient = false;
  int? clientCloseCode;

  List<WsEnvelope> get sentEnvelopes => [
    for (final f in sentFrames) WsEnvelope.tryParse(jsonDecode(f))!,
  ];

  List<ClientMessage> get sentMessages => [
    for (final e in sentEnvelopes) ClientMessage.fromEnvelope(e),
  ];

  List<T> sent<T extends ClientMessage>() =>
      sentMessages.whereType<T>().toList();

  bool get isOpen => _ready.isCompleted && !_incoming.isClosed;

  void open() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void failToOpen() {
    if (!_ready.isCompleted) _ready.completeError(StateError('refused'));
    unawaited(_incoming.close());
  }

  void deliver(ServerMessage message, {required int seq}) =>
      deliverRaw(jsonEncode(message.toEnvelope(seq).toJson()));

  void deliverRaw(String frame) => _incoming.add(frame);

  /// The server closes the socket with [code].
  void serverClose(int? code, [String? reason]) {
    _closeCode = code;
    _closeReason = reason;
    unawaited(_incoming.close());
  }

  @override
  Future<void> get ready => _ready.future;

  @override
  Stream<Object?> get frames => _incoming.stream;

  @override
  void send(String frame) => sentFrames.add(frame);

  @override
  Future<void> close([int? code, String? reason]) async {
    closedByClient = true;
    clientCloseCode = code;
    _closeCode ??= code;
    if (!_incoming.isClosed) await _incoming.close();
  }

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => _closeReason;
}

/// Hands out [FakeWsConnection]s and numbers server frames with one
/// per-player `seq` stream across connections (brief §4.3).
class FakeWsServer {
  FakeWsServer({this.autoOpen = true});

  bool autoOpen;
  final List<FakeWsConnection> connections = [];
  int seq = 0;

  WsConnection connect(Uri uri) {
    final connection = FakeWsConnection(uri);
    connections.add(connection);
    if (autoOpen) connection.open();
    return connection;
  }

  FakeWsConnection get current => connections.last;

  /// Sends [message] on the current connection with the next seq.
  int send(ServerMessage message) {
    current.deliver(message, seq: ++seq);
    return seq;
  }

  /// Every client message on every connection, in order.
  List<ClientMessage> get received => [
    for (final c in connections) ...c.sentMessages,
  ];

  List<T> receivedOf<T extends ClientMessage>() =>
      received.whereType<T>().toList();
}

JsonMap decodeFrame(String frame) => jsonDecode(frame) as JsonMap;
