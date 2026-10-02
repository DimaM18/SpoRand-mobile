// End-to-end: a whose_song game with provider external_player (BYOP,
// addendum A2.2) between three simulated phones running the app's client
// stack and the real server, over real sockets. See README.md,
// "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/party.dart';
import 'support/rounds.dart';

/// The early tapper's `round.answer` is held back this long on its way out,
/// so it reaches the server after the later tap's (brief §5: the tap time is
/// the device's, never the arrival time). It stays below
/// `timing_tolerance_ms` (500) minus the head start, so the server has no
/// reason to clamp it (validation step 8).
const Duration _answerSendDelay = Duration(milliseconds: 380);

/// Tap times after the DJ's «Музыка играет!».
const int _earlyTapAfterStartMs = 300;
const int _lateTapAfterStartMs = 520;

void main() {
  final audit = ContractAudit();
  // The DJ has a rewarded ad loaded and will close it early.
  final djAds = FakeAdsService(
    interstitialLoaded: false,
    rewardedResult: RewardedResult.dismissed,
  );
  setUpAll(requireRealNetwork);
  setUpAll(
    () => djAds.initialize(
      const AdsInitOptions(
        underAgeOfConsent: false,
        personalizedAllowed: false,
      ),
    ),
  );

  test(
    'whose_song, external_player: only the DJ gets the cue, dj_tap starts the '
    'round, device tap times win over arrival order, a bonus request without '
    'App Check token, ad break and results',
    () async {
      final party = await Party.assemble(
        api: e2eApiBaseUrl()!,
        // Four players: the DJ (the host) never answers in whose_song
        // (whose_song_dj_can_answer = false), and neither does the owner,
        // so at least two players race in every round.
        names: const ['Ana', 'Borys', 'Celina', 'Dawid'],
        mode: GameMode.whoseSong,
        provider: MusicProviderId.externalPlayer,
        audit: audit,
        ads: {0: djAds},
      );
      addTearDown(party.dispose);
      addTearDown(() {
        for (final phone in party.phones) {
          printOnFailure(phone.wireSummary());
        }
      });
      final phones = party.phones;
      final dj = party.host;
      expect(dj.session.config.whoseSongDjCanAnswer, isFalse);

      // The room as the app sees it (welcome.room).
      final room = dj.session.room!;
      expect(room.provider, MusicProviderId.externalPlayer);
      expect(room.capabilities.audioSource, AudioSource.externalApp);
      expect(room.capabilities.playback, AudioStartSource.hostReported);
      expect(room.capabilities.allowsMonetization, isTrue);
      expect(room.player(dj.playerId)!.isPlaybackDevice, isTrue);
      // Every player passed the age gate as an adult, and the server knows:
      // it forces the explicit filter only for minors or unknown ages.
      expect(room.settings.explicitFilter, isFalse);

      for (final phone in phones) {
        // hello with a single-use ticket, then the clock-sync burst answered.
        final hello = phone.wire.sent.first;
        expect(hello.type, 'hello');
        expect(hello.payload['ticket'], matches(r'^[A-Za-z0-9_.-]{16,512}$'));
        expect(hello.payload['platform'], 'android');
        expect(hello.payload.containsKey('last_seq'), isFalse);
        expect(phone.wire.sentOf('clock.pong').length, greaterThanOrEqualTo(5));
        final sync = phone.session.clock.latest!;
        expect(sync.quality, ClockQuality.good, reason: phone.name);
        expect(sync.samples, greaterThanOrEqualTo(5));
        expect(
          phone.session.room!.player(phone.playerId)!.poolTrackCount,
          picksPerPlayer,
        );
      }
      // Different device clocks give very different offsets.
      final offsets = {for (final p in phones) p.session.clock.offsetUs};
      expect(offsets, hasLength(phones.length));

      party.start();
      for (final phone in phones) {
        await phone.waitMessage<GameStarting>('game.starting');
      }
      final roundsTotal =
          dj.wire.receivedOf('game.starting').last.payload['rounds_total']!
              as int;
      expect(roundsTotal, 3);

      final points = {for (final p in phones) p.playerId: 0};
      for (var index = 0; index < roundsTotal; index++) {
        final reveal = await _playRound(party, index);
        for (final r in reveal.results) {
          points[r.playerId] = points[r.playerId]! + r.points;
        }
      }

      await _declinedBonus(party);

      // All rounds -> (bonus offer) -> ad_break -> results.
      for (final phone in phones) {
        final finished = await phone.waitGame<GameFinishedState>(
          'game.results',
          timeout: const Duration(seconds: 20),
        );
        expect(finished.roundsPlayed, roundsTotal);
        expect(finished.bonusUsed, isFalse);
        final types = [for (final f in phone.wire.received) f.type];
        expect(
          types.lastIndexOf('game.ad_break'),
          lessThan(types.lastIndexOf('game.results')),
          reason: '${phone.name}: ad_break comes before results',
        );
        expect(
          {for (final s in finished.standings) s.playerId: s.points},
          points,
          reason: '${phone.name}: final standings = sum of reveal points',
        );
        // The room itself is now in `results` (play again or leave).
        final after = await phone.waitMessage<RoomStateMessage>(
          'room.state',
          where: (f) => f.payload['state'] == 'results',
        );
        expect(after.room.state, RoomState.results);
      }

      // Only the DJ reports starts, always dj_tap; nobody played audio.
      expect(dj.wire.sentOf('round.playback_started'), hasLength(roundsTotal));
      for (final guest in phones.skip(1)) {
        expect(guest.wire.sentOf('round.playback_started'), isEmpty);
        expect(guest.musicApp.opened, isEmpty);
      }
      expect(dj.musicApp.opened, hasLength(roundsTotal));
      for (final phone in phones) {
        expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
      }
    },
    skip: e2eSkip(),
  );

  test(
    'contract: every server frame of the BYOP game decodes with the Dart DTOs',
    () {
      final counts = audit.typeCounts;
      e2eLog('BYOP game frames by type: $counts');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      e2eLog('REST calls: ${audit.restCounts}');
      expect(audit.restProblems(), isEmpty);
      expect(
        counts.keys,
        containsAll(<String>[
          'welcome',
          'clock.ping',
          'clock.result',
          'room.player_joined',
          'room.player_updated',
          'game.starting',
          'round.prepare',
          'round.start',
          'round.answer_ack',
          'round.progress',
          'round.reveal',
          'game.bonus_offer',
          'bonus.sponsor_locked',
          'bonus.nonce',
          'bonus.cancelled',
          'game.ad_break',
          'game.results',
        ]),
      );
    },
    skip: e2eSkip(),
  );
}

