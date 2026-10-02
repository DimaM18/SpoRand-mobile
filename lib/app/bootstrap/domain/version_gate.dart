// Wave 8b: the `min_supported_app_version` check is mobile_kit's
// (mobile-template), with the same rules: a plain semver string or a JSON
// object per platform, and anything unparseable never blocks the user.
export 'package:mobile_kit/mobile_kit.dart' show VersionGate;
