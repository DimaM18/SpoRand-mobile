import 'dart:async';

/// Raw key/value source behind [RemoteConfigService]. The service owns the
/// typing, defaults and clamping; a backend only stores and fetches strings.
abstract interface class RemoteConfigBackend {
  /// Prepares the SDK (for Firebase: initializes the app and settings).
  Future<void> ensureReady();

  Future<void> setDefaults(Map<String, Object> defaults);

  /// Activates the most recently fetched values (fetched on an earlier run).
  Future<bool> activate();

  /// Fetches without activating. Values fetched after the boot deadline are
  /// activated on the next cold start by `config_activate_cached`.
  Future<void> fetch();

  /// The active value, or null when the key has no remote or default value.
  String? getRaw(String key);

  /// Keys updated in real time (Firebase `onConfigUpdated`).
  Stream<Set<String>> get onUpdated;
}

/// In-memory backend: used by tests and by builds without Firebase config.
final class InMemoryRemoteConfigBackend implements RemoteConfigBackend {
  InMemoryRemoteConfigBackend({
    Map<String, String>? cached,
    Map<String, String>? remote,
    this.fetchDelay = Duration.zero,
    this.failFetch = false,
    this.failReady = false,
  }) : _pendingActivation = Map.of(cached ?? const {}),
       remote = Map.of(remote ?? const {});

  /// Values the next [fetch] returns.
  final Map<String, String> remote;
  Duration fetchDelay;
  bool failFetch;
  bool failReady;

  final Map<String, String> _defaults = {};
  final Map<String, String> _active = {};
  Map<String, String> _pendingActivation;
  final StreamController<Set<String>> _updates =
      StreamController<Set<String>>.broadcast();

  int fetchCount = 0;

  @override
  Future<void> ensureReady() async {
    if (failReady) throw StateError('Remote Config backend unavailable');
  }

  @override
  Future<void> setDefaults(Map<String, Object> defaults) async {
    _defaults
      ..clear()
      ..addAll(defaults.map((key, value) => MapEntry(key, '$value')));
  }

  @override
  Future<bool> activate() async {
    if (_pendingActivation.isEmpty) return false;
    _active.addAll(_pendingActivation);
    _pendingActivation = {};
    return true;
  }

  @override
  Future<void> fetch() async {
    fetchCount++;
    if (fetchDelay > Duration.zero) await Future<void>.delayed(fetchDelay);
    if (failFetch) throw StateError('fetch failed');
    _pendingActivation = Map.of(remote);
  }

  @override
  String? getRaw(String key) => _active[key] ?? _defaults[key];

  /// Simulates a real-time update pushed by the backend.
  void pushUpdate(Map<String, String> values) {
    _active.addAll(values);
    _updates.add(values.keys.toSet());
  }

  @override
  Stream<Set<String>> get onUpdated => _updates.stream;
}
