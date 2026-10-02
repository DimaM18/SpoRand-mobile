// End-to-end: whose_song with provider external_player and
// byop_dj_rotation on (scripts/e2e.sh). Three of four players opt in with
// «Могу включать музыку» (`lobby.set_can_dj`; the host is in by default);
// the server picks each round's DJ among them. See README.md,
// "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/party.dart';
import 'support/rounds.dart';

const int _rounds = 5;

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test(
    'whose_song, external_player, byop_dj_rotation: the DJ rotates among the '
    'players who opted in, only the round DJ gets the cue and may report the '
    'start, and the DJ does not answer',
    () async {
      final party = await Party.assemble(
        api: e2eApiBaseUrl()!,
        names: const ['Kuba', 'Lena', 'Marek', 'Nina'],
        mode: GameMode.whoseSong,
        provider: MusicProviderId.externalPlayer,
        audit: audit,
      );
      addTearDown(party.dispose);
      addTearDown(() {
        for (final phone in party.phones) {
          printOnFailure(phone.wireSummary());
        }
      });
      final phones = party.phones;
      final host = party.host;
      final config = host.session.config;
      expect(config.byopDjRotation, isTrue, reason: 'set by scripts/e2e.sh');
      expect(config.whoseSongDjCanAnswer, isFalse);

      // Lena and Marek opt in; Nina does not. The host is in by default.
      final optedIn = phones.take(3).toList();
      final optedOut = phones[3];
      for (final phone in optedIn.skip(1)) {
        phone.setCanDj(true);
      }
      final ids = {for (final p in optedIn) p.playerId};
      for (final phone in phones) {
        await phone.waitFor('can_dj in every lobby', () {
          final state = phone.lobbyState;
          if (state is! LobbyLoaded) return null;
          final djs = {
            for (final p in state.view.players)
              if (p.canDj) p.playerId,
          };
          return djs.length == ids.length && djs.containsAll(ids) ? true : null;
        });
      }
      expect(host.lobby.setRounds(_rounds), isTrue);
      for (final phone in phones) {
        await phone.waitFor(
          'rounds_total $_rounds',
          () => (phone.lobbyState as LobbyLoaded).view.roundsTotal == _rounds
              ? true
              : null,
        );
      }
      await host.waitFor(
        'a startable lobby',
        () => (host.lobbyState as LobbyLoaded).view.canStart ? true : null,
      );

      party.start();
      final starting = await host.waitMessage<GameStarting>('game.starting');
      expect(starting.roundsTotal, _rounds);

      final djs = <E2ePhone>[];
      E2ePhone? intruder;
      for (var index = 0; index < _rounds; index++) {
        final played = await _playRound(
          party,
          index,
          optedIn: optedIn,
          previousDj: djs.lastOrNull,
        );
        djs.add(played.dj);
        intruder ??= played.intruder;
      }
      e2eLog('DJs by round: ${[for (final p in djs) p.name]}');
      expect(djs, everyElement(isNot(same(optedOut))));
      // Balanced: every candidate had a turn, none more than one extra.
      final turns = {
        for (final p in optedIn) p: djs.where((d) => d == p).length,
      };
      expect(turns.values, everyElement(greaterThanOrEqualTo(1)));
      expect(
        turns.values.reduce((a, b) => a > b ? a : b) -
            turns.values.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
        reason: '$turns',
      );

      for (final phone in phones) {
        final finished = await phone.waitGame<GameFinishedState>(
          'game.results',
          timeout: const Duration(seconds: 30),
        );
        expect(finished.roundsPlayed, _rounds);
        // Exactly the rounds it was DJ: a start report and the music app.
        final djRounds = djs.where((d) => d == phone).length;
        expect(
          phone.wire
              .sentOf('round.playback_started')
              .where((f) => f.payload['source'] == 'dj_tap'),
          hasLength(djRounds + (phone == intruder ? 1 : 0)),
          reason: phone.name,
        );
        expect(phone.musicApp.opened, hasLength(djRounds), reason: phone.name);
      }
    },
    skip: e2eSkip(),
  );

  test(
    'contract: every frame of the DJ-rotation game decodes with the Dart DTOs',
    () {
      e2eLog('DJ rotation game frames by type: ${audit.typeCounts}');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      expect(audit.restProblems(), isEmpty);
      expect(audit.typeCounts.keys, contains('error'));
    },
    skip: e2eSkip(),
  );
}

