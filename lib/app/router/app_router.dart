import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/presentation/boot_splash_page.dart';
import 'package:sporand/app/bootstrap/presentation/gate_pages.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/deep_links.dart';
import 'package:sporand/app/router/route_guard.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/tokens.dart';
import 'package:sporand/app/widgets/placeholder_page.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/features/debug/presentation/clock_calibration_page.dart';
import 'package:sporand/features/game/presentation/game_page.dart';
import 'package:sporand/features/home/presentation/home_page.dart';
import 'package:sporand/features/lobby/presentation/join_room_page.dart';
import 'package:sporand/features/lobby/presentation/lobby_page.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_page.dart';
import 'package:sporand/features/onboarding/presentation/onboarding_controller.dart';
import 'package:sporand/features/onboarding/presentation/onboarding_pages.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_page.dart';
import 'package:sporand/features/results/presentation/results_page.dart';
import 'package:sporand/features/settings/presentation/settings_page.dart';

/// Re-evaluates redirects when the boot phase or onboarding status changes
/// (not on every progress tick).
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref
      ..listen(
        bootControllerProvider.select((state) => state.runtimeType),
        (_, _) => notifyListeners(),
      )
      ..listen(
        onboardingControllerProvider.select(
          (state) => (state.completed, state.blocked),
        ),
        (_, _) => notifyListeners(),
      );
  }
}

/// Fade + slight scale: the hand-off from the splash lands on the same
/// backdrop color, so the first screen appears to grow out of the loader.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.medium,
      reverseTransitionDuration: Motion.fast,
      transitionsBuilder: (context, animation, secondary, child) {
        if (MediaQuery.disableAnimationsOf(context)) return child;
        final curve = CurveTween(curve: Motion.emphasizedDecelerate);
        return FadeTransition(
          opacity: animation.drive(curve),
          child: ScaleTransition(
            scale: animation.drive(
              Tween<double>(begin: 0.96, end: 1).chain(curve),
            ),
            child: child,
          ),
        );
      },
    );

GoRoute _route(String path, Widget Function(GoRouterState state) build) =>
    GoRoute(
      path: path,
      pageBuilder: (context, state) => _page(state, build(state)),
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  final router = GoRouter(
    initialLocation: Routes.boot,
    refreshListenable: refresh,
    redirect: (context, state) {
      final onboarding = ref.read(onboardingControllerProvider);
      return guardRedirect(
        uri: state.uri,
        boot: ref.read(bootControllerProvider),
        onboardingCompleted: onboarding.completed,
        ageBlocked: onboarding.blocked,
        queue: ref.read(deepLinkQueueProvider),
        parser: ref.read(deepLinkParserProvider),
      );
    },
    routes: [
      GoRoute(
        path: Routes.boot,
        pageBuilder: (context, state) => NoTransitionPage<void>(
          key: state.pageKey,
          child: const BootSplashPage(),
        ),
      ),
      _route(Routes.onboarding, (_) => const AgeGatePage()),
      _route(Routes.onboardingConsent, (_) => const ConsentPage()),
      _route(Routes.onboardingBlocked, (_) => const AgeBlockedPage()),
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
              DeepLinkParser.normalizeRoomCode(
                s.pathParameters['roomCode'] ?? '',
              ) ??
              (s.pathParameters['roomCode'] ?? ''),
          via: JoinVia.fromQuery(s.uri.queryParameters['via']),
        ),
      ),
      _route(
        Routes.paywall,
        (s) => PaywallPage(
          placement: PaywallPlacement.fromWire(
            s.uri.queryParameters['placement'],
          ),
        ),
      ),
      _route(Routes.settings, (_) => const SettingsPage()),
      _route(Routes.mySongs, (_) => const MySongsPage()),
      _route(Routes.forceUpdate, (_) => const ForceUpdatePage()),
      _route(Routes.maintenance, (_) => const MaintenancePage()),
      _route(Routes.debugClock, (_) => const ClockCalibrationPage()),
    ],
    errorPageBuilder: (context, state) => _page(
      state,
      Builder(
        builder: (context) =>
            PlaceholderPage(title: context.l10n.notFoundTitle),
      ),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
