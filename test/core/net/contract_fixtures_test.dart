// Contract drift test: every JSON fixture of packages/protocol (the single
// source of truth for wire contracts) must round-trip through the app's
// hand-written DTOs in lib/core/net/protocol/, or be listed below with the
// reason the app does not consume it. A new fixture therefore fails this test
// until someone decides which of the two it is.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';

typedef _Codec = JsonMap Function(JsonMap json);

/// REST fixture key (`<endpoint_id>.<part>` or `problem`) -> decode and
/// re-encode with the app's DTO.
final Map<String, _Codec> _restCodecs = {
  'auth_guest.request': (j) => GuestAuthRequest.fromJson(j).toJson(),
  'auth_guest.response': (j) => AuthTokensResponse.fromJson(j).toJson(),
  'auth_refresh.request': (j) => RefreshTokenRequest.fromJson(j).toJson(),
  'auth_refresh.response': (j) => AuthTokensResponse.fromJson(j).toJson(),
  'auth_logout.request': (j) => RefreshTokenRequest.fromJson(j).toJson(),
  'rooms_create.request': (j) => RoomCreateRequest.fromJson(j).toJson(),
  'rooms_create.response': (j) => RoomCreateResponse.fromJson(j).toJson(),
  'rooms_join.request': (j) => RoomJoinRequest.fromJson(j).toJson(),
  'rooms_join.response': (j) => RoomJoinResponse.fromJson(j).toJson(),
  'room_get.response': (j) => RoomSnapshot.fromJson(j).toJson(),
  'room_ws_ticket.response': (j) => WsTicketResponse.fromJson(j).toJson(),
  'room_report_create.request': (j) => ReportCreateRequest.fromJson(j).toJson(),
  'room_report_create.response': (j) =>
      ReportCreateResponse.fromJson(j).toJson(),
  'room_pool_put.request': (j) => PoolPutRequest.fromJson(j).toJson(),
  'room_pool_put.response': (j) => PoolContributionView.fromJson(j).toJson(),
  'songs_search.query': (j) => SongSearchQuery.fromJson(j).toJson(),
  'songs_search.response': (j) => SongSearchResponse.fromJson(j).toJson(),
  'me_patch.request': (j) => MePatchRequest.fromJson(j).toJson(),
  'me_get.response': (j) => MeResponse.fromJson(j).toJson(),
  'me_consent_put.request': (j) => ConsentUpdateRequest.fromJson(j).toJson(),
  'me_consent_put.response': (j) => ConsentState.fromJson(j).toJson(),
  'me_picks_get.response': (j) => PicksResponse.fromJson(j).toJson(),
  'me_picks_put.request': (j) => PicksUpdateRequest.fromJson(j).toJson(),
  'me_picks_put.response': (j) => PicksResponse.fromJson(j).toJson(),
  'problem': (j) => Problem.fromJson(j).toJson(),
};

/// REST fixtures the app does not read or send, and why.
const Map<String, String> _restNotConsumed = {
  'catalog_packs.response': 'legacy catalogue packs; no pack picker yet',
  'catalog_search.query':
      'legacy catalogue search; «Мои песни» search '
      'songs (A2.3)',
  'catalog_search.response': 'legacy catalogue search (A2.3)',
  'healthz.response': 'ops probe',
  'readyz.response': 'ops probe',
  'me_delete.response': 'not called by the app yet',
  'me_export.response': 'not called by the app yet',
  'me_patch.response': 'the body is ignored (AgeBandSync only needs 2xx)',
  'me_entitlements_sync.response':
      'the body is ignored; entitlements come from RevenueCat',
  'public_deletion_request.request': 'web deletion form, not the app',
  'public_deletion_request.response': 'web deletion form, not the app',
  'webhook_admob_ssv.query': 'third party -> server',
  'webhook_apple_assn.request': 'third party -> server',
  'webhook_google_rtdn.request': 'third party -> server',
  'webhook_revenuecat.request': 'third party -> server',
};

/// Fixture directories that hold no wire message, and why.
const Map<String, String> _dirsNotConsumed = {
  'emoji/':
      'the emoji catalogue is server data; the app only sees '
      'round.prepare.emoji_prompt and round.reveal',
};

