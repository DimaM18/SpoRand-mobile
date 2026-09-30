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
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

/// The round screen over a [GameHarness] (Russian UI).
Future<void> _pumpRoundScreen(WidgetTester tester, GameHarness h) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
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
            builder: (context, ref, _) {
              final state = ref.watch(gameControllerProvider);
              return state is GameRoundState
                  ? RoundScreen(state: state)
                  : const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
}

Future<GameHarness> _harness(
  WidgetTester tester, {
  required String me,
  required Welcome welcome,
}) async {
  final h = GameHarness(clock: tester.binding.clock, flush: () {}, me: me);
  await tester.pump();
  h.send(welcome);
  await tester.pump();
  await _pumpRoundScreen(tester, h);
  return h;
}

/// Cancels the harness timers inside the test body (the binding checks for
/// pending timers before tear-down runs).
Future<void> _end(WidgetTester tester, GameHarness h) async {
  h.dispose();
  await tester.pump();
}

Finder _answer(String optionId) => find.byKey(ValueKey('answer-$optionId'));

Future<void> _pointerDown(
  WidgetTester tester,
  Finder target, {
  required int osUs,
  int pointer = 1,
}) async {
  final finger = TestPointer(pointer);
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

void main() {
  testWidgets('DJ: cue card, hand-off to the music app, and a pointer down on '
      '«Музыка играет!» sends round.playback_started{dj_tap} with the event '
      'time minus the process anchor; with whose_song_dj_can_answer the DJ '
      'then answers', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.hostId,
      welcome: Samples.welcome(
        me: Samples.hostId,
        room: Samples.byopRoom(),
        config: const {'whose_song_dj_can_answer': true},
      ),
    );
    h.send(Samples.djPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000));
    await tester.pump();

    expect(
      find.text('Включи эту песню в своём музыкальном приложении'),
      findsOneWidget,
    );
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(find.text('Test Artist, Example Choir'), findsOneWidget);
    expect(find.byType(Image), findsNothing, reason: 'never artwork or logos');
    expect(_answer('opt-a'), findsNothing);
    expect(h.playback.prepared, isEmpty, reason: 'the app plays nothing');

    await tester.tap(find.text('Открыть в музыкальном приложении'));
    await tester.pump();
    expect(h.musicApp.opened.single.title, 'Northern Lights');

    // The DJ starts the song in their app, then taps; the OS stamped the
    // touch 20 ms before Flutter handled it.
    await tester.pump(const Duration(seconds: 3));
    final tapOsUs = h.inputClock.nowUs - 20000;
    await _pointerDown(
      tester,
      find.byKey(const ValueKey('dj-music-playing')),
      osUs: tapOsUs,
    );

    final started = h.received<RoundPlaybackStarted>().single;
    expect(started.roundId, 'round-1');
    expect(started.source, PlaybackStartSource.djTap);
    expect(started.audioStartMonoUs, tapOsUs - h.inputClock.anchorUs);
    expect(started.outputLatencyMs, 0);
    expect(started.outputRoute, OutputRoute.other);

    // The room lets the whose_song DJ answer: from their own start.
    await tester.pump();
    expect(find.text('Жмите быстрее всех!'), findsOneWidget);
    expect(_answer('opt-a'), findsOneWidget);
    expect(find.byKey(const ValueKey('dj-music-playing')), findsNothing);

    final answerOsUs = h.inputClock.nowUs;
    await _pointerDown(tester, _answer('opt-b'), osUs: answerOsUs);
    final answer = h.received<RoundAnswer>().single;
    expect(answer.optionId, 'opt-b');
    expect(answer.tapMonoUs, answerOsUs - h.inputClock.anchorUs);
    expect(h.received<RoundPlaybackStarted>(), hasLength(1));
    await _end(tester, h);
  });

  // The server clamps a start to [cue sent, report arrival]: a pointer time
  // on another clock base (e.g. iOS after sleep) would move the start back
  // to the cue and make every guest's reaction seconds too long.
  for (final (label, offBaseUs) in [
    ('behind', -60000000),
    ('ahead of', 60000000),
  ]) {
    testWidgets('DJ: a pointer time $label the input clock is not the audio '
        'start; the input clock is read instead', (tester) async {
      final h = await _harness(
        tester,
        me: Samples.hostId,
        welcome: Samples.welcome(me: Samples.hostId, room: Samples.byopRoom()),
      );
      h.send(
        Samples.djPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      final nowMonoUs = h.inputClock.monoNowUs;
      await _pointerDown(
        tester,
        find.byKey(const ValueKey('dj-music-playing')),
        osUs: h.inputClock.nowUs + offBaseUs,
      );
      expect(
        h.received<RoundPlaybackStarted>().single.audioStartMonoUs,
        nowMonoUs,
      );
      await _end(tester, h);
    });
  }

  testWidgets('guest of a BYOP round waits for the DJ, never sees the title, '
      'and unlocks on round.start', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.guestId,
      welcome: Samples.welcome(room: Samples.byopRoom()),
    );
    h.send(
      Samples.prepare(
        startAtMonoUs: h.inputClock.monoNowUs + 2500000,
        source: AudioStartSource.hostReported,
      ),
    );
    await tester.pump();
    expect(find.text('Ведущий включает песню…'), findsOneWidget);
    expect(find.text('Northern Lights'), findsNothing);
    expect(find.text('Музыка играет!'), findsNothing);
    expect(_answer('opt-a'), findsOneWidget);

    // Well past start_at: a host-reported round does not open on a timer.
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Ведущий включает песню…'), findsOneWidget);
    expect((h.state as GameRoundState).phase, isA<RoundLocked>());

    h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
    await tester.pump();
    await tester.pump();
    expect(find.text('Жмите быстрее всех!'), findsOneWidget);
    await _end(tester, h);
  });

  testWidgets('guess_track DJ has no answer buttons (dj_ineligible)', (
    tester,
  ) async {
    final h = await _harness(
      tester,
      me: Samples.hostId,
      welcome: Samples.welcome(
        me: Samples.hostId,
        room: Samples.byopRoom(mode: GameMode.guessTrack),
      ),
    );
    h.send(
      Samples.djPrepare(
        startAtMonoUs: h.inputClock.monoNowUs + 2500000,
        prompt: RoundPrompt.guessTrack,
      ),
    );
    await tester.pump();
    expect(find.text('Что за трек?'), findsOneWidget);
    expect(_answer('opt-a'), findsNothing);

    await _pointerDown(
      tester,
      find.byKey(const ValueKey('dj-music-playing')),
      osUs: h.inputClock.nowUs,
    );
    expect(
      h.received<RoundPlaybackStarted>().single.source,
      PlaybackStartSource.djTap,
    );
    expect(
      find.text('Ты DJ этого раунда — отвечают остальные'),
      findsOneWidget,
    );
    expect(find.text('В этом раунде отвечают гости'), findsOneWidget);
    expect(_answer('opt-a'), findsNothing);

    h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
    await tester.pump();
    expect(_answer('opt-a'), findsNothing);
    expect(
      h.controller.tap(
        roundId: 'round-1',
        optionId: 'opt-a',
        tapMonoUs: h.inputClock.monoNowUs,
      ),
      isFalse,
    );
    await tester.pump();
    expect(h.received<RoundAnswer>(), isEmpty);
    await _end(tester, h);
  });

  testWidgets('text round (provider none): the song card and options, no '
      'audio UI, unlock at start_at', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.guestId,
      welcome: Samples.welcome(
        room: Samples.room(
          mode: GameMode.whoseSong,
          state: RoomState.roundPlaying,
          provider: MusicProviderId.none,
          capabilities: Samples.textCapabilities,
        ),
      ),
    );
    h.send(
      Samples.textPrepare(startAtMonoUs: h.inputClock.monoNowUs + 1000000),
    );
    await tester.pump();
    expect(find.text('Чья это песня?'), findsOneWidget);
    expect(find.text('Раунд без музыки: читаем и угадываем'), findsOneWidget);
    expect(find.text('Paper Boats'), findsOneWidget);
    expect(find.text('Sample Band'), findsOneWidget);
    expect(find.byType(EqualizerBars), findsNothing);
    expect(find.text('Слушайте…'), findsNothing);
    expect(find.text('Приготовьтесь…'), findsOneWidget);
    expect(_answer('opt-c'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump();
    expect(find.text('Жмите быстрее всех!'), findsOneWidget);
    await _pointerDown(tester, _answer('opt-c'), osUs: h.inputClock.nowUs);
    expect(h.received<RoundAnswer>().single.optionId, 'opt-c');
    expect(h.received<RoundPlaybackStarted>(), isEmpty);
    expect(h.playback.prepared, isEmpty);
    await _end(tester, h);
  });

  testWidgets('whose_song DJ does not answer by default: «Ты DJ этого '
      'раунда — отвечают остальные» from the cue card on', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.hostId,
      welcome: Samples.welcome(me: Samples.hostId, room: Samples.byopRoom()),
    );
    h.send(Samples.djPrepare(startAtMonoUs: h.inputClock.monoNowUs));
    await tester.pump();
    expect(find.byKey(const ValueKey('dj-no-answer')), findsOneWidget);
    expect(_answer('opt-a'), findsNothing);

    await _pointerDown(
      tester,
      find.byKey(const ValueKey('dj-music-playing')),
      osUs: h.inputClock.nowUs,
    );
    expect(h.received<RoundPlaybackStarted>(), hasLength(1));
    expect((h.state as GameRoundState).phase, isA<RoundDjWatching>());
    expect(
      find.text('Ты DJ этого раунда — отвечают остальные'),
      findsOneWidget,
    );
    expect(_answer('opt-a'), findsNothing);
    await _end(tester, h);
  });

  testWidgets('a rotated DJ is whoever gets you_are_dj: a guest DJ gets the '
      'cue and reports dj_tap', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.guestId,
      welcome: Samples.welcome(room: Samples.byopRoom()),
    );
    expect(h.session.isPlaybackDevice, isFalse);
    h.send(
      Samples.djPrepare(
        startAtMonoUs: h.inputClock.monoNowUs,
        djId: Samples.guestId,
      ),
    );
    await tester.pump();
    expect(find.text('Northern Lights'), findsOneWidget);
    await _pointerDown(
      tester,
      find.byKey(const ValueKey('dj-music-playing')),
      osUs: h.inputClock.nowUs,
    );
    expect(
      h.received<RoundPlaybackStarted>().single.source,
      PlaybackStartSource.djTap,
    );
    await _end(tester, h);
  });

  testWidgets('the playback device is not the DJ of a rotated round: no cue, '
      'no «Музыка играет!», «<имя> включает песню…»', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.hostId,
      welcome: Samples.welcome(me: Samples.hostId, room: Samples.byopRoom()),
    );
    expect(h.session.isPlaybackDevice, isTrue);
    h.send(
      Samples.byopGuestPrepare(
        startAtMonoUs: h.inputClock.monoNowUs,
        djId: Samples.guestId,
      ),
    );
    await tester.pump();
    expect(find.text('Bartek включает песню…'), findsOneWidget);
    expect(find.text('Northern Lights'), findsNothing);
    expect(find.byKey(const ValueKey('dj-music-playing')), findsNothing);
    expect(_answer('opt-a'), findsOneWidget);
    expect((h.state as GameRoundState).phase, isA<RoundLocked>());

    h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
    await tester.pump();
    await tester.pump();
    expect((h.state as GameRoundState).phase, isA<RoundOpen>());
    expect(h.received<RoundPlaybackStarted>(), isEmpty);
    await _end(tester, h);
  });

  testWidgets('a dj_ineligible ack says so', (tester) async {
    final h = await _harness(
      tester,
      me: Samples.guestId,
      welcome: Samples.welcome(room: Samples.byopRoom()),
    );
    h.send(
      Samples.prepare(
        startAtMonoUs: h.inputClock.monoNowUs,
        source: AudioStartSource.hostReported,
      ),
    );
    await tester.pump();
    h.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
    await tester.pump();
    await tester.pump();
    await _pointerDown(tester, _answer('opt-a'), osUs: h.inputClock.nowUs);
    h.send(
      const RoundAnswerAck(
        roundId: 'round-1',
        accepted: false,
        reason: AnswerValidation.djIneligible,
      ),
    );
    await tester.pump();
    expect(find.text('Диджей в этом раунде не отвечает'), findsOneWidget);
    await _end(tester, h);
  });
}
