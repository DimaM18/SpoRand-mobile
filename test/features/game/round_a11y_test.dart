import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/widgets/emoji_puzzle.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import '../../support/protocol_samples.dart';
import '../../support/round_screen_harness.dart';

final _player = find.byKey(const ValueKey('youtube-player-tEsTvIdEo01'));

/// Wave 6 fix round 1: reduce-motion, large text and screen-reader
/// regressions of the round screens.
void main() {
  group('StartingScreen', () {
    for (final (label, platformOff) in [
      ('reduce-motion (MediaQuery)', false),
      ('Android «Remove animations» (platform flag)', true),
    ]) {
      testWidgets('$label: the countdown still counts down in real time', (
        tester,
      ) async {
        if (platformOff) {
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
        }
        await tester.pumpWidget(
          roundApp(
            reduceMotion: true,
            home: const Scaffold(
              body: StartingScreen(
                state: GameStartingState(
                  gameId: 'g-1',
                  roundsTotal: 10,
                  countdownMs: 3000,
                ),
              ),
            ),
          ),
        );
        expect(find.text('3'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1100));
        expect(find.text('2'), findsOneWidget);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1'), findsOneWidget);
        await tester.pump(const Duration(seconds: 2));
        expect(find.text('1'), findsOneWidget, reason: 'never shows 0');
      });
    }
  });

  group('EmojiPuzzle', () {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('text scale $scale: every glyph fits its slot (nothing '
          'paints over a neighbour or the card) and the row fits the width', (
        tester,
      ) async {
        tester.view
          ..physicalSize = const Size(360, 640)
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final revealed in [false, true]) {
          await tester.pumpWidget(
            roundApp(
              textScale: scale,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 296,
                    child: Center(
                      child: EmojiPuzzle(
                        emoji: '🎭🎼👑🌙🔥🎸',
                        revealed: revealed,
                        animate: false,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byType(EmojiPuzzle)).width,
            lessThanOrEqualTo(296),
          );
          final glyphs = find.descendant(
            of: find.byType(EmojiPuzzle),
            matching: find.byType(RichText),
          );
          expect(glyphs, findsNWidgets(6));
          for (final element in glyphs.evaluate()) {
            final paragraph = element.renderObject! as RenderParagraph;
            final needW = paragraph.getMaxIntrinsicWidth(double.infinity);
            final needH = paragraph.getMinIntrinsicHeight(double.infinity);
            expect(
              paragraph.size.width,
              greaterThanOrEqualTo(needW - 0.01),
              reason: 'revealed=$revealed: the glyph is not clamped',
            );
            expect(paragraph.size.height, greaterThanOrEqualTo(needH - 0.01));
            // The slot (the nearest fixed SizedBox) holds the whole glyph.
            RenderBox? slot;
            element.visitAncestorElements((ancestor) {
              final widget = ancestor.widget;
              if (widget is SizedBox && widget.width != null) {
                slot = ancestor.renderObject as RenderBox?;
                return false;
              }
              return true;
            });
            expect(slot, isNotNull);
            expect(slot!.size.width, greaterThanOrEqualTo(needW));
            expect(slot!.size.height, greaterThanOrEqualTo(needH));
          }
        }
      });
    }
  });

  group('GamePage inline leave confirm (YouTube DJ screen)', () {
    setUpAll(loadBundledFonts);

    for (final (width, scale) in [
      (360.0, 1.0),
      (360.0, 1.5),
      (360.0, 2.0),
      (356.0, 2.0),
      (412.0, 2.0),
    ]) {
      testWidgets('$width dp at text scale $scale: «Остаться» and «Выйти из '
          'игры?» keep 48x48 targets inside the app bar, and the player '
          'does not move', (tester) async {
        final h = await pumpGamePage(
          tester,
          me: Samples.hostId,
          room: Samples.youtubeRoom(),
          screen: Size(width, 780),
          textScale: scale,
        );
        h.send(
          Samples.youtubeDjPrepare(
            startAtMonoUs: h.inputClock.monoNowUs + 2500000,
          ),
        );
        await tester.pump();
        await tester.pump();
        final player = tester.getRect(_player);
        await tester.tap(find.byKey(const ValueKey('game-leave')));
        await tester.pump();
        await tester.pump();
        expect(tester.takeException(), isNull);
        for (final key in ['game-leave-cancel', 'game-leave-confirm']) {
          final rect = tester.getRect(find.byKey(ValueKey(key)));
          expect(rect.height, greaterThanOrEqualTo(48), reason: key);
          expect(rect.width, greaterThanOrEqualTo(48), reason: key);
          expect(rect.left, greaterThanOrEqualTo(0), reason: key);
          expect(rect.right, lessThanOrEqualTo(width), reason: key);
          expect(rect.bottom, lessThanOrEqualTo(player.top), reason: key);
        }
        expect(tester.getRect(_player), player, reason: 'player untouched');
        await endRoundScreen(tester, h);
      });
    }

    testWidgets('no time limit, and focus moves to «Остаться» when the '
        'confirm appears', (tester) async {
      final h = await pumpGamePage(
        tester,
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
      await tester.tap(find.byKey(const ValueKey('game-leave')));
      await tester.pump();
      await tester.pump();
      final cancel = find.byKey(const ValueKey('game-leave-cancel'));
      final focused = FocusManager.instance.primaryFocus?.context;
      expect(focused, isNotNull);
      expect(
        find.ancestor(
          of: find.byElementPredicate((e) => e == focused),
          matching: cancel,
        ),
        findsOneWidget,
        reason: 'focus is on «Остаться»',
      );
      await tester.pump(const Duration(seconds: 30));
      expect(find.byKey(const ValueKey('game-leave-confirm')), findsOneWidget);
      await tester.tap(cancel);
      await tester.pump();
      expect(find.byKey(const ValueKey('game-leave')), findsOneWidget);
      await endRoundScreen(tester, h);
    });
  });
}
