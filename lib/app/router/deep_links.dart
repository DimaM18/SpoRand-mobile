import 'package:sporand/app/router/routes.dart';

/// Something that asked to open a screen: a URL (universal link / app link /
/// go_router initial location) or a push notification payload.
sealed class IncomingLink {
  const IncomingLink();
}

final class UriLink extends IncomingLink {
  const UriLink(this.uri);

  final Uri uri;
}

final class PushLink extends IncomingLink {
  const PushLink(this.payload);

  /// Expected keys: `room_code`, or `link` with an absolute URL.
  final Map<String, Object?> payload;
}

/// A link the app knows how to open.
sealed class AppLink {
  const AppLink();

  String get location;
}

final class JoinRoomLink extends AppLink {
  const JoinRoomLink(this.roomCode);

  final String roomCode;

  @override
  String get location => Routes.join(roomCode);

  @override
  bool operator ==(Object other) =>
      other is JoinRoomLink && other.roomCode == roomCode;

  @override
  int get hashCode => roomCode.hashCode;
}

/// Parses incoming links into [AppLink]s. Only the join link exists in the
/// MVP: `https://<domain>/j/{room_code}` (brief §2 "Rooms").
final class DeepLinkParser {
  const DeepLinkParser({required this.allowedHosts});

  /// Hosts accepted for absolute https links. Relative locations (what
  /// go_router receives from the platform) are always accepted.
  final Set<String> allowedHosts;

  /// Crockford base32 alphabet used by room codes (brief §7): no I, L, O, U.
  static const _alphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const roomCodeLength = 6;

  AppLink? parse(IncomingLink link) => switch (link) {
    UriLink(:final uri) => parseUri(uri),
    PushLink(:final payload) => _parsePush(payload),
  };

  AppLink? parseUri(Uri uri) {
    if (uri.hasScheme) {
      if (uri.scheme != 'https') return null;
      if (!allowedHosts.contains(uri.host.toLowerCase())) return null;
    }
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length == 2 && segments[0] == 'j') {
      final code = normalizeRoomCode(segments[1]);
      if (code != null) return JoinRoomLink(code);
    }
    return null;
  }

  AppLink? _parsePush(Map<String, Object?> payload) {
    final code = payload['room_code'];
    if (code is String) {
      final normalized = normalizeRoomCode(code);
      return normalized == null ? null : JoinRoomLink(normalized);
    }
    final link = payload['link'];
    if (link is String) {
      final uri = Uri.tryParse(link);
      return uri == null ? null : parseUri(uri);
    }
    return null;
  }

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

/// Links received before the app can show them (during boot, or before
/// onboarding is done). The boot `route` step drains the queue; a link that
/// must wait for onboarding is parked in [deferred].
final class DeepLinkQueue {
  final List<IncomingLink> _pending = [];
  AppLink? _deferred;

  bool get isEmpty => _pending.isEmpty;
  int get length => _pending.length;

  void enqueue(IncomingLink link) => _pending.add(link);

  List<IncomingLink> drain() {
    final items = List<IncomingLink>.of(_pending);
    _pending.clear();
    return items;
  }

  AppLink? get deferred => _deferred;

  void defer(AppLink link) => _deferred = link;

  AppLink? takeDeferred() {
    final link = _deferred;
    _deferred = null;
    return link;
  }
}