/// `ws/invalid` fixtures the app's DTOs deliberately accept, and why. The
/// test also fails if one of these starts being rejected, so the list stays
/// honest.
const Map<String, String> _invalidNotValidated = {
  's2c-bad-id.json': 'the app does not check id formats (the server does)',
};

/// Optional fields are omitted, never null: compare modulo null values.
Object? _withoutNulls(Object? json) => switch (json) {
  final Map<Object?, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      if (value != null) key: _withoutNulls(value),
  },
  final List<Object?> list => [for (final item in list) _withoutNulls(item)],
  _ => json,
};

Object? _normalize(Object? json) => _withoutNulls(jsonDecode(jsonEncode(json)));

final _root = Directory('../../packages/protocol/fixtures');

List<File> _jsonFiles(String relative) {
  final dir = relative.isEmpty ? _root : Directory('${_root.path}/$relative');
  if (!dir.existsSync()) return const [];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
}

String _rel(File file) => file.path.substring(_root.path.length + 1);

JsonMap _read(File file) => jsonDecode(file.readAsStringSync()) as JsonMap;

/// The REST key of a golden (`rest/<key>.json`) or variant
/// (`rest/variants/<key>/<variant>.json`) fixture.
String _restKey(String relative) {
  final parts = relative.split('/');
  final key = parts.length == 4 && parts[1] == 'variants'
      ? parts[2]
      : parts.last.replaceFirst(RegExp(r'\.json$'), '');
  return key.startsWith('problem.') ? 'problem' : key;
}

void _expectRoundTrip(Object? reencoded, Object? original, String reason) =>
    expect(_normalize(reencoded), _normalize(original), reason: reason);

/// True when the app's parsers reject [frame] (as the server would).
bool _rejects(String direction, JsonMap frame) {
  final envelope = WsEnvelope.tryParse(frame);
  if (envelope == null) return true;
  try {
    if (direction == 's2c') {
      // An unknown server type is forward compatible, not an error.
      ServerMessage.fromEnvelope(envelope);
    } else {
      ClientMessage.fromEnvelope(envelope);
    }
  } on ProtocolFormatException {
    return true;
  }
  return false;
}

