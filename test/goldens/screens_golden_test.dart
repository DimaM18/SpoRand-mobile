import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/bootstrap/application/boot_controller.dart';
import 'package:sporand/app/bootstrap/domain/boot_models.dart';
import 'package:sporand/app/bootstrap/domain/init_step.dart';
import 'package:sporand/app/router/app_router.dart';
import 'package:sporand/app/router/routes.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/features/game/presentation/game_controller.dart';
import 'package:sporand/features/lobby/data/rooms_api.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/presentation/my_songs_controller.dart';

import '../support/fake_services.dart';
import '../support/protocol_samples.dart';
import 'golden_harness.dart';

/// Screen goldens of the wave 6 "Neon Night+" refresh, light and dark, on a
/// 390x844 phone at 3x (see `golden_harness.dart`). They walk the real
/// router and game controller over the in-memory server, like
/// `test/app/screens_smoke_test.dart`.
///
/// Update after an intended visual change (Linux only):
/// `flutter test test/goldens --update-goldens`, then look at every changed
/// PNG before committing it. `GOLDEN_SHOTS_DIR=<dir>` also writes each
/// frame at 3x (1170x2532) for design review.
///
/// Frames use full motion (the default device setting). The reduce-motion
/// look is covered by the layout tests, not here.

const _fourthId = 'p-fourth';

List<PlayerSnapshot> _players() => [
  Samples.player(
    Samples.hostId,
    'Ania',
    role: PlayerRole.host,
    playbackDevice: true,
  ),
  Samples.player(Samples.guestId, 'Bartek'),
  Samples.player(Samples.thirdId, 'Celina'),
  Samples.player(_fourthId, 'Dominik', ready: false),
];

RoomSnapshot _youtubeRoom() => Samples.room(
  mode: GameMode.whoseSong,
  provider: MusicProviderId.youtubeEmbed,
  capabilities: Samples.youtubeCapabilities,
  players: _players(),
);

RoomSnapshot _emojiRoom() => Samples.room(
  mode: GameMode.emojiQuiz,
  provider: MusicProviderId.none,
  capabilities: Samples.textCapabilities,
  players: _players(),
  emojiMarkets: const [EmojiMarket.intl],
);

const _whoseSongOptions = [
  ...Samples.options,
  RoundOption(optionId: 'opt-d', label: 'Dominik'),
];

const _roundIndex = 3;

/// The standings after round 4 and at the end of the game.
const _roundStandings = [
  Standing(
    playerId: Samples.hostId,
    rank: 1,
    points: 2710,
    correctCount: 3,
    correctReactionMsSum: 5130,
  ),
  Standing(
    playerId: Samples.thirdId,
    rank: 2,
    points: 2240,
    correctCount: 3,
    correctReactionMsSum: 7400,
  ),
  Standing(
    playerId: Samples.guestId,
    rank: 3,
    points: 1985,
    correctCount: 2,
    correctReactionMsSum: 3900,
  ),
  Standing(
    playerId: _fourthId,
    rank: 4,
    points: 1320,
    correctCount: 2,
    correctReactionMsSum: 6120,
  ),
];

const _finalStandings = [
  Standing(
    playerId: Samples.hostId,
    rank: 1,
    points: 6480,
    correctCount: 8,
    correctReactionMsSum: 14210,
  ),
  Standing(
    playerId: Samples.thirdId,
    rank: 2,
    points: 5960,
    correctCount: 7,
    correctReactionMsSum: 16020,
  ),
  Standing(
    playerId: Samples.guestId,
    rank: 3,
    points: 4105,
    correctCount: 5,
    correctReactionMsSum: 11800,
  ),
  Standing(
    playerId: _fourthId,
    rank: 4,
    points: 2730,
    correctCount: 3,
    correctReactionMsSum: 9020,
  ),
];

/// The boot pipeline held in the warm-up stage at 62 %.
class _WarmingUp extends BootController {
  @override
  BootState build() => const BootRunning(
    BootProgress(
      value: 0.62,
      stage: InitStage.warmup,
      label: BootLabel.warmingUp,
      stepId: 'fonts',
    ),
  );
}