/// One round: checks who the DJ is, lets an opted-in non-DJ try to report
/// the start (refused), lets the DJ try to answer (refused), then the DJ
/// taps «Музыка играет!» and everyone else but the owner answers. Returns
/// the round's DJ, and in round 0 the phone that tried to start it.
Future<({E2ePhone dj, E2ePhone? intruder})> _playRound(
  Party party,
  int index, {
  required List<E2ePhone> optedIn,
  required E2ePhone? previousDj,
}) async {
  final phones = party.phones;
  final rounds = {
    for (final phone in phones) phone: await phone.waitRound(index),
  };
  final roundId = rounds[party.host]!.round.roundId;

  // One DJ, the same for everyone, among those who opted in.
  final dj = phones.singleWhere((p) => rounds[p]!.round.youAreDj);
  expect(optedIn, contains(dj));
  if (previousDj != null) {
    expect(dj, isNot(same(previousDj)), reason: 'never twice in a row');
  }
  for (final phone in phones) {
    final round = rounds[phone]!.round;
    final payload = receivedFor(phone, 'round.prepare', roundId).payload;
    expect(round.djPlayerId, dj.playerId, reason: phone.name);
    expect(payload['you_are_dj'], phone == dj, reason: phone.name);
    expect(payload['dj_player_id'], dj.playerId);
    expect(payload.containsKey('clip'), isFalse);
    if (phone == dj) {
      expect(payload.containsKey('cue'), isTrue);
      expect(rounds[phone]!.phase, isA<RoundDjCue>());
      expect(round.djMayAnswer, isFalse);
    } else {
      expect(payload.containsKey('cue'), isFalse, reason: phone.name);
      expect(round.waitsForDj, isTrue, reason: phone.name);
      expect(round.djName, dj.name, reason: phone.name);
    }
  }
  final cue = rounds[dj]!.round.cue!;
  final owner = phones.singleWhere((p) => rounds[p]!.round.youAreOwner);
  final answerers = [
    for (final p in phones)
      if (p != owner && p != dj) p,
  ];
  final correct = optionLabelled(rounds[answerers.first]!, owner.name).optionId;

  E2ePhone? intruder;
  if (index == 0) {
    // A modified client that is not this round's DJ (the host, when it is
    // not, else another opted-in player) reports a start: refused, and the
    // round stays locked.
    final phone = intruder = optedIn.firstWhere((p) => p != dj);
    final sinceUs = e2eNowUs();
    phone.session.send(
      RoundPlaybackStarted(
        roundId: roundId,
        audioStartMonoUs: phone.clock.nowMonoUs,
        outputLatencyMs: 0,
        outputRoute: OutputRoute.other,
        source: PlaybackStartSource.djTap,
      ),
    );
    final error = await phone.waitMessage<ServerError>(
      'error',
      sinceUs: sinceUs,
    );
    expect(error.code, 'not_host');
    expect(error.refType, 'round.playback_started');
    for (final other in phones) {
      expect(
        other.wire
            .receivedOf('round.start')
            .where((f) => f.payload['round_id'] == roundId),
        isEmpty,
        reason: '${other.name}: the refused report started nothing',
      );
    }
    expect(
      phone.gameState,
      isA<GameRoundState>().having(
        (s) => s.phase,
        'phase',
        anyOf(isA<RoundLocked>(), isA<RoundOwnerWatching>()),
      ),
    );
  }

  expect(await dj.game.openCueInMusicApp(), isTrue);
  expect(dj.musicApp.opened.last.title, cue.title);
  final djTapMonoUs = await dj.djTap(roundId);
  expect(djTapMonoUs, isNotNull);
  final djStartUs = dj.clock.e2eUsOf(djTapMonoUs!);
  // The DJ watches; a DJ who also owns the track sees «Это твой трек!».
  expect(
    dj.gameState,
    isA<GameRoundState>().having(
      (s) => s.phase,
      'phase',
      dj == owner ? isA<RoundOwnerWatching>() : isA<RoundDjWatching>(),
    ),
  );
  expect(dj.tapAnswer(roundId, correct), isNull, reason: 'no buttons');

  // A modified DJ client that answers anyway is refused on receipt.
  final nowUs = dj.clock.nowMonoUs;
  dj.session.send(
    RoundAnswer(
      roundId: roundId,
      nonce: RoundPrepare.fromJson(
        receivedFor(dj, 'round.prepare', roundId).payload,
      ).nonce,
      optionId: correct,
      tapMonoUs: nowUs,
      unlockMonoUs: nowUs,
    ),
  );
  final djAck = await dj.waitMessage<RoundAnswerAck>(
    'round.answer_ack',
    where: (f) => f.payload['round_id'] == roundId,
  );
  expect(djAck.accepted, isFalse);
  expect(
    djAck.reason,
    dj == owner
        ? anyOf(AnswerValidation.ownerIneligible, AnswerValidation.djIneligible)
        : AnswerValidation.djIneligible,
  );

  for (final phone in answerers) {
    await phone.waitGame<GameRoundState>(
      'unlocked round $index',
      where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
    );
  }
  for (final (i, phone) in answerers.indexed) {
    await sleepUntil(djStartUs + (300 + 200 * i) * 1000);
    expect(phone.tapAnswer(roundId, correct), isNotNull, reason: phone.name);
  }

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
  expect(reveal.track.title, cue.title);
  expect(reveal.ownerPlayerIds, [owner.playerId]);
  for (final phone in answerers) {
    final result = resultOf(reveal, phone);
    expect(result.correct, isTrue, reason: phone.name);
    expect(result.validation, AnswerValidation.ok, reason: phone.name);
  }
  final djResult = resultOf(reveal, dj);
  expect(djResult.optionId, isNull);
  expect(djResult.points, 0);
  e2eLog(
    'round $index: DJ ${dj.name}, owner ${owner.name}, answered by '
    '${[for (final p in answerers) p.name]}',
  );
  return (dj: dj, intruder: intruder);
}
