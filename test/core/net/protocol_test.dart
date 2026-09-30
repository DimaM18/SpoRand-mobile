import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/platform/app_platform.dart';

import '../../support/protocol_samples.dart';

/// Every §4.3 message type, as listed in the brief.
const serverTypes = {
  'welcome', 'clock.ping', 'clock.result', 'room.state', //
  'room.player_joined', 'room.player_left', 'room.player_updated',
  'room.closed', 'game.starting', 'round.prepare', 'round.start',
  'round.answer_ack', 'round.progress', 'round.voided', 'round.reveal',
  'game.bonus_offer', 'bonus.sponsor_locked', 'bonus.nonce',
  'bonus.granted', 'bonus.cancelled', 'game.ad_break', 'game.results',
  'player.entitlements_updated', 'server.draining', 'error',
};

const clientTypes = {
  'hello', 'clock.pong', 'app.state', 'lobby.ready', //
  'lobby.update_settings', 'lobby.kick', 'lobby.set_can_dj', 'game.start',
  'round.preloaded',
  'round.playback_started', 'round.playback_failed', 'round.answer',
  'bonus.request', 'bonus.ad_result', 'ad.interstitial_result',
  'game.play_again', 'room.leave',
};

WsEnvelope _wire(WsEnvelope envelope) =>
    WsEnvelope.tryParse(jsonDecode(jsonEncode(envelope.toJson())))!;

/// [actual] must be contained in [expected] (fields a newer server adds to a
/// fixture are fine; everything this client reads must match).
void expectSubset(Object? actual, Object? expected, [String path = r'$']) {
  if (actual is Map) {
    expect(expected, isA<Map<String, Object?>>(), reason: path);
    final map = expected! as Map<String, Object?>;
    for (final MapEntry(:key, :value) in actual.entries) {
      expect(map.containsKey(key), isTrue, reason: '$path.$key missing');
      expectSubset(value, map[key], '$path.$key');
    }
  } else if (actual is List) {
    expect(expected, isA<List<Object?>>(), reason: path);
    final list = expected! as List<Object?>;
    expect(actual.length, list.length, reason: path);
    for (var i = 0; i < actual.length; i++) {
      expectSubset(actual[i], list[i], '$path[$i]');
    }
  } else {
    expect(actual, expected, reason: path);
  }
}

void main() {
  group('server messages round-trip through JSON', () {
    for (final message in Samples.allServerMessages()) {
      test(message.type, () {
        final envelope = _wire(message.toEnvelope(7));
        expect(envelope.v, WsEnvelope.protocolVersion);
        expect(envelope.seq, 7);
        expect(envelope.type, message.type);
        final parsed = ServerMessage.fromEnvelope(envelope);
        expect(parsed.runtimeType, message.runtimeType);
        expect(parsed.toJson(), equals(message.toJson()));
      });
    }

    test('every server type has a class and a sample', () {
      final sampled = {for (final m in Samples.allServerMessages()) m.type};
      expect(sampled, serverTypes);
      for (final type in serverTypes) {
        expect(
          () => ServerMessage.fromJson(type, const {}),
          throwsA(isA<ProtocolFormatException>()),
          reason: '$type must be a typed message, not UnknownServerMessage',
        );
      }
    });
  });

  group('client messages round-trip through JSON', () {
    for (final message in Samples.allClientMessages()) {
      test('${message.type} ${message.toJson().keys.length}', () {
        final envelope = _wire(message.toEnvelope(3));
        final parsed = ClientMessage.fromEnvelope(envelope);
        expect(parsed.runtimeType, message.runtimeType);
        expect(parsed.toJson(), equals(message.toJson()));
      });
    }

    test('every client type has a class and a sample', () {
      expect({
        for (final m in Samples.allClientMessages()) m.type,
      }, clientTypes);
    });

    test('optional fields are omitted, never sent as null', () {
      const hello = Hello(
        ticket: 'wst_4f9d2c7a1b8e6f3d0c5a9b2e',
        appVersion: '1.0.0',
        platform: AppPlatform.ios,
      );
      expect(hello.toJson().containsKey('last_seq'), isFalse);
      const settings = LobbyUpdateSettings(
        mode: GameMode.guessTrack,
        roundsTotal: 5,
        explicitFilter: true,
        poolSources: [PoolSource.catalogPack],
      );
      expect(settings.toJson().keys, isNot(contains('pack_id')));
      expect(settings.toJson().keys, isNot(contains('shuffle_strategy')));
    });
  });

  group('forward compatibility', () {
    test('unknown message types are kept as UnknownServerMessage', () {
      final message = ServerMessage.fromJson('game.awards', const {'x': 1});
      expect(message, isA<UnknownServerMessage>());
    });

    test('unknown reason values map to unknown', () {
      final closed = ServerMessage.fromJson('room.closed', const {
        'reason': 'moderation',
      });
      expect((closed as RoomClosed).reason, RoomClosedReason.unknown);
    });

    test('unknown fields are ignored', () {
      final start = ServerMessage.fromJson('round.start', const {
        'round_id': 'r',
        'audio_start_server_ms': 5,
        'future_field': true,
      });
      expect((start as RoundStart).audioStartServerMs, 5);
    });

    test('a missing required field is a format error', () {
      expect(
        () => ServerMessage.fromJson('round.progress', const {
          'round_id': 'r',
          'answered_count': 1,
        }),
        throwsA(isA<ProtocolFormatException>()),
      );
    });

    test('integral doubles are accepted for int64 fields', () {
      final ping = ServerMessage.fromJson('clock.ping', const {
        'ping_id': 'p',
        't1_server_us': 1759212345678901.0,
      });
      expect((ping as ClockPing).t1ServerUs, 1759212345678901);
    });
  });

  // Contract check against the golden fixtures of packages/protocol (read
  // only). Skipped when the monorepo sibling is not checked out.
  final fixtures = Directory('../../packages/protocol/fixtures/ws');
  group('packages/protocol golden fixtures', () {
    test('server fixtures parse into typed messages', () {
      final files = Directory('${fixtures.path}/s2c')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        final json = jsonDecode(file.readAsStringSync());
        final envelope = WsEnvelope.tryParse(json)!;
        final message = ServerMessage.fromEnvelope(envelope);
        expect(message, isNot(isA<UnknownServerMessage>()), reason: file.path);
        expectSubset(message.toEnvelope(envelope.seq).toJson(), json);
      }
    });

    test('client fixtures equal what this client sends', () {
      final files = Directory('${fixtures.path}/c2s')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList();
      expect(files, isNotEmpty);
      for (final file in files) {
        final json = jsonDecode(file.readAsStringSync());
        final envelope = WsEnvelope.tryParse(json)!;
        final message = ClientMessage.fromEnvelope(envelope);
        expect(
          message.toEnvelope(envelope.seq).toJson(),
          equals(json),
          reason: file.path,
        );
      }
    });

    test('an invalid server fixture is rejected', () {
      final file = File('${fixtures.path}/invalid/s2c-missing-field.json');
      final frame = (jsonDecode(file.readAsStringSync()) as JsonMap)['frame'];
      expect(
        () => ServerMessage.fromEnvelope(WsEnvelope.tryParse(frame)!),
        throwsA(isA<ProtocolFormatException>()),
      );
    });
  }, skip: fixtures.existsSync() ? false : 'packages/protocol not present');
}
