// End-to-end: an emoji_quiz game (wave 3) between three simulated phones and
// the real server. No audio and no DJ: every phone reads the same emoji,
// gets the same four «Title — Artist» options in its own order, unlocks at
// start_at on its own clock, and the host answers too. See
// README.md, "End-to-end suite".
@Timeout(Duration(minutes: 3))
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';
import 'package:sporand/features/lobby/presentation/lobby_controller.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/emoji_catalog.dart';
import 'support/party.dart';
import 'support/rounds.dart';
import 'support/server_analytics.dart';

/// As in the other suites: the early tap reaches the server after the late
/// one, and still wins on device time.
const Duration _answerSendDelay = Duration(milliseconds: 380);
const int _earlyTapAfterStartMs = 300;
const int _lateTapAfterStartMs = 520;
const int _wrongTapAfterStartMs = 800;
const int _unlockSlackMs = 100;

/// Keys that would give the answer away before `round.reveal`.
const Set<String> _answerKeys = {
  'title',
  'artists',
  'year',
  'track',
  'correct_option_ids',
  'emoji_song_id',
  'cue',
  'text_prompt',
  'clip',
};

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test('emoji_quiz: the same emoji for everyone, the options in each player\'s '
      'own order, no answer on the wire before the reveal, the earlier device '
      'tap wins, and the reveal names title, artist and year', () async {
    final catalog = readEmojiCatalog(e2eEmojiCatalogFile());
    expect(catalog, isNotEmpty);
    // The owner's rule for this mode: only the intl and pl markets.
    expect({
      for (final s in catalog) s.market,
    }, everyElement(isIn(['intl', 'pl'])));

    final party = await Party.assemble(
      api: e2eApiBaseUrl()!,
      names: const ['Ola', 'Piotr', 'Rita'],
      mode: GameMode.emojiQuiz,
      provider: MusicProviderId.none,
      audit: audit,
      pools: false,
    );
    addTearDown(party.dispose);
    addTearDown(() {
      for (final phone in party.phones) {
        printOnFailure(phone.wireSummary());
      }
    });
    final phones = party.phones;
    final host = party.host;

    final room = host.session.room!;
    expect(room.settings.mode, GameMode.emojiQuiz);
    expect(room.settings.emojiMarkets, isNotNull);
    expect(
      room.settings.emojiMarkets,
      everyElement(isIn([EmojiMarket.intl, EmojiMarket.pl])),
    );
    expect(room.settings.emojiMaxDifficulty, 3);
    final lobby = (host.lobbyState as LobbyLoaded).view;
    expect(lobby.isEmojiQuiz, isTrue);
    expect(lobby.canStart, isTrue, reason: 'no pools needed');
    for (final phone in phones) {
      expect(phone.session.room!.player(phone.playerId)!.poolTrackCount, 0);
    }

    party.start();
    final starting = await host.waitMessage<GameStarting>('game.starting');
    expect(starting.prefetch, isEmpty);

    final orders = <List<List<String>>>[];
    final points = {for (final p in phones) p.playerId: 0};
    final played = <EmojiCatalogSong>[];
    for (var index = 0; index < starting.roundsTotal; index++) {
      final (:reveal, :song, :optionOrders) = await _playRound(
        party,
        index,
        catalog,
      );
      orders.add(optionOrders);
      played.add(song);
      for (final r in reveal.results) {
        points[r.playerId] = points[r.playerId]! + r.points;
      }
    }
    expect(
      {for (final s in played) s.id},
      hasLength(played.length),
      reason: 'no song twice in one game',
    );
    // The options are shuffled per player: over the game, at least one
    // round shows them in different orders on different phones.
    expect(
      orders.any(
        (perPhone) => perPhone.map((o) => o.join()).toSet().length > 1,
      ),
      isTrue,
      reason: 'option orders per round and phone: $orders',
    );

    for (final phone in phones) {
      final finished = await phone.waitGame<GameFinishedState>(
        'game.results',
        timeout: const Duration(seconds: 30),
      );
      expect(finished.roundsPlayed, starting.roundsTotal);
      expect({
        for (final s in finished.standings) s.playerId: s.points,
      }, points);
      // Nothing plays: no start reports, no music app, no DJ.
      expect(phone.wire.sentOf('round.playback_started'), isEmpty);
      expect(phone.musicApp.opened, isEmpty);
      expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
    }

    // Server analytics never carry the song (brief hard rule 3): at most
    // the catalogue id.
    final log = e2eServerLog();
    if (log != null) {
      for (final line in serverAnalyticsLines(log)) {
        for (final song in played) {
          expect(line, isNot(contains(song.title)));
          expect(line, isNot(contains(song.emoji)));
        }
      }
    }
  }, skip: e2eSkip());

  test(
    'contract: every frame of the emoji game decodes with the Dart DTOs',
    () {
      final counts = audit.typeCounts;
      e2eLog('emoji game frames by type: $counts');
      expect(audit.problems(), isEmpty);
      expect(audit.clientProblems(), isEmpty);
      e2eLog('REST calls: ${audit.restCounts}');
      expect(audit.restProblems(), isEmpty);
      expect(
        counts.keys,
        containsAll(<String>[
          'welcome',
          'game.starting',
          'round.prepare',
          'round.answer_ack',
          'round.progress',
          'round.reveal',
          'game.results',
        ]),
      );
      expect(counts.keys, isNot(contains('round.voided')));
    },
    skip: e2eSkip(),
  );
}

Future<
  ({RoundReveal reveal, EmojiCatalogSong song, List<List<String>> optionOrders})
