import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';

/// App lifecycle and connectivity changes as `app.state` values
/// (brief §4.3): each one makes the server run a clock re-sync burst.
abstract interface class AppSignalSource {
  Stream<AppStateSignal> get signals;

  void dispose();
}

/// Real source: `AppLifecycleListener` + connectivity_plus.
final class FlutterAppSignalSource implements AppSignalSource {
  FlutterAppSignalSource({Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _lifecycle = AppLifecycleListener(
      onResume: () => _emit(AppStateSignal.foreground),
      onPause: () => _emit(AppStateSignal.background),
    );
    _network = _connectivity.onConnectivityChanged.listen((results) {
      final key = (results.toList()..sort((a, b) => a.index - b.index)).join();
      // The first event is the current state, not a change.
      if (_lastNetwork != null && _lastNetwork != key) {
        _emit(AppStateSignal.networkChanged);
      }
      _lastNetwork = key;
    }, onError: (Object _) {});
  }

  final Connectivity _connectivity;
  late final AppLifecycleListener _lifecycle;
  late final StreamSubscription<List<ConnectivityResult>> _network;
  String? _lastNetwork;
  final StreamController<AppStateSignal> _signals =
      StreamController<AppStateSignal>.broadcast();

  void _emit(AppStateSignal signal) {
    if (!_signals.isClosed) _signals.add(signal);
  }

  @override
  Stream<AppStateSignal> get signals => _signals.stream;

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_network.cancel());
    unawaited(_signals.close());
  }
}

final class FakeAppSignalSource implements AppSignalSource {
  final StreamController<AppStateSignal> _signals =
      StreamController<AppStateSignal>.broadcast();

  void emit(AppStateSignal signal) => _signals.add(signal);

  @override
  Stream<AppStateSignal> get signals => _signals.stream;

  @override
  void dispose() => unawaited(_signals.close());
}
