/// Realtime (WebSocket) client. The boot pipeline only configures it: it
/// connects lazily when the player enters a room (brief §3 `realtime` step).
abstract interface class RealtimeClient {
  /// Stores the endpoint; must not open a socket.
  void configure({required Uri? endpoint});

  Uri? get endpoint;
}

/// Lazy client used until the socket implementation lands (reconnect,
/// resume via `hello.last_seq`, clock sync; part 2).
final class LazyRealtimeClient implements RealtimeClient {
  Uri? _endpoint;

  @override
  void configure({required Uri? endpoint}) => _endpoint = endpoint;

  @override
  Uri? get endpoint => _endpoint;
}
