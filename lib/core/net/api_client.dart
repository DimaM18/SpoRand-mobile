import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/security/app_check_service.dart';

/// A failed REST call. Server errors carry the RFC 9457 problem `code`
/// (brief §4.2); transport failures use the client-side codes below.
final class ApiError implements Exception {
  const ApiError({
    required this.code,
    this.status,
    this.title,
    this.detail,
    this.fieldErrors = const [],
  });

  /// Client-side codes (never sent by the server).
  static const network = 'network_error';
  static const timeout = 'timeout';
  static const invalidResponse = 'invalid_response';

  /// Problem `code` (see packages/protocol PROBLEM_CODES) or a client code.
  final String code;

  /// HTTP status; null when no response arrived.
  final int? status;
  final String? title;
  final String? detail;
  final List<({String path, String message})> fieldErrors;

  bool get isUnauthorized => status == 401;
  bool get isNetwork => code == network || code == timeout;

  @override
  String toString() => 'ApiError($status, $code)';
}

/// Which App Check token a call carries (brief §7 "Attestation").
enum AppCheckUse {
  /// Standard token: every REST call.
  standard,

  /// Limited-use (`consume: true`): `POST /v1/auth/guest`, `POST /v1/rooms`,
  /// `POST /v1/me/entitlements/sync`.
  limitedUse,
}

/// Source of access tokens for authenticated calls (implemented by
/// `AuthService`).
abstract interface class AccessTokenProvider {
  /// A valid access token (refreshed first if it expired), or null when the
  /// app has no session.
  Future<String?> accessToken();

  /// Called when [rejectedToken] got a 401. Refreshes the session (the
  /// refresh token rotates) and returns the new access token. Concurrent
  /// callers share one refresh (single flight).
  Future<String?> refreshAfterUnauthorized(String rejectedToken);
}

/// JSON REST client for `https://api.<domain>` (brief §4.2).
///
/// - `Authorization: Bearer <access JWT>` on authenticated calls; one 401
///   triggers a single-flight refresh and one retry.
/// - `X-Firebase-AppCheck` on every call (standard or limited-use token).
/// - `application/problem+json` errors become [ApiError] with the `code`.
/// - Tokens never appear in logs or error messages.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this._tokens,
    this._appCheck,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  static const appCheckHeader = 'X-Firebase-AppCheck';

  final Uri baseUrl;
  final Duration timeout;
  final http.Client _http;
  final AccessTokenProvider? _tokens;
  final AppCheckService? _appCheck;

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => send('GET', path, query: query, authenticated: authenticated);

  /// [bearer] sends that access token as is (no refresh on 401): for the
  /// unauthenticated auth client, e.g. `POST /v1/auth/logout`.
  Future<Map<String, Object?>> post(
    String path, {
    Object? body,
    bool authenticated = true,
    AppCheckUse appCheck = AppCheckUse.standard,
    String? bearer,
  }) => send(
    'POST',
    path,
    body: body ?? const <String, Object?>{},
    authenticated: authenticated,
    appCheck: appCheck,
    bearer: bearer,
  );

  Future<Map<String, Object?>> put(String path, {Object? body}) =>
      send('PUT', path, body: body ?? const <String, Object?>{});

  Future<Map<String, Object?>> patch(String path, {Object? body}) =>
      send('PATCH', path, body: body ?? const <String, Object?>{});

  Future<Map<String, Object?>> delete(String path) => send('DELETE', path);

  Future<Map<String, Object?>> send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
    AppCheckUse appCheck = AppCheckUse.standard,
    String? bearer,
  }) async {
    final tokens = _tokens;
    if (bearer != null) {
      return _decode(
        await _perform(method, path, body, query, bearer, appCheck),
      );
    }
    if (authenticated && tokens == null) {
      throw StateError('ApiClient without tokens cannot call $path');
    }
    final token = authenticated ? await tokens!.accessToken() : null;
    var response = await _perform(method, path, body, query, token, appCheck);
    if (response.statusCode == 401 && authenticated && token != null) {
      final fresh = await tokens!.refreshAfterUnauthorized(token);
      if (fresh != null && fresh != token) {
        response = await _perform(method, path, body, query, fresh, appCheck);
      }
    }
    return _decode(response);
  }

  Future<http.Response> _perform(
    String method,
    String path,
    Object? body,
    Map<String, String>? query,
    String? bearer,
    AppCheckUse appCheck,
  ) async {
    final uri = baseUrl.resolve(path).replace(queryParameters: query);
    // A limited-use token is consumed by the server, so a retry needs a new
    // one; fetch it per attempt.
    final appCheckToken = switch (appCheck) {
      AppCheckUse.standard => await _appCheck?.getToken(),
      AppCheckUse.limitedUse => await _appCheck?.getLimitedUseToken(),
    };
    final request = http.Request(method, uri)
      ..headers.addAll({
        'accept': 'application/json, application/problem+json',
        'authorization': ?(bearer == null ? null : 'Bearer $bearer'),
        appCheckHeader: ?appCheckToken,
      });
    if (body != null) {
      request
        ..headers['content-type'] = 'application/json'
        ..body = jsonEncode(body);
    }
    try {
      final streamed = await _http.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiError(code: ApiError.timeout);
    } on http.ClientException {
      throw const ApiError(code: ApiError.network);
    }
  }

  static Map<String, Object?> _decode(http.Response response) {
    Object? json;
    if (response.body.isNotEmpty) {
      try {
        json = jsonDecode(response.body);
      } on FormatException {
        json = null;
      }
    }
    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) {
      if (json is Map<String, Object?>) return json;
      if (response.body.isEmpty) return const {};
      throw ApiError(
        code: ApiError.invalidResponse,
        status: response.statusCode,
      );
    }
    if (json is Map<String, Object?>) {
      final Problem problem;
      try {
        problem = Problem.fromJson(json);
      } on ProtocolFormatException {
        return _lenientError(response.statusCode, json);
      }
      throw ApiError(
        status: response.statusCode,
        code: problem.code,
        title: problem.title,
        detail: problem.detail,
        fieldErrors: [
          for (final e in problem.errors ?? const <ProblemFieldError>[])
            (path: e.path, message: e.message),
        ],
      );
    }
    return _lenientError(response.statusCode, const {});
  }

  /// A body that is not RFC 9457 (a proxy or load balancer answered): keep
  /// whatever can be read.
  static Never _lenientError(int status, Map<String, Object?> problem) {
    final code = problem['code'];
    final title = problem['title'];
    final detail = problem['detail'];
    final errors = problem['errors'];
    throw ApiError(
      status: status,
      code: code is String ? code : 'http_$status',
      title: title is String ? title : null,
      detail: detail is String ? detail : null,
      fieldErrors: [
        if (errors is List<Object?>)
          for (final e in errors)
            if (e is Map<String, Object?> &&
                e['path'] is String &&
                e['message'] is String)
              (path: e['path']! as String, message: e['message']! as String),
      ],
    );
  }

  void close() => _http.close();
}
