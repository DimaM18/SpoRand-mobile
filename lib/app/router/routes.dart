import 'package:mobile_kit/mobile_kit.dart' show KitRoutes, KitRoutesConfig;

/// Route paths. Kept in one place so that boot, guards and screens agree:
/// mobile_kit's routes (wave 8b; the kit router owns them, their guard and
/// redirects) plus the game's (`projectRoutesProvider`, app_router.dart).
abstract final class Routes {
  static const boot = KitRoutes.boot;
  static const onboarding = KitRoutes.onboarding;
  static const onboardingConsent = KitRoutes.onboardingConsent;
  static const onboardingBlocked = KitRoutes.onboardingBlocked;
  static const home = KitRoutesConfig.defaultHome;
  static const paywall = KitRoutes.paywall;
  static const settings = KitRoutes.settings;

  /// «Мои песни» (addendum A2.3) [новое имя — согласовать].
  static const mySongs = '/my-songs';
  static const forceUpdate = KitRoutes.forceUpdate;
  static const maintenance = KitRoutes.maintenance;

  /// Dev-only: the device timing calibration screen (brief §5/§9).
  static const debugClock = '/debug/clock';

  static const lobbyPattern = '/lobby/:roomId';
  static const gamePattern = '/game/:roomId';
  static const resultsPattern = '/results/:roomId';

  /// Public join link path: `https://<domain>/j/{room_code}` (brief §2).
  static const joinPattern = '/j/:roomCode';

  static String lobby(String roomId) => '/lobby/${Uri.encodeComponent(roomId)}';
  static String game(String roomId) => '/game/${Uri.encodeComponent(roomId)}';
  static String results(String roomId) =>
      '/results/${Uri.encodeComponent(roomId)}';

  /// [via] is `room_join.via` (`code` | `link` | `qr`); links carry no
  /// query unless they came from the in-app QR code or the code field.
  static String join(String roomCode, {String? via}) => Uri(
    path: '/j/$roomCode',
    queryParameters: via == null ? null : {'via': via},
  ).toString();
  static String paywallFor(String placement) =>
      KitRoutes.paywallFor(placement);

  /// Screens that are reachable while onboarding is incomplete.
  static bool isOnboarding(String path) => KitRoutes.isOnboarding(path);

  /// Screens that must stay reachable whatever the app state.
  static bool isStatusScreen(String path) => KitRoutes.isStatusScreen(path);
}
