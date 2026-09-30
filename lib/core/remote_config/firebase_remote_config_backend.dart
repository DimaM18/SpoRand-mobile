import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import 'package:sporand/core/firebase/firebase_core_gate.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';

/// Firebase Remote Config (client template) adapter.
final class FirebaseRemoteConfigBackend implements RemoteConfigBackend {
  FirebaseRemoteConfigBackend({
    required FirebaseCoreGate firebase,
    required Duration minimumFetchInterval,
  }) : _firebase = firebase,
       _minimumFetchInterval = minimumFetchInterval;

  final FirebaseCoreGate _firebase;
  final Duration _minimumFetchInterval;
  FirebaseRemoteConfig? _config;
  Future<void>? _ready;

  @override
  Future<void> ensureReady() => _ready ??= _init();

  Future<void> _init() async {
    await _firebase.require();
    final config = FirebaseRemoteConfig.instance;
    await config.setConfigSettings(
      RemoteConfigSettings(
        // The boot step enforces boot_config_timeout_ms itself; this is only
        // the SDK-level upper bound for background fetches.
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: _minimumFetchInterval,
      ),
    );
    _config = config;
  }

  FirebaseRemoteConfig get _require {
    final config = _config;
    if (config == null) throw StateError('Remote Config not ready');
    return config;
  }

  @override
  Future<void> setDefaults(Map<String, Object> defaults) async {
    await ensureReady();
    await _require.setDefaults(defaults);
  }

  @override
  Future<bool> activate() async {
    await ensureReady();
    return _require.activate();
  }

  @override
  Future<void> fetch() async {
    await ensureReady();
    await _require.fetch();
  }

  @override
  String? getRaw(String key) {
    final config = _config;
    if (config == null) return null;
    final value = config.getValue(key);
    if (value.source == ValueSource.valueStatic) return null;
    return value.asString();
  }

  @override
  Stream<Set<String>> get onUpdated async* {
    await ensureReady();
    yield* _require.onConfigUpdated.asyncMap((update) async {
      // Real-time updates are fetched but not active until activate().
      await _require.activate();
      return update.updatedKeys;
    });
  }
}
