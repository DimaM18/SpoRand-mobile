import 'package:mobile_kit/mobile_kit.dart' as kit;

import 'package:sporand/app/router/routes.dart';

// Wave 8b: incoming links, the queue and the parser are mobile_kit's
// (mobile-template); SpoRand's join link reaches the kit parser as a
// `LinkMatcher` (`linkMatchersProvider`).
export 'package:mobile_kit/mobile_kit.dart'
    show AppLink, DeepLinkQueue, IncomingLink, LinkMatcher, PushLink, UriLink;

/// `room_join.via`.
enum JoinVia {
  code('code'),
  link('link'),
  qr('qr');

  const JoinVia(this.wire);

  final String wire;

  static JoinVia fromQuery(String? raw) => switch (raw) {
    'qr' => JoinVia.qr,
    'code' => JoinVia.code,
    _ => JoinVia.link,
  };
}

final class JoinRoomLink extends kit.AppLink {
  const JoinRoomLink(this.roomCode, {this.via = JoinVia.link});

  final String roomCode;
  final JoinVia via;

  @override
  String get location =>
      Routes.join(roomCode, via: via == JoinVia.link ? null : via.wire);

  @override
  bool operator ==(Object other) =>
      other is JoinRoomLink && other.roomCode == roomCode && other.via == via;

  @override
  int get hashCode => Object.hash(roomCode, via);
}

/// The join link `https://<domain>/j/{room_code}` (relative `/j/{code}`
/// too), and a push payload's `room_code` [новое имя — согласовать].
final class JoinRoomLinkMatcher implements kit.LinkMatcher {
  const JoinRoomLinkMatcher();

  @override
  kit.AppLink? matchUri(Uri uri) {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2 && segments[0] == 'j') {
      final code = DeepLinkParser.normalizeRoomCode(segments[1]);
      if (code != null) {
        return JoinRoomLink(
          code,
          via: JoinVia.fromQuery(uri.queryParameters['via']),
        );
      }
    }
    return null;
  }

  @override
  kit.AppLink? matchPush(Map<String, Object?> data) {
    final code = data['room_code'];
    if (code is! String) return null;
    final normalized = DeepLinkParser.normalizeRoomCode(code);
    return normalized == null ? null : JoinRoomLink(normalized);
  }
}

/// SpoRand's deep-link matchers (`linkMatchersProvider`)
/// [новое имя — согласовать].
const sporandLinkMatchers = <kit.LinkMatcher>[JoinRoomLinkMatcher()];

/// Parses incoming links into [kit.AppLink]s: mobile_kit's parser with
/// [sporandLinkMatchers]. Only the join link exists in the MVP.
class DeepLinkParser extends kit.DeepLinkParser {
  const DeepLinkParser({required super.allowedHosts})
    : super(matchers: sporandLinkMatchers);

  /// Crockford base32 alphabet used by room codes: no I, L, O, U.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const roomCodeLength = 6;

  /// Normalizes user or link input to the canonical code, or null if it is
  /// not a valid room code. Crockford decoding maps I/L to 1 and O to 0.
  static String? normalizeRoomCode(String raw) {
    final cleaned = raw
        .trim()
        .toUpperCase()
        .replaceAll('-', '')
        .replaceAll(' ', '')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0');
    if (cleaned.length != roomCodeLength) return null;
    for (final char in cleaned.split('')) {
      if (!_alphabet.contains(char)) return null;
    }
    return cleaned;
  }
}