/// Starts a whose_song game in the YouTube room and sends round 4's
/// prepare as [prepare] builds it.
Future<GoldenGame> _whoseSongRound(
  WidgetTester tester,
  RoundPrepare Function(GoldenGame game) prepare, {
  RoomSnapshot? room,
  FakeServices? services,
}) async {
  final game = await GoldenGame.launch(tester, services: services);
  await game.enterLobby(tester, room ?? _youtubeRoom(), me: Samples.hostId);
  game.send(
    const GameStarting(
      gameId: Samples.gameId,
      roundsTotal: 10,
      countdownMs: 3000,
    ),
  );
  await settle(tester);
  game.send(prepare(game));
  await tester.pump();
  await tester.pump();
  // Past the cross-fade from the countdown (the player screen has none).
  await settle(tester, const Duration(milliseconds: 500));
  return game;
}

/// Ania answers round 4 while Bartek is the DJ, before his «Музыка
/// играет!»: the tiles are readable but locked.
Future<GoldenGame> _guestRoundLocked(WidgetTester tester) => _whoseSongRound(
  tester,
  (game) => Samples.prepare(
    roundIndex: _roundIndex,
    startAtMonoUs: game.clock.monoNowUs + 2500000,
    source: AudioStartSource.hostReported,
    options: _whoseSongOptions,
    youAreDj: false,
    djPlayerId: Samples.guestId,
  ),
);

/// The same round once it opens on the DJ's tap, [elapsed] into the 15 s
/// window (3 s by default).
Future<GoldenGame> _guestRoundOpen(
  WidgetTester tester, {
  Duration elapsed = const Duration(seconds: 3),
}) async {
  final game = await _guestRoundLocked(tester);
  game.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
  await tester.pump();
  await tester.pump(elapsed);
  await tester.pump();
  return game;
}

Future<void> _leave(WidgetTester tester, GoldenGame game) async {
  unawaited(game.container.read(activeRoomProvider.notifier).leave());
  await tester.pump();
  await settle(tester);
  await closeGolden(tester);
}

