// Wave 8b: the UMP consent interface lives in mobile_kit (mobile-template);
// this path stays so existing imports keep working (a shim until 8c).
export 'package:mobile_kit/mobile_kit.dart'
    show ConsentInfo, ConsentService, ConsentStatus, FakeConsentService;
