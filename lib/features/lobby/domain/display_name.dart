/// Display-name rules the client can check before `POST /v1/rooms/join`
/// (brief §7 "UGC"): 2–20 characters with bidi and zero-width characters
/// stripped. NFKC normalization and the profanity filter run on the server.
abstract final class DisplayName {
  static const minLength = 2;
  static const maxLength = 20;

  /// Zero-width and bidirectional control characters.
  static final RegExp _invisible = RegExp(
    r'[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF]',
  );
  static final RegExp _spaces = RegExp(r'\s+');

  static String clean(String raw) =>
      raw.replaceAll(_invisible, '').replaceAll(_spaces, ' ').trim();

  /// The cleaned name, or null when it is too short or too long.
  static String? validate(String raw) {
    final name = clean(raw);
    final length = name.runes.length;
    if (length < minLength || length > maxLength) return null;
    return name;
  }
}
