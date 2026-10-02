// Wave 8b: the analytics identity (the GA4 user id follows the session's
// `analytics_uid`, never the raw user id) lives in mobile_kit
// (mobile-template); this path stays so existing imports keep working (a
// shim until 8c).
export 'package:mobile_kit/mobile_kit.dart' show AnalyticsIdentity;
