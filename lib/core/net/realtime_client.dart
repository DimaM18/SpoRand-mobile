/// Realtime (WebSocket) client. The boot pipeline only configures it: it
/// connects lazily when the player enters a room (brief §3 `realtime` step).
abstract interface class RealtimeClient {
  /// Stores the endpoint; must not open a socket.
  void configure({required Uri? endpoint});

  Uri? get endpoint;
}

/// Holds the endpoint for the room connections: each room opens its own
/// `WsClient` (reconnect, resume via `hello.last_seq`, clock sync) when the
/// player creates or joins it.
final class LazyRealtimeClient implements RealtimeClient {
  Uri? _endpoint;

  @override
  void configure({required Uri? endpoint}) => _endpoint = endpoint;

  @override
  Uri? get endpoint => _endpoint;
}
