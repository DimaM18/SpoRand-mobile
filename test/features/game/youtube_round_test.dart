import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/app_theme.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/l10n/l10n.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/game/presentation/widgets/round_views.dart';

import '../../support/game_harness.dart';
import '../../support/protocol_samples.dart';

/// youtube_embed rounds (wave 4): the DJ's embedded player (a fake: there is
/// no WebView in `flutter test`), its fallback chain, consent, disposal and
/// the «Музыка играет!» timing path.
Future<GameHarness> _harness(
  WidgetTester tester, {
  String me = Samples.hostId,
  FakeConsentService? consent,
  Size screen = const Size(400, 900),
}) async {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async => null,
  );
  tester.view
    ..physicalSize = screen
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = GameHarness(
    clock: tester.binding.clock,
    flush: () {},
    me: me,
    consent: consent,
  );
  await tester.pump();
  h.send(Samples.welcome(me: me, room: Samples.youtubeRoom()));
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
  return h;
}

Future<void> _end(WidgetTester tester, GameHarness h) async {
  await tester.pumpWidget(const SizedBox.shrink());
  h.dispose();
  await tester.pump();
}

Finder _player(String videoId) =>
    find.byKey(ValueKey('youtube-player-$videoId'));

final _musicPlaying = find.byKey(const ValueKey('dj-music-playing'));

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

/// A region where consent applies (EEA/UK): UMP says a form is required.
FakeConsentService _eeaConsent() =>
    FakeConsentService(statusAfterRefresh: ConsentStatus.required)
      ..refresh(underAgeOfConsent: false).ignore();

