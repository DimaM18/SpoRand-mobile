import 'dart:async';

import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/security/session_repository.dart';

/// Keeps the analytics user id equal to the signed-in user's `analytics_uid`
/// (S8.6: an HMAC of `user_id` computed by the server; never the raw id).
/// [новое имя — согласовать]
///
/// - The id comes from the auth response (`POST /v1/auth/guest` and, since
///   wave 3, `POST /v1/auth/refresh`) stored in [AuthSession.analyticsUid];
///   a session restored without one (stored by an older app) asks
///   `GET /v1/me` once through [fetchAnalyticsUid].
/// - Every session change is followed: a new guest or rotated tokens set the
///   id again, and a cleared session (logout, account deletion, a revoked
///   token family) clears it.
/// - [AnalyticsService] hands the id to GA4 only while analytics consent is
///   granted.
final class AnalyticsIdentity {
  AnalyticsIdentity({
    required this._analytics,
    required this._sessions,
    this._fetchAnalyticsUid,
    this._onUserId,
  });

  final AnalyticsService _analytics;
  final SessionRepository _sessions;

  /// `GET /v1/me` -> `user.analytics_uid`; null without a backend.
  final Future<String?> Function()? _fetchAnalyticsUid;

  /// Also receives each non-null id (the crash reporter's user id).
  final Future<void> Function(String analyticsUid)? _onUserId;

  StreamSubscription<AuthSession?>? _sub;
  int _generation = 0;

  /// Applies [session] and follows every later session change.
  Future<void> attach(AuthSession? session) {
    _sub ??= _sessions.changes.listen((next) => unawaited(apply(next)));
    return apply(session);
  }

  /// Sets (or, for null, clears) the analytics user id for [session]. Never
  /// throws: a failed `/v1/me` leaves the id unset until the next change.
  Future<void> apply(AuthSession? session) async {
    final generation = ++_generation;
    if (session == null) {
      await _analytics.setUserId(null);
      return;
    }
    var uid = session.analyticsUid;
    final fetch = _fetchAnalyticsUid;
    if (uid == null && fetch != null) {
      try {
        uid = await fetch();
      } on Object {
        uid = null;
      }
      // A newer session arrived while `/v1/me` was in flight.
      if (generation != _generation) return;
    }
    if (uid == null) return;
    await _analytics.setUserId(uid);
    await _onUserId?.call(uid);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
