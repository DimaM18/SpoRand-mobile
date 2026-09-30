import 'dart:convert';

import 'package:pub_semver/pub_semver.dart';

import 'package:sporand/core/platform/app_platform.dart';

/// `min_supported_app_version` check (brief §4.6).
///
/// The value is normally a plain semver string, already made
/// platform-specific by Remote Config platform conditions. A JSON object is
/// also accepted so one value can carry both platforms:
/// `{"ios": "1.2.0", "android": "1.1.0", "default": "1.0.0"}`.
///
/// Anything unparseable never blocks the user: a broken config value must
/// not lock everyone out of the app.
abstract final class VersionGate {
  static bool requiresUpdate({
    required String minSupportedRaw,
    required String currentVersion,
    required AppPlatform platform,
  }) {
    final minimum = _minimumFor(minSupportedRaw, platform);
    final current = _parse(currentVersion);
    if (minimum == null || current == null) return false;
    return current < minimum;
  }

  static Version? _minimumFor(String raw, AppPlatform platform) {
    final trimmed = raw.trim();
    if (!trimmed.startsWith('{')) return _parse(trimmed);
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map<String, Object?>) return null;
      final value = decoded[platform.wireName] ?? decoded['default'];
      return value is String ? _parse(value) : null;
    } on FormatException {
      return null;
    }
  }

  /// Parses `1.2.3`, `1.2.3-beta.1` and tolerates `1.2` / `1`. Build
  /// metadata (`+45`) is ignored, as semver precedence requires.
  static Version? _parse(String raw) {
    final trimmed = raw.trim().split('+').first;
    if (trimmed.isEmpty) return null;
    try {
      return Version.parse(trimmed);
    } on FormatException {
      final parts = trimmed.split('.');
      if (parts.length > 3 || parts.any((p) => int.tryParse(p) == null)) {
        return null;
      }
      final numbers = [...parts.map(int.parse), 0, 0];
      return Version(numbers[0], numbers[1], numbers[2]);
    }
  }
}
