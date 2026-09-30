import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_identity.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/auth/auth_service.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/security/session_repository.dart';

AuthSession _session(String userId, {String? uid}) => AuthSession(
  userId: userId,
  accessToken: 'access-$userId',
  refreshToken: 'refresh-$userId',
  accessTokenExpiresAt: DateTime(2100),
  analyticsUid: uid,
);

void main() {
  late InMemoryAnalyticsBackend backend;
  late AnalyticsService analytics;
  late SessionRepository sessions;
  late FakeAuthApi api;
  late AuthService auth;
  final crashIds = <String>[];

  setUp(() async {
    backend = InMemoryAnalyticsBackend();
    analytics = AnalyticsService(backend: backend);
    await analytics.initialize();
    sessions = SessionRepository(InMemorySecureStore());
    api = FakeAuthApi();
    auth = AuthService(
      api: api,
      sessions: sessions,
      appInfo: const FakeAppInfoSource(
        AppInfo(version: '1.0.0', buildNumber: '1', platform: AppPlatform.ios),
      ),
    );
    crashIds.clear();
  });

  AnalyticsIdentity identity({Future<String?> Function()? fetch}) =>
      AnalyticsIdentity(
        analytics: analytics,
        sessions: sessions,
        fetchAnalyticsUid: fetch,
        onUserId: (id) async => crashIds.add(id),
      );

  test('GA4 gets analytics_uid only with analytics consent', () async {
    await identity().attach(_session('u-1', uid: 'a-1'));
    expect(analytics.userId, 'a-1');
    expect(backend.userId, isNull, reason: 'consent still unknown');
    expect(crashIds, ['a-1']);

    await analytics.applyConsent(AnalyticsConsent.granted);
    expect(backend.userId, 'a-1');
    await analytics.applyConsent(AnalyticsConsent.denied);
    expect(backend.userId, isNull);
  });

  test('refresh and new guests move the id; logout clears it', () async {
    await analytics.applyConsent(AnalyticsConsent.granted);
    final session = await auth.ensureSession();
    await identity().attach(session);
    expect(backend.userId, 'a-guest-1');

    await sessions.save(_session('u-9', uid: 'a-9'));
    await pumpEventQueue();
    expect(backend.userId, 'a-9');

    await auth.signOut();
    await pumpEventQueue();
    expect(api.loggedOut, ['refresh-u-9']);
    expect(sessions.current, isNull);
    expect(backend.userId, isNull);
    expect(analytics.userId, isNull);
  });

  test('an offline logout still forgets the session and the id', () async {
    await analytics.applyConsent(AnalyticsConsent.granted);
    await sessions.save(_session('u-1', uid: 'a-1'));
    await identity().attach(sessions.current);
    api.failWith = StateError('offline');
    await auth.signOut();
    await pumpEventQueue();
    expect(sessions.current, isNull);
    expect(backend.userId, isNull);
  });

  test('a session without an id asks /v1/me once', () async {
    await analytics.applyConsent(AnalyticsConsent.granted);
    var fetched = 0;
    await identity(
      fetch: () async {
        fetched++;
        return 'a-from-me';
      },
    ).attach(_session('u-1'));
    expect(fetched, 1);
    expect(backend.userId, 'a-from-me');
  });

  test('a failing /v1/me leaves the id unset', () async {
    await analytics.applyConsent(AnalyticsConsent.granted);
    await identity(fetch: () async => throw StateError('500'))
        .attach(_session('u-1'));
    expect(backend.userId, isNull);
  });

  test('GET /v1/me reads user.analytics_uid', () {
    final me = MeResponse.fromJson({
      'user': {
        'user_id': 'u-1',
        'analytics_uid': 'a-1',
        'created_at': '2026-09-30T10:00:00Z',
        'locale': 'pl-PL',
        'consent_analytics': true,
        'consent_ads_personalized': false,
        'games_completed': 0,
      },
      'entitlements': {'no_ads': false, 'premium': false, 'items': <Object>[]},
      'music_links': <Object>[],
    });
    expect(me.user.analyticsUid, 'a-1');
  });
}
