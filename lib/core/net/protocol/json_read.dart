/// Small, strict readers for protocol JSON. A missing or mistyped field throws
/// [ProtocolFormatException] naming the field, so a bad frame is dropped
/// with a useful log line instead of crashing a controller later.
library;

final class ProtocolFormatException implements Exception {
  const ProtocolFormatException(this.message);

  final String message;

  @override
  String toString() => 'ProtocolFormatException: $message';
}

/// A value that has a canonical wire spelling (snake_case enum value).
abstract interface class WireEnum {
  String get wire;
}

/// Looks up [raw] among [values]; [fallback] handles values added by a newer
/// server (reasons, codes), otherwise unknown values are a format error.
T parseWire<T extends WireEnum>(List<T> values, Object? raw, {T? fallback}) {
  for (final value in values) {
    if (value.wire == raw) return value;
  }
  if (fallback != null) return fallback;
  throw ProtocolFormatException('unknown enum value "$raw" for $T');
}

typedef JsonMap = Map<String, Object?>;

extension JsonRead on JsonMap {
  Object? _required(String key) {
    if (!containsKey(key) || this[key] == null) {
      throw ProtocolFormatException('missing field "$key"');
    }
    return this[key];
  }

  String str(String key) {
    final value = _required(key);
    if (value is String) return value;
    throw ProtocolFormatException('"$key" must be a string');
  }

  String? optStr(String key) {
    final value = this[key];
    if (value == null || value is String) return value as String?;
    throw ProtocolFormatException('"$key" must be a string');
  }

  /// Accepts integral doubles too: some JSON encoders write `1.0`.
  int integer(String key) => _toInt(key, _required(key));

  int? optInt(String key) {
    final value = this[key];
    return value == null ? null : _toInt(key, value);
  }

  bool boolean(String key) {
    final value = _required(key);
    if (value is bool) return value;
    throw ProtocolFormatException('"$key" must be a boolean');
  }

  bool? optBool(String key) {
    final value = this[key];
    if (value == null || value is bool) return value as bool?;
    throw ProtocolFormatException('"$key" must be a boolean');
  }

  JsonMap obj(String key) {
    final value = _required(key);
    if (value is Map<String, Object?>) return value;
    throw ProtocolFormatException('"$key" must be an object');
  }

  JsonMap? optObj(String key) {
    final value = this[key];
    if (value == null || value is Map<String, Object?>) {
      return value as Map<String, Object?>?;
    }
    throw ProtocolFormatException('"$key" must be an object');
  }

  List<T> list<T>(String key, T Function(Object? item) read) {
    final value = _required(key);
    if (value is! List<Object?>) {
      throw ProtocolFormatException('"$key" must be an array');
    }
    return List<T>.unmodifiable(value.map(read));
  }

  List<T>? optList<T>(String key, T Function(Object? item) read) =>
      this[key] == null ? null : list(key, read);

  T wire<T extends WireEnum>(String key, List<T> values, {T? fallback}) =>
      parseWire(values, _required(key), fallback: fallback);

  T? optWire<T extends WireEnum>(String key, List<T> values, {T? fallback}) {
    final raw = this[key];
    return raw == null ? null : parseWire(values, raw, fallback: fallback);
  }
}

int _toInt(String key, Object? value) {
  if (value is int) return value;
  if (value is double && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw ProtocolFormatException('"$key" must be an integer');
}

/// Readers for array items.
JsonMap asObject(Object? item) {
  if (item is Map<String, Object?>) return item;
  throw const ProtocolFormatException('array item must be an object');
}

String asString(Object? item) {
  if (item is String) return item;
  throw const ProtocolFormatException('array item must be a string');
}

int asInt(Object? item) => _toInt('item', item);
