import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/app_signals.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/share/share_service.dart';
import 'package:sporand/core/ui/reduce_motion_scope.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';

import '../support/app_harness.dart';
import '../support/fake_services.dart';
import '../support/fake_ws.dart';

/// Screen goldens of the wave 6 visual refresh: the real app (router,
/// theme, bundled fonts) over the shared fakes, on a 390x844 phone at 3x
/// with an iPhone-like status bar and home indicator. No network.

/// Logical size of the golden phone.
const goldenScreen = Size(390, 844);

/// 390x844 at 3x is a 1170x2532 screenshot.
const goldenPixelRatio = 3.0;

/// Top (status bar) and bottom (home indicator) insets, logical px.
const goldenSafeTop = 47.0;
const goldenSafeBottom = 34.0;

/// Wraps the whole app, so a golden captures dialogs and sheets too.
const goldenBoundary = ValueKey('golden-boundary');

/// Font family the emoji fallback is registered under (test only).
const goldenEmojiFamily = 'GoldenEmoji';

/// The system colour emoji font the goldens were rendered with:
/// Ubuntu 24.04 `fonts-noto-color-emoji` 2.047-0ubuntu0.24.04.1 (SIL OFL
/// 1.1, read at test time and never bundled; SHA-256
/// 93cdc4ee9aa40e2afceecc63da0ca05ec7aab4bec991ece51a6b52389f48a477).
/// `flutter test` has no system font fallback, so without it every emoji
/// (and a symbol such as the ▶ of the DJ hint) renders as a box; the
/// goldens are skipped when this exact file is missing.
const _emojiFontPath = '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf';
const _emojiFontLength = 10788068;
const _emojiFontFnv1a = 0x08f22731;

/// Why the screen goldens are skipped here, or null. They are Linux
/// renders (what CI runs; other platforms rasterize text differently) and
/// need the reference emoji font.
final String? goldenSkipReason = _goldenSkipReason();

Uint8List? _emojiFontBytes;

String? _goldenSkipReason() {
  if (!Platform.isLinux) {
    return 'screen goldens are Linux renders; '
        '${Platform.operatingSystem} rasterizes text differently';
  }
  final file = File(_emojiFontPath);
  if (!file.existsSync()) {
    return 'the reference emoji font $_emojiFontPath is missing '
        '(apt install fonts-noto-color-emoji)';
  }
  final bytes = file.readAsBytesSync();
  if (bytes.length != _emojiFontLength || _fnv1a32(bytes) != _emojiFontFnv1a) {
    return '$_emojiFontPath is not the reference build '
        '(fonts-noto-color-emoji 2.047-0ubuntu0.24.04.1)';
  }
  _emojiFontBytes = bytes;
  return null;
}

int _fnv1a32(Uint8List bytes) {
  var hash = 0x811c9dc5;
  for (final byte in bytes) {
    hash = ((hash ^ byte) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

/// Loads every font of the app's `FontManifest.json` (Unbounded, Nunito,
/// Material and Cupertino icons) and the reference emoji font. Call from
/// `setUpAll`.
Future<void> loadGoldenFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<Object?>;
  for (final entry in manifest.cast<Map<String, Object?>>()) {
    final loader = FontLoader(entry['family']! as String);
    for (final font
        in (entry['fonts']! as List<Object?>).cast<Map<String, Object?>>()) {
      loader.addFont(rootBundle.load(Uri.decodeFull(font['asset']! as String)));
    }
    await loader.load();
  }

  final emoji = _emojiFontBytes;
  if (goldenSkipReason != null || emoji == null) return;
  await (FontLoader(
    goldenEmojiFamily,
  )..addFont(Future.value(ByteData.sublistView(emoji)))).load();
}

/// The app's theme plus the emoji font as the last fallback family,
/// standing in for the platform's emoji fallback on a device.
ThemeData _withEmojiFallback(ThemeData theme) {
  if (_emojiFontBytes == null) return theme;
  const fallback = [goldenEmojiFamily];
  return theme.copyWith(
    textTheme: theme.textTheme.apply(fontFamilyFallback: fallback),
    primaryTextTheme: theme.primaryTextTheme.apply(
      fontFamilyFallback: fallback,
    ),
  );
}

/// `SporandApp` as it ships (router, themes, locales), except that the
/// themes carry the emoji fallback of [_withEmojiFallback].
class GoldenApp extends ConsumerWidget {
  const GoldenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RepaintBoundary(
      key: goldenBoundary,
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        debugShowCheckedModeBanner: false,
        theme: _withEmojiFallback(AppTheme.light()),
        darkTheme: _withEmojiFallback(AppTheme.dark()),
        themeMode: ThemeMode.system,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeListResolutionCallback: resolveAppLocale,
        routerConfig: ref.watch(routerProvider),
        builder: (context, child) => ReduceMotionScope(child: child!),
      ),
    );
  }
}

