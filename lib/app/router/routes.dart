/// Route paths. Kept in one place so that boot, guards and screens agree.
abstract final class Routes {
  static const boot = '/boot';
  static const onboarding = '/onboarding';
  static const onboardingConsent = '/onboarding/consent';
  static const onboardingBlocked = '/onboarding/blocked';
  static const home = '/home';
  static const paywall = '/paywall';
  static const settings = '/settings';
  static const forceUpdate = '/force-update';
  static const maintenance = '/maintenance';

  static const lobbyPattern = '/lobby/:roomId';
  static const gamePattern = '/game/:roomId';
  static const resultsPattern = '/results/:roomId';

  /// Public join link path: `https://<domain>/j/{room_code}` (brief §2).
  static const joinPattern = '/j/:roomCode';

  static String lobby(String roomId) => '/lobby/${Uri.encodeComponent(roomId)}';
  static String game(String roomId) => '/game/${Uri.encodeComponent(roomId)}';
  static String results(String roomId) =>
      '/results/${Uri.encodeComponent(roomId)}';
  static String join(String roomCode) => '/j/$roomCode';
  static String paywallFor(String placement) =>
      Uri(path: paywall, queryParameters: {'placement': placement}).toString();

  /// Screens that are reachable while onboarding is incomplete.
  static bool isOnboarding(String path) =>
      path == onboarding || path.startsWith('$onboarding/');

  /// Screens that must stay reachable whatever the app state.
  static bool isStatusScreen(String path) =>
      path == forceUpdate || path == maintenance;
}
