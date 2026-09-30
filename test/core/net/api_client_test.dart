import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:sporand/core/auth/auth_api.dart';
import 'package:sporand/core/auth/auth_service.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/platform/app_info.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/security/app_check_service.dart';
import 'package:sporand/core/security/secure_store.dart';
import 'package:sporand/core/security/session_repository.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';

/// Counts refreshes and can hold them open to test single flight.
class _Tokens implements AccessTokenProvider {
  String token = 'access-1';
  int refreshes = 0;
  Completer<void>? gate;

  @override
  Future<String?> accessToken() async => token;

  @override
  Future<String?> refreshAfterUnauthorized(String rejectedToken) async {
    if (rejectedToken != token) return token;
    refreshes++;
    await gate?.future;
    return token = 'access-${refreshes + 1}';
  }
}

http.Response _json(Object body, {int status = 200, String? type}) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': type ?? 'application/json'},
    );

void main() {
  final base = Uri.parse('https://api.example.test');

  test('adds Bearer and the standard App Check token', () async {
    late http.BaseRequest seen;
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        seen = request;
        return _json({'ok': true});
      }),
      tokens: _Tokens(),
      appCheck: FakeAppCheckService(token: 'app-check-std'),
    );
    final json = await client.get('/v1/me');
    expect(json, {'ok': true});
    expect(seen.headers['authorization'], 'Bearer access-1');
    expect(seen.headers['X-Firebase-AppCheck'], 'app-check-std');
    expect(seen.url.toString(), 'https://api.example.test/v1/me');
  });

  test('limited-use calls fetch a limited-use App Check token', () async {
    final appCheck = FakeAppCheckService(token: 'limited');
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async => _json({})),
      tokens: _Tokens(),
      appCheck: appCheck,
    );
    await client.post('/v1/rooms', appCheck: AppCheckUse.limitedUse);
    expect(appCheck.limitedUseTokensIssued, 1);
  });

  test('401 refreshes once and retries with the new token', () async {
    final authHeaders = <String?>[];
    final tokens = _Tokens();
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        authHeaders.add(request.headers['authorization']);
        return request.headers['authorization'] == 'Bearer access-1'
            ? _json({'code': 'unauthorized'}, status: 401)
            : _json({'ok': true});
      }),
      tokens: tokens,
    );
    expect(await client.get('/v1/me'), {'ok': true});
    expect(tokens.refreshes, 1);
    expect(authHeaders, ['Bearer access-1', 'Bearer access-2']);
  });

  test('concurrent 401s share one refresh through AuthService', () async {
    final gate = Completer<void>();
    final authApi = FakeAuthApi();
    final auth = AuthService(
      api: authApi,
      sessions: SessionRepository(InMemorySecureStore()),
      appInfo: const FakeAppInfoSource(
        AppInfo(version: '1.0.0', buildNumber: '1', platform: AppPlatform.ios),
      ),
    );
    final stale = (await auth.accessToken())!;
    authApi.refreshGate = gate.future;
    final seen = <String?>[];
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient((request) async {
        seen.add(request.headers['authorization']);
        return request.headers['authorization'] == 'Bearer $stale'
            ? _json({'code': 'unauthorized'}, status: 401)
            : _json({'ok': true});
      }),
      tokens: auth,
    );
    final calls = [client.get('/a'), client.get('/b'), client.get('/c')];
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    expect(await Future.wait(calls), everyElement({'ok': true}));
    expect(authApi.refreshed, 1);
    expect(seen.where((h) => h == 'Bearer $stale'), hasLength(3));
  });

  test('problem+json errors become ApiError with the code', () async {
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient(
        (request) async => _json(
          {
            'type': 'about:blank',
            'title': 'Room is full',
            'status': 409,
            'code': 'room_full',
            'errors': [
              {'path': '/room_code', 'message': 'full'},
            ],
          },
          status: 409,
          type: 'application/problem+json',
        ),
      ),
      tokens: _Tokens(),
    );
    await expectLater(
      client.post('/v1/rooms/join'),
      throwsA(
        isA<ApiError>()
            .having((e) => e.code, 'code', 'room_full')
            .having((e) => e.status, 'status', 409)
            .having((e) => e.title, 'title', 'Room is full')
            .having((e) => e.fieldErrors.single.path, 'path', '/room_code'),
      ),
    );
  });

  test('transport failures are typed', () async {
    final client = ApiClient(
      baseUrl: base,
      httpClient: MockClient(
        (request) async => throw http.ClientException('offline'),
      ),
      tokens: _Tokens(),
    );
    await expectLater(
      client.get('/v1/me'),
      throwsA(isA<ApiError>().having((e) => e.isNetwork, 'isNetwork', isTrue)),
    );
  });

  group('AuthService token provider', () {
    AuthService service(FakeAuthApi api, SessionRepository sessions) =>
        AuthService(
          api: api,
          sessions: sessions,
          appInfo: const FakeAppInfoSource(
            AppInfo(
              version: '1.0.0',
              buildNumber: '1',
              platform: AppPlatform.ios,
              osVersion: 'iOS 26.0',
            ),
          ),
          localeTag: () => 'pl-PL',
        );

    test('creates a guest with os_version and locale', () async {
      final api = FakeAuthApi();
      final auth = service(api, SessionRepository(InMemorySecureStore()));
      expect(await auth.accessToken(), 'access-guest-1:1');
      expect(api.lastRegistration?.osVersion, 'iOS 26.0');
      expect(api.lastRegistration?.locale, 'pl-PL');
    });

    test('concurrent 401s rotate the refresh token only once', () async {
      final gate = Completer<void>();
      final api = FakeAuthApi()..refreshGate = gate.future;
      final sessions = SessionRepository(InMemorySecureStore());
      final auth = service(api, sessions);
      final stale = (await auth.accessToken())!;
      final a = auth.refreshAfterUnauthorized(stale);
      final b = auth.refreshAfterUnauthorized(stale);
      gate.complete();
      final tokens = await Future.wait([a, b]);
      expect(api.refreshed, 1);
      expect(tokens.toSet(), hasLength(1));
      expect(tokens.first, isNot(stale));
      // A request that failed with the old token after the rotation reuses
      // the new one without another refresh.
      expect(await auth.refreshAfterUnauthorized(stale), tokens.first);
      expect(api.refreshed, 1);
    });

    test('a revoked family starts a new guest session', () async {
      final api = FakeAuthApi();
      final sessions = SessionRepository(InMemorySecureStore());
      final auth = service(api, sessions);
      final stale = (await auth.accessToken())!;
      api.refreshFailWith = const ApiError(code: 'token_reused', status: 401);
      final fresh = await auth.refreshAfterUnauthorized(stale);
      expect(api.guestCreated, 2);
      expect(fresh, 'access-guest-2:1');
    });
  });

  group('HttpRoomsApi', () {
    test('create uses a limited-use token and parses the response', () async {
      late Map<String, Object?> body;
      final appCheck = FakeAppCheckService();
      final api = HttpRoomsApi(
        ApiClient(
          baseUrl: base,
          httpClient: MockClient((request) async {
            body = jsonDecode(request.body) as Map<String, Object?>;
            return _json({
              'room_id': 'r1',
              'room_code': '7KQ2MX',
              'player_id': 'p1',
              'config_snapshot': {
                'rounds_free_options': [5, 10],
              },
              'config_version': '18a4b88131908136',
            });
          }),
          tokens: _Tokens(),
          appCheck: appCheck,
        ),
      );
      final created = await api.createRoom(
        mode: GameMode.guessTrack,
        provider: MusicProviderId.testCatalog,
        displayName: 'Ania',
      );
      expect(body, {
        'mode': 'guess_track',
        'provider': 'test_catalog',
        'display_name': 'Ania',
      });
      expect(created.roomCode, '7KQ2MX');
      expect(created.config.roundsFreeOptions, [5, 10]);
      expect(appCheck.limitedUseTokensIssued, 1);
    });
  });
}
