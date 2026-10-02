// End-to-end: the account side of wave 3 against the real server.
// - `analytics_uid` comes with the guest sign-up, stays the same across
//   token refreshes (and in `GET /v1/me`), and becomes the GA4 user id.
// - Consent sync: after the app's `PUT /v1/me/consent` the server accepts
//   server analytics for that user, and drops them again after a revoke.
// The server runs with ANALYTICS_SINK=console (scripts/e2e.sh), so accepted
// server events are lines of its log (E2E_SERVER_LOG). See
// README.md, "End-to-end suite".
@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/rest_tap.dart';
import 'support/server_analytics.dart';

void main() {
  final audit = ContractAudit();
  final phones = <E2ePhone>[];
  setUpAll(requireRealNetwork);
  tearDownAll(() async {
    for (final phone in phones) {
      await phone.dispose();
    }
  });

  E2ePhone newPhone(String name, int clock) {
    final phone = E2ePhone(
      name: name,
      apiBaseUrl: e2eApiBaseUrl()!,
      uptimeAtZeroUs: 2000000000 + clock * 1000000,
      anchorUs: 1000000 + clock,
    );
    audit.watchRest(phone.rest);
    phones.add(phone);
    return phone;
  }

  Future<MeResponse> me(E2ePhone phone) async => MeResponse.fromJson(
    await phone.container.read(apiClientProvider)!.get('/v1/me'),
  );

  test(
    'analytics_uid: issued at sign-up, the same after token refreshes and in '
    'GET /v1/me, and handed to the analytics wrapper as the user id',
    () async {
      final phone = newPhone('Oskar', 1);
      await phone.signIn();
      final auth = phone.container.read(authServiceProvider);
      final first = auth.current!;
      final uid = first.analyticsUid;
      expect(uid, isNotNull);
      expect(uid, isNot(first.userId), reason: 'never the raw user id');
      expect(uid, matches(RegExp(r'^[A-Za-z0-9_-]{16,}$')));

      final identity = phone.container.read(analyticsIdentityProvider);
      await identity.attach(first);
      expect(phone.analytics.userId, uid);

      final profile = (await me(phone)).user;
      expect(profile.userId, first.userId);
      expect(profile.analyticsUid, uid);

      var previous = first;
      for (var i = 0; i < 2; i++) {
        // What ApiClient does after a 401: rotate the tokens.
        await auth.refreshAfterUnauthorized(previous.accessToken);
        final next = auth.current!;
        expect(next.refreshToken, isNot(previous.refreshToken));
        expect(next.userId, first.userId);
        expect(next.analyticsUid, uid, reason: 'refresh #${i + 1}');
        previous = next;
      }
      final refreshes = _calls(phone.rest, 'POST', '/v1/auth/refresh');
      expect(refreshes, hasLength(2));
      for (final call in refreshes) {
        expect(call.status, 200);
        final body = call.responseJson! as Map<String, Object?>;
        expect((body['user']! as Map<String, Object?>)['analytics_uid'], uid);
      }
      // The identity followed the rotated session and kept the id.
      await phone.waitFor(
        'the analytics user id after the refresh',
        () => phone.analytics.userId == uid ? true : null,
      );
      expect((await me(phone)).user.analyticsUid, uid);

      final other = newPhone('Paula', 2);
      await other.signIn();
      final otherUid = other.container
          .read(authServiceProvider)
          .current!
          .analyticsUid;
      expect(otherUid, isNotNull);
      expect(otherUid, isNot(uid));
    },
    skip: e2eSkip(),
  );

  test('consent sync: after PUT /v1/me/consent the server logs analytics for '
      'that user (with its analytics_uid); without consent, or after a revoke, '
      'it drops them', () async {
    final log = e2eServerLog();
    if (log == null) {
      markTestSkipped('needs E2E_SERVER_LOG (run scripts/e2e.sh)');
      return;
    }
    final granted = newPhone('Roksana', 3);
    final silent = newPhone('Szymon', 4);
    await granted.signIn();
    await silent.signIn();
    final grantedUid = granted.container
        .read(authServiceProvider)
        .current!
        .analyticsUid!;
    final silentUid = silent.container
        .read(authServiceProvider)
        .current!
        .analyticsUid!;
    // A new guest has not consented yet.
    expect((await me(granted)).user.consentAnalytics, isFalse);

    // Settings → «Аналитика» on: the app's debounced consent sync.
    await _syncConsent(granted, analytics: true);
    final profile = (await me(granted)).user;
    expect(profile.consentAnalytics, isTrue);
    expect(profile.consentAdsPersonalized, isFalse);
    expect(profile.consentUpdatedAt, isNotNull);

    // Each room creation emits `room_created` for its host. The server
    // delivers events in order, so once the last consented one is in the
    // log, the ones before it were either written or dropped.
    final grantedRoom = await _createRoom(granted);
    final silentRoom = await _createRoom(silent);
    final marker = await _createRoom(granted);
    await _waitRoomCreated(granted, log, marker);

    final events = readServerEvents(log);
    final grantedEvent = _roomCreated(events, grantedRoom);
    expect(grantedEvent, isNotNull, reason: 'consented: logged');
    expect(grantedEvent!.analyticsUid, grantedUid);
    expect(
      _roomCreated(events, silentRoom),
      isNull,
      reason: 'no consent: dropped by the server',
    );
    expect(
      events.where((e) => e.analyticsUid == silentUid),
      isEmpty,
      reason: 'nothing at all for a user without consent',
    );
    // Only the HMAC ever reaches analytics, never the user id.
    for (final line in serverAnalyticsLines(log)) {
      for (final phone in [granted, silent]) {
        expect(line, isNot(contains(phone.userId!)));
      }
    }

    // Revoke: the next event of that user is dropped again.
    await _syncConsent(granted, analytics: false);
    expect((await me(granted)).user.consentAnalytics, isFalse);
    final afterRevoke = await _createRoom(granted);
    await _syncConsent(silent, analytics: true);
    final silentMarker = await _createRoom(silent);
    await _waitRoomCreated(silent, log, silentMarker);
    final later = readServerEvents(log);
    expect(_roomCreated(later, afterRevoke), isNull);
    expect(_roomCreated(later, silentMarker)!.analyticsUid, silentUid);
  }, skip: e2eSkip());

  test('contract: every REST exchange decodes with the Dart DTOs', () {
    e2eLog('REST calls: ${audit.restCounts}');
    expect(audit.restProblems(), isEmpty);
    expect(
      audit.restCounts.keys,
      containsAll(<String>[
        'GET /v1/me 200',
        'PUT /v1/me/consent 200',
        'POST /v1/auth/refresh 200',
      ]),
    );
  }, skip: e2eSkip());
}

