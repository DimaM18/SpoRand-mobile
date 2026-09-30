import 'dart:convert';

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';

import 'rest_tap.dart';
import 'wire_tap.dart';

typedef _Codec = JsonMap Function(JsonMap json);

/// The REST calls the app makes: the request and response DTO of each.
/// A call missing here is a problem too (the audit must know every call).
final List<({String method, RegExp path, _Codec? request, _Codec? response})>
_restCodecs = [
  (
    method: 'POST',
    path: RegExp(r'^/v1/auth/guest$'),
    request: (j) => GuestAuthRequest.fromJson(j).toJson(),
    response: (j) => AuthTokensResponse.fromJson(j).toJson(),
  ),
  (
    method: 'POST',
    path: RegExp(r'^/v1/auth/refresh$'),
    request: (j) => RefreshTokenRequest.fromJson(j).toJson(),
    response: (j) => AuthTokensResponse.fromJson(j).toJson(),
  ),
  (
    method: 'PATCH',
    path: RegExp(r'^/v1/me$'),
    request: (j) => MePatchRequest.fromJson(j).toJson(),
    // The app ignores the MeResponse body (AgeBandSync needs only a 2xx).
    response: null,
  ),
  (
    method: 'GET',
    path: RegExp(r'^/v1/me$'),
    request: null,
    response: (j) => MeResponse.fromJson(j).toJson(),
  ),
  (
    method: 'PUT',
    path: RegExp(r'^/v1/me/consent$'),
    request: (j) => ConsentUpdateRequest.fromJson(j).toJson(),
    response: (j) => ConsentState.fromJson(j).toJson(),
  ),
  (
    method: 'GET',
    path: RegExp(r'^/v1/songs/search$'),
    request: null,
    response: (j) => SongSearchResponse.fromJson(j).toJson(),
  ),
  (
    method: 'GET',
    path: RegExp(r'^/v1/me/picks$'),
    request: null,
    response: (j) => PicksResponse.fromJson(j).toJson(),
  ),
  (
    method: 'PUT',
    path: RegExp(r'^/v1/me/picks$'),
    request: (j) => PicksUpdateRequest.fromJson(j).toJson(),
    response: (j) => PicksResponse.fromJson(j).toJson(),
  ),
  (
    method: 'POST',
    path: RegExp(r'^/v1/rooms$'),
    request: (j) => RoomCreateRequest.fromJson(j).toJson(),
    response: (j) => RoomCreateResponse.fromJson(j).toJson(),
  ),
  (
    method: 'POST',
    path: RegExp(r'^/v1/rooms/join$'),
    request: (j) => RoomJoinRequest.fromJson(j).toJson(),
    response: (j) => RoomJoinResponse.fromJson(j).toJson(),
  ),
  (
    method: 'POST',
    path: RegExp(r'^/v1/rooms/[^/]+/ws-ticket$'),
    // The body is `{}`.
    request: (j) => j,
    response: (j) => WsTicketResponse.fromJson(j).toJson(),
  ),
  (
    method: 'PUT',
    path: RegExp(r'^/v1/rooms/[^/]+/pool$'),
    request: (j) => PoolPutRequest.fromJson(j).toJson(),
    response: (j) => PoolContributionView.fromJson(j).toJson(),
  ),
  (
    method: 'GET',
    path: RegExp(r'^/v1/rooms/[^/]+$'),
    request: null,
    response: (j) => RoomSnapshot.fromJson(j).toJson(),
  ),
];

/// Contract sanity over live traffic: every server frame a phone got from
/// the real server must decode with the app's DTOs (`ServerMessage`), must
/// not be an [UnknownServerMessage], and must re-encode to the same JSON
/// (modulo omitted nulls). The last check catches a field the server sends
/// that the Dart DTO silently drops, which fixtures alone cannot: fixtures
/// only show the fields someone wrote into them.
final class ContractAudit {
  final List<WireTap> _taps = [];
  final List<RestTap> _rest = [];

  void watch(WireTap tap) => _taps.add(tap);

  void watchRest(RestTap tap) => _rest.add(tap);

