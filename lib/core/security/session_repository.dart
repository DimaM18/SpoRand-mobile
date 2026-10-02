// Wave 8b: the session repository lives in mobile_kit (mobile-template);
// this path stays so existing imports keep working (a shim until 8c). The
// secure storage key `auth_session_v1` and its JSON are unchanged.
export 'package:mobile_kit/mobile_kit.dart' show AuthSession, SessionRepository;
