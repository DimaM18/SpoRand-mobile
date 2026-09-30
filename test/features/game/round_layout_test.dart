import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/ui/ui.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';
import 'package:sporand/features/game/presentation/widgets/standings_list.dart';
import 'package:sporand/features/game/presentation/widgets/youtube_round_player.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';
import '../../support/round_screen_harness.dart';

/// Wave 6 layout contract of the round screens (design system "Neon
/// Night+" §6-§8): the YouTube player screen, landscape, large text, the
/// reveal recap and the calm, fade-free player screen. It keeps the 1 em
/// wide test font (stricter for overflow); the height budgets with the real
/// fonts are in `round_budget_test.dart`.

final _player = find.byKey(const ValueKey('youtube-player-tEsTvIdEo01'));
final _musicPlaying = find.byKey(const ValueKey('dj-music-playing'));

/// The widgets from [of]'s parent up to (not including) the first ancestor
/// [stop] accepts.
List<Widget> _between(
  WidgetTester tester,
  Finder of,
  bool Function(Widget widget) stop,
) {
  final widgets = <Widget>[];
  tester.element(of).visitAncestorElements((element) {
    if (stop(element.widget)) return false;
    widgets.add(element.widget);
    return true;
  });
  return widgets;
}

/// Nothing of these may wrap the player: no overlay, fade, clip, transform,
/// padding or decoration (`docs/DEVELOPMENT.md` §7, YouTube rules).
const _forbiddenAroundPlayer = {
  Stack,
  Positioned,
  Overlay,
  Opacity,
  AnimatedOpacity,
  FadeTransition,
  ClipRRect,
  ClipRect,
  ClipPath,
  Transform,
  ScaleTransition,
  IgnorePointer,
  AbsorbPointer,
  DecoratedBox,
  ShaderMask,
  BackdropFilter,
};

/// The wrappers around the player that change how it looks or is hit.
List<Type> _decorations(List<Widget> around) => [
  for (final w in around)
    if (w is Padding
        ? w.padding != EdgeInsets.zero
        : _forbiddenAroundPlayer.contains(w.runtimeType))
      w.runtimeType,
];

Future<void> _pointerDown(
  WidgetTester tester,
  Finder target, {
  required int osUs,
}) async {
  final finger = TestPointer(1);
  await tester.sendEventToBinding(
    finger.down(
      tester.getCenter(target),
      timeStamp: Duration(microseconds: osUs),
    ),
  );
  await tester.pump();
  await tester.sendEventToBinding(finger.up());
  await tester.pump();
}

const _fourOptions = [
  ...Samples.options,
  RoundOption(optionId: 'opt-d', label: 'Dominik'),
];