  /// REST calls checked so far, as `METHOD /path` with ids collapsed.
  Map<String, int> get restCounts {
    final counts = <String, int>{};
    for (final tap in _rest) {
      for (final call in tap.exchanges) {
        final key =
            '${call.method} ${call.path.replaceAll(RegExp('[0-9a-f-]{36}'), '{id}')} ${call.status}';
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Every REST exchange: the request body must parse with the app's strict
  /// request DTO and round-trip, and the response with the response DTO
  /// (errors: `Problem`).
  List<String> restProblems() {
    final problems = <String>[];
    for (final tap in _rest) {
      for (final call in tap.exchanges) {
        final problem = _checkRest(call);
        if (problem != null) problems.add('${tap.name} $call: $problem');
      }
    }
    return problems;
  }

  static String? _checkRest(RestExchange call) {
    final codecs = _restCodecs.where(
      (c) => c.method == call.method && c.path.hasMatch(call.path),
    );
    if (codecs.isEmpty) return 'no DTO known for this call';
    final codec = codecs.first;
    String? roundTrip(String part, Object? json, _Codec? decode) {
      if (decode == null) return null;
      if (json is! JsonMap) return '$part is not a JSON object';
      try {
        final diff = _firstDifference(
          _withoutNulls(json),
          _withoutNulls(jsonDecode(jsonEncode(decode(json)))),
          r'$',
        );
        return diff == null ? null : '$part does not round-trip: $diff';
      } on ProtocolFormatException catch (e) {
        return '$part rejected by the Dart DTO: ${e.message}';
      }
    }

    final ok = call.status >= 200 && call.status < 300;
    return roundTrip('request', call.requestJson, codec.request) ??
        (ok
            ? roundTrip('response', call.responseJson, codec.response)
            : roundTrip(
                'problem',
                call.responseJson,
                (j) => Problem.fromJson(j).toJson(),
              ));
  }

  /// Frames checked so far, by message type.
  Map<String, int> get typeCounts {
    final counts = <String, int>{};
    for (final frame in _frames) {
      final type = frame.type ?? '<none>';
      counts[type] = (counts[type] ?? 0) + 1;
    }
    return counts;
  }

  Iterable<WireFrame> get _frames sync* {
    for (final tap in _taps) {
      // Lost frames count too: the server sent them, and the replay after a
      // reconnect repeats them.
      yield* tap.received;
      yield* tap.lost;
    }
  }

  /// One line per problem; empty when every frame passed.
  List<String> problems() {
    final problems = <String>[];
    for (final tap in _taps) {
      for (final frame in [...tap.received, ...tap.lost]) {
        final problem = _check(frame);
        if (problem != null) problems.add('${tap.name} $frame: $problem');
      }
    }
    return problems;
  }

  /// The same for what the phones sent (the app's strict client DTOs), plus
  /// the wire rule the server enforces silently: client `seq` strictly
  /// increases per connection (a frame below the last one is dropped as a
  /// replay).
  List<String> clientProblems() {
    final problems = <String>[];
    for (final tap in _taps) {
      final lastSeq = <int, int>{};
      for (final frame in tap.sent) {
        final seq = frame.seq ?? -1;
        final previous = lastSeq[frame.connection] ?? 0;
        if (seq <= previous) {
          problems.add('${tap.name} $frame: seq after $previous');
        }
        lastSeq[frame.connection] = seq;
        final problem = _checkClient(frame);
        if (problem != null) problems.add('${tap.name} $frame: $problem');
      }
    }
    return problems;
  }

  static String? _checkClient(WireFrame frame) {
    final json = frame.json;
    final envelope = json == null ? null : WsEnvelope.tryParse(json);
    if (envelope == null) return 'not a v1 envelope: ${frame.raw}';
    try {
      final message = ClientMessage.fromEnvelope(envelope);
      final diff = _firstDifference(
        _withoutNulls(json),
        _withoutNulls(
          jsonDecode(jsonEncode(message.toEnvelope(envelope.seq).toJson())),
        ),
        r'$',
      );
      return diff == null ? null : 'does not round-trip: $diff';
    } on ProtocolFormatException catch (e) {
      return 'rejected by the strict client DTO: ${e.message}';
    }
  }

  static String? _check(WireFrame frame) {
    final json = frame.json;
    if (json == null) return 'not a JSON object: ${frame.raw}';
    final envelope = WsEnvelope.tryParse(json);
    if (envelope == null) return 'not a v1 envelope: ${frame.raw}';
    final ServerMessage message;
    try {
      message = ServerMessage.fromEnvelope(envelope);
    } on ProtocolFormatException catch (e) {
      return 'rejected by the Dart DTO: ${e.message}';
    }
    if (message is UnknownServerMessage) {
      return 'unknown type ${envelope.type}';
    }
    final original = _withoutNulls(json);
    final reencoded = _withoutNulls(
      jsonDecode(jsonEncode(message.toEnvelope(envelope.seq).toJson())),
    );
    final diff = _firstDifference(original, reencoded, r'$');
    return diff == null ? null : 'does not round-trip: $diff';
  }

  static Object? _withoutNulls(Object? json) => switch (json) {
    final Map<Object?, Object?> map => {
      for (final MapEntry(:key, :value) in map.entries)
        if (value != null) key: _withoutNulls(value),
    },
    final List<Object?> list => [for (final item in list) _withoutNulls(item)],
    _ => json,
  };

  /// The first path where [a] (server) and [b] (Dart re-encoding) differ.
  static String? _firstDifference(Object? a, Object? b, String path) {
    if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
      for (final key in {...a.keys, ...b.keys}) {
        if (!a.containsKey(key)) return '$path.$key added by the DTO';
        if (!b.containsKey(key)) return '$path.$key dropped by the DTO';
        final diff = _firstDifference(a[key], b[key], '$path.$key');
        if (diff != null) return diff;
      }
      return null;
    }
    if (a is List<Object?> && b is List<Object?>) {
      if (a.length != b.length) {
        return '$path has ${a.length} items, re-encoded ${b.length}';
      }
      for (var i = 0; i < a.length; i++) {
        final diff = _firstDifference(a[i], b[i], '$path[$i]');
        if (diff != null) return diff;
      }
      return null;
    }
    // JSON numbers: 1 and 1.0 are the same value.
    if (a is num && b is num) return a == b ? null : '$path: $a != $b';
    return a == b ? null : '$path: ${jsonEncode(a)} != ${jsonEncode(b)}';
  }
}
