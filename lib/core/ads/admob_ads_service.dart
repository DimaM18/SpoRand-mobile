// Wave 8b: the AdMob adapter lives in mobile_kit (mobile-template); this
// path stays so existing imports keep working (a shim until 8c).
// TODO(owner): replace the sample AdMob app ids in AndroidManifest.xml
// (`com.google.android.gms.ads.APPLICATION_ID`) and Info.plist
// (`GADApplicationIdentifier`) and pass real ad unit ids via --dart-define.
export 'package:mobile_kit/mobile_kit.dart' show AdMobAdsService;