void main() {
  final skip = _root.existsSync()
      ? false
      : 'packages/protocol is not checked out next to apps/mobile';

  group('packages/protocol fixtures round-trip through the app DTOs', () {
    test('every fixture is classified', () {
      final all = _jsonFiles('');
      expect(all, isNotEmpty);
      for (final file in all) {
        final rel = _rel(file);
        final known =
            RegExp(r'^ws/(s2c|c2s)/[a-z_.]+\.json$').hasMatch(rel) ||
            RegExp(r'^ws/variants/(s2c|c2s)/[a-z_.]+/\w+\.json$')
                .hasMatch(rel) ||
            RegExp(r'^ws/invalid/[\w-]+\.json$').hasMatch(rel) ||
            _dirsNotConsumed.keys.any(rel.startsWith) ||
            (rel.startsWith('rest/') &&
                (_restCodecs.containsKey(_restKey(rel)) ||
                    _restNotConsumed.containsKey(_restKey(rel))));
        expect(known, isTrue, reason: '$rel is not classified');
      }
    }, skip: skip);

    for (final direction in ['s2c', 'c2s']) {
      test('ws $direction goldens and variants', () {
        final files = [
          ..._jsonFiles('ws/$direction'),
          ..._jsonFiles('ws/variants/$direction'),
        ];
        expect(files, isNotEmpty);
        for (final file in files) {
          final json = _read(file);
          final envelope = WsEnvelope.tryParse(json);
          expect(envelope, isNotNull, reason: _rel(file));
          final path = _rel(file);
          if (direction == 's2c') {
            final message = ServerMessage.fromEnvelope(envelope!);
            expect(message, isNot(isA<UnknownServerMessage>()), reason: path);
            expect(message.type, envelope.type, reason: path);
            _expectRoundTrip(
              message.toEnvelope(envelope.seq).toJson(),
              json,
              path,
            );
          } else {
            final message = ClientMessage.fromEnvelope(envelope!);
            expect(message.type, envelope.type, reason: path);
            _expectRoundTrip(
              message.toEnvelope(envelope.seq).toJson(),
              json,
              path,
            );
          }
        }
      }, skip: skip);
    }

    test('ws invalid frames are rejected where the DTO validates', () {
      final files = _jsonFiles('ws/invalid');
      expect(files, isNotEmpty);
      for (final file in files) {
        final fixture = _read(file);
        final name = file.uri.pathSegments.last;
        final rejected = _rejects(
          fixture['direction']! as String,
          fixture['frame']! as JsonMap,
        );
        expect(
          rejected,
          !_invalidNotValidated.containsKey(name),
          reason:
              '$name (${fixture['expected_kind']}): '
              '${_invalidNotValidated[name] ?? fixture['note']}',
        );
      }
    }, skip: skip);

    test('rest goldens and variants', () {
      final files = _jsonFiles('rest');
      expect(files, isNotEmpty);
      var decoded = 0;
      for (final file in files) {
        final rel = _rel(file);
        final codec = _restCodecs[_restKey(rel)];
        if (codec == null) continue;
        final json = _read(file);
        _expectRoundTrip(codec(json), json, rel);
        decoded++;
      }
      expect(decoded, greaterThanOrEqualTo(_restCodecs.length));
    }, skip: skip);

    test('the not-consumed lists name real fixtures', () {
      final restKeys = {for (final f in _jsonFiles('rest')) _restKey(_rel(f))};
      for (final key in [..._restCodecs.keys, ..._restNotConsumed.keys]) {
        expect(restKeys, contains(key), reason: 'no fixture for $key');
      }
      final invalid = {
        for (final f in _jsonFiles('ws/invalid')) f.uri.pathSegments.last,
      };
      expect(invalid, containsAll(_invalidNotValidated.keys));
      for (final dir in _dirsNotConsumed.keys) {
        expect(
          _jsonFiles(dir.substring(0, dir.length - 1)),
          isNotEmpty,
          reason: 'no fixtures under $dir',
        );
      }
    }, skip: skip);
  });

  group('cross-field rules the DTOs enforce', () {
    JsonMap prepare(Map<String, Object?> changes) {
      final file = File('${_root.path}/ws/s2c/round.prepare.json');
      final payload = Map<String, Object?>.of(
        _read(file)['payload']! as JsonMap,
      )..addAll(changes);
      return payload..removeWhere((_, v) => v == null);
    }

    const cue = {
      'title': 'Northern Lights',
      'artists': ['Test Artist'],
    };

    test('a cue needs a host-reported start', () {
      expect(
        () => RoundPrepare.fromJson(prepare({'clip': null, 'cue': cue})),
        throwsA(isA<ProtocolFormatException>()),
      );
    }, skip: skip);

    test('text_round goes with audio_start_source none, without clip', () {
      expect(
        () => RoundPrepare.fromJson(prepare({'prompt': 'text_round'})),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => RoundPrepare.fromJson(
          prepare({'audio_start_source': 'none', 'clip': null}),
        ),
        throwsA(isA<ProtocolFormatException>()),
        reason: 'audio_start_source none needs prompt text_round',
      );
    }, skip: skip);

    test('text_prompt only in a text round', () {
      expect(
        () => RoundPrepare.fromJson(prepare({'text_prompt': cue})),
        throwsA(isA<ProtocolFormatException>()),
      );
    }, skip: skip);

    test('a pick is a song pick or a catalogue pick, never both', () {
      final file = File('${_root.path}/rest/me_picks_get.response.json');
      final pick = Map<String, Object?>.of(
        (_read(file)['picks']! as List<Object?>).first! as JsonMap,
      )..['catalog_track_id'] = '0192b1a0-0000-7000-8000-000000000801';
      expect(
        () => CatalogPick.fromJson(pick),
        throwsA(isA<ProtocolFormatException>()),
      );
    }, skip: skip);

    test('picks update takes exactly one list', () {
      expect(
        () => PicksUpdateRequest.fromJson(const {
          'song_ids': ['a', 'b', 'c', 'd', 'e'],
          'catalog_track_ids': ['a', 'b', 'c', 'd', 'e'],
        }),
        throwsA(isA<ProtocolFormatException>()),
      );
      expect(
        () => PicksUpdateRequest.fromJson(const {}),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  });
}
