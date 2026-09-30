import 'dart:convert';

import 'package:clock/clock.dart';

import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/security/session_repository.dart';

/// What `POST /v1/auth/guest` needs to register the installation.
final class GuestRegistration {
  const GuestRegistration({
    required this.appVersion,
    required this.platform,
    required this.osVersion,
    required this.locale,
  });

  final String appVersion;
  final AppPlatform platform;
  final String osVersion;

  /// BCP 47 tag, e.g. `ru-RU`.
  final String locale;
}

/// Guest auth endpoints (brief §4.2 "Auth").
abstract interface class AuthApi {
  /// Needs a limited-use App Check token (added by [ApiClient]).
  Future<AuthSession> createGuest(GuestRegistration registration);

  /// Rotates the refresh token. A reused token revokes the whole family;
  /// the server then answers 401 and the client starts a new guest session.
  Future<AuthSession> refresh(String refreshToken);
}

final class HttpAuthApi implements AuthApi {
  /// [client] must be the unauthenticated client (no token provider): these
  /// endpoints are how tokens are obtained.
  HttpAuthApi(this._client);

  final ApiClient _client;

  /// Access tokens live 10 minutes (brief §7); used when the response has
  /// neither `access_token_ttl_ms` nor a JWT `exp` claim.
  static const _defaultAccessTtl = Duration(minutes: 10);

  @override
  Future<AuthSession> createGuest(GuestRegistration registration) async {
    final json = await _client.post(
      '/v1/auth/guest',
      body: {
        'platform': registration.platform.wireName,
        'app_version': registration.appVersion,
        'os_version': registration.osVersion,
        'locale': registration.locale,
      },
      authenticated: false,
      appCheck: AppCheckUse.limitedUse,
    );
    return _parse(json);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final json = await _client.post(
      '/v1/auth/refresh',
      body: {'refresh_token': refreshToken},
      authenticated: false,
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
    if (access is! String || refresh is! String) {
      throw const ApiError(code: ApiError.invalidResponse);
    }
    final ttlMs = json['access_token_ttl_ms'];
    final expiresIn = json['expires_in'];
    final expiresAt = ttlMs is int
        ? clock.now().add(Duration(milliseconds: ttlMs))
        : expiresIn is int
        ? clock.now().add(Duration(seconds: expiresIn))
        : _jwtExpiry(access) ?? clock.now().add(_defaultAccessTtl);
    // `/v1/auth/refresh` returns only the token pair; the user id then
    // comes from the JWT `sub`.
    final resolvedUserId = userId is String ? userId : _jwtSubject(access);
    if (resolvedUserId == null) {
      throw const ApiError(code: ApiError.invalidResponse);
    }
    return AuthSession(
      userId: resolvedUserId,
      accessToken: access,
      refreshToken: refresh,
      accessTokenExpiresAt: expiresAt,
      analyticsUid: analyticsUid is String ? analyticsUid : null,
    );
  }

  /// Reads JWT claims without verifying the signature: the client only uses
  /// them for bookkeeping; the server verifies the token.
  static Map<String, Object?>? _jwtClaims(String jwt) {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map<String, Object?> ? payload : null;
    } on FormatException {
      return null;
    }
  }

  static DateTime? _jwtExpiry(String jwt) {
    final exp = _jwtClaims(jwt)?['exp'];
    return exp is int ? DateTime.fromMillisecondsSinceEpoch(exp * 1000) : null;
  }

  static String? _jwtSubject(String jwt) {
    final sub = _jwtClaims(jwt)?['sub'];
    return sub is String ? sub : null;
  }
}

/// Offline guest auth for dev builds without a backend and for tests.
final class FakeAuthApi implements AuthApi {
  FakeAuthApi({this.failWith, this.refreshFailWith});

  Object? failWith;
  Object? refreshFailWith;
  int guestCreated = 0;
  int refreshed = 0;
  GuestRegistration? lastRegistration;

  /// Completes refreshes only when set (to test single-flight refresh).
  Future<void>? refreshGate;

  @override
  Future<AuthSession> createGuest(GuestRegistration registration) async {
    final error = failWith;
    if (error != null) throw error;
    lastRegistration = registration;
    guestCreated++;
    return _session('guest-$guestCreated', 1);
  }

  @override
  Future<AuthSession> refresh(String refreshToken) async {
    final gate = refreshGate;
    if (gate != null) await gate;
    final error = refreshFailWith ?? failWith;
    if (error != null) throw error;
    refreshed++;
    final userId = refreshToken.split(':').first.replaceFirst('refresh-', '');
    return _session(userId, refreshed + 1);
  }

  static AuthSession _session(String userId, int generation) => AuthSession(
    userId: userId,
    accessToken: 'access-$userId:$generation',
    refreshToken: 'refresh-$userId:$generation',
    accessTokenExpiresAt: clock.now().add(const Duration(minutes: 10)),
    analyticsUid: 'a-$userId',
  );
}
