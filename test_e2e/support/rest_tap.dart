import 'dart:convert';

import 'package:http/http.dart' as http;

import 'e2e_env.dart';

/// One REST call of a simulated phone, bodies included.
final class RestExchange {
  RestExchange({
    required this.method,
    required this.url,
    required this.status,
    required this.requestBody,
    required this.responseBody,
    required this.atUs,
  });

  final String method;
  final Uri url;
  final int status;

  /// Null when the request had no body.
  final String? requestBody;
  final String responseBody;
  final int atUs;

  String get path => url.path;

  Object? get requestJson => _decode(requestBody);
  Object? get responseJson => _decode(responseBody);

  static Object? _decode(String? body) {
    if (body == null || body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => '$method $path -> $status';
}

/// The `http.Client` under a phone's real `ApiClient`: a plain
/// `http.Client()` that records every exchange for the contract audit.
final class RestTap extends http.BaseClient {
  RestTap(this.name);

  final String name;
  final http.Client _inner = http.Client();
  final List<RestExchange> exchanges = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final requestBody = request is http.Request && request.body.isNotEmpty
        ? request.body
        : null;
    final response = await _inner.send(request);
    final bytes = await response.stream.toBytes();
    exchanges.add(
      RestExchange(
        method: request.method,
        url: request.url,
        status: response.statusCode,
        requestBody: requestBody,
        responseBody: utf8.decode(bytes, allowMalformed: true),
        atUs: e2eNowUs(),
      ),
    );
    return http.StreamedResponse(
      http.ByteStream.fromBytes(bytes),
      response.statusCode,
      contentLength: bytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  /// Both of the phone's `ApiClient`s share this client and close it when
  /// their providers are disposed; the phone calls [shutdown] once instead.
  @override
  void close() {}

  void shutdown() => _inner.close();
}
