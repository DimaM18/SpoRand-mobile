// End-to-end: a whose_song game with provider none (text rounds without
// audio, addendum A2.1 plan C) between three simulated phones and the real
// server. See README.md, "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/party.dart';
import 'support/rounds.dart';

const Duration _answerSendDelay = Duration(milliseconds: 380);
const int _earlyTapAfterStartMs = 300;
const int _lateTapAfterStartMs = 520;

/// How late a local unlock may fire after `start_at`: timer latency on a
/// busy CI runner. Wrong clock handling would miss by hours, not by this.
const int _unlockSlackMs = 100;

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test(
    'whose_song, provider none: everyone reads the song, the buttons unlock '
    'at start_at on every device clock, taps are scored by device time',
    () async {
      final party = await Party.assemble(
        api: e2eApiBaseUrl()!,
        names: const ['Dorota', 'Emil', 'Filip'],
        mode: GameMode.whoseSong,
        provider: MusicProviderId.none,
        audit: audit,
      );
      addTearDown(party.dispose);
      addTearDown(() {
        for (final phone in party.phones) {
          printOnFailure(phone.wireSummary());
        }
      });
      final phones = party.phones;

      final room = party.host.session.room!;
      expect(room.provider, MusicProviderId.none);
      expect(room.audioMode, AudioMode.none);
      expect(room.capabilities.audioSource, AudioSource.none);
      expect(room.capabilities.playback, AudioStartSource.none);

      await _lobbyRoundTrip(party);

      party.start();
      final starting = await party.host.waitMessage<GameStarting>(
        'game.starting',
      );
      expect(starting.prefetch, isEmpty);

      final points = {for (final p in phones) p.playerId: 0};
      for (var index = 0; index < starting.roundsTotal; index++) {
        final reveal = await _playRound(
          party,
          index,
          lateAnswersWrong: index == starting.roundsTotal - 1,
        );
        for (final r in reveal.results) {
          points[r.playerId] = points[r.playerId]! + r.points;
        }
      }

      for (final phone in phones) {
        final finished = await phone.waitGame<GameFinishedState>(
          'game.results',
          timeout: const Duration(seconds: 20),
        );
        expect(finished.roundsPlayed, starting.roundsTotal);
        expect({
          for (final s in finished.standings) s.playerId: s.points,
        }, points);
        expect(phone.wire.receivedOf('game.ad_break'), hasLength(1));
        // Nothing plays, so nothing reports a start.
        expect(phone.wire.sentOf('round.playback_started'), isEmpty);
        expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
      }

      // «Сыграть ещё»: the same room goes back to the lobby.
      party.host.game.playAgain();
      for (final phone in phones) {
        await phone.waitMessage<RoomStateMessage>(
          'room.state',
          where: (f) => f.payload['state'] == 'lobby',
        );
        await phone.waitGame<GameIdle>('the lobby again');
        expect(phone.lobbyState, isA<LobbyLoaded>());
      }
    },
    skip: e2eSkip(),
  );

  test(
    'contract: every frame of the text-round game decodes with the Dart DTOs',
    () {
      e2eLog('text game frames by type: ${audit.typeCounts}');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      e2eLog('REST calls: ${audit.restCounts}');
      expect(audit.restProblems(), isEmpty);
      expect(
        audit.typeCounts.keys,
        containsAll(<String>[
          'welcome',
          'round.prepare',
          'round.start',
          'round.answer_ack',
          'round.reveal',
          'room.player_left',
          'room.state',
          'game.bonus_offer',
          'bonus.cancelled',
          'game.ad_break',
          'game.results',
        ]),
      );
    },
    skip: e2eSkip(),
  );
}