/// The phone: 390x844 at 3x with safe-area insets, Russian, [brightness],
/// text scale 1.0 and full motion (the default device setting). Loops such
/// as the equalizer keep running, so frames are taken at fixed fake times:
/// use [settle], never `pumpAndSettle`.
///
/// [size] and [textScale] give the edge-case frames (a 360x640 phone, text
/// scale 2.0); a landscape [size] gets the notch insets on the sides.
void useGoldenPhone(
  WidgetTester tester, {
  required Brightness brightness,
  Size size = goldenScreen,
  double textScale = 1,
}) {
  final landscape = size.width > size.height;
  final small = size.height < 700 && !landscape;
  final insets = landscape
      ? const FakeViewPadding(
          left: goldenSafeTop * goldenPixelRatio,
          right: goldenSafeTop * goldenPixelRatio,
          bottom: 21 * goldenPixelRatio,
        )
      : small
      // A small Android phone: status bar only, 3-button navigation below
      // the view.
      ? const FakeViewPadding(top: 24 * goldenPixelRatio)
      : const FakeViewPadding(
          top: goldenSafeTop * goldenPixelRatio,
          bottom: goldenSafeBottom * goldenPixelRatio,
        );
  tester.view
    ..physicalSize = size * goldenPixelRatio
    ..devicePixelRatio = goldenPixelRatio
    ..padding = insets
    ..viewPadding = insets;
  addTearDown(tester.view.reset);
  final dispatcher = tester.platformDispatcher
    ..platformBrightnessTestValue = brightness
    ..localesTestValue = const [Locale('ru')]
    ..textScaleFactorTestValue = textScale
    ..accessibilityFeaturesTestValue = const FakeAccessibilityFeatures();
  addTearDown(dispatcher.clearAllTestValues);
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
}

/// Pumps [total] of fake time in 100 ms frames: route transitions and
/// entrance animations finish, loops advance deterministically.
Future<void> settle(
  WidgetTester tester, [
  Duration total = const Duration(seconds: 2),
]) async {
  const frame = Duration(milliseconds: 100);
  for (var t = Duration.zero; t < total; t += frame) {
    await tester.pump(frame);
  }
}

/// Compares the whole app against `screens/<name>.<light|dark>.png` (the
/// logical screen size, 390x844 by default: `flutter test` captures at 1x).
///
/// With `GOLDEN_SHOTS_DIR` set, the same frame is also written there at 3x
/// (1170x2532 for the default phone) for design review (never compared).
Future<void> expectScreen(
  WidgetTester tester,
  String name,
  Brightness brightness,
) async {
  final file = '$name.${brightness.name}';
  await expectLater(
    find.byKey(goldenBoundary),
    matchesGoldenFile('screens/$file.png'),
  );
  final shots = Platform.environment['GOLDEN_SHOTS_DIR'];
  if (shots == null || shots.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(goldenBoundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: goldenPixelRatio);
    final png = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    final out = File('$shots/$file@3x.png');
    await out.parent.create(recursive: true);
    await out.writeAsBytes(png!.buffer.asUint8List(), flush: true);
  });
}

/// Boots the app like `launch` in `test/support/app_harness.dart`, but
/// with [GoldenApp] and the golden phone already set up by the caller.
Future<ProviderContainer> launchGolden(
  WidgetTester tester,
  FakeServices services, {
  List<Override> extra = const [],
  bool boot = true,
}) async {
  final container = ProviderContainer(
    overrides: [...fakeOverrides(services), ...extra],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const GoldenApp()),
  );
  if (boot) {
    unawaited(container.read(bootControllerProvider.notifier).start());
    await tester.pump(const Duration(seconds: 3));
    await settle(tester);
  }
  return container;
}