void main() {
  testWidgets('youtube DJ at 360 dp: the player is edge to edge right under '
      'the app bar with nothing around it; «Музыка играет!» sits 16 dp or '
      'more below it, above the fold; nothing animates; after the tap the '
      'slot shows «Отмечено»', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(360, 640),
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
    );
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();

    final player = tester.getRect(_player);
    expect(player.left, 0);
    expect(player.width, 360);
    expect(player.height, closeTo(360 * 9 / 16, 0.01));
    expect(player.top, kToolbarHeight);
    final around = _between(
      tester,
      find.byType(DjVideoSlot),
      (w) => w is RoundScreen,
    );
    expect(
      _decorations(around),
      isEmpty,
      reason: '${around.map((w) => w.runtimeType)}',
    );
    expect(
      tester.hitTestOnBinding(player.center).path.first.target,
      tester.renderObject(_player),
    );

    final button = tester.getRect(_musicPlaying);
    expect(button.top, greaterThanOrEqualTo(player.bottom + 16));
    expect(button.height, greaterThanOrEqualTo(88));
    expect(button.bottom, lessThanOrEqualTo(640), reason: 'above the fold');
    expect(find.byType(AnswerTimerRing), findsNothing);
    expect(find.byType(EqualizerBars), findsNothing);
    expect(tester.hasRunningAnimations, isFalse, reason: 'a calm screen');

    await _pointerDown(tester, _musicPlaying, osUs: h.inputClock.nowUs);
    expect(h.received<RoundPlaybackStarted>(), hasLength(1));
    expect(_musicPlaying, findsNothing);
    final done = find.byKey(const ValueKey('dj-music-played'));
    expect(done, findsOneWidget);
    expect(find.text('Отмечено'), findsOneWidget);
    expect(tester.getRect(done).top, button.top, reason: 'same slot');
    expect(tester.getRect(_player), player);
    expect(tester.hasRunningAnimations, isFalse);
    await endRoundScreen(tester, h);
  });

  testWidgets('youtube DJ: the play symbol is an inline icon (no emoji or '
      '▶ character anywhere), one instruction, the role line as the status '
      'and a quiet question', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(390, 844),
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
    );
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    expect(_player, findsOneWidget);

    // No text on the DJ screen carries ▶, a variation selector or any
    // emoji-presentation code point: the icon is a Material glyph.
    for (final paragraph in tester.renderObjectList<RenderParagraph>(
      find.byType(RichText),
    )) {
      final text = paragraph.text.toPlainText(includePlaceholders: false);
      for (final rune in text.runes) {
        expect(
          rune == 0x25B6 ||
              rune == 0xFE0E ||
              rune == 0xFE0F ||
              (rune >= 0x1F000 && rune <= 0x1FAFF) ||
              (rune >= 0x2600 && rune <= 0x27BF),
          isFalse,
          reason: 'U+${rune.toRadixString(16)} in «$text»',
        );
      }
    }
    final note = find.byKey(const ValueKey('youtube-note'));
    expect(
      find.descendant(
        of: note,
        matching: find.byIcon(Icons.play_arrow_rounded),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(note).label,
      'Нажми кнопку воспроизведения в плеере. Если YouTube сначала покажет '
      'рекламу, дождись песни',
    );

    // One instruction: no button hint and no repeated status.
    expect(find.text('Нажмите, как только песня зазвучит'), findsNothing);
    expect(
      find.text('Когда зазвучит песня, жми «Музыка играет!»'),
      findsNothing,
    );
    expect(
      find.text('Ты DJ этого раунда — отвечают остальные'),
      findsOneWidget,
    );
    // The question is for the others: smaller than the note's neighbours.
    final prompt = tester.widget<Text>(
      find.byKey(const ValueKey('round-prompt')),
    );
    final theme = Theme.of(tester.element(_player));
    expect(prompt.style?.fontSize, theme.textTheme.titleMedium?.fontSize);
    expect(prompt.style?.color, theme.colorScheme.onSurfaceVariant);
    semantics.dispose();
    await endRoundScreen(tester, h);
  });

  testWidgets('youtube DJ: a SnackBar left from before is cleared when the '
      'player mounts', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(400, 900),
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
    );
    ScaffoldMessenger.of(tester.element(find.byType(Consumer)))
        .showSnackBar(const SnackBar(content: Text('from the lobby')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('from the lobby'), findsOneWidget);

    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    expect(_player, findsOneWidget);
    // Cleared after the player's first frame: the SnackBar runs its exit
    // animation (well before its 4 s timeout), then leaves the tree.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
    await endRoundScreen(tester, h);
  });

  testWidgets('youtube DJ in landscape (844x390): the player takes the left '
      'pane, 16:9 and fully visible; «Музыка играет!» sits beside it; a '
      'rotation keeps the same player', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(844, 390),
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
    );
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    final player = tester.getRect(_player);
    expect(player.left, 0);
    expect(player.width, greaterThanOrEqualTo(youTubePlayerFloorWidthDp));
    expect(player.height, closeTo(player.width * 9 / 16, 0.01));
    expect(player.top, greaterThanOrEqualTo(kToolbarHeight));
    expect(player.bottom, lessThanOrEqualTo(390));
    expect(
      844 - player.right,
      greaterThanOrEqualTo(RoundScreen.landscapePaneMinWidth),
    );
    final button = tester.getRect(_musicPlaying);
    expect(button.left, greaterThanOrEqualTo(player.right));
    expect(button.bottom, lessThanOrEqualTo(390), reason: 'above the fold');
    expect(button.height, greaterThanOrEqualTo(72));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(h.youTube.created, hasLength(1), reason: 'not reloaded');
    expect(h.youTube.created.single.disposed, isFalse);
    expect(tester.getRect(_player).width, 390);
    await endRoundScreen(tester, h);
  });

  group('youtube DJ: small and landscape windows keep a legal player', () {
    Future<GameHarness> djRound(WidgetTester tester, Size screen) async {
      final h = await pumpRoundScreen(
        tester,
        screen: screen,
        me: Samples.hostId,
        room: Samples.youtubeRoom(),
      );
      h.send(
        Samples.youtubeDjPrepare(
          startAtMonoUs: h.inputClock.monoNowUs + 2500000,
        ),
      );
      await tester.pump();
      await tester.pump();
      return h;
    }

    void expectLegalPlayer(WidgetTester tester, Size screen) {
      expect(tester.takeException(), isNull);
      final player = tester.getRect(_player);
      expect(player.width, greaterThanOrEqualTo(youTubePlayerFloorWidthDp));
      expect(player.height, closeTo(player.width * 9 / 16, 0.01));
      expect(player.left, greaterThanOrEqualTo(0));
      expect(player.right, lessThanOrEqualTo(screen.width));
      expect(player.top, greaterThanOrEqualTo(kToolbarHeight));
      expect(player.bottom, lessThanOrEqualTo(screen.height));
    }

    testWidgets('rotating a 360x640 phone with 3-button navigation '
        '(body 592x280) keeps the playing video; rotating back too', (
      tester,
    ) async {
      const portrait = Size(360, 648);
      const landscape = Size(592, 336);
      final h = await djRound(tester, portrait);
      expectLegalPlayer(tester, portrait);
      expect(tester.getRect(_player).width, 360);

      tester.view.physicalSize = landscape;
      await tester.pump();
      await tester.pump();
      expectLegalPlayer(tester, landscape);
      expect(h.youTube.created, hasLength(1), reason: 'not reloaded');
      expect(h.youTube.created.single.disposed, isFalse);
      expect((h.state as GameRoundState).djVideo, isA<DjVideoPlayer>());
      final button = tester.getRect(_musicPlaying);
      expect(button.left, greaterThanOrEqualTo(tester.getRect(_player).right));
      expect(
        button.width,
        greaterThanOrEqualTo(RoundScreen.landscapePaneFloorWidth - 32),
      );

      tester.view.physicalSize = portrait;
      await tester.pump();
      await tester.pump();
      expectLegalPlayer(tester, portrait);
      expect(h.youTube.created, hasLength(1));
      expect(h.youTube.created.single.disposed, isFalse);
      await endRoundScreen(tester, h);
    });

    testWidgets('a round that starts in a 592x336 landscape window gets the '
        'player', (tester) async {
      const screen = Size(592, 336);
      final h = await djRound(tester, screen);
      expectLegalPlayer(tester, screen);
      expect(h.youTube.created, hasLength(1));
      await endRoundScreen(tester, h);
    });

    testWidgets('a split-screen window (360x356) gets the full-width player '
        'on top', (tester) async {
      const screen = Size(360, 356);
      final h = await djRound(tester, screen);
      expectLegalPlayer(tester, screen);
      expect(tester.getRect(_player).width, 360);
      await endRoundScreen(tester, h);
    });

    testWidgets('a window too small for any legal player shows the cue for '
        'now, and the player comes back when the window grows', (tester) async {
      final h = await djRound(tester, const Size(340, 300));
      expect(tester.takeException(), isNull);
      expect(_player, findsNothing);
      expect(h.youTube.created, isEmpty);
      expect(
        find.text('Northern Lights', skipOffstage: false),
        findsOneWidget,
        reason: 'the cue',
      );
      expect(
        (h.state as GameRoundState).djVideo,
        isA<DjVideoPlayer>(),
        reason: 'a layout shortfall is not a playback failure',
      );
      expect(h.received<RoundPlaybackFailed>(), isEmpty);

      tester.view.physicalSize = const Size(400, 800);
      await tester.pump();
      await tester.pump();
      expectLegalPlayer(tester, const Size(400, 800));
      expect(find.text('Northern Lights', skipOffstage: false), findsNothing);
      await endRoundScreen(tester, h);
    });
  });

  for (final (label, screen, me, room) in [
    ('a guest round', const Size(375, 667), Samples.guestId, null),
    (
      'the youtube DJ',
      const Size(360, 640),
      Samples.hostId,
      Samples.youtubeRoom(),
    ),
  ]) {
    testWidgets('text scale 2.0: $label lays out without overflow', (
      tester,
    ) async {
      final h = await pumpRoundScreen(
        tester,
        screen: screen,
        me: me,
        room: room,
        textScale: 2,
      );
      h.send(
        me == Samples.hostId
            ? Samples.youtubeDjPrepare(
                startAtMonoUs: h.inputClock.monoNowUs + 2500000,
              )
            : Samples.prepare(
                startAtMonoUs: h.inputClock.monoNowUs,
                options: _fourOptions,
              ),
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await endRoundScreen(tester, h);
    });
  }

  testWidgets('reveal after a wrong pick: «Мимо», and the correct option next '
      'to the pick as static tiles; text scale 2.0 fits', (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(375, 667),
      textScale: 2,
      reduceMotion: true,
    );
    h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    await tester.pump();
    expect(
      h.controller.tap(
        roundId: 'round-1',
        optionId: 'opt-a',
        tapMonoUs: h.inputClock.monoNowUs,
      ),
      isTrue,
    );
    h.send(
      Samples.reveal(
        results: const [
          RoundResult(
            playerId: Samples.guestId,
            optionId: 'opt-a',
            correct: false,
            reactionMs: 900,
            points: 0,
            streak: 0,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('reveal-option-opt-c')), findsOneWidget);
    expect(find.byKey(const ValueKey('reveal-option-opt-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('reveal-option-opt-b')), findsNothing);
    expect(find.text('Верно'), findsOneWidget, reason: 'the correct tile');
    expect(find.text('Мимо'), findsNWidgets(2), reason: 'pill and pick');
    expect(find.byType(Image), findsNothing, reason: 'never artwork');
    await endRoundScreen(tester, h);
  });

  testWidgets('reveal after a right answer: «Верно», the points, the '
      "server's streak chip, and no recap", (tester) async {
    final h = await pumpRoundScreen(
      tester,
      screen: const Size(412, 915),
      reduceMotion: true,
    );
    h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    await tester.pump();
    h.controller.tap(
      roundId: 'round-1',
      optionId: 'opt-c',
      tapMonoUs: h.inputClock.monoNowUs,
    );
    h.send(
      Samples.reveal(
        results: const [
          RoundResult(
            playerId: Samples.guestId,
            optionId: 'opt-c',
            correct: true,
            reactionMs: 842,
            points: 986,
            streak: 3,
          ),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Верно'), findsOneWidget);
    expect(find.byType(PointsGained), findsOneWidget);
    expect(find.text('Серия ×3'), findsOneWidget);
    expect(find.byKey(const ValueKey('reveal-option-opt-c')), findsNothing);
    await endRoundScreen(tester, h);
  });

  testWidgets('standings say how a row moved, and grow with large text', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    tester.view
      ..physicalSize = const Size(375, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const rows = [
      StandingRow(
        playerId: 'p-1',
        name: 'Ania',
        rank: 1,
        points: 1200,
        gained: 986,
        isMe: true,
        previousRank: 2,
      ),
      StandingRow(
        playerId: 'p-2',
        name: 'Bartek',
        rank: 2,
        points: 900,
        gained: 0,
        isMe: false,
        previousRank: 1,
      ),
    ];
    await tester.pumpWidget(
      roundApp(
        textScale: 2,
        reduceMotion: true,
        home: const Scaffold(
          body: SingleChildScrollView(child: StandingsList(rows: rows)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel(RegExp('вверх на 1')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('вниз на 1')), findsOneWidget);
    expect(find.byIcon(Icons.emoji_events_rounded), findsOneWidget);
    final extent = tester.getSize(find.byType(StandingsList)).height / 2;
    expect(extent, greaterThan(StandingsList.rowHeight));
    semantics.dispose();
  });

  testWidgets('GamePage: no fade into the youtube DJ screen; «Выйти» there '
      'confirms inline (no dialog over the player) and a server error is '
      'not toasted', (tester) async {
    final h = await pumpGamePage(
      tester,
      me: Samples.hostId,
      room: Samples.youtubeRoom(),
    );
    await tester.pump();
    expect(find.byType(StatusScreen), findsOneWidget);

    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    expect(_player, findsOneWidget);
    expect(find.byType(StatusScreen), findsNothing, reason: 'dropped at once');
    final around = _between(
      tester,
      find.byType(DjVideoSlot),
      (w) => w is SafeArea,
    );
    expect(
      _decorations(around),
      isEmpty,
      reason: '${around.map((w) => w.runtimeType)}',
    );
    expect(tester.hasRunningAnimations, isFalse);

    h.send(const ServerError(code: 'rate_limited', message: 'slow down'));
    await tester.pump();
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);

    // First press: the inline confirm, no dialog; «Остаться» undoes it.
    await tester.tap(find.byKey(const ValueKey('game-leave')));
    await tester.pump();
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Выйти из игры?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-leave-cancel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('game-leave')), findsOneWidget);

    // No time limit (WCAG 2.2.1); two presses leave.
    await tester.tap(find.byKey(const ValueKey('game-leave')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    await tester.tap(find.byKey(const ValueKey('game-leave-confirm')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('HOME'), findsOneWidget);
    expect(h.youTube.live, isEmpty);
    await endRoundScreen(tester, h);
  });

  testWidgets('GamePage without the player: «Выйти» asks with the dialog', (
    tester,
  ) async {
    final h = await pumpGamePage(tester, me: Samples.guestId);
    h.send(Samples.prepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('game-leave')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AlertDialog), findsNothing);
    await endRoundScreen(tester, h);
  });
}
