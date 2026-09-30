import 'package:clock/clock.dart';

import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/security/session_repository.dart';

/// Silent guest accounts (brief §7 "Identity and sessions") and the token
/// source for authenticated REST calls.
///
/// Refreshes are single-flight: the refresh token rotates on every use and
/// the server revokes the whole family when an old one is replayed, so two
/// concurrent refreshes with the same token would log the user out.
class AuthService implements AccessTokenProvider {
  AuthService({
    required this._api,
    required this._sessions,
    required this._appInfo,
    this._localeTag = _defaultLocale,
  });

  final AuthApi _api;
  final SessionRepository _sessions;
  final AppInfoSource _appInfo;
  final String Function() _localeTag;

  Future<AuthSession>? _refreshing;
  Future<AuthSession>? _creating;

  static String _defaultLocale() => 'und';

  AuthSession? get current => _sessions.current;

  /// Our `user_id`: the stored session's, or a new session's when there is
  /// none yet (network errors propagate).
  Future<String> currentUserId() async =>
      (_sessions.current ?? await ensureSession()).userId;

  /// Returns a usable session: the restored one, a refreshed one, or a new
  /// guest. Network errors propagate (the `auth` boot step then degrades and
  /// the app retries later); a rejected refresh starts a new guest session.
  Future<AuthSession> ensureSession() async {
    final existing = _sessions.current;
    if (existing == null) return _createGuest();
    if (existing.isAccessTokenValid(clock.now())) return existing;
    return _refresh();
  }

  @override
  Future<String?> accessToken() async => (await ensureSession()).accessToken;

  @override
  Future<String?> refreshAfterUnauthorized(String rejectedToken) async {
    final current = _sessions.current;
    // Another request already rotated the tokens: reuse the new ones.
    if (current != null && current.accessToken != rejectedToken) {
      return current.accessToken;
    }
    if (current == null) return (await _createGuest()).accessToken;
    return (await _refresh()).accessToken;
  }

  Future<AuthSession> _refresh() =>
      _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);

  Future<AuthSession> _doRefresh() async {
    final existing = _sessions.current;
    if (existing == null) return _createGuest();
    try {
      final refreshed = await _api.refresh(existing.refreshToken);
      await _sessions.save(refreshed);
      return refreshed;
    } on ApiError catch (e) {
      // 401 = token reused/revoked/expired: the family is gone.
      if (!e.isUnauthorized) rethrow;
      await _sessions.clear();
      return _createGuest();
    }
  }

  Future<AuthSession> _createGuest() =>
      _creating ??= _doCreateGuest().whenComplete(() => _creating = null);

  Future<AuthSession> _doCreateGuest() async {
    final info = await _appInfo.load();
    final created = await _api.createGuest(
      GuestRegistration(
        appVersion: info.version,
        platform: info.platform,
        osVersion: info.osVersion,
        locale: _localeTag(),
      ),
    );
    await _sessions.save(created);
    return created;
  }
}