void main() {
  testWidgets('DJ: the official player, full width at 16:9 and nothing on '
      'it; «Музыка играет!» below it sends dj_tap with the pointer time; the '
      'player stays until the reveal and is disposed then', (tester) async {
    final h = await _harness(tester);
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();

    final player = h.youTube.created.single;
    expect(player.spec.videoId, 'tEsTvIdEo01');
    expect(player.spec.startS, 42);
    expect(player.spec.origin, 'https://dev.brandtbd.sporand');
    expect(_player('tEsTvIdEo01'), findsOneWidget);
    final box = tester.getRect(_player('tEsTvIdEo01'));
    expect(box.width, 400);
    expect(box.height, closeTo(400 * 9 / 16, 0.01));
    expect(box.top, 0);
    // Above the scrolling content, never under the button or any overlay.
    final button = tester.getRect(_musicPlaying);
    expect(button.top, greaterThanOrEqualTo(box.bottom));
    // The first thing a touch on the player hits is the player itself.
    expect(
      tester.hitTestOnBinding(box.center).path.first.target,
      tester.renderObject(_player('tEsTvIdEo01')),
    );
    // The cue card is not shown while the player works.
    expect(
      find.text('Включи эту песню в своём музыкальном приложении'),
      findsNothing,
    );
    expect(find.byType(Image), findsNothing, reason: 'no YouTube images');

    // The DJ pressed play in the player, sat through an ad, and taps.
    player.emit(const YouTubePlayerStateChanged(YouTubePlayerState.playing));
    await tester.pump(const Duration(seconds: 3));
    final tapOsUs = h.inputClock.nowUs - 15000;
    await _pointerDown(tester, _musicPlaying, osUs: tapOsUs);
    final started = h.received<RoundPlaybackStarted>().single;
    expect(started.source, PlaybackStartSource.djTap);
    expect(started.audioStartMonoUs, tapOsUs - h.inputClock.anchorUs);
    expect(h.received<RoundPlaybackFailed>(), isEmpty);

    // The song keeps playing: the player stays for the rest of the round.
    await tester.pump();
    expect(_player('tEsTvIdEo01'), findsOneWidget);
    expect(player.disposed, isFalse);
    expect(_musicPlaying, findsNothing);

    h.send(Samples.reveal());
    await tester.pump();
    expect(player.disposed, isTrue);
    expect(h.youTube.live, isEmpty);
    await _end(tester, h);
  });

  testWidgets('each failing video is reported with its code, the next '
      'fallback id is tried in order, then the BYOP cue', (tester) async {
    final h = await _harness(tester);
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    final first = h.youTube.created.single;

    // Embedding disabled (150).
    first.fail(150);
    await tester.pump();
    await tester.pump();
    expect(first.disposed, isTrue);
    final second = h.youTube.last!;
    expect(second.spec.videoId, 'tEsTvIdEo02');
    expect(second.spec.startS, 42);
    expect(_player('tEsTvIdEo02'), findsOneWidget);

    // Missing app identity (153; the package itself only knows -1).
    second.fail(153);
    await tester.pump();
    await tester.pump();
    expect(second.disposed, isTrue);
    expect(h.youTube.created, hasLength(2));

    final failures = h.received<RoundPlaybackFailed>();
    expect(
      [for (final f in failures) (f.reason, f.code, f.videoId)],
      [
        ('embed_disabled', 150, 'tEsTvIdEo01'),
        ('no_identity', 153, 'tEsTvIdEo02'),
      ],
    );
    // Every reported frame is a valid client frame.
    for (final f in failures) {
      expect(RoundPlaybackFailed.fromJson(f.toJson()).toJson(), f.toJson());
    }

    // The BYOP cue takes over; «Музыка играет!» still works.
    expect(find.text('Видео не играет — включи песню сам'), findsOneWidget);
    expect(
      find.text('Включи эту песню в своём музыкальном приложении'),
      findsOneWidget,
    );
    expect(find.text('Northern Lights'), findsOneWidget);
    await _pointerDown(tester, _musicPlaying, osUs: h.inputClock.nowUs);
    expect(
      h.received<RoundPlaybackStarted>().single.source,
      PlaybackStartSource.djTap,
    );
    await _end(tester, h);
  });

  testWidgets('a late error of an older video is ignored', (tester) async {
    final h = await _harness(tester);
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    h.youTube.created.single.fail(100);
    await tester.pump();
    h.controller.youTubeVideoFailed(
      roundId: 'round-1',
      videoId: 'tEsTvIdEo01',
      code: 100,
    );
    await tester.pump();
    expect(h.received<RoundPlaybackFailed>().single.reason, 'not_found');
    expect(_player('tEsTvIdEo02'), findsOneWidget);
    await _end(tester, h);
  });

  testWidgets('the player is disposed when the round is voided and while the '
      'app is in the background', (tester) async {
    final h = await _harness(tester);
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    final first = h.youTube.created.single;

    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    expect(first.disposed, isTrue, reason: 'never plays in the background');
    expect(h.youTube.live, isEmpty);

    for (final state in [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pump();
    final again = h.youTube.last!;
    expect(again, isNot(same(first)));
    expect(again.spec.videoId, 'tEsTvIdEo01');
    expect(again.disposed, isFalse);

    h.send(
      const RoundVoided(
        roundId: 'round-1',
        reason: RoundVoidReason.playbackTimeout,
      ),
    );
    // One more frame: Riverpod resumes the screen's subscription after the
    // app came back.
    await tester.pump();
    await tester.pump();
    expect(h.state, isA<GameVoidedState>());
    expect(again.disposed, isTrue);
    expect(h.youTube.live, isEmpty);
    expect(h.received<RoundPlaybackFailed>(), isEmpty);
    await _end(tester, h);
  });

  testWidgets('EEA without consent: the consent sheet first, no player; '
      '«Разрешить» stores the choice and creates the player', (tester) async {
    final h = await _harness(tester, consent: _eeaConsent());
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    expect(find.text('Включить плеер YouTube?'), findsOneWidget);
    expect(h.youTube.created, isEmpty, reason: 'nothing loads before consent');
    expect(_musicPlaying, findsNothing);
    expect(
      h.controller.djStarted(roundId: 'round-1', audioStartMonoUs: 1),
      isFalse,
    );

    await tester.tap(find.byKey(const ValueKey('youtube-consent-allow')));
    await tester.pump();
    await tester.pump();
    expect(h.prefs.getBool(PrefKeys.youtubePlayerConsent), isTrue);
    expect(h.youTube.created.single.spec.videoId, 'tEsTvIdEo01');
    expect(_player('tEsTvIdEo01'), findsOneWidget);
    expect(h.received<RoundPlaybackFailed>(), isEmpty);

    // The next round does not ask again.
    h.send(Samples.reveal());
    await tester.pump();
    h.send(
      Samples.youtubeDjPrepare(
        roundId: 'round-2',
        startAtMonoUs: h.inputClock.monoNowUs + 2500000,
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Включить плеер YouTube?'), findsNothing);
    expect(h.youTube.live, hasLength(1));
    await _end(tester, h);
  });

  testWidgets('EEA consent declined: playback_failed consent_declined, the '
      'cue, and no question again this session', (tester) async {
    final h = await _harness(tester, consent: _eeaConsent());
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('youtube-consent-decline')));
    await tester.pump();
    final failed = h.received<RoundPlaybackFailed>().single;
    expect(failed.reason, 'consent_declined');
    expect(failed.videoId, isNull);
    expect(failed.code, isNull);
    expect(h.youTube.created, isEmpty);
    expect(
      find.text('Без YouTube: включи песню в своём приложении'),
      findsOneWidget,
    );
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(_musicPlaying, findsOneWidget);
    expect(h.prefs.getBool(PrefKeys.youtubePlayerConsent), isNull);

    h.send(Samples.reveal());
    await tester.pump();
    h.send(
      Samples.youtubeDjPrepare(
        roundId: 'round-2',
        startAtMonoUs: h.inputClock.monoNowUs + 2500000,
      ),
    );
    await tester.pump();
    expect(find.text('Включить плеер YouTube?'), findsNothing);
    expect(h.youTube.created, isEmpty);
    expect(
      [for (final f in h.received<RoundPlaybackFailed>()) f.roundId],
      ['round-1', 'round-2'],
    );
    await _end(tester, h);
  });

  testWidgets('a screen below the YouTube 200 px floor gets the cue, without '
      'blaming the video', (tester) async {
    final h = await _harness(tester, screen: const Size(320, 900));
    h.send(
      Samples.youtubeDjPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    await tester.pump();
    expect(h.youTube.created, isEmpty);
    expect((h.state as GameRoundState).djVideo, isA<DjVideoCueFallback>());
    expect(find.text('Northern Lights'), findsOneWidget);
    expect(h.received<RoundPlaybackFailed>(), isEmpty);
    await _end(tester, h);
  });

  testWidgets('a guest of a youtube_embed round sees «<имя> включает песню…» '
      'and no player', (tester) async {
    final h = await _harness(tester, me: Samples.guestId);
    h.send(
      Samples.byopGuestPrepare(startAtMonoUs: h.inputClock.monoNowUs + 2500000),
    );
    await tester.pump();
    expect(find.text('Ania включает песню…'), findsOneWidget);
    expect(h.youTube.created, isEmpty);
    expect(find.text('Northern Lights'), findsNothing);
    await _end(tester, h);
  });

  group('player errors map to round.playback_failed reasons', () {
    test('known IFrame codes', () {
      expect(videoFailureReasonFor(100), VideoPlaybackFailureReason.notFound);
      expect(videoFailureReasonFor(105), VideoPlaybackFailureReason.notFound);
      for (final code in [101, 150, 152]) {
        expect(
          videoFailureReasonFor(code),
          VideoPlaybackFailureReason.embedDisabled,
        );
      }
      expect(videoFailureReasonFor(153), VideoPlaybackFailureReason.noIdentity);
      expect(videoFailureReasonFor(2), VideoPlaybackFailureReason.other);
      expect(videoFailureReasonFor(null), VideoPlaybackFailureReason.other);
    });

    test('the player box: full width at 16:9, never below 356 dp', () {
      expect(youTubePlayerSize(480, minWidthDp: 480), const Size(480, 270));
      expect(youTubePlayerSize(390, minWidthDp: 480), const Size(390, 219.375));
      expect(youTubePlayerSize(355, minWidthDp: 480), isNull);
      expect(youTubePlayerSize(double.infinity, minWidthDp: 480), isNull);
    });

    test('capabilities fall back to the protocol defaults when absent', () {
      expect(Samples.byopCapabilities.needsVisiblePlayer, isFalse);
      expect(Samples.byopCapabilities.allowsPaywall, isTrue);
      expect(Samples.byopCapabilities.showsTitleDuringPlay, isTrue);
      expect(Samples.youtubeCapabilities.needsConsentBeforeLoad, isTrue);
      expect(Samples.youtubeCapabilities.allowsPaywall, isFalse);
      final fallback = ProviderCapabilities.fallbackFor(
        MusicProviderId.youtubeEmbed,
      );
      expect(fallback.toJson(), Samples.youtubeCapabilities.toJson());
    });
  });
}