/// One BYOP round: the DJ opens the cue in its music app and taps «Музыка
/// играет!»; of the players who may answer (neither the owner nor the DJ),
/// the early one taps 220 ms before the late one but its answer reaches the
/// server ~160 ms after it; a third one, if any, answers later still.
Future<RoundReveal> _playRound(Party party, int index) async {
  final phones = party.phones;
  final rounds = {
    for (final phone in phones) phone: await phone.waitRound(index),
  };
  final roundId = rounds[party.host]!.round.roundId;
  e2eLog('round $index ($roundId) prepared');

  // Only the DJ (the host, the playback device) gets the cue; no clip ever.
  final dj = phones.singleWhere((p) => rounds[p]!.round.isDj);
  expect(dj, same(party.host));
  expect(rounds[dj]!.round.djMayAnswer, isFalse);
  for (final phone in phones) {
    final round = rounds[phone]!;
    final frame = receivedFor(phone, 'round.prepare', roundId);
    expect(round.round.roundId, roundId);
    expect(round.round.audioStartSource, AudioStartSource.hostReported);
    expect(round.round.prompt, RoundPrompt.whoseSong);
    expect(frame.payload.containsKey('clip'), isFalse, reason: phone.name);
    expect(frame.payload.containsKey('text_prompt'), isFalse);
    if (phone == dj) {
      expect(round.phase, isA<RoundDjCue>());
      expect(frame.payload.containsKey('cue'), isTrue);
    } else {
      expect(frame.payload.containsKey('cue'), isFalse, reason: phone.name);
      expect(round.round.waitsForDj, isTrue);
      expect(round.phase, anyOf(isA<RoundLocked>(), isA<RoundOwnerWatching>()));
    }
  }
  final cue = rounds[dj]!.round.cue!;
  final owner = phones.singleWhere((p) => rounds[p]!.round.youAreOwner);
  final answerers = [
    for (final p in phones)
      if (p != owner && p != dj) p,
  ];
  expect(answerers, hasLength(owner == dj ? 3 : 2));

  // The DJ starts the song in its own music app, comes back and taps.
  expect(await dj.game.openCueInMusicApp(), isTrue);
  expect(dj.musicApp.opened.last.title, cue.title);
  await Future<void>.delayed(const Duration(milliseconds: 150));
  final djTapMonoUs = await dj.djTap(roundId);
  expect(djTapMonoUs, isNotNull);
  final djStartUs = dj.clock.e2eUsOf(djTapMonoUs!);
  final started = sentFor(dj, 'round.playback_started', roundId).payload;
  expect(started, {
    'round_id': roundId,
    'audio_start_mono_us': djTapMonoUs,
    'output_latency_ms': 0,
    'output_route': 'other',
    'source': 'dj_tap',
  });

  // Guests unlock on round.start, the DJ on its own report.
  for (final phone in answerers) {
    await phone.waitGame<GameRoundState>(
      'unlocked round $index',
      where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
    );
  }
  final roundStart = await owner.waitMessage<RoundStart>(
    'round.start',
    where: (f) => f.payload['round_id'] == roundId,
  );
  expect(
    (serverMsToE2eUs(owner, roundStart.audioStartServerMs) - djStartUs).abs(),
    lessThan(reactionToleranceMs * 1000),
    reason: 'audio_start_server_ms is the DJ tap time, not its arrival',
  );

  final early = answerers[index.isEven ? 0 : 1];
  final late = answerers[index.isEven ? 1 : 0];
  final correct = optionLabelled(rounds[early]!, owner.name).optionId;
  expect(optionLabelled(rounds[late]!, owner.name).optionId, correct);

  await sleepUntil(djStartUs + _earlyTapAfterStartMs * 1000);
  early.wire.delayNext('round.answer', _answerSendDelay);
  final earlyTap = early.tapAnswer(roundId, correct);
  await sleepUntil(djStartUs + _lateTapAfterStartMs * 1000);
  final lateTap = late.tapAnswer(roundId, correct);
  expect(earlyTap, isNotNull);
  expect(lateTap, isNotNull);
  final slow = answerers.skip(2).toList();
  await sleepUntil(djStartUs + (_lateTapAfterStartMs + 250) * 1000);
  for (final phone in slow) {
    expect(phone.tapAnswer(roundId, correct), isNotNull);
  }
  // The DJ has no buttons (it watches), so its controller commits nothing.
  expect(dj.tapAnswer(roundId, correct), isNull);
  for (final phone in [early, late, ...slow]) {
    final ack = await phone.waitMessage<RoundAnswerAck>(
      'round.answer_ack',
      where: (f) => f.payload['round_id'] == roundId,
    );
    expect(ack.accepted, isTrue, reason: '${phone.name}: ${ack.reason}');
  }

  final reveals = <E2ePhone, GameRevealState>{
    for (final phone in phones)
      phone: await phone.waitGame<GameRevealState>(
        'round.reveal #$index',
        where: (s) => s.reveal.round.roundId == roundId,
      ),
  };
  final reveal = await party.host.waitMessage<RoundReveal>(
    'round.reveal',
    where: (f) => f.payload['round_id'] == roundId,
  );

  // What the server got: the late tap first, the early tap ~160 ms later.
  final earlyAnswer = sentFor(early, 'round.answer', roundId);
  final lateAnswer = sentFor(late, 'round.answer', roundId);
  expect(earlyAnswer.payload['tap_mono_us'], earlyTap);
  expect(lateAnswer.payload['tap_mono_us'], lateTap);
  expect(
    earlyAnswer.atUs - early.clock.e2eUsOf(earlyTap!),
    greaterThanOrEqualTo(_answerSendDelay.inMicroseconds - 1000),
  );
  expect(earlyAnswer.atUs, greaterThan(lateAnswer.atUs));
  expect(
    receivedFor(early, 'round.answer_ack', roundId).atUs,
    greaterThan(receivedFor(late, 'round.answer_ack', roundId).atUs),
    reason: 'the server acked the late tap first: it arrived first',
  );

  // …and still scored the early tap as the faster one, with the reaction
  // measured on each device's own clock.
  final earlyResult = resultOf(reveal, early);
  final lateResult = resultOf(reveal, late);
  for (final (phone, tapMonoUs, result) in [
    (early, earlyTap, earlyResult),
    (late, lateTap!, lateResult),
  ]) {
    final truthMs = (phone.clock.e2eUsOf(tapMonoUs) - djStartUs) / 1000;
    expect(result.correct, isTrue, reason: phone.name);
    expect(result.optionId, correct);
    expect(result.validation, AnswerValidation.ok, reason: phone.name);
    expect(
      (result.reactionMs! - truthMs).abs(),
      lessThan(reactionToleranceMs),
      reason: '${phone.name}: reaction ${result.reactionMs} ms, true $truthMs',
    );
  }
  expect(earlyResult.reactionMs, lessThan(lateResult.reactionMs!));
  // Streak bonuses differ between players; the speed part must not.
  expect(
    speedPoints(early, earlyResult),
    greaterThan(speedPoints(late, lateResult)),
  );
  e2eLog(
    'round $index: early ${early.name} ${earlyResult.reactionMs} ms '
    '${earlyResult.points} pts (streak ${earlyResult.streak}), late '
    '${late.name} ${lateResult.reactionMs} ms ${lateResult.points} pts '
    '(streak ${lateResult.streak}), owner ${owner.name}',
  );

  // The owner sat out; the reveal names the song the DJ saw in the cue.
  final ownerResult = resultOf(reveal, owner);
  expect(ownerResult.optionId, isNull);
  expect(ownerResult.points, 0);
  final djResult = resultOf(reveal, dj);
  expect(djResult.optionId, isNull);
  expect(djResult.points, 0);
  expect(reveal.ownerPlayerIds, [owner.playerId]);
  expect(reveal.correctOptionIds, [correct]);
  expect(reveal.track.title, cue.title);
  expect(reveal.track.artists, cue.artists);
  for (final MapEntry(key: phone, value: state) in reveals.entries) {
    expect(state.reveal.track.title, cue.title, reason: phone.name);
    expect(state.reveal.ownerNames, [owner.name]);
  }
  return reveal;
}

