import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/presentation/widgets/equalizer_bars.dart';
import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/reveal_view.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

/// The round and reveal screens over a [GameHarness] (Russian UI).
Future<GameHarness> _emojiHarness(
  WidgetTester tester, {
  bool reduceMotion = false,
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  if (reduceMotion) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }
  final h = GameHarness(clock: tester.binding.clock, flush: () {});
  await tester.pump();
  h.send(
    Samples.welcome(
      room: Samples.room(
        mode: GameMode.emojiQuiz,
        state: RoomState.roundPlaying,
      ),
    ),
  );
  await tester.pump();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: h.container,
      child: MaterialApp(
        theme: AppTheme.dark(),
        locale: const Locale('ru'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
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

Future<void> _end(WidgetTester tester, GameHarness h) async {
  h.dispose();
  await tester.pump();
}

Finder _answer(String optionId) => find.byKey(ValueKey('answer-$optionId'));

double _opacityOf(WidgetTester tester, String glyph) => tester
    .widget<Opacity>(
      find.ancestor(of: find.text(glyph), matching: find.byType(Opacity)).first,
    )
    .opacity;

void main() {
  testWidgets('emoji round: the puzzle stays hidden until the round opens '
      'for everyone, then the first pointer down answers with the OS touch '
      'time; the reveal shows title, artist and year', (tester) async {
    final h = await _emojiHarness(tester);
    h.send(
      Samples.emojiPrepare(startAtMonoUs: h.inputClock.monoNowUs + 1000000),
    );
    await tester.pump();

    expect(find.text('Какая это песня?'), findsOneWidget);
    expect(find.text('Приготовься…'), findsOneWidget);
    expect(find.text('🎭'), findsNothing, reason: 'not before start_at');
    expect(find.text('?'), findsNWidgets(3));
    expect(find.byType(EqualizerBars), findsNothing, reason: 'no audio');
    for (final option in Samples.emojiOptions) {
      expect(_answer(option.optionId), findsOneWidget);
    }

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.text('Жми быстрее всех!'), findsOneWidget);
    for (final glyph in ['🎭', '🎼', '👑']) {
      expect(find.text(glyph), findsOneWidget);
    }
    // The emoji pop in over a few hundred milliseconds.
    expect(_opacityOf(tester, '👑'), lessThan(1));
    await tester.pump(const Duration(milliseconds: 600));
    expect(_opacityOf(tester, '👑'), 1);

    final osUs = h.inputClock.nowUs - 15000;
    final finger = TestPointer(1);
    await tester.sendEventToBinding(
      finger.down(
        tester.getCenter(_answer('opt-c')),
        timeStamp: Duration(microseconds: osUs),
      ),
    );
    await tester.pump();
    await tester.sendEventToBinding(finger.up());
    await tester.pump();
    final answer = h.received<RoundAnswer>().single;
    expect(answer.optionId, 'opt-c');
    expect(answer.tapMonoUs, osUs - h.inputClock.anchorUs);
    expect(h.received<RoundPlaybackStarted>(), isEmpty);
    expect(h.playback.prepared, isEmpty);

    h.send(Samples.emojiReveal());
    await tester.pump();
    await tester.pump();
    expect(find.text('Ответ: Bohemian Rhapsody — Queen'), findsOneWidget);
    expect(find.byKey(const ValueKey('reveal-track')), findsOneWidget);
    expect(find.text('Год: 1975'), findsOneWidget);
    expect(find.text('👑'), findsOneWidget, reason: 'the puzzle, solved');
    expect(find.byType(Image), findsNothing, reason: 'never artwork');
    await _end(tester, h);
  });

  testWidgets('with reduced motion the emoji appear at once', (tester) async {
    final h = await _emojiHarness(tester, reduceMotion: true);
    h.send(Samples.emojiPrepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    await tester.pump();
    expect((h.state as GameRoundState).phase, isA<RoundOpen>());
    expect(_opacityOf(tester, '🎭'), 1);
    expect(_opacityOf(tester, '👑'), 1);
    await _end(tester, h);
  });

  testWidgets('the host answers too: no DJ, no owner, nothing to play', (
    tester,
  ) async {
    final h = await _emojiHarness(tester);
    h.send(
      Samples.welcome(
        me: Samples.hostId,
        room: Samples.room(
          mode: GameMode.emojiQuiz,
          state: RoomState.roundPlaying,
        ),
      ),
    );
    await tester.pump();
    h.send(Samples.emojiPrepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    await tester.pump();
    final state = h.state as GameRoundState;
    expect(state.round.isDj, isFalse);
    expect(state.showsButtons, isTrue);
    expect(state.phase, isA<RoundOpen>());
    expect(h.playback.prepared, isEmpty);
    expect(find.byKey(const ValueKey('dj-music-playing')), findsNothing);
    await _end(tester, h);
  });

  testWidgets('a voided round leaves «Раунд пропущен: …» over the spare '
      'without blocking its answers', (tester) async {
    final h = await _emojiHarness(tester);
    h.send(Samples.emojiPrepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    h.send(
      const RoundVoided(
        roundId: 'round-1',
        reason: RoundVoidReason.serverRestart,
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    h.send(
      Samples.emojiPrepare(
        roundId: 'spare-1',
        startAtMonoUs: h.inputClock.monoNowUs,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Раунд пропущен: сервер перезапустился'), findsOneWidget);
    expect((h.state as GameRoundState).phase, isA<RoundOpen>());

    final finger = TestPointer(1);
    await tester.sendEventToBinding(
      finger.down(
        tester.getCenter(_answer('opt-a')),
        timeStamp: Duration(microseconds: h.inputClock.nowUs),
      ),
    );
    await tester.sendEventToBinding(finger.up());
    await tester.pump();
    expect(h.received<RoundAnswer>().single.roundId, 'spare-1');

    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.byKey(const ValueKey('void-notice')), findsNothing);
    await _end(tester, h);
  });
}