void main() {
  setUpAll(loadGoldenFonts);

  group('screen goldens', skip: goldenSkipReason, () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('boot loader ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        await launchGolden(
          tester,
          returningUser(),
          boot: false,
          extra: [bootControllerProvider.overrideWith(_WarmingUp.new)],
        );
        // A fixed frame of the running loader (vinyl, ring, equalizer).
        await tester.pump(const Duration(milliseconds: 1400));
        await expectScreen(tester, 'boot', brightness);
        await closeGolden(tester);
      });

      testWidgets('home ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        await launchGolden(tester, returningUser());
        expect(find.text('Создать комнату'), findsWidgets);
        await expectScreen(tester, 'home', brightness);
        await closeGolden(tester);
      });

      testWidgets('lobby, host of a «Чья песня?» room ($theme)', (
        tester,
      ) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await GoldenGame.launch(tester);
        await game.enterLobby(tester, _youtubeRoom(), me: Samples.hostId);
        expect(find.text('Начать игру'), findsOneWidget);
        await expectScreen(tester, 'lobby', brightness);

        // The rest of the lobby: settings, «Могу быть DJ» and the players.
        final players = find.text('Игроки: 4');
        await tester.scrollUntilVisible(
          players,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(players);
        await settle(tester);
        await expectScreen(tester, 'lobby_players', brightness);
        await _leave(tester, game);
      });

      testWidgets('whose_song DJ with the YouTube player placeholder '
          '($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _whoseSongRound(
          tester,
          (game) => Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 2500000,
            source: AudioStartSource.hostReported,
            options: _whoseSongOptions,
            cue: Samples.cue,
            video: Samples.video,
            youAreDj: true,
            djPlayerId: Samples.hostId,
          ),
        );
        expect(
          find.byKey(const ValueKey('youtube-player-tEsTvIdEo01')),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('dj-music-playing')), findsOneWidget);
        await expectScreen(tester, 'whose_song_dj', brightness);
        await _leave(tester, game);
      });

      testWidgets('whose_song player answering ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        expect(find.byKey(const ValueKey('answer-opt-d')), findsOneWidget);
        await expectScreen(tester, 'whose_song_player', brightness);
        await _leave(tester, game);
      });

      testWidgets('emoji puzzle, «Угадай песню» ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await GoldenGame.launch(tester);
        await game.enterLobby(tester, _emojiRoom(), me: Samples.hostId);
        game.send(
          const GameStarting(
            gameId: Samples.gameId,
            roundsTotal: 10,
            countdownMs: 3000,
          ),
        );
        await settle(tester);
        game.send(
          Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 200000,
            source: AudioStartSource.none,
            prompt: RoundPrompt.emojiRound,
            emojiPrompt: const RoundEmojiPrompt(emoji: '🎭🎼👑'),
            options: Samples.emojiOptions,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        expect(find.byKey(const ValueKey('answer-opt-c')), findsOneWidget);
        await expectScreen(tester, 'emoji_puzzle', brightness);
        await _leave(tester, game);
      });

      testWidgets('reveal after a right answer ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        expect(
          game.container
              .read(gameControllerProvider.notifier)
              .tap(
                roundId: 'round-1',
                optionId: 'opt-c',
                tapMonoUs: game.clock.monoNowUs,
              ),
          isTrue,
        );
        await tester.pump();
        game.send(
          const RoundReveal(
            roundId: 'round-1',
            correctOptionIds: ['opt-c'],
            commitSalt: 'b3c1f0e9d8a7b6c5d4e3f2a1b0c9d8e7',
            track: RevealTrack(
              title: 'Northern Lights',
              artists: ['Test Artist'],
              attribution: TrackAttribution(
                provider: MusicProviderId.youtubeEmbed,
              ),
            ),
            ownerPlayerIds: [Samples.thirdId],
            results: [
              RoundResult(
                playerId: Samples.hostId,
                optionId: 'opt-c',
                correct: true,
                reactionMs: 1840,
                points: 912,
                streak: 3,
                validation: AnswerValidation.ok,
              ),
              RoundResult(
                playerId: _fourthId,
                optionId: 'opt-a',
                correct: false,
                reactionMs: 2950,
                points: 0,
                streak: 0,
                validation: AnswerValidation.ok,
              ),
            ],
            standings: _roundStandings,
          ),
        );
        await settle(tester);
        await expectScreen(tester, 'reveal', brightness);
        await _leave(tester, game);
      });

      testWidgets('results podium ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        game.send(
          const GameResults(
            gameId: Samples.gameId,
            standings: _finalStandings,
            roundsPlayed: 10,
            bonusUsed: false,
          ),
        );
        await settle(tester);
        expect(find.text('Итоги'), findsOneWidget);
        await expectScreen(tester, 'results', brightness);
        await _leave(tester, game);
      });

      testWidgets('paywall ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final container = await launchGolden(tester, returningUser());
        unawaited(
          container.read(routerProvider).push(Routes.paywallFor('settings')),
        );
        await settle(tester);
        expect(find.text('Играйте без границ'), findsOneWidget);
        await expectScreen(tester, 'paywall', brightness);
        await closeGolden(tester);
      });
    }
  });

  // The states and sizes the first review never saw (fix round 1, VQ-05).
  group('edge-state goldens', skip: goldenSkipReason, () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final theme = brightness.name;

      testWidgets('onboarding: age and privacy steps ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        await launchGolden(tester, FakeServices());
        expect(find.text('Год рождения'), findsOneWidget);
        await expectScreen(tester, 'onboarding_age', brightness);
        await tester.enterText(find.byType(TextField), '1995');
        await tester.tap(find.text('Продолжить'));
        await settle(tester);
        expect(find.text('Ваша приватность'), findsOneWidget);
        await expectScreen(tester, 'onboarding_consent', brightness);
        await closeGolden(tester);
      });

      testWidgets('create-room sheet ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        await launchGolden(tester, returningUser());
        await tester.tap(find.text('Создать комнату'));
        await settle(tester);
        expect(find.text('Новая комната'), findsOneWidget);
        await expectScreen(tester, 'create_room_sheet', brightness);
        await closeGolden(tester);
      });

      testWidgets('join a room: the error banner ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await GoldenGame.launch(
          tester,
          rooms: FakeRoomsApi(failWith: const ApiError(code: 'room_full')),
        );
        unawaited(
          game.container.read(routerProvider).push(Routes.join('7KQ2MX')),
        );
        await settle(tester);
        await tester.enterText(find.byType(TextField), 'Celina');
        await tester.tap(find.text('Войти в комнату'));
        await settle(tester);
        await expectScreen(tester, 'join_error', brightness);
        await closeGolden(tester);
      });

      testWidgets('settings and «Мои песни» ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final container = await launchGolden(
          tester,
          returningUser(),
          extra: [
            mySongsApiProvider.overrideWithValue(
              FakeMySongsApi(
                picks: [
                  for (final (i, song)
                      in FakeMySongsApi.sampleSongs.take(3).indexed)
                    SongPick(position: i + 1, song: song),
                ],
              ),
            ),
          ],
        );
        final router = container.read(routerProvider);
        unawaited(router.push(Routes.settings));
        await settle(tester);
        expect(find.text('Настройки'), findsWidgets);
        await expectScreen(tester, 'settings', brightness);
        router.pop();
        await settle(tester);
        unawaited(router.push(Routes.mySongs));
        await settle(tester);
        expect(find.text('Выбрано 3 из 10'), findsOneWidget);
        await expectScreen(tester, 'my_songs', brightness);
        await closeGolden(tester);
      });

      testWidgets('lobby, a guest («Я готов») ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await GoldenGame.launch(tester);
        await game.enterLobby(tester, _youtubeRoom(), me: _fourthId);
        await expectScreen(tester, 'lobby_guest', brightness);
        await _leave(tester, game);
      });

      testWidgets('game starting: the countdown ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await GoldenGame.launch(tester);
        await game.enterLobby(tester, _youtubeRoom(), me: Samples.hostId);
        game.send(
          const GameStarting(
            gameId: Samples.gameId,
            roundsTotal: 10,
            countdownMs: 3000,
          ),
        );
        await settle(tester, const Duration(milliseconds: 600));
        expect(find.text('3'), findsOneWidget);
        await expectScreen(tester, 'starting', brightness);
        await _leave(tester, game);
      });

      testWidgets('BYOP DJ: the cue card and the 96 dp «Музыка играет!» '
          '($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _whoseSongRound(
          tester,
          room: Samples.room(
            mode: GameMode.whoseSong,
            provider: MusicProviderId.externalPlayer,
            capabilities: Samples.byopCapabilities,
            players: _players(),
          ),
          (game) => Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 2500000,
            source: AudioStartSource.hostReported,
            options: _whoseSongOptions,
            cue: Samples.cue,
            youAreDj: true,
            djPlayerId: Samples.hostId,
          ),
        );
        expect(find.byKey(const ValueKey('dj-music-playing')), findsOneWidget);
        await expectScreen(tester, 'byop_dj', brightness);
        await _leave(tester, game);
      });

      testWidgets('YouTube DJ in the EEA: the consent card ($theme)', (
        tester,
      ) async {
        useGoldenPhone(tester, brightness: brightness);
        final services = returningUser();
        services.consent.statusAfterRefresh = ConsentStatus.required;
        final game = await _whoseSongRound(
          tester,
          services: services,
          (game) => Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 2500000,
            source: AudioStartSource.hostReported,
            options: _whoseSongOptions,
            cue: Samples.cue,
            video: Samples.video,
            youAreDj: true,
            djPlayerId: Samples.hostId,
          ),
        );
        expect(find.byKey(const ValueKey('youtube-consent')), findsOneWidget);
        await expectScreen(tester, 'youtube_consent', brightness);
        await _leave(tester, game);
      });

      testWidgets('YouTube DJ in landscape (844x390): two panes ($theme)', (
        tester,
      ) async {
        useGoldenPhone(
          tester,
          brightness: brightness,
          size: const Size(844, 390),
        );
        final game = await _whoseSongRound(
          tester,
          (game) => Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 2500000,
            source: AudioStartSource.hostReported,
            options: _whoseSongOptions,
            cue: Samples.cue,
            video: Samples.video,
            youAreDj: true,
            djPlayerId: Samples.hostId,
          ),
        );
        expect(
          find.byKey(const ValueKey('youtube-player-tEsTvIdEo01')),
          findsOneWidget,
        );
        await expectScreen(tester, 'whose_song_dj_landscape', brightness);
        await _leave(tester, game);
      });

      testWidgets('round states: locked, answered, urgent, time-up ($theme)', (
        tester,
      ) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundLocked(tester);
        await expectScreen(tester, 'round_locked', brightness);
        game.send(const RoundStart(roundId: 'round-1', audioStartServerMs: 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 12));
        await tester.pump();
        await expectScreen(tester, 'round_urgent', brightness);
        await tester.pump(const Duration(seconds: 5));
        await tester.pump();
        await expectScreen(tester, 'round_time_up', brightness);
        await _leave(tester, game);
      });

      testWidgets('round: your answer picked ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        expect(
          game.container
              .read(gameControllerProvider.notifier)
              .tap(
                roundId: 'round-1',
                optionId: 'opt-b',
                tapMonoUs: game.clock.monoNowUs,
              ),
          isTrue,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        await expectScreen(tester, 'round_answered', brightness);
        await _leave(tester, game);
      });

      testWidgets('reveal after a wrong pick: the recap tiles ($theme)', (
        tester,
      ) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        game.container
            .read(gameControllerProvider.notifier)
            .tap(
              roundId: 'round-1',
              optionId: 'opt-a',
              tapMonoUs: game.clock.monoNowUs,
            );
        await tester.pump();
        game.send(
          Samples.reveal(
            results: const [
              RoundResult(
                playerId: Samples.hostId,
                optionId: 'opt-a',
                correct: false,
                reactionMs: 1320,
                points: 0,
                streak: 0,
              ),
            ],
          ),
        );
        await settle(tester);
        await expectScreen(tester, 'reveal_wrong', brightness);
        await _leave(tester, game);
      });

      testWidgets('bonus offer and ad break ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness);
        final game = await _guestRoundOpen(tester);
        game.send(Samples.reveal());
        await settle(tester);
        game.send(
          const GameBonusOffer(
            bonusId: 'bonus-1',
            expiresAtServerMs: 1759212360000,
            eligiblePlayerIds: [Samples.hostId],
          ),
        );
        await settle(tester);
        await expectScreen(tester, 'bonus_offer', brightness);
        game.send(
          const BonusCancelled(
            bonusId: 'bonus-1',
            reason: BonusCancelReason.ssvTimeout,
          ),
        );
        await settle(tester);
        game.send(
          const GameAdBreak(
            gameId: Samples.gameId,
            resultsRevealAtServerMs: 1,
            showInterstitial: false,
            showRemoveAdsUpsell: true,
          ),
        );
        await settle(tester);
        await expectScreen(tester, 'ad_break', brightness);
        await _leave(tester, game);
      });

      testWidgets('round at 360x640 ($theme)', (tester) async {
        useGoldenPhone(
          tester,
          brightness: brightness,
          size: const Size(360, 640),
        );
        final game = await _guestRoundOpen(tester);
        await expectScreen(tester, 'round_360x640', brightness);
        await _leave(tester, game);
      });

      testWidgets('round at text scale 2.0 ($theme)', (tester) async {
        useGoldenPhone(tester, brightness: brightness, textScale: 2);
        final game = await _guestRoundOpen(tester);
        await expectScreen(tester, 'round_text2x', brightness);
        await _leave(tester, game);
      });

      testWidgets('emoji round at text scale 2.0, 360x640 ($theme)', (
        tester,
      ) async {
        useGoldenPhone(
          tester,
          brightness: brightness,
          size: const Size(360, 640),
          textScale: 2,
        );
        final game = await GoldenGame.launch(tester);
        await game.enterLobby(tester, _emojiRoom(), me: Samples.hostId);
        game.send(
          const GameStarting(
            gameId: Samples.gameId,
            roundsTotal: 10,
            countdownMs: 3000,
          ),
        );
        await settle(tester);
        game.send(
          Samples.prepare(
            roundIndex: _roundIndex,
            startAtMonoUs: game.clock.monoNowUs + 200000,
            source: AudioStartSource.none,
            prompt: RoundPrompt.emojiRound,
            emojiPrompt: const RoundEmojiPrompt(emoji: '🎭🎼👑'),
            options: Samples.emojiOptions,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pump(const Duration(seconds: 2));
        await tester.pump();
        await expectScreen(tester, 'emoji_puzzle_text2x', brightness);
        await _leave(tester, game);
      });

      testWidgets('paywall at 360x640, text scale 2.0 ($theme)', (
        tester,
      ) async {
        useGoldenPhone(
          tester,
          brightness: brightness,
          size: const Size(360, 640),
          textScale: 2,
        );
        final container = await launchGolden(tester, returningUser());
        unawaited(
          container.read(routerProvider).push(Routes.paywallFor('settings')),
        );
        await settle(tester);
        await expectScreen(tester, 'paywall_text2x', brightness);
        await closeGolden(tester);
      });
    }
  });
}
