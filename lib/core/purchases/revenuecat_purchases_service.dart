// Wave 8b: the RevenueCat adapter lives in mobile_kit (mobile-template);
// this path stays so existing imports keep working (a shim until 8c).
// TODO(owner): pass REVENUECAT_API_KEY_IOS/ANDROID via --dart-define.
export 'package:mobile_kit/mobile_kit.dart' show RevenueCatPurchasesService;