Future<RoundReveal> _playRound(
  Party party,
  int index, {
  required bool lateAnswersWrong,
}) async {
  final phones = party.phones;
  final rounds = {
    for (final phone in phones) phone: await phone.waitRound(index),
  };
  final roundId = rounds[party.host]!.round.roundId;
  final prepares = {
    for (final phone in phones)
      phone: RoundPrepare.fromJson(
        receivedFor(phone, 'round.prepare', roundId).payload,
      ),
  };
  final song = rounds[party.host]!.round.textPrompt!;
  for (final phone in phones) {
    final view = rounds[phone]!.round;
    final payload = receivedFor(phone, 'round.prepare', roundId).payload;
    expect(view.isTextRound, isTrue);
    expect(view.prompt, RoundPrompt.textRound);
    expect(view.audioStartSource, AudioStartSource.none);
    expect(view.isDj, isFalse);
    expect(payload.containsKey('cue'), isFalse);
    expect(payload.containsKey('clip'), isFalse);
    // whose_song: everyone reads the same song and guesses whose it is.
    expect(view.textPrompt!.title, song.title, reason: phone.name);
    expect(view.textPrompt!.artists, song.artists);
  }
  final owner = phones.singleWhere((p) => rounds[p]!.round.youAreOwner);
  final answerers = [
    for (final p in phones)
      if (p != owner) p,
  ];
  final early = answerers[index.isEven ? 0 : 1];
  final late = answerers[index.isEven ? 1 : 0];

  // Each phone unlocks by itself at start_at, converted with its own clock
  // offset; the server never tells it "now".
  for (final phone in answerers) {
    await phone.waitGame<GameRoundState>(
      'unlocked text round $index',
      where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
    );
    final startAtUs = serverMsToE2eUs(phone, prepares[phone]!.startAtServerMs);
    final lateByMs = (unlockedAtUs(phone, roundId) - startAtUs) / 1000;
    expect(
      lateByMs,
      inInclusiveRange(-10, _unlockSlackMs),
      reason: '${phone.name} unlocked ${lateByMs}ms after start_at',
    );
  }
  final startAtUs = serverMsToE2eUs(early, prepares[early]!.startAtServerMs);
  final correct = optionLabelled(rounds[early]!, owner.name).optionId;
  final lateChoice = lateAnswersWrong
      ? rounds[late]!.round.options
            .firstWhere((o) => o.label != owner.name)
            .optionId
      : correct;

  await sleepUntil(startAtUs + _earlyTapAfterStartMs * 1000);
  early.wire.delayNext('round.answer', _answerSendDelay);
  final earlyTap = early.tapAnswer(roundId, correct);
  await sleepUntil(startAtUs + _lateTapAfterStartMs * 1000);
  final lateTap = late.tapAnswer(roundId, lateChoice);
  expect(earlyTap, isNotNull);
  expect(lateTap, isNotNull);

  for (final phone in phones) {
    await phone.waitGame<GameRevealState>(
      'round.reveal #$index',
      where: (s) => s.reveal.round.roundId == roundId,
    );
  }
  final reveal = await party.host.waitMessage<RoundReveal>(
    'round.reveal',
    where: (f) => f.payload['round_id'] == roundId,
  );
  expect(reveal.track.title, song.title);
  expect(reveal.track.artists, song.artists);
  expect(reveal.ownerPlayerIds, [owner.playerId]);
  expect(
    sentFor(early, 'round.answer', roundId).atUs,
    greaterThan(sentFor(late, 'round.answer', roundId).atUs),
  );

  final earlyResult = resultOf(reveal, early);
  final lateResult = resultOf(reveal, late);
  for (final (phone, tapMonoUs, result) in [
    (early, earlyTap!, earlyResult),
    (late, lateTap!, lateResult),
  ]) {
    final startUs = serverMsToE2eUs(phone, prepares[phone]!.startAtServerMs);
    final truthMs = (phone.clock.e2eUsOf(tapMonoUs) - startUs) / 1000;
    expect(result.validation, AnswerValidation.ok, reason: phone.name);
    expect(
      (result.reactionMs! - truthMs).abs(),
      lessThan(reactionToleranceMs),
      reason: '${phone.name}: reaction ${result.reactionMs} ms, true $truthMs',
    );
  }
  expect(earlyResult.correct, isTrue);
  expect(earlyResult.reactionMs, lessThan(lateResult.reactionMs!));
  if (lateAnswersWrong) {
    expect(lateResult.correct, isFalse);
    expect(lateResult.points, 0);
    expect(lateResult.streak, 0);
  } else {
    expect(lateResult.correct, isTrue);
    expect(
      speedPoints(early, earlyResult),
      greaterThan(speedPoints(late, lateResult)),
    );
  }
  e2eLog(
    'text round $index: early ${early.name} ${earlyResult.reactionMs} ms '
    '${earlyResult.points} pts, late ${late.name} ${lateResult.reactionMs} ms '
    '${lateResult.points} pts${lateAnswersWrong ? ' (wrong)' : ''}',
  );
  return reveal;
}

LobbyView _view(E2ePhone phone) => (phone.lobbyState as LobbyLoaded).view;

/// The lobby messages the screens send: rounds (host, `lobby.update_settings`,
/// which the server validates strictly), ready (guests) and a kick, which
/// ends the kicked phone's room with close code 4403.
Future<void> _lobbyRoundTrip(Party party) async {
  final phones = party.phones;
  final host = party.host;
  for (final rounds in [5, 3]) {
    expect(host.lobby.setRounds(rounds), isTrue);
    for (final phone in phones) {
      await phone.waitFor(
        'rounds_total $rounds',
        () => _view(phone).roundsTotal == rounds ? true : null,
      );
    }
  }
  for (final guest in phones.skip(1)) {
    guest.lobby.toggleReady();
  }
  await host.waitFor(
    'guests ready',
    () => _view(host).players.where((p) => !p.isHost).every((p) => p.ready)
        ? true
        : null,
  );

  final late = await party.extraPhone('Kasia');
  await late.joinRoom(host.session.roomCode!);
  await late.waitSynced();
  await host.waitFor(
    'Kasia in the lobby',
    () => _view(host).players.length == phones.length + 1 ? true : null,
  );
  final kicked = late.playerId;
  host.lobby.kick(kicked);
  await late.waitFor(
    'the kick',
    () => switch (late.activeRoom) {
      RoomEnded(reason: RoomEndReason.kicked) => true,
      _ => null,
    },
  );
  expect(late.wire.closeCodes, [4403]);
  for (final phone in phones) {
    final left = await phone.waitMessage<RoomPlayerLeft>('room.player_left');
    expect(left.playerId, kicked);
    expect(left.reason, PlayerLeftReason.kicked);
  }
  await host.waitFor(
    'a startable lobby without Kasia',
    () => _view(host).players.length == phones.length && _view(host).canStart
        ? true
        : null,
  );
}
