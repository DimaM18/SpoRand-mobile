import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// One WebSocket connection, reduced to what [WsClient] needs so tests can
/// plug in an in-memory fake.
abstract interface class WsConnection {
  /// Completes when the socket is open; errors when it cannot connect.
  Future<void> get ready;

  /// Incoming frames. The stream is done when the socket closes.
  Stream<Object?> get frames;

  void send(String frame);

  Future<void> close([int? code, String? reason]);

  /// Close code/reason from the server, available once [frames] is done.
  int? get closeCode;
  String? get closeReason;
}

typedef WsConnector = WsConnection Function(Uri uri);

/// `web_socket_channel` implementation (TLS via `wss://`).
final class ChannelWsConnection implements WsConnection {
  ChannelWsConnection(Uri uri) : _channel = WebSocketChannel.connect(uri);

  final WebSocketChannel _channel;

  static WsConnection connect(Uri uri) => ChannelWsConnection(uri);

  @override
  Future<void> get ready => _channel.ready;

  @override
  Stream<Object?> get frames => _channel.stream;

  @override
  void send(String frame) => _channel.sink.add(frame);

  @override
  Future<void> close([int? code, String? reason]) async {
    await _channel.sink.close(code, reason);
  }

  @override
  int? get closeCode => _channel.closeCode;

  @override
  String? get closeReason => _channel.closeReason;
}
