import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/theme/app_theme.dart';
import 'package:sporand/core/theme/tokens.dart';
import 'package:sporand/core/ui/ui.dart';

import 'ui_harness.dart';

void main() {
  group('PartyButton', () {
    testWidgets('is a 64 dp hero on the cta gradient, 56 dp compact', (
      tester,
    ) async {
      var presses = 0;
      await pumpUi(
        tester,
        Column(
          children: [
            PartyButton(
              key: const ValueKey('hero'),
              label: 'Создать комнату',
              icon: Icons.add_rounded,
              onPressed: () => presses++,
            ),
            PartyButton(
              key: const ValueKey('compact'),
              label: 'Создать',
              compact: true,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byKey(const ValueKey('hero'))).height, 64);
      expect(tester.getSize(find.byKey(const ValueKey('compact'))).height, 56);
      final box = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byKey(const ValueKey('hero')),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      final decoration = box.decoration as ShapeDecoration;
      expect(
        (decoration.gradient! as LinearGradient).colors,
        PartyColors.dark.ctaGradient,
      );
      await tester.tap(find.text('Создать комнату'));
      expect(presses, 1);
    });

    testWidgets('pressed shrinks (not under reduce-motion); disabled and '
        'loading do not fire', (tester) async {
      for (final reduce in [false, true]) {
        await pumpUi(
          tester,
          PartyButton(label: 'Начать игру', onPressed: () {}),
          reduceMotion: reduce,
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(PartyButton)),
        );
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
          reduce ? 1 : 0.97,
        );
        await gesture.up();
        await tester.pumpAndSettle();
      }

      var presses = 0;
      await pumpUi(
        tester,
        Column(
          children: [
            const PartyButton(label: 'Выключена', onPressed: null),
            PartyButton(
              label: 'Грузится',
              icon: Icons.add_rounded,
              loading: true,
              onPressed: () => presses++,
            ),
          ],
        ),
      );
      await tester.tap(find.text('Выключена'));
      await tester.tap(find.text('Грузится'));
      expect(presses, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsNothing);
    });

    testWidgets('loading says «Загрузка…» to screen readers (a live '
        'value), not just "disabled"', (tester) async {
      final semantics = tester.ensureSemantics();
      var loading = true;
      late StateSetter setLoading;
      await pumpUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setLoading = setState;
            return PartyButton(
              label: 'Создать комнату',
              loading: loading,
              onPressed: () {},
            );
          },
        ),
      );
      final busy = find.bySemanticsLabel(RegExp('Создать комнату'));
      expect(busy, findsOneWidget);
      final node = tester.getSemantics(busy);
      expect(node.value, 'Загрузка…');
      expect(node.flagsCollection.isLiveRegion, isTrue);
      setLoading(() => loading = false);
      await tester.pump();
      final idle = tester.getSemantics(
        find.bySemanticsLabel(RegExp('Создать комнату')),
      );
      expect(idle.value, isEmpty);
      semantics.dispose();
    });

    testWidgets('wraps at text scale 2.0 without overflow', (tester) async {
      await pumpUi(
        tester,
        PartyButton(
          label: 'Очень длинная надпись на главной кнопке экрана',
          icon: Icons.play_arrow_rounded,
          onPressed: () {},
        ),
        size: const Size(360, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(PartyButton)).height, greaterThan(64));
    });
  });

  group('TimedCtaButton', () {
    testWidgets('commits the pointer time on down; done is tonal and inert', (
      tester,
    ) async {
      final clock = FakeInputClock(anchorUs: 1000);
      final commits = <int?>[];
      var done = false;
      late StateSetter setDone;
      await pumpUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setDone = setState;
            return TimedCtaButton(
              key: const ValueKey('dj-music-playing'),
              label: 'Музыка играет!',
              hint: 'Нажми, когда песня началась',
              doneLabel: 'Отмечено',
              done: done,
              clock: clock,
              onCommit: commits.add,
            );
          },
        ),
      );
      final button = find.byKey(const ValueKey('dj-music-playing'));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(88));
      expect(
        find.descendant(of: button, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      final finger = TestPointer(1);
      await tester.sendEventToBinding(
        finger.down(
          tester.getCenter(button),
          timeStamp: const Duration(microseconds: 51000),
        ),
      );
      expect(commits, [50000]);
      await tester.sendEventToBinding(finger.up());
      setDone(() => done = true);
      await tester.pump();
      expect(find.text('Отмечено'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(button);
      expect(commits, hasLength(1));
      final box = tester.widget<Container>(
        find.descendant(of: button, matching: find.byType(Container)).first,
      );
      expect(
        (box.decoration! as BoxDecoration).color,
        AppColorsProbe.primaryContainer(tester, button),
      );
    });
  });

  group('cards and headline', () {
    testWidgets('a cta card puts onCta on the cta gradient; the headline '
        'reads as plain text', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        const Column(
          children: [
            PartyCard(
              tone: PartyCardTone.cta,
              child: Row(
                children: [
                  Icon(Icons.headphones_rounded),
                  Text('Это твой трек!'),
                ],
              ),
            ),
            GradientHeadline('Угадай песню'),
          ],
        ),
      );
      final text = tester.widget<RichText>(
        find.descendant(
          of: find.text('Это твой трек!'),
          matching: find.byType(RichText),
        ),
      );
      expect(text.text.style?.color, PartyColors.dark.onCta);
      expect(
        tester.getSemantics(find.byType(GradientHeadline)),
        isSemantics(label: 'Угадай песню', isHeader: true),
      );
      expect(find.byType(ShaderMask), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the headline gradient spans the glyphs (its longest line), '
        'not the whole row, so a wrapped headline reaches the last stop', (
      tester,
    ) async {
      for (final align in [TextAlign.start, TextAlign.center]) {
        await pumpUi(
          tester,
          ListView(
            shrinkWrap: true,
            children: [GradientHeadline('Чья это песня?', textAlign: align)],
          ),
          size: const Size(390, 844),
          scroll: false,
        );
        final mask = tester.renderObject<RenderBox>(find.byType(ShaderMask));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.byType(ShaderMask),
            matching: find.byType(RichText),
          ),
        );
        final painter = TextPainter(
          text: paragraph.text,
          textDirection: TextDirection.ltr,
          textScaler: paragraph.textScaler,
        )..layout(maxWidth: 358);
        final longest = painter
            .computeLineMetrics()
            .map((line) => line.width)
            .reduce(math.max);
        expect(painter.computeLineMetrics(), hasLength(greaterThan(1)));
        painter.dispose();
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(mask.size.width, lessThan(358), reason: '$align');
        expect(mask.size.width, closeTo(longest, 1), reason: '$align');
        final left = tester.getTopLeft(find.byType(ShaderMask)).dx;
        if (align == TextAlign.start) {
          expect(left, 16, reason: 'starts at the gutter');
        } else {
          expect(left + mask.size.width / 2, closeTo(390 / 2, 1));
        }
      }
    });
  });

  group('chips', () {
    testWidgets('selected chips carry a check; locked chips a lock; the hit '
        'area is at least 48 dp', (tester) async {
      final toggles = <bool>[];
      await pumpUi(
        tester,
        Wrap(
          children: [
            PartyChip(
              key: const ValueKey('on'),
              label: '10 раундов',
              selected: true,
              onSelected: toggles.add,
            ),
            PartyChip(
              key: const ValueKey('locked'),
              label: '20 раундов',
              selected: false,
              locked: true,
              lockedTooltip: 'Premium',
              onSelected: toggles.add,
            ),
            const StatusChip(
              icon: Icons.local_fire_department_rounded,
              label: 'Бонус',
            ),
          ],
        ),
      );
      expect(
        tester.getSize(find.byKey(const ValueKey('on'))).height,
        greaterThanOrEqualTo(48),
      );
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('on')));
      await tester.tap(find.byKey(const ValueKey('locked')));
      expect(toggles, [false, true]);
      expect(find.text('Бонус'), findsOneWidget);
    });
  });

  group('PlayerAvatar', () {
    testWidgets('a neutral monogram disc (never an answer colour), a me '
        'ring and a badge; no images', (tester) async {
      await pumpUi(
        tester,
        const Row(
          children: [
            PlayerAvatar(
              key: ValueKey('me'),
              playerId: 'p-1',
              name: 'аня',
              isMe: true,
            ),
            PlayerAvatar(
              key: ValueKey('host'),
              playerId: 'p-2',
              name: '  ',
              size: 56,
              badge: PlayerBadge.host,
            ),
          ],
        ),
      );
      expect(find.text('А'), findsOneWidget);
      expect(find.text('?'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(PlayerAvatar.monogram('Łukasz'), 'Ł');

      // In «Чья песня?» the answers are the players: an avatar must never
      // wear a slot colour, or «amber» means Celina here and slot D there.
      final theme = Theme.of(tester.element(find.byKey(const ValueKey('me'))));
      final game = GameColors.of(
        tester.element(find.byKey(const ValueKey('me'))),
      );
      final fills = [
        for (final box in tester.widgetList<DecoratedBox>(
          find.byKey(const ValueKey('avatar-disc')),
        ))
          if (box.decoration case BoxDecoration(
            shape: BoxShape.circle,
            :final color?,
          ))
            color,
      ];
      expect(fills, hasLength(2));
      for (final fill in fills) {
        expect(fill, theme.colorScheme.surfaceContainerHighest);
        expect(game.answers, isNot(contains(fill)));
      }
      final monogram = tester.widget<Text>(find.text('А'));
      expect(monogram.style?.color, theme.colorScheme.onSurface);
    });
  });

  group('AnswerTimerRing', () {
    testWidgets('visual countdown: urgent number in the last 5 s, then it '
        'stops ticking', (tester) async {
      final semantics = tester.ensureSemantics();
      var running = false;
      late StateSetter setRunning;
      await pumpUi(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            setRunning = setState;
            return AnswerTimerRing(
              window: const Duration(seconds: 12),
              running: running,
            );
          },
        ),
      );
      expect(tester.hasRunningAnimations, isFalse);
      setRunning(() => running = true);
      await tester.pump();
      expect(find.text('12'), findsNothing);
      expect(
        tester.getSemantics(find.byType(AnswerTimerRing)),
        isSemantics(label: 'Осталось 12 с'),
      );
      await tester.pump(const Duration(seconds: 7, milliseconds: 100));
      expect(find.text('5'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.getSize(find.byType(AnswerTimerRing)), const Size(56, 56));
      semantics.dispose();
    });

    for (final reduced in [false, true]) {
      testWidgets('keeps real time when the platform removes animations '
          '(Android «Remove animations» scales normal controllers to 5 %); '
          'reduce-motion=$reduced', (tester) async {
        final semantics = tester.ensureSemantics();
        tester.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: true);
        addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
        );
        await pumpUi(
          tester,
          const AnswerTimerRing(window: Duration(seconds: 15), running: true),
          reduceMotion: reduced,
        );
        await tester.pump(const Duration(seconds: 1));
        expect(
          tester.getSemantics(find.byType(AnswerTimerRing)),
          isSemantics(label: 'Осталось 14 с'),
        );
        expect(find.text('0'), findsNothing);
        // Reduce-motion steps on a timer: no frame loop at all.
        expect(tester.hasRunningAnimations, !reduced);
        await tester.pump(const Duration(seconds: 9, milliseconds: 100));
        expect(
          tester.getSemantics(find.byType(AnswerTimerRing)),
          isSemantics(label: 'Осталось 5 с'),
        );
        await tester.pump(const Duration(seconds: 6));
        expect(find.text('0'), findsOneWidget);
        semantics.dispose();
      });
    }
  });

  group('reveal feedback', () {
    testWidgets('pill, points and streak; celebration only when motion is '
        'allowed', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final reduce in [false, true]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pumpUi(
          tester,
          const Column(
            children: [
              CelebrationBurst(
                play: true,
                child: ResultPill(kind: ResultKind.correct),
              ),
              ResultPill(kind: ResultKind.wrong),
              ResultPill(kind: ResultKind.noAnswer),
              PointsGained(points: 120),
              StreakChip(streak: 3),
              StreakChip(streak: 1),
            ],
          ),
          reduceMotion: reduce,
        );
        expect(find.text('Верно'), findsOneWidget);
        expect(find.text('Мимо'), findsOneWidget);
        expect(find.text('Без ответа'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
        expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
        expect(find.text('Серия ×3'), findsOneWidget);
        expect(find.text('Серия ×1'), findsNothing);
        expect(
          tester.getSemantics(find.byType(PointsGained)),
          isSemantics(label: '+120'),
        );
        if (reduce) {
          // Count-up jumps, no scale-in, no burst.
          expect(find.text('+120'), findsOneWidget);
          expect(tester.hasRunningAnimations, isFalse);
          expect(
            find.descendant(
              of: find.byType(CelebrationBurst),
              matching: find.byType(CustomPaint),
            ),
            findsNothing,
          );
        } else {
          expect(tester.hasRunningAnimations, isTrue);
          await tester.pumpAndSettle();
          expect(find.text('+120'), findsOneWidget);
        }
      }
      semantics.dispose();
    });
  });

  group('PartyActionBar', () {
    testWidgets('a bottom bar on surfaceContainer with a hairline top edge, '
        'so the list above ends at a visible edge', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark(),
          home: Scaffold(
            body: ListView(
              children: [for (var i = 0; i < 30; i++) Text('row $i')],
            ),
            bottomNavigationBar: PartyActionBar(
              children: [PartyButton(label: 'Сыграть ещё', onPressed: () {})],
            ),
          ),
        ),
      );
      final bar = find.byType(PartyActionBar);
      final scheme = AppTheme.darkScheme;
      final box = tester.widget<DecoratedBox>(
        find.descendant(of: bar, matching: find.byType(DecoratedBox)).first,
      );
      final decoration = box.decoration as BoxDecoration;
      expect(decoration.color, scheme.surfaceContainer);
      expect(
        (decoration.border! as Border).top,
        BorderSide(color: scheme.outlineVariant),
      );
      expect(tester.getRect(bar).bottom, 844);
      expect(
        tester.getSize(find.byType(PartyButton)).height,
        greaterThanOrEqualTo(64),
      );
    });
  });

  group('banners, toasts, sheets and loaders', () {
    testWidgets('a banner is in layout and a live region; a toast replaces '
        'the previous one', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        Builder(
          builder: (context) => Column(
            children: [
              const PartyBanner(
                icon: Icons.wifi_tethering_rounded,
                message: 'Переподключаемся…',
              ),
              TextButton(
                onPressed: () {
                  showPartyToast(context, 'Первый');
                  showPartyToast(context, 'Второй');
                },
                child: const Text('toast'),
              ),
            ],
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(PartyBanner)),
        isSemantics(isLiveRegion: true),
      );
      expect(
        find.ancestor(
          of: find.byType(PartyBanner),
          matching: find.byType(Positioned),
        ),
        findsNothing,
      );
      await tester.tap(find.text('toast'));
      await tester.pumpAndSettle();
      expect(find.text('Второй'), findsOneWidget);
      expect(find.text('Первый'), findsNothing);
      semantics.dispose();
    });

    testWidgets('a sheet has the themed shape and a drag handle', (
      tester,
    ) async {
      await pumpUi(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showPartySheet<void>(
              context: context,
              builder: (_) => const Text('В листе'),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('В листе'), findsOneWidget);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.showDragHandle ?? true, isTrue);
      final material = tester.widget<Material>(
        find
            .descendant(
              of: find.byType(BottomSheet),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(
        material.shape,
        const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        ),
      );
    });

    testWidgets('the loader freezes under reduce-motion and announces its '
        'status', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpUi(
        tester,
        const Column(
          children: [
            PartyLoader(status: 'Считаем очки…'),
            SkeletonRow(),
            InlineSpinner(),
          ],
        ),
        reduceMotion: true,
      );
      expect(
        tester.widget<EqualizerBars>(find.byType(EqualizerBars)).animate,
        isFalse,
      );
      expect(
        tester.getSemantics(find.text('Считаем очки…')),
        isSemantics(isLiveRegion: true),
      );
      expect(tester.getSize(find.byType(InlineSpinner)), const Size(20, 20));
      semantics.dispose();
    });
  });
}

/// Reads theme colours for assertions.
abstract final class AppColorsProbe {
  static Color primaryContainer(WidgetTester tester, Finder finder) =>
      Theme.of(tester.element(finder)).colorScheme.primaryContainer;
}
