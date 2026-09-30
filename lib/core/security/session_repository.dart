import 'dart:async';
import 'dart:convert';

import 'package:sporand/core/security/secure_store.dart';

/// Guest session issued by `POST /v1/auth/guest` / `/v1/auth/refresh`.
final class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    this.analyticsUid,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;

  /// HMAC of `user_id` computed by the server; the only id sent to analytics
  /// and crash reporting.
  final String? analyticsUid;

  /// Access tokens live 10 minutes (brief §7); refresh a little early so a
  /// request never leaves with a token that expires in flight.
  bool isAccessTokenValid(
    DateTime now, {
    Duration skew = const Duration(seconds: 30),
  }) => now.add(skew).isBefore(accessTokenExpiresAt);

  Map<String, Object?> toJson() => {
    'user_id': userId,
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_expires_at_ms': accessTokenExpiresAt.millisecondsSinceEpoch,
    'analytics_uid': analyticsUid,
  };

  static AuthSession? tryParse(Map<String, Object?> json) {
    final userId = json['user_id'];
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final expiresAt = json['access_expires_at_ms'];
    if (userId is! String ||
        access is! String ||
        refresh is! String ||
        expiresAt is! int) {
      return null;
    }
    final analyticsUid = json['analytics_uid'];
    return AuthSession(
      userId: userId,
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: DateTime.fromMillisecondsSinceEpoch(expiresAt),
      analyticsUid: analyticsUid is String ? analyticsUid : null,
    );
  }

  /// Tokens never appear in logs (brief §7).
  @override
  String toString() => 'AuthSession(user: $userId, tokens: <redacted>)';
}

/// Persists the access/refresh tokens in [SecureStore] only.
class SessionRepository {
  SessionRepository(this._store);

  static const storageKey = 'auth_session_v1';

  final SecureStore _store;
  AuthSession? _current;
  final StreamController<AuthSession?> _changes =
      StreamController<AuthSession?>.broadcast(sync: true);

  AuthSession? get current => _current;

  /// Every [save] (new guest, rotated tokens) and [clear] (logout, account
  /// deletion, a revoked family), in order. Not emitted by [restore].
  Stream<AuthSession?> get changes => _changes.stream;

  Future<AuthSession?> restore() async {
    final raw = await _store.read(storageKey);
    if (raw == null) return _current = null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) {
        return _current = AuthSession.tryParse(decoded);
      }
    } on FormatException {
      // Corrupt entry: fall through and start a fresh guest session.
    }
    await _store.delete(storageKey);
    return _current = null;
  }

  Future<void> save(AuthSession session) async {
    _current = session;
    _changes.add(session);
    await _store.write(storageKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _current = null;
    _changes.add(null);
    await _store.delete(storageKey);
  }
}
