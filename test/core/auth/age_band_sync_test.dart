import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sporand/core/auth/age_band_sync.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

class _Tokens implements AccessTokenProvider {
  @override
  Future<String?> accessToken() async => 'access-1';

  @override
  Future<String?> refreshAfterUnauthorized(String rejectedToken) async => null;
}

/// `PATCH /v1/me` against a scripted server.
class _Harness {
  _Harness({AgeBand? band = AgeBand.adult, this.withBackend = true}) {
    if (band != null) prefs.values[PrefKeys.ageBand] = band.wireName;
  }

  final bool withBackend;
  final InMemoryPreferencesStore prefs = InMemoryPreferencesStore();
  late final UserPrefsRepository userPrefs = UserPrefsRepository(prefs);
  final List<http.Request> requests = [];
  String userId = 'user-1';

  /// Status of the next responses.
  int status = 200;

  late final AgeBandSync sync = AgeBandSync(
    client: withBackend
        ? ApiClient(
            baseUrl: Uri.parse('https://api.example.test'),
            tokens: _Tokens(),
            httpClient: MockClient((request) async {
              requests.add(request);
              return status == 0
                  ? throw http.ClientException('offline')
                  : http.Response(
                      jsonEncode(
                        status < 300
                            ? const {}
                            : {
                                'type': 'about:blank',
                                'title': 'Conflict',
                                'status': status,
                                'code': 'conflict',
                              },
                      ),
                      status,
                      headers: {'content-type': 'application/json'},
                    );
            }),
          )
        : null,
    prefs: userPrefs,
    currentUserId: () async => userId,
  );
}

void main() {
  test('sends the age gate band once per account', () async {
    final t = _Harness();
    await t.sync.ensureSynced();
    expect(t.requests, hasLength(1));
    expect(t.requests.single.method, 'PATCH');
    expect(t.requests.single.url.path, '/v1/me');
    expect(jsonDecode(t.requests.single.body), {'age_band': '18_plus'});
    expect(t.userPrefs.ageBandSyncedFor, 'user-1');

    await t.sync.ensureSynced();
    expect(t.requests, hasLength(1), reason: 'already on the server');

    // A new guest account (e.g. after the refresh family was revoked).
    t.userId = 'user-2';
    await t.sync.ensureSynced();
    expect(t.requests, hasLength(2));
    expect(t.userPrefs.ageBandSyncedFor, 'user-2');
  });

  test('409: the account already has a band; it is never sent again', () async {
    final t = _Harness()..status = 409;
    await t.sync.ensureSynced();
    expect(t.userPrefs.ageBandSyncedFor, 'user-1');
    await t.sync.ensureSynced();
    expect(t.requests, hasLength(1));
  });

  test('a hanging request does not hold up the room for long', () async {
    final hang = Completer<http.Response>();
    final requests = <http.Request>[];
    final prefs = InMemoryPreferencesStore(
      initial: {PrefKeys.ageBand: AgeBand.adult.wireName},
    );
    final sync = AgeBandSync(
      client: ApiClient(
        baseUrl: Uri.parse('https://api.example.test'),
        tokens: _Tokens(),
        httpClient: MockClient((request) {
          requests.add(request);
          return hang.future;
        }),
      ),
      prefs: UserPrefsRepository(prefs),
      currentUserId: () async => 'user-1',
    );
    await sync.ensureSynced(maxWait: const Duration(milliseconds: 20));
    expect(requests, hasLength(1));
    expect(UserPrefsRepository(prefs).ageBandSyncedFor, isNull);
    // The request still counts if it completes later.
    hang.complete(http.Response('{}', 200));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(UserPrefsRepository(prefs).ageBandSyncedFor, 'user-1');
  });

  test(
    'network and server errors are retried next time, never thrown',
    () async {
      final t = _Harness()..status = 0;
      await t.sync.ensureSynced();
      expect(t.userPrefs.ageBandSyncedFor, isNull);
      t.status = 503;
      await t.sync.ensureSynced();
      expect(t.userPrefs.ageBandSyncedFor, isNull);
      t.status = 200;
      await t.sync.ensureSynced();
      expect(t.requests, hasLength(3));
      expect(t.userPrefs.ageBandSyncedFor, 'user-1');
    },
  );

  test('nothing to send without a band, for a blocked band, or offline '
      'builds', () async {
    for (final t in [
      _Harness(band: null),
      _Harness(band: AgeBand.under13),
      _Harness(withBackend: false),
    ]) {
      await t.sync.ensureSynced();
      expect(t.requests, isEmpty);
      expect(t.userPrefs.ageBandSyncedFor, isNull);
    }
  });
}
