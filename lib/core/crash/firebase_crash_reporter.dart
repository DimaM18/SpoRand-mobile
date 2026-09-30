import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import 'package:sporand/core/crash/crash_reporter.dart';
import 'package:sporand/core/firebase/firebase_core_gate.dart';

/// Crashlytics adapter. PII policy (brief §7 "Secrets"): callers pass
/// pseudonymous ids only and never tokens.
final class FirebaseCrashReporter implements CrashReporter {
  FirebaseCrashReporter(this._firebase);

  final FirebaseCoreGate _firebase;
  FirebaseCrashlytics? _crashlytics;

  @override
  Future<void> initialize({required bool collectionEnabled}) async {
    await _firebase.require();
    final crashlytics = FirebaseCrashlytics.instance;
    await crashlytics.setCrashlyticsCollectionEnabled(collectionEnabled);
    _crashlytics = crashlytics;
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
    String? reason,
  }) async {
    await _crashlytics?.recordError(error, stack, fatal: fatal, reason: reason);
  }

  @override
  Future<void> log(String message) async {
    await _crashlytics?.log(message);
  }

  @override
  Future<void> setUserId(String id) async {
    await _crashlytics?.setUserIdentifier(id);
  }
}
