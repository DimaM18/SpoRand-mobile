// End-to-end: guess_track with provider external_player (addendum A2.2):
// the DJ saw the title, so it may not answer (`dj_ineligible`), and a round
// the DJ never starts is voided after `byop_start_timeout_ms` and replaced
// by a spare. See apps/mobile/README.md, "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/party.dart';
import 'support/rounds.dart';

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test(
    'guess_track, external_player: an unstarted round is voided and a spare '
    'follows; the DJ may not answer; guests are scored by device time',
    () async {
      final party = await Party.assemble(
        api: e2eApiBaseUrl()!,
        names: const ['Jan', 'Kinga', 'Lena'],
        mode: GameMode.guessTrack,
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
      final dj = party.host;
      final guests = phones.skip(1).toList();
      expect(dj.session.config.guessTrackDjCanAnswer, isFalse);
      final byopStartTimeoutMs = dj.session.config.byopStartTimeoutMs;

      party.start();
      final starting = await dj.waitMessage<GameStarting>('game.starting');
      final seen = <String>{};
      var played = 0;
      var voided = false;
      while (played < starting.roundsTotal) {
        final rounds = await _nextRound(phones, seen);
        final round = rounds[dj]!.round;
        seen.add(round.roundId);
        expect(round.prompt, RoundPrompt.guessTrack);
        expect(round.isDj, isTrue);
        expect(round.djMayAnswer, isFalse);
        for (final guest in guests) {
          expect(rounds[guest]!.round.cue, isNull);
          expect(rounds[guest]!.round.youAreOwner, isFalse);
        }

        if (!voided) {
          // The DJ never taps «Музыка играет!»: after start_at +
          // byop_start_timeout_ms the round is voided, and a spare follows.
          final prepare = RoundPrepare.fromJson(
            receivedFor(dj, 'round.prepare', round.roundId).payload,
          );
          for (final phone in phones) {
            final state = await phone.waitGameSeen<GameVoidedState>(
              'round.voided',
              timeout: Duration(milliseconds: byopStartTimeoutMs + 5000),
            );
            expect(state.reason, RoundVoidReason.playbackTimeout);
          }
          final voidedAtUs = receivedFor(
            dj,
            'round.voided',
            round.roundId,
          ).atUs;
          final startAtUs = serverMsToE2eUs(dj, prepare.startAtServerMs);
          expect(
            (voidedAtUs - startAtUs) / 1000,
            inInclusiveRange(byopStartTimeoutMs - 50, byopStartTimeoutMs + 500),
          );
          voided = true;
          continue;
        }
        if (played == 0) expect(round.kind, RoundKind.spare);
        // «Раунд N из M» counts rounds as played: the spare takes the place
        // of the voided round although its round_index (the plan index)
        // comes after every regular round.
        for (final phone in phones) {
          final view = rounds[phone]!.round;
          expect(
            (view.number, view.roundsTotal),
            (played + 1, starting.roundsTotal),
            reason:
                '${phone.name}: ${view.kind.wire} round_index '
                '${view.roundIndex}',
          );
        }
        await _playRound(party, rounds, checkDjRefused: played == 0);
        played++;
      }

      for (final phone in phones) {
        final finished = await phone.waitGame<GameFinishedState>(
          'game.results',
          timeout: const Duration(seconds: 20),
        );
        expect(finished.roundsPlayed, starting.roundsTotal);
      }
      // The DJ sat every round out, so it kept a zero score and no errors.
      final djRow = (dj.gameState as GameFinishedState).standings.firstWhere(
        (s) => s.isMe,
      );
      expect(djRow.points, 0);
      expect(dj.wire.receivedOf('error'), isEmpty);
    },
    skip: e2eSkip(),
  );

  test(
    'contract: every frame of the guess_track game decodes with the Dart DTOs',
    () {
      e2eLog('guess_track game frames by type: ${audit.typeCounts}');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      expect(audit.restProblems(), isEmpty);
      expect(audit.typeCounts.keys, contains('round.voided'));
    },
    skip: e2eSkip(),
  );
}

/// Every phone's view of the next round none of them had yet.
Future<Map<E2ePhone, GameRoundState>> _nextRound(
  List<E2ePhone> phones,
  Set<String> seen,
) async => {
  for (final phone in phones)
    phone: await phone.waitGame<GameRoundState>(
      'the next round.prepare',
      where: (s) => !seen.contains(s.round.roundId),
      timeout: const Duration(seconds: 20),
    ),
};

Future<void> _playRound(
  Party party,
  Map<E2ePhone, GameRoundState> rounds, {
  required bool checkDjRefused,
}) async {
  final dj = party.host;
  final guests = party.phones.skip(1).toList();
  final roundId = rounds[dj]!.round.roundId;
  final cue = rounds[dj]!.round.cue!;
  final label = '${cue.title} — ${cue.artists.join(', ')}';
  final correct = optionLabelled(rounds[guests.first]!, label).optionId;

  final djTap = await dj.djTap(roundId);
  expect(djTap, isNotNull);
  final djStartUs = dj.clock.e2eUsOf(djTap!);
  // No buttons for the DJ: it watches.
  expect(
    dj.gameState,
    isA<GameRoundState>().having(
      (s) => s.phase,
      'phase',
      isA<RoundDjWatching>(),
    ),
  );
  expect(dj.tapAnswer(roundId, correct), isNull);

  for (final guest in guests) {
    await guest.waitGame<GameRoundState>(
      'unlocked',
      where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
    );
  }
  if (checkDjRefused) {
    // A modified client that answers anyway is refused on receipt.
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
    final ack = await dj.waitMessage<RoundAnswerAck>(
      'round.answer_ack',
      where: (f) => f.payload['round_id'] == roundId,
    );
    expect(ack.accepted, isFalse);
    expect(ack.reason, AnswerValidation.djIneligible);
  }

  await sleepUntil(djStartUs + 350 * 1000);
  final firstTap = guests[0].tapAnswer(roundId, correct);
  await sleepUntil(djStartUs + 600 * 1000);
  final secondTap = guests[1].tapAnswer(roundId, correct);

  for (final phone in party.phones) {
    await phone.waitGame<GameRevealState>(
      'round.reveal',
      where: (s) => s.reveal.round.roundId == roundId,
    );
  }
  final reveal = await dj.waitMessage<RoundReveal>(
    'round.reveal',
    where: (f) => f.payload['round_id'] == roundId,
  );
  expect(reveal.ownerPlayerIds, isEmpty);
  expect(reveal.correctOptionIds, [correct]);
  expect(reveal.track.title, cue.title);
  final djResult = resultOf(reveal, dj);
  expect(djResult.optionId, isNull);
  expect(djResult.points, 0);
  for (final (guest, tap) in [
    (guests[0], firstTap!),
    (guests[1], secondTap!),
  ]) {
    final result = resultOf(reveal, guest);
    final truthMs = (guest.clock.e2eUsOf(tap) - djStartUs) / 1000;
    expect(result.correct, isTrue, reason: guest.name);
    expect(result.validation, AnswerValidation.ok);
    expect((result.reactionMs! - truthMs).abs(), lessThan(reactionToleranceMs));
  }
  expect(
    speedPoints(guests[0], resultOf(reveal, guests[0])),
    greaterThan(speedPoints(guests[1], resultOf(reveal, guests[1]))),
  );
  e2eLog(
    'guess_track round ${rounds[dj]!.round.roundIndex} (${rounds[dj]!.round.kind.wire}) played',
  );
}
