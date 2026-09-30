import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/ws_connection.dart';

import 'e2e_env.dart';

/// One WebSocket frame of a simulated phone, as it crossed the socket.
final class WireFrame {
  WireFrame({required this.connection, required this.atUs, required this.raw})
    : json = _decode(raw);

  /// 0 for the first socket, 1 after the first reconnect, …
  final int connection;

  /// [e2eNowUs] when the frame was read from / written to the socket.
  final int atUs;
  final String raw;

  /// Null when [raw] is not a JSON object.
  final JsonMap? json;

  String? get type => json?['type'] as String?;
  int? get seq => json?['seq'] as int?;
  JsonMap get payload => (json?['payload'] as JsonMap?) ?? const {};

  static JsonMap? _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is JsonMap ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => '#$connection@${atUs ~/ 1000}ms $type seq=$seq';
}

/// The network of one simulated phone: a real WebSocket
/// ([ChannelWsConnection]) with a recorder and two fault injectors.
///
/// - [delayNext] holds the next outgoing frame of a type for a while. Later
///   frames queue behind it, as on one TCP stream: letting a `clock.pong`
///   overtake a delayed `round.answer` would give the answer a lower `seq`
///   than a frame the server already saw, and the server drops those.
/// - [blackout] loses every server frame from now on (the server believes
///   they were delivered), and [killSocket] then drops the socket, so the
///   app must resume with `hello.last_seq`.
final class WireTap {
  WireTap(this.name);

  final String name;

  /// Server frames the app received (not the ones lost in a blackout).
  final List<WireFrame> received = [];

  /// Server frames lost in a blackout.
  final List<WireFrame> lost = [];

  /// Client frames, when they were written to the socket.
  final List<WireFrame> sent = [];

  /// Close code of every socket that ended, in order (null: none received).
  final List<int?> closeCodes = [];

  final Map<String, Duration> _delays = {};
  final List<_TappedConnection> _connections = [];
  bool _blackout = false;

  int get connectionCount => _connections.length;

  /// The [WsConnector] the phone's `WsClient` uses.
  WsConnection connect(Uri uri) {
    final connection = _TappedConnection(
      this,
      ChannelWsConnection(uri),
      _connections.length,
    );
    _connections.add(connection);
    return connection;
  }

  void delayNext(String type, Duration by) => _delays[type] = by;

  /// From now on server frames are lost.
  void blackout() => _blackout = true;

  /// Drops the current socket (the frames lost so far stay lost) and ends
  /// the blackout, so the reconnect works.
  Future<void> killSocket() async {
    final current = _connections.last;
    _blackout = false;
    current.lostForGood = true;
    // A client may only send 1000 or 3000-4999; 4000 is not one of the
    // protocol's codes, so the app treats it like any lost connection.
    await current.close(4000, 'e2e: simulated network loss');
  }

  List<WireFrame> sentOf(String type) => [
    for (final f in sent)
      if (f.type == type) f,
  ];

  List<WireFrame> receivedOf(String type) => [
    for (final f in received)
      if (f.type == type) f,
  ];

  /// Every server frame the socket carried, received or lost, in order.
  List<WireFrame> get allServerFrames =>
      [...received, ...lost]..sort((a, b) => a.atUs.compareTo(b.atUs));

  bool _onIncoming(_TappedConnection connection, Object? data) {
    if (data is! String) return true;
    final frame = WireFrame(
      connection: connection.index,
      atUs: e2eNowUs(),
      raw: data,
    );
    if (_blackout || connection.lostForGood) {
      lost.add(frame);
      return false;
    }
    received.add(frame);
    return true;
  }

  Duration _takeDelay(String frame) {
    if (_delays.isEmpty) return Duration.zero;
    final type = WireFrame(connection: 0, atUs: 0, raw: frame).type;
    return _delays.remove(type) ?? Duration.zero;
  }
}

final class _TappedConnection implements WsConnection {
  _TappedConnection(this._tap, this._inner, this.index);

  final WireTap _tap;
  final WsConnection _inner;
  final int index;

  /// Set by [WireTap.killSocket]: frames still in flight are lost too.
  bool lostForGood = false;

  final Queue<({String frame, Duration delay})> _outbox = Queue();
  bool _draining = false;

  @override
  late final Stream<Object?> frames = _inner.frames.transform(
    StreamTransformer.fromHandlers(
      handleData: (data, sink) {
        if (_tap._onIncoming(this, data)) sink.add(data);
      },
      handleDone: (sink) {
        _tap.closeCodes.add(_inner.closeCode);
        sink.close();
      },
    ),
  );

  @override
  Future<void> get ready => _inner.ready;

  @override
  void send(String frame) {
    final delay = _tap._takeDelay(frame);
    if (delay == Duration.zero && !_draining) {
      _write(frame);
      return;
    }
    _outbox.add((frame: frame, delay: delay));
    if (!_draining) unawaited(_drain());
  }

  /// Writes the queued frames in order. A frame leaves the queue only once
  /// written, so nothing sent meanwhile can overtake it.
  Future<void> _drain() async {
    _draining = true;
    while (_outbox.isNotEmpty) {
      final next = _outbox.first;
      if (next.delay > Duration.zero) await Future<void>.delayed(next.delay);
      _outbox.removeFirst();
      _write(next.frame);
    }
    _draining = false;
  }

  void _write(String frame) {
    _tap.sent.add(WireFrame(connection: index, atUs: e2eNowUs(), raw: frame));
    _inner.send(frame);
  }

  @override
  Future<void> close([int? code, String? reason]) => _inner.close(code, reason);

  @override
  int? get closeCode => _inner.closeCode;

  @override
  String? get closeReason => _inner.closeReason;
}
