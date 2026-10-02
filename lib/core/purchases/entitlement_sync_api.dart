// Wave 8b: the entitlement sync (`POST /v1/me/entitlements/sync`) lives in
// mobile_kit (mobile-template); this path stays so existing imports keep
// working (a shim until 8c).
export 'package:mobile_kit/mobile_kit.dart'
    show EntitlementSyncApi, FakeEntitlementSyncApi, HttpEntitlementSyncApi;