/// Unmounts the app so tickers and the socket's timers stop before the
/// test ends.
Future<void> closeGolden(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}

/// A returning user past onboarding (analytics consent given).
FakeServices returningUser() => FakeServices(
  prefs: {
    'age_band': '18_plus',
    'onboarding_completed': true,
    'analytics_consent': true,
  },
);

/// The app wired to an in-memory game server, with the YouTube player
/// replaced by [PlaceholderYouTubePlayer].
final class GoldenGame {
  GoldenGame._(this.container, this.server, this.clock);

  final ProviderContainer container;
  final FakeWsServer server;
  final FakeInputClock clock;

  static Future<GoldenGame> launch(
    WidgetTester tester, {
    FakeServices? services,
    RoomsApi? rooms,
  }) async {
    final server = FakeWsServer();
    final clock = FakeInputClock(clock: tester.binding.clock);
    final container = await launchGolden(
      tester,
      services ?? returningUser(),
      extra: [
        roomsApiProvider.overrideWithValue(rooms ?? FakeRoomsApi()),
        wsConnectorProvider.overrideWithValue(server.connect),
        inputClockProvider.overrideWithValue(clock),
        appSignalSourceProvider.overrideWithValue(FakeAppSignalSource()),
        playbackAdapterFactoryProvider.overrideWithValue(
          (_) => FakePlaybackAdapter(),
        ),
        shareServiceProvider.overrideWithValue(FakeShareService()),
        youTubePlayerFactoryProvider.overrideWithValue(
          PlaceholderYouTubePlayerFactory(),
        ),
      ],
    );
    return GoldenGame._(container, server, clock);
  }

  /// Creates a room from home as «Ania» and lands in its lobby as the host
  /// once the server welcomes her into [room].
  Future<void> enterLobby(
    WidgetTester tester,
    RoomSnapshot room, {
    required String me,
  }) async {
    await tester.tap(find.text('Создать комнату'));
    await settle(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Ваше имя в игре'),
      'Ania',
    );
    final create = find.widgetWithText(FilledButton, 'Создать комнату').last;
    await tester.ensureVisible(create);
    await settle(tester);
    await tester.tap(create);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    send(
      Welcome(
        playerId: me,
        room: room,
        config: const RoomConfig({
          'rounds_free_options': [5, 10],
          'rounds_premium_options': [5, 10, 15, 25, 50],
          'answer_window_ms': 15000,
        }),
        configVersion: '18a4b88131908136',
        serverVersion: '0.1.0',
      ),
    );
    await settle(tester);
  }

  void send(ServerMessage message) => server.send(message);
}

/// Stands in for the embedded YouTube player (no WebView in `flutter
/// test`): a black 16:9 box with a neutral outline and a caption, so the
/// screenshots show the player's real size and position. No logo.
final class PlaceholderYouTubePlayerFactory implements YouTubePlayerFactory {
  @override
  YouTubeEmbedPlayer create(YouTubePlayerSpec spec) =>
      PlaceholderYouTubePlayer(spec.videoId);
}

final class PlaceholderYouTubePlayer implements YouTubeEmbedPlayer {
  PlaceholderYouTubePlayer(this.videoId);

  @override
  final String videoId;

  final StreamController<YouTubePlayerEvent> _events =
      StreamController.broadcast(sync: true);

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  @override
  Widget buildView(BuildContext context) => SizedBox.expand(
    key: ValueKey('youtube-player-$videoId'),
    child: const CustomPaint(
      painter: _PlaceholderPainter(),
      child: Center(
        child: Text(
          'embedded player · test placeholder',
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 13,
            color: Color(0xFF9E9E9E),
          ),
        ),
      ),
    ),
  );

  @override
  Future<void> dispose() => _events.close();
}

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF000000));
    final line = Paint()
      ..color = const Color(0xFF3A3A3A)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas
      ..drawRect(rect.deflate(0.5), line)
      ..drawLine(rect.topLeft, rect.bottomRight, line)
      ..drawLine(rect.topRight, rect.bottomLeft, line);
  }

  @override
  bool shouldRepaint(_PlaceholderPainter oldDelegate) => false;
}
