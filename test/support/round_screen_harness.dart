import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/router/routes.dart';
import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/game_page.dart';
import 'package:sporand/features/game/presentation/widgets/reveal_view.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import 'game_harness.dart';
import 'protocol_samples.dart';

/// Loads the bundled Unbounded and Nunito, so text metrics are the real
/// ones instead of the 1 em wide test font (call from `setUpAll`).
Future<void> loadBundledFonts() async {
  for (final MapEntry(key: family, value: path) in AppFonts.files.entries) {
    await (FontLoader(family)..addFont(rootBundle.load(path))).load();
  }
}

MaterialApp roundApp({
  Widget? home,
  GoRouter? router,
  double textScale = 1,
  bool reduceMotion = false,
}) {
  Widget scaled(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
    ),
    child: child!,
  );
  const delegates = [
    AppLocalizations.delegate,
    ...GlobalMaterialLocalizations.delegates,
  ];
  if (router != null) {
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.dark(),
      locale: const Locale('ru'),
      localizationsDelegates: delegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: scaled,
    );
  }
  return MaterialApp(
    theme: AppTheme.dark(),
    locale: const Locale('ru'),
    localizationsDelegates: delegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: scaled,
    home: home,
  );
}

GameHarness _harness(
  WidgetTester tester, {
  required Size screen,
  String me = Samples.guestId,
  double statusBar = 0,
}) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  tester.view
    ..physicalSize = screen
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: statusBar);
  addTearDown(tester.view.reset);
  return GameHarness(clock: tester.binding.clock, flush: () {}, me: me);
}

/// The round and reveal screens under the game's app bar (so the height
/// budget is the real one).
Future<GameHarness> pumpRoundScreen(
  WidgetTester tester, {
  required Size screen,
  String me = Samples.guestId,
  RoomSnapshot? room,
  double textScale = 1,
  bool reduceMotion = false,
  double statusBar = 0,
}) async {
  final h = _harness(tester, screen: screen, me: me, statusBar: statusBar);
  await tester.pump();
  h.send(Samples.welcome(me: me, room: room));
  await tester.pump();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: roundApp(
        textScale: textScale,
        reduceMotion: reduceMotion,
        home: Scaffold(
          appBar: AppBar(),
          body: Consumer(
            builder: (context, ref, _) => switch (ref.watch(
              gameControllerProvider,
            )) {
              final GameRoundState state => RoundScreen(state: state),
              GameRevealState(:final reveal) => RevealScreen(reveal: reveal),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    ),
  );
  return h;
}

/// [GamePage] behind a minimal router (its room sync navigates).
Future<GameHarness> pumpGamePage(
  WidgetTester tester, {
  required String me,
  RoomSnapshot? room,
  Size screen = const Size(400, 900),
  double textScale = 1,
}) async {
  final h = _harness(tester, screen: screen, me: me);
  await tester.pump();
  h.send(Samples.welcome(me: me, room: room));
  await tester.pump();
  final router = GoRouter(
    initialLocation: Routes.game(Samples.roomId),
    routes: [
      GoRoute(
        path: Routes.gamePattern,
        builder: (_, s) => GamePage(roomId: s.pathParameters['roomId']!),
      ),
      GoRoute(
        path: Routes.lobbyPattern,
        builder: (_, _) => const Text('LOBBY'),
      ),
      GoRoute(
        path: Routes.resultsPattern,
        builder: (_, _) => const Text('RESULTS'),
      ),
      GoRoute(path: Routes.home, builder: (_, _) => const Text('HOME')),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: roundApp(router: router, textScale: textScale),
    ),
  );
  return h;
}

Future<void> endRoundScreen(WidgetTester tester, GameHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.dispose();
  await tester.pump();
}
