import 'package:firebase_app_check/firebase_app_check.dart';

import 'package:sporand/core/firebase/firebase_core_gate.dart';

/// Firebase App Check (brief §7 "Attestation").
///
/// Standard tokens go on every REST call (`X-Firebase-AppCheck`);
/// limited-use tokens are required for `POST /v1/auth/guest`,
/// `POST /v1/rooms`, `bonus.request` and `POST /v1/me/entitlements/sync`.
/// Never attest per answer.
abstract interface class AppCheckService {
  Future<void> activate();

  /// Null when App Check is unavailable; the server decides by
  /// `app_check_mode` (monitor/enforce) whether that is acceptable.
  Future<String?> getToken();

  Future<String?> getLimitedUseToken();
}

final class FirebaseAppCheckService implements AppCheckService {
  FirebaseAppCheckService(this._firebase, {required this.useDebugProviders});

  final FirebaseCoreGate _firebase;

  /// Dev builds use the debug providers (register the debug token in the
  /// Firebase console). TODO(owner): register debug tokens for testers.
  final bool useDebugProviders;
  bool _active = false;

  @override
  Future<void> activate() async {
    if (_active) return;
    await _firebase.require();
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugProviders
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugProviders
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
    _active = true;
  }

  @override
  Future<String?> getToken() async {
    if (!_active) return null;
    try {
      return await FirebaseAppCheck.instance.getToken();
    } on Object {
      return null;
    }
  }

  @override
  Future<String?> getLimitedUseToken() async {
    if (!_active) return null;
    try {
      return await FirebaseAppCheck.instance.getLimitedUseToken();
    } on Object {
      return null;
    }
  }
}

final class FakeAppCheckService implements AppCheckService {
  FakeAppCheckService({this.token = 'fake-app-check-token'});

  final String? token;
  bool activated = false;
  int limitedUseTokensIssued = 0;

  @override
  Future<void> activate() async => activated = true;

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String?> getLimitedUseToken() async {
    limitedUseTokensIssued++;
    return token;
  }
}
