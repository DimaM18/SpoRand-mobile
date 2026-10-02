// Wave 8b: the REST client lives in mobile_kit (mobile-template); this path
// stays so existing imports keep working (a shim until 8c). Bearer auth with
// one single-flight refresh on 401, the App Check header and RFC 9457
// problems as `ApiError` are unchanged; tokens never appear in errors.
export 'package:mobile_kit/mobile_kit.dart'
    show AccessTokenProvider, ApiClient, ApiError, AppCheckUse;