List<RestExchange> _calls(RestTap rest, String method, String path) => [
  for (final call in rest.exchanges)
    if (call.method == method && call.path == path) call,
];

/// What the Settings screen does: `ConsentSync.schedule`, then waits for the
/// debounced `PUT /v1/me/consent` to be answered.
Future<void> _syncConsent(E2ePhone phone, {required bool analytics}) async {
  final before = _calls(phone.rest, 'PUT', '/v1/me/consent').length;
  phone.container
      .read(consentSyncProvider)
      .schedule(
        analytics: analytics,
        adsPersonalized: false,
        source: ConsentSource.settings,
      );
  final call = await phone.waitFor('PUT /v1/me/consent', () {
    final calls = _calls(phone.rest, 'PUT', '/v1/me/consent');
    return calls.length > before ? calls.last : null;
  });
  expect(call.status, 200, reason: call.responseBody);
  expect(
    (call.requestJson! as Map<String, Object?>)['consent_analytics'],
    analytics,
  );
}

/// `POST /v1/rooms` through the app's RoomsApi (no socket needed).
Future<String> _createRoom(E2ePhone phone) async {
  final room = await phone.container
      .read(roomsApiProvider)
      .createRoom(
        mode: GameMode.whoseSong,
        provider: MusicProviderId.externalPlayer,
        displayName: phone.name,
      );
  return room.roomId;
}

ServerEvent? _roomCreated(List<ServerEvent> events, String roomId) => events
    .where((e) => e.name == 'room_created' && e.params['room_id'] == roomId)
    .firstOrNull;

Future<void> _waitRoomCreated(E2ePhone phone, File log, String roomId) =>
    phone.waitFor(
      'room_created for $roomId in the server log',
      () => _roomCreated(readServerEvents(log), roomId) == null ? null : true,
      timeout: const Duration(seconds: 5),
    );
