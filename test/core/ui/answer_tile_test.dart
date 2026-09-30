import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';

import '../../support/round_screen_harness.dart' show loadBundledFonts;
import 'ui_harness.dart';

const _anchorUs = 5000000;

Widget _grid({
  required InputClock clock,
  required AnswerTileMode Function(int index) mode,
  required List<int?> commits,
  int count = 4,
}) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    for (var i = 0; i < count; i++)
      Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: AnswerTile(
          key: ValueKey('answer-$i'),
          label: 'Option ${String.fromCharCode(0x41 + i)}',
          index: i,
          mode: mode(i),
          clock: clock,
          onCommit: commits.add,
        ),
      ),
  ],
);

Finder _tile(int i) => find.byKey(ValueKey('answer-$i'));

void main() {
  testWidgets('input is a Listener: no GestureDetector, InkWell or Opacity '
      'inside a tile', (tester) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (_) => AnswerTileMode.open, commits: []),
    );
    for (final type in [
      GestureDetector,
      InkWell,
      InkResponse,
      Opacity,
      AnimatedOpacity,
    ]) {
      expect(
        find.descendant(of: _tile(0), matching: find.byType(type)),
        findsNothing,
        reason: '$type inside an answer tile',
      );
    }
    final listener = tester.widget<Listener>(
      find.descendant(of: _tile(0), matching: find.byType(Listener)).first,
    );
    expect(listener.onPointerDown, isNotNull);
    expect(listener.behavior, HitTestBehavior.opaque);
    for (final type in [IgnorePointer, AbsorbPointer]) {
      expect(
        find.descendant(of: _tile(0), matching: find.byType(type)),
        findsNothing,
      );
    }
    expect(
      tester
          .widgetList<IgnorePointer>(
            find.ancestor(of: _tile(0), matching: find.byType(IgnorePointer)),
          )
          .where((w) => w.ignoring),
      isEmpty,
    );
  });

  testWidgets('a pointer down commits the OS touch time minus the anchor, '
      'before the finger lifts', (tester) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    final commits = <int?>[];
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (_) => AnswerTileMode.open, commits: commits),
    );
    const osUs = 9876543;
    final finger = TestPointer(1);
    await tester.sendEventToBinding(
      finger.down(
        tester.getCenter(_tile(2)),
        timeStamp: const Duration(microseconds: osUs),
      ),
    );
    expect(commits, [osUs - _anchorUs]);
    await tester.pump();
    await tester.sendEventToBinding(finger.up());
    await tester.pump();
    expect(commits, hasLength(1));
  });

  testWidgets('locked, picked and reveal tiles do not commit; a screen '
      'reader activation commits null', (tester) async {
    final semantics = tester.ensureSemantics();
    final clock = FakeInputClock(anchorUs: _anchorUs);
    final commits = <int?>[];
    final modes = [
      AnswerTileMode.locked,
      AnswerTileMode.picked,
      AnswerTileMode.correct,
      AnswerTileMode.open,
    ];
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (i) => modes[i], commits: commits),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tap(_tile(i), warnIfMissed: false);
    }
    expect(commits, isEmpty);

    expect(tester.getSemantics(_tile(3)).label, 'Ромб: Option D');
    tester.semantics.tap(find.semantics.byLabel('Ромб: Option D'));
    expect(commits, [null]);

    expect(
      tester.getSemantics(_tile(1)),
      isSemantics(
        label: 'Треугольник: Option B',
        value: 'Твой ответ',
        isSelected: true,
        isEnabled: false,
        isButton: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the state word is the semantics value (never only a hint); '
      'reveal recap tiles are static information, not disabled buttons', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final clock = FakeInputClock(anchorUs: _anchorUs);
    final modes = [AnswerTileMode.correct, AnswerTileMode.wrong];
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (i) => modes[i], commits: [], count: 2),
    );
    final correct = tester.getSemantics(_tile(0));
    expect(correct.label, 'Круг: Option A');
    expect(correct.value, 'Верно');
    expect(correct.hint, isEmpty);
    expect(correct.flagsCollection.isButton, isFalse);
    expect(correct.flagsCollection.isEnabled, Tristate.none);
    final wrong = tester.getSemantics(_tile(1));
    expect(wrong.label, 'Треугольник: Option B');
    expect(wrong.value, 'Мимо');
    expect(wrong.flagsCollection.isButton, isFalse);
    expect(
      find.descendant(of: _tile(0), matching: find.byType(Listener)),
      findsNothing,
      reason: 'a recap tile takes no input at all',
    );
    semantics.dispose();
  });

  testWidgets('the unlock is instant: the first open frame has no running '
      'animation and the tile is fully opaque', (tester) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    var mode = AnswerTileMode.locked;
    late StateSetter setMode;
    await pumpUi(
      tester,
      StatefulBuilder(
        builder: (context, setState) {
          setMode = setState;
          return _grid(clock: clock, mode: (_) => mode, commits: []);
        },
      ),
    );
    setMode(() => mode = AnswerTileMode.open);
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
    expect(
      find.descendant(of: _tile(0), matching: find.byType(AnimatedOpacity)),
      findsNothing,
    );
    final scale = tester.widget<AnimatedScale>(
      find.descendant(of: _tile(0), matching: find.byType(AnimatedScale)),
    );
    expect(scale.scale, 1);
  });

  testWidgets('pressed shrinks to 0.97, never grows; reduce-motion keeps the '
      'scale at 1', (tester) async {
    for (final reduce in [false, true]) {
      final clock = FakeInputClock(anchorUs: _anchorUs);
      await pumpUi(
        tester,
        _grid(clock: clock, mode: (_) => AnswerTileMode.open, commits: []),
        reduceMotion: reduce,
      );
      final finger = TestPointer(1);
      await tester.sendEventToBinding(finger.down(tester.getCenter(_tile(0))));
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(
        find.descendant(of: _tile(0), matching: find.byType(AnimatedScale)),
      );
      expect(scale.scale, reduce ? 1 : 0.97);
      expect(scale.scale, lessThanOrEqualTo(1));
      await tester.sendEventToBinding(finger.up());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AnimatedScale>(
              find.descendant(
                of: _tile(0),
                matching: find.byType(AnimatedScale),
              ),
            )
            .scale,
        1,
      );
    }
  });

  testWidgets('tiles are at least 88 dp tall, 76 dp on compact screens, and '
      'four fit above the fold at 375x667', (tester) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (_) => AnswerTileMode.open, commits: []),
    );
    expect(tester.getSize(_tile(0)).height, greaterThanOrEqualTo(88));

    await pumpUi(
      tester,
      _grid(clock: clock, mode: (_) => AnswerTileMode.open, commits: []),
      size: const Size(375, 667),
    );
    expect(tester.getSize(_tile(0)).height, greaterThanOrEqualTo(76));
    expect(tester.getRect(_tile(3)).bottom, lessThanOrEqualTo(667));
  });

  testWidgets('long labels at text scale 2.0 grow the tile without overflow', (
    tester,
  ) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    await pumpUi(
      tester,
      Column(
        children: [
          for (final (i, mode) in AnswerTileMode.values.indexed)
            AnswerTile(
              key: ValueKey('answer-$i'),
              label: 'Очень длинное название песни, которое не влезет',
              index: i,
              mode: mode,
              clock: clock,
              onCommit: (_) {},
            ),
        ],
      ),
      size: const Size(360, 640),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(_tile(0)).height, greaterThan(88));
  });

  group('with the bundled fonts', () {
    setUpAll(loadBundledFonts);

    // The longest labels of the emoji catalogue, with a decoy that differs
    // only in its last letters (emoji_distractor_strategy=mangled).
    const labels = [
      "You're the One That I Want — John Travolta & Olivia Newton-John",
      "You're the One That I Want — John Travolta & Olivia Newton-Jones",
      'Welcome to the Black Parade — My Chemical Romance',
      'Welcome to the Black Parade — My Chemical Romanse',
    ];

    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('360x640 at text scale $scale: an emoji-quiz label is '
          'never cut, the title and the artist sit on their own lines and '
          'no line starts with «—»', (tester) async {
        final clock = FakeInputClock(anchorUs: _anchorUs);
        await pumpUi(
          tester,
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, label) in labels.indexed)
                AnswerTile(
                  key: ValueKey('answer-$i'),
                  label: label,
                  index: i,
                  mode: i.isEven ? AnswerTileMode.open : AnswerTileMode.picked,
                  clock: clock,
                  onCommit: (_) {},
                ),
            ],
          ),
          size: const Size(360, 640),
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        for (var i = 0; i < labels.length; i++) {
          final paragraphs = tester.renderObjectList<RenderParagraph>(
            find.descendant(of: _tile(i), matching: find.byType(RichText)),
          );
          for (final p in paragraphs) {
            expect(p.didExceedMaxLines, isFalse, reason: labels[i]);
            expect(p.maxLines, isNull, reason: 'never truncated');
            expect(p.text.toPlainText().startsWith('—'), isFalse);
            expect(p.text.toPlainText().contains(' — '), isFalse);
          }
        }
        expect(find.text("You're the One That I Want"), findsNWidgets(2));
        expect(find.text('John Travolta & Olivia Newton-John'), findsOneWidget);
        expect(
          find.text('John Travolta & Olivia Newton-Jones'),
          findsOneWidget,
        );
        expect(find.text('My Chemical Romanse'), findsOneWidget);
        // Screen readers still get the whole label.
        expect(
          tester.getSemantics(_tile(2)).label,
          'Квадрат: Welcome to the Black Parade — My Chemical Romance',
        );
      });
    }

    test('splitLabel splits «Title — Artist» at the last separator only', () {
      expect(AnswerTile.splitLabel('Dominik'), ('Dominik', null));
      expect(AnswerTile.splitLabel('Bohemian Rhapsody — Queen'), (
        'Bohemian Rhapsody',
        'Queen',
      ));
      expect(AnswerTile.splitLabel('A — B — C'), ('A — B', 'C'));
      expect(AnswerTile.splitLabel(' — Queen'), (' — Queen', null));
      expect(AnswerTile.splitLabel('Queen — '), ('Queen — ', null));
    });
  });

  testWidgets('each state carries an icon and a word, not colour alone', (
    tester,
  ) async {
    final clock = FakeInputClock(anchorUs: _anchorUs);
    final modes = [
      AnswerTileMode.picked,
      AnswerTileMode.correct,
      AnswerTileMode.wrong,
    ];
    await pumpUi(
      tester,
      _grid(clock: clock, mode: (i) => modes[i], commits: [], count: 3),
      dark: false,
    );
    expect(find.text('Твой ответ'), findsOneWidget);
    expect(find.text('Верно'), findsOneWidget);
    expect(find.text('Мимо'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
    expect(find.byType(AnswerMarker), findsNWidgets(3));
  });

  test('six distinct shapes and letters A..F, wrapping after six', () {
    expect(AnswerShape.values, hasLength(GameColors.slots));
    expect(
      [for (var i = 0; i < 7; i++) AnswerShape.letterFor(i)],
      ['A', 'B', 'C', 'D', 'E', 'F', 'A'],
    );
    expect(AnswerShape.forIndex(6), AnswerShape.circle);
    for (final shape in AnswerShape.values) {
      final bounds = shape.path(const Size(40, 40)).getBounds();
      expect(bounds.width, greaterThan(20), reason: '$shape');
      expect(
        const Rect.fromLTWH(-1, -1, 42, 42).contains(bounds.topLeft) &&
            const Rect.fromLTWH(-1, -1, 42, 42).contains(bounds.bottomRight),
        isTrue,
        reason: '$shape fits its box',
      );
    }
  });
}
