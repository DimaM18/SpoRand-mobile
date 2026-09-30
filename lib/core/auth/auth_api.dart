import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/security/session_repository.dart';

/// Guest auth endpoints (brief §4.2 "Auth").
abstract interface class AuthApi {
  Future<AuthSession> createGuest({
    required String? limitedUseAppCheckToken,
    required String appVersion,
    required AppPlatform platform,
  });

  /// Rotates the refresh token. A reused token revokes the whole family;
  /// the server then answers 401 and the client starts a new guest session.
  Future<AuthSession> refresh(String refreshToken, {String? appCheckToken});
}

final class HttpAuthApi implements AuthApi {
  HttpAuthApi(this._client);

  final ApiClient _client;

  /// Access tokens live 10 minutes (brief §7); used when neither
  /// `expires_in` nor a JWT `exp` claim is available.
  static const _defaultAccessTtl = Duration(minutes: 10);

  @override
  Future<AuthSession> createGuest({
    required String? limitedUseAppCheckToken,
    required String appVersion,
    required AppPlatform platform,
  }) async {
    final json = await _client.postJson(
      '/v1/auth/guest',
      body: {'app_version': appVersion, 'platform': platform.wireName},
      appCheckToken: limitedUseAppCheckToken,
    );
    return _parse(json);
  }

  @override
  Future<AuthSession> refresh(
    String refreshToken, {
    String? appCheckToken,
  }) async {
    final json = await _client.postJson(
      '/v1/auth/refresh',
      body: {'refresh_token': refreshToken},
      appCheckToken: appCheckToken,
    );
    return _parse(json);
  }

  static AuthSession _parse(Map<String, Object?> json) {
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final user = json['user'];
    final userId = user is Map<String, Object?> ? user['user_id'] : null;
    final analyticsUid = user is Map<String, Object?>
        ? user['analytics_uid']
        : null;
    if (access is! String || refresh is! String || userId is! String) {
      throw const ApiException(502, code: 'invalid_auth_response');
    }
    final expiresIn = json['expires_in'];
    final expiresAt = expiresIn is int
        ? clock.now().add(Duration(seconds: expiresIn))
        : _jwtExpiry(access) ?? clock.now().add(_defaultAccessTtl);
    return AuthSession(
      userId: userId,
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: expiresAt,
      analyticsUid: analyticsUid is String ? analyticsUid : null,
    );
  }

  /// Reads the `exp` claim without verifying the signature: the client only
  /// uses it to decide when to refresh; the server verifies the token.
  static DateTime? _jwtExpiry(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map<String, Object?> ? payload['exp'] : null;
      return exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000)
          : null;
    } on FormatException {
      return null;
    }
  }
}

/// Offline guest auth for dev builds without a backend and for tests.
final class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.failWith});

  Object? failWith;
  int guestCreated = 0;
  int refreshed = 0;

  @override
  Future<AuthSession> createGuest({
    required String? limitedUseAppCheckToken,
    required String appVersion,
    required AppPlatform platform,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    guestCreated++;
    return _session('guest-$guestCreated');
  }

  @override
  Future<AuthSession> refresh(
    String refreshToken, {
    String? appCheckToken,
  }) async {
    final error = failWith;
    if (error != null) throw error;
    refreshed++;
    return _session(refreshToken.replaceFirst('refresh-', ''));
  }

  static AuthSession _session(String userId) => AuthSession(
    userId: userId,
    accessToken: 'access-$userId',
    refreshToken: 'refresh-$userId',
    accessTokenExpiresAt: clock.now().add(const Duration(minutes: 10)),
    analyticsUid: 'a-$userId',
  );
}
