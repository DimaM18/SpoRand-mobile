// End-to-end: a guest loses its connection in the middle of a BYOP round and
// resumes with `hello.last_seq` (brief §4.3 replay), then answers the round
// it half missed. See apps/mobile/README.md, "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/net/ws_client.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/party.dart';
import 'support/rounds.dart';
import 'support/wire_tap.dart';

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test('a guest that loses frames and its socket mid-round resumes with '
      'last_seq: the server replays exactly what it missed and the guest '
      'answers the same round', () async {
    final party = await Party.assemble(
      api: e2eApiBaseUrl()!,
      names: const ['Gosia', 'Hubert', 'Iga'],
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
    final dj = party.host;
    final dropper = phones.last;

    // The dropper's app goes to the background and back: `app.state`
    // makes the server run a fresh clock-sync burst (brief §5).
    final resultsBefore = dropper.wire.receivedOf('clock.result').length;
    dropper.signals
      ..emit(AppStateSignal.background)
      ..emit(AppStateSignal.foreground);
    await dropper.waitFor(
      'app.state foreground on the wire',
      () => dropper.wire.sentOf('app.state').length == 2 ? true : null,
    );
    expect(
      dropper.session.clock.isSynced,
      isFalse,
      reason: 'the offset is stale after a wake-up until the new burst',
    );
    await dropper.waitFor(
      'a clock.result after foreground',
      () =>
          dropper.wire.receivedOf('clock.result').length > resultsBefore &&
              dropper.session.clock.isSynced
          ? true
          : null,
    );
    expect(
      [for (final f in dropper.wire.sentOf('app.state')) f.payload['state']],
      ['background', 'foreground'],
    );

    party.start();
    final starting = await dj.waitMessage<GameStarting>('game.starting');
    var resumed = false;
    for (var index = 0; index < starting.roundsTotal; index++) {
      final rounds = {
        for (final phone in phones) phone: await phone.waitRound(index),
      };
      final roundId = rounds[dj]!.round.roundId;
      final owner = phones.singleWhere((p) => rounds[p]!.round.youAreOwner);
      final correct = optionLabelled(
        rounds[phones.firstWhere((p) => p != owner)]!,
        owner.name,
      ).optionId;
      // Consecutive rounds have different owners (spread_owner_gap), so
      // the dropper answers round 1 or round 2.
      final outage =
          !resumed && index >= 1 && !rounds[dropper]!.round.youAreOwner;

      final lastSeqBefore = dropper.session.ws.lastServerSeq;
      if (outage) {
        e2eLog('round $index: ${dropper.name} loses the network');
        dropper.wire.blackout();
      }
      expect(await dj.game.openCueInMusicApp(), isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final djTap = await dj.djTap(roundId);
      expect(djTap, isNotNull);
      final djStartUs = dj.clock.e2eUsOf(djTap!);

      final others = [
        for (final p in phones)
          if (p != owner && !(outage && p == dropper)) p,
      ];
      for (final phone in others) {
        await phone.waitGame<GameRoundState>(
          'unlocked round $index',
          where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
        );
      }
      await sleepUntil(djStartUs + 300 * 1000);
      for (final phone in others) {
        expect(phone.tapAnswer(roundId, correct), isNotNull);
      }

      if (outage) {
        // round.start and the progress of the others' answers were sent
        // to the dropper but lost.
        await dropper.waitFor('lost round.start', () {
          final lost = [for (final f in dropper.wire.lost) f.type];
          return lost.contains('round.start') && lost.contains('round.progress')
              ? true
              : null;
        });
        expect(
          dropper.gameState,
          isA<GameRoundState>().having(
            (s) => s.phase,
            'phase',
            isA<RoundLocked>(),
          ),
          reason: 'still waiting for the DJ: it never saw round.start',
        );
        await dropper.wire.killSocket();
        await dropper.waitFor('the second socket', () {
          final ws = dropper.session.ws;
          return dropper.wire.connectionCount == 2 && ws.state is WsConnected
              ? true
              : null;
        });
        e2eLog('round $index: ${dropper.name} reconnected');
        await dropper.waitGame<GameRoundState>(
          'unlocked round $index after the replay',
          where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
        );
        expect(dropper.tapAnswer(roundId, correct), isNotNull);
        _expectResumedWithLastSeq(dropper, lastSeqBefore, roundId);
        resumed = true;
      }

      for (final phone in phones) {
        await phone.waitGame<GameRevealState>(
          'round.reveal #$index',
          where: (s) => s.reveal.round.roundId == roundId,
        );
      }
      final reveal = await dj.waitMessage<RoundReveal>(
        'round.reveal',
        where: (f) => f.payload['round_id'] == roundId,
      );
      for (final phone in phones.where((p) => p != owner)) {
        final result = resultOf(reveal, phone);
        expect(result.correct, isTrue, reason: '${phone.name} round $index');
        expect(result.validation, AnswerValidation.ok);
      }
      if (outage) {
        // Answered well after the others, on its own clock.
        final result = resultOf(reveal, dropper);
        final tap = sentFor(dropper, 'round.answer', roundId);
        final truthMs =
            (dropper.clock.e2eUsOf(tap.payload['tap_mono_us']! as int) -
                djStartUs) /
            1000;
        expect((result.reactionMs! - truthMs).abs(), lessThan(50));
        e2eLog(
          'round $index: ${dropper.name} answered after the resume, '
          'reaction ${result.reactionMs} ms',
        );
      }
    }
    expect(resumed, isTrue, reason: 'no round had the dropper answering');

    final standings = <String, Map<String, int>>{};
    for (final phone in phones) {
      final finished = await phone.waitGame<GameFinishedState>(
        'game.results',
        timeout: const Duration(seconds: 20),
      );
      standings[phone.name] = {
        for (final s in finished.standings) s.playerId: s.points,
      };
      expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
    }
    for (final MapEntry(key: name, value: table) in standings.entries) {
      expect(table, standings[dj.name], reason: '$name sees the same table');
    }
    expect(dropper.session.ws.lastServerSeq, _maxSeq(dropper.wire.received));

    // The others saw the dropper go and come back.
    final updates = [
      for (final f in dj.wire.receivedOf('room.player_updated'))
        RoomPlayerUpdated.fromJson(f.payload).player,
    ].where((p) => p.playerId == dropper.playerId).map((p) => p.connection);
    expect(
      updates,
      containsAllInOrder([
        PlayerConnection.reconnecting,
        PlayerConnection.connected,
      ]),
    );
  }, skip: e2eSkip());

  test(
    'contract: every frame of the reconnect game decodes with the Dart DTOs',
    () {
      e2eLog('reconnect game frames by type: ${audit.typeCounts}');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      e2eLog('REST calls: ${audit.restCounts}');
      expect(audit.restProblems(), isEmpty);
    },
    skip: e2eSkip(),
  );
}

int _maxSeq(List<WireFrame> frames) =>
    frames.map((f) => f.seq ?? 0).fold(0, (a, b) => a > b ? a : b);

/// What the resume must look like on the wire.
void _expectResumedWithLastSeq(
  E2ePhone phone,
  int lastSeqBefore,
  String roundId,
) {
  final wire = phone.wire;
  final hellos = wire.sentOf('hello');
  expect(hellos, hasLength(2));
  expect(hellos.first.payload.containsKey('last_seq'), isFalse);
  expect(hellos.last.connection, 1);
  expect(
    hellos.last.payload['last_seq'],
    lastSeqBefore,
    reason: 'hello.last_seq is the last seq the app processed',
  );

  final lost = wire.lost;
  expect(lost, isNotEmpty);
  expect(lost.every((f) => (f.seq ?? 0) > lastSeqBefore), isTrue);

  // On the new socket the server replays everything after last_seq, then
  // sends welcome.
  final second = [
    for (final f in wire.received)
      if (f.connection == 1) f,
  ];
  final welcomeAt = second.indexWhere((f) => f.type == 'welcome');
  expect(welcomeAt, greaterThan(0), reason: 'replayed frames come first');
  final replayed = second.sublist(0, welcomeAt);
  expect(
    [for (final f in replayed) f.seq],
    [for (var s = lastSeqBefore + 1; s <= lastSeqBefore + welcomeAt; s++) s],
  );
  expect(second[welcomeAt].seq, lastSeqBefore + welcomeAt + 1);
  final replayedSeqs = {for (final f in replayed) f.seq};
  expect(replayedSeqs, containsAll([for (final f in lost) f.seq]));
  expect(
    replayed.any(
      (f) => f.type == 'round.start' && f.payload['round_id'] == roundId,
    ),
    isTrue,
  );

  // Across both sockets every seq arrived exactly once, without gaps.
  final seqs = [for (final f in wire.received) f.seq!];
  expect(seqs.toSet(), hasLength(seqs.length), reason: 'no duplicates');
  final sorted = [...seqs]..sort();
  expect(sorted, [for (var s = sorted.first; s <= sorted.last; s++) s]);
}
