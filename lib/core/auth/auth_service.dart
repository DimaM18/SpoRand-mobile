import 'package:clock/clock.dart';

import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/session_repository.dart';

/// Silent guest accounts (brief §7 "Identity and sessions").
class AuthService {
  AuthService({
    required AuthApi api,
    required SessionRepository sessions,
    required AppCheckService appCheck,
    required AppInfoSource appInfo,
  }) : _api = api,
       _sessions = sessions,
       _appCheck = appCheck,
       _appInfo = appInfo;

  final AuthApi _api;
  final SessionRepository _sessions;
  final AppCheckService _appCheck;
  final AppInfoSource _appInfo;

  AuthSession? get current => _sessions.current;

  /// Returns a usable session: the restored one, a refreshed one, or a new
  /// guest. Network errors propagate (the `auth` boot step then degrades and
  /// the app retries later); a rejected refresh starts a new guest session.
  Future<AuthSession> ensureSession() async {
    final existing = _sessions.current;
    if (existing != null) {
      if (existing.isAccessTokenValid(clock.now())) return existing;
      try {
        final refreshed = await _api.refresh(
          existing.refreshToken,
          appCheckToken: await _appCheck.getToken(),
        );
        await _sessions.save(refreshed);
        return refreshed;
      } on ApiException catch (e) {
        // 401 = token reused/revoked/expired: the family is gone.
        if (!e.isUnauthorized) rethrow;
        await _sessions.clear();
      }
    }
    final info = await _appInfo.load();
    final created = await _api.createGuest(
      limitedUseAppCheckToken: await _appCheck.getLimitedUseToken(),
      appVersion: info.version,
      platform: info.platform,
    );
    await _sessions.save(created);
    return created;
  }
}
