import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_kit/mobile_kit.dart'
    show KitPagesSpec, kitPage, kitRouterProvider;

import 'package:sporand/app/bootstrap/presentation/boot_splash_page.dart';
import 'package:sporand/app/bootstrap/presentation/gate_pages.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/features/debug/presentation/clock_calibration_page.dart';
import 'package:sporand/features/game/presentation/game_page.dart';
import 'package:sporand/features/home/presentation/home_page.dart';
import 'package:sporand/features/lobby/presentation/join_room_page.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_page.dart';
import 'package:sporand/features/onboarding/presentation/onboarding_pages.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_page.dart';
import 'package:sporand/features/results/presentation/results_page.dart';
import 'package:sporand/features/settings/presentation/settings_page.dart';

/// The app router (wave 8b): mobile_kit's router with its routes, guard,
/// redirects and «not found» page, SpoRand's screens on the kit routes
/// ([sporandKitPages]) and the game routes ([sporandRoutes]). The same
/// provider as `kitRouterProvider`, under its old name.
final routerProvider = kitRouterProvider;

/// The game screens, added to the kit routes (`projectRoutesProvider`)
/// [новое имя — согласовать].
List<RouteBase> sporandRoutes() => [
  _route(Routes.home, (_) => const HomePage()),
  _route(
    Routes.lobbyPattern,
    (s) => LobbyPage(roomId: s.pathParameters['roomId'] ?? ''),
  ),
  _route(
    Routes.gamePattern,
    (s) => GamePage(roomId: s.pathParameters['roomId'] ?? ''),
  ),
  _route(
    Routes.resultsPattern,
    (s) => ResultsPage(roomId: s.pathParameters['roomId'] ?? ''),
  ),
  _route(
    Routes.joinPattern,
    (s) => JoinRoomPage(
      roomCode:
          DeepLinkParser.normalizeRoomCode(s.pathParameters['roomCode'] ?? '') ??
          (s.pathParameters['roomCode'] ?? ''),
      via: JoinVia.fromQuery(s.uri.queryParameters['via']),
    ),
  ),
  _route(Routes.mySongs, (_) => const MySongsPage()),
  _route(Routes.debugClock, (_) => const ClockCalibrationPage()),
];

GoRoute _route(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => kitPage(state, build(state)),
    );

/// SpoRand's screens on the kit routes (`kitPagesProvider`): the splash,
/// onboarding, settings, paywall and force update stay SpoRand's (their
/// copy, icons and layout differ from the kit's); maintenance is the kit's
/// [новое имя — согласовать].
const sporandKitPages = KitPagesSpec(
  boot: _boot,
  onboarding: _onboarding,
  onboardingConsent: _onboardingConsent,
  onboardingBlocked: _onboardingBlocked,
  settings: _settings,
  paywall: _paywall,
  forceUpdate: _forceUpdate,
);

Widget _boot() => const BootSplashPage();
Widget _onboarding() => const AgeGatePage();
Widget _onboardingConsent() => const ConsentPage();
Widget _onboardingBlocked() => const AgeBlockedPage();
Widget _settings() => const SettingsPage();
Widget _paywall(String placement) =>
    PaywallPage(placement: PaywallPlacement.fromWire(placement));
Widget _forceUpdate() => const ForceUpdatePage();