/// End of game (brief §6): every adult may sponsor a bonus round. The DJ
/// asks for it, which a device without App Check does without a token, then
/// closes the rewarded ad early, so the server cancels the bonus.
Future<void> _declinedBonus(Party party) async {
  final phones = party.phones;
  final dj = party.host;
  for (final phone in phones) {
    await phone.waitGame<GameBonusState>(
      'game.bonus_offer',
      where: (s) => s.phase is BonusOffered,
    );
  }
  final offer = await dj.waitMessage<GameBonusOffer>('game.bonus_offer');
  expect(
    offer.eligiblePlayerIds,
    unorderedEquals([for (final p in phones) p.playerId]),
  );
  final phase = (dj.gameState as GameBonusState).phase as BonusOffered;
  expect(phase.canWatch, isTrue, reason: 'the DJ has a rewarded ad loaded');

  await dj.game.requestBonus();
  final request = await dj.waitFor(
    'bonus.request on the wire',
    () => dj.wire.sentOf('bonus.request').lastOrNull,
  );
  expect(request.payload, {'bonus_id': offer.bonusId});
  for (final phone in phones) {
    final locked = await phone.waitMessage<BonusSponsorLocked>(
      'bonus.sponsor_locked',
    );
    expect(locked.sponsorPlayerId, dj.playerId);
  }
  final adResult = await dj.waitFor(
    'bonus.ad_result on the wire',
    () => dj.wire.sentOf('bonus.ad_result').lastOrNull,
  );
  expect(adResult.payload, {'bonus_id': offer.bonusId, 'status': 'dismissed'});
  for (final phone in phones) {
    final cancelled = await phone.waitMessage<BonusCancelled>(
      'bonus.cancelled',
    );
    expect(cancelled.reason, BonusCancelReason.adNotCompleted);
    // The reward nonce goes to the sponsor only.
    expect(
      phone.wire.receivedOf('bonus.nonce'),
      hasLength(phone == dj ? 1 : 0),
      reason: phone.name,
    );
  }
}