>
_playRound(Party party, int index, List<EmojiCatalogSong> catalog) async {
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
  final emoji = rounds[party.host]!.round.emojiPrompt!.emoji;
  final labels = {
    for (final o in rounds[party.host]!.round.options) o.optionId: o.label,
  };
  expect(labels, hasLength(4));
  for (final phone in phones) {
    final view = rounds[phone]!.round;
    expect(view.isEmojiRound, isTrue);
    expect(view.prompt, RoundPrompt.emojiRound);
    expect(view.audioStartSource, AudioStartSource.none);
    expect(view.emojiPrompt!.emoji, emoji, reason: phone.name);
    expect(view.isDj, isFalse);
    expect(view.djPlayerId, isNull);
    expect(view.youAreOwner, isFalse);
    expect(view.cue, isNull);
    expect(view.textPrompt, isNull);
    // The same options everywhere (same ids, same labels) …
    expect(
      {for (final o in view.options) o.optionId: o.label},
      labels,
      reason: phone.name,
    );
  }
  // … and the answer known only from the catalogue.
  final song = catalog.singleWhere(
    (s) => s.emoji == emoji && labels.containsValue('${s.title} — ${s.artist}'),
  );
  final correct = labels.entries
      .singleWhere((e) => e.value == '${song.title} — ${song.artist}')
      .key;

  // Everyone unlocks by itself at start_at: no DJ, no round.start needed.
  for (final phone in phones) {
    await phone.waitGame<GameRoundState>(
      'unlocked emoji round $index',
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

  // Everyone answers, the host included; the roles rotate per round.
  final early = phones[index % 3];
  final late = phones[(index + 1) % 3];
  final wrong = phones[(index + 2) % 3];
  final wrongOption = labels.keys.firstWhere((id) => id != correct);
  final startAtUs = serverMsToE2eUs(early, prepares[early]!.startAtServerMs);
  await sleepUntil(startAtUs + _earlyTapAfterStartMs * 1000);
  early.wire.delayNext('round.answer', _answerSendDelay);
  final earlyTap = early.tapAnswer(roundId, correct);
  await sleepUntil(startAtUs + _lateTapAfterStartMs * 1000);
  final lateTap = late.tapAnswer(roundId, correct);
  await sleepUntil(startAtUs + _wrongTapAfterStartMs * 1000);
  final wrongTap = wrong.tapAnswer(roundId, wrongOption);
  expect([earlyTap, lateTap, wrongTap], everyElement(isNotNull));

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

  // Nothing before the reveal named the song or marked the right option.
  for (final phone in phones) {
    final prepareAt = receivedFor(phone, 'round.prepare', roundId).atUs;
    final revealAt = receivedFor(phone, 'round.reveal', roundId).atUs;
    for (final frame in phone.wire.received) {
      if (frame.atUs < prepareAt || frame.atUs >= revealAt) continue;
      final leak = _leak(frame.payload, song, r'$');
      expect(leak, isNull, reason: '${phone.name} $frame leaks at $leak');
    }
  }

  expect(reveal.correctOptionIds, [correct]);
  expect(reveal.ownerPlayerIds, isEmpty);
  expect(reveal.track.title, song.title);
  expect(reveal.track.artists, [song.artist]);
  expect(reveal.track.year, song.year);
  expect(reveal.track.attribution.provider, MusicProviderId.none);
  // What the reveal screen shows: «Title — Artist» and «Год: …».
  for (final phone in phones) {
    final state = await phone.waitGameSeen<GameRevealState>(
      'the reveal state #$index',
      where: (s) => s.reveal.round.roundId == roundId,
    );
    expect(state.reveal.track.title, song.title, reason: phone.name);
    expect(state.reveal.track.year, song.year, reason: phone.name);
  }

  final earlyResult = resultOf(reveal, early);
  final lateResult = resultOf(reveal, late);
  final wrongResult = resultOf(reveal, wrong);
  expect(
    sentFor(early, 'round.answer', roundId).atUs,
    greaterThan(sentFor(late, 'round.answer', roundId).atUs),
    reason: 'the early tap arrived last',
  );
  for (final (phone, tapMonoUs, result) in [
    (early, earlyTap!, earlyResult),
    (late, lateTap!, lateResult),
    (wrong, wrongTap!, wrongResult),
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
  expect(lateResult.correct, isTrue);
  expect(wrongResult.correct, isFalse);
  expect(wrongResult.points, 0);
  expect(earlyResult.reactionMs, lessThan(lateResult.reactionMs!));
  expect(
    speedPoints(early, earlyResult),
    greaterThan(speedPoints(late, lateResult)),
  );
  e2eLog(
    'emoji round $index (${song.id}, ${song.market}): early ${early.name} '
    '${earlyResult.reactionMs} ms ${earlyResult.points} pts, late '
    '${late.name} ${lateResult.reactionMs} ms ${lateResult.points} pts, '
    'wrong ${wrong.name}',
  );
  return (
    reveal: reveal,
    song: song,
    optionOrders: [
      for (final phone in phones)
        [for (final o in rounds[phone]!.round.options) o.optionId],
    ],
  );
}

/// The first place in [json] that names [song] or the right option outside
/// the option labels, or null.
String? _leak(Object? json, EmojiCatalogSong song, String path) {
  switch (json) {
    case final Map<String, Object?> map:
      for (final MapEntry(:key, :value) in map.entries) {
        if (_answerKeys.contains(key)) return '$path.$key';
        final inner = _leak(value, song, '$path.$key');
        if (inner != null) return inner;
      }
    case final List<Object?> list:
      for (final (i, item) in list.indexed) {
        final inner = _leak(item, song, '$path[$i]');
        if (inner != null) return inner;
      }
    case final String text:
      if (text == song.title || text == song.artist) return '$path = "$text"';
  }
  return null;
}
