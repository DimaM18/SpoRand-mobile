import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// RFC 9457 problem (`application/problem+json` with a `code`, brief §4.2).
final class ApiException implements Exception {
  const ApiException(this.statusCode, {this.code, this.detail});

  final int statusCode;
  final String? code;
  final String? detail;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'ApiException($statusCode, code: $code)';
}

/// Minimal JSON REST client for `https://api.<domain>`. Adds the bearer
/// token and the App Check header; never logs tokens.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 10),
  }) : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final Duration timeout;
  final http.Client _http;

  Future<Map<String, Object?>> postJson(
    String path, {
    Map<String, Object?> body = const {},
    String? bearer,
    String? appCheckToken,
  }) async {
    final response = await _http
        .post(
          baseUrl.resolve(path),
          headers: {
            'content-type': 'application/json',
            'accept': 'application/json, application/problem+json',
            'authorization': ?(bearer == null ? null : 'Bearer $bearer'),
            'x-firebase-appcheck': ?appCheckToken,
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    return _decode(response);
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
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    if (response.statusCode >= 200 && response.statusCode < 300) return map;
    final code = map['code'];
    final detail = map['detail'];
    throw ApiException(
      response.statusCode,
      code: code is String ? code : null,
      detail: detail is String ? detail : null,
    );
  }

  void close() => _http.close();
}
