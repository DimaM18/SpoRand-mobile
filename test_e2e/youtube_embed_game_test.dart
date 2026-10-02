// End-to-end: whose_song with provider youtube_embed (wave 4) between
// simulated phones running the app's client stack and the real server, over
// real sockets. The round DJ's phone plays the song in the official embedded
// YouTube player; here the player itself is not built (no WebView in
// `flutter test`): the suite drives what the player widget reports to
// `GameController` (consent answer, player errors) and checks what goes over
// the wire. Video ids are made up; nothing calls YouTube. See
// README.md, "End-to-end suite".
@Timeout(Duration(minutes: 4))
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/core/ads/ads_service.dart';
import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/features/game/domain/game_state.dart';

import 'support/contract_audit.dart';
import 'support/e2e_env.dart';
import 'support/e2e_phone.dart';
import 'support/emoji_catalog.dart';
import 'support/party.dart';
import 'support/rounds.dart';
import 'support/server_analytics.dart';

/// Tap times after the DJ's «Музыка играет!»; the next answerer taps
/// [_tapStepMs] later.
const int _firstTapAfterStartMs = 300;
const int _tapStepMs = 220;

/// The raw IFrame API error the player reports for the first video of the
/// first round: 150, embedding disabled by the owner.
const int _embedDisabledCode = 150;

/// How the DJ answers the consent question before the player may load.
enum _Consent { grant, decline }

void main() {
  final audit = ContractAudit();
  setUpAll(requireRealNetwork);

  test('whose_song, youtube_embed: only the DJ gets video + cue, consent comes '
      'before the player, a failed video is reported and the fallback video '
      'follows without voiding the round, dj_tap starts it, answers are '
      'scored, and no video id reaches guests or analytics', () async {
    final party = await Party.assemble(
      api: e2eApiBaseUrl()!,
      // The DJ (the host) never answers in whose_song, and neither does
      // the owner, so at least two players race in every round.
      names: const ['Ada', 'Bruno', 'Cecylia', 'Damian'],
      mode: GameMode.whoseSong,
      provider: MusicProviderId.youtubeEmbed,
      audit: audit,
      // EEA-like: UMP has not said consent is not required, so the DJ is
      // asked before the player is created (YouTube III.E.4.i).
      consent: {
        0: FakeConsentService(statusAfterRefresh: ConsentStatus.required),
      },
      videoPrefix: 'ytA',
    );
    addTearDown(party.dispose);
    addTearDown(() {
      for (final phone in party.phones) {
        printOnFailure(phone.wireSummary());
      }
    });
    final phones = party.phones;
    final dj = party.host;

    // A second video for every song, linked by two other users' «Мои
    // песни» (song_picks): the round offers it as a fallback.
    final songs = [for (final list in party.picks.values) ...list];
    final alternates = <String, String>{};
    for (var i = 0; i * 10 < songs.length; i++) {
      final linker = await party.extraPhone('Linker ${i + 1}');
      final chunk = songs.skip(i * 10).take(10).toList();
      final videos = {
        for (final (j, song) in chunk.indexed)
          song.songId: e2eVideoId('ytB', i * 10 + j),
      };
      await linker.savePicks([
        for (final song in chunk) song.songId,
      ], videos: videos);
      alternates.addAll(videos);
    }
    final allVideoIds = {...party.videos.values, ...alternates.values};
    expect(party.videos, hasLength(songs.length));

    // The room as the app sees it: capabilities, not the provider id,
    // drive the client (hard rule 9).
    final room = dj.session.room!;
    expect(room.provider, MusicProviderId.youtubeEmbed);
    final caps = room.capabilities;
    expect(caps.audioSource, AudioSource.externalApp);
    expect(caps.playback, AudioStartSource.hostReported);
    expect(caps.needsVisiblePlayer, isTrue);
    expect(caps.needsConsentBeforeLoad, isTrue);
    expect(caps.allowsPaywall, isFalse);
    expect(caps.showsTitleDuringPlay, isTrue);
    for (final phone in phones) {
      expect(
        phone.session.room!.player(phone.playerId)!.poolTrackCount,
        picksPerPlayer,
      );
    }
    // The pool carried each owner's video on (PUT /v1/rooms/{id}/pool).
    for (final phone in phones) {
      final pool = phone.rest.exchanges.lastWhere(
        (c) => c.method == 'PUT' && c.path.endsWith('/pool'),
      );
      final tracks =
          (pool.requestJson! as Map<String, Object?>)['tracks']!
              as List<Object?>;
      for (final track in tracks.cast<Map<String, Object?>>()) {
        expect(
          track['youtube_video_id'],
          party.videos[track['song_id']],
          reason: phone.name,
        );
      }
    }

    party.start();
    final starting = await dj.waitMessage<GameStarting>('game.starting');
    expect(starting.roundsTotal, 3);

    final points = {for (final p in phones) p.playerId: 0};
    for (var index = 0; index < starting.roundsTotal; index++) {
      final reveal = await _playVideoRound(
        party,
        index,
        consent: index == 0 ? _Consent.grant : null,
        failFirstVideo: index == 0,
        alternates: alternates,
      );
      for (final r in reveal.results) {
        points[r.playerId] = points[r.playerId]! + r.points;
      }
    }

    // Nobody has a rewarded ad loaded: the bonus offer (an emoji round,
    // never a YouTube round) times out, then ad break and results.
    for (final phone in phones) {
      final cancelled = await phone.waitMessage<BonusCancelled>(
        'bonus.cancelled',
        timeout: const Duration(seconds: 20),
      );
      expect(cancelled.reason, BonusCancelReason.offerTimeout);
      final finished = await phone.waitGame<GameFinishedState>(
        'game.results',
        timeout: const Duration(seconds: 20),
      );
      expect(finished.roundsPlayed, 3);
      expect(finished.bonusUsed, isFalse);
      expect({
        for (final s in finished.standings) s.playerId: s.points,
      }, points);
      expect(phone.wire.receivedOf('round.voided'), isEmpty);
      expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
    }

    // The DJ reported exactly one failure (round 0, the owner's video)
    // and one dj_tap start per round; guests never report anything.
    expect(dj.wire.sentOf('round.playback_failed'), hasLength(1));
    expect(dj.wire.sentOf('round.playback_started'), hasLength(3));
    for (final guest in phones.skip(1)) {
      expect(guest.wire.sentOf('round.playback_failed'), isEmpty);
      expect(guest.wire.sentOf('round.playback_started'), isEmpty);
    }

    // Leak guard: no video id in any frame a guest got, and on the DJ's
    // phone only in its own round.prepare.
    for (final phone in phones) {
      for (final frame in phone.wire.received) {
        if (phone == dj && frame.type == 'round.prepare') continue;
        final text = jsonEncode(frame.payload);
        for (final id in allVideoIds) {
          expect(
            text.contains(id),
            isFalse,
            reason: '${phone.name} saw $id in $frame',
          );
        }
      }
    }
    _expectNoVideoDataInServerAnalytics(allVideoIds);
  }, skip: e2eSkip());

  test('youtube_embed: the DJ declines the player (consent_declined, the BYOP '
      'cue instead), and the rewarded bonus round is played as the paywall-'
      'safe fallback mode (emoji_quiz), never as a YouTube round', () async {
    // Filip will sponsor the bonus round and watch the rewarded ad to
    // the end (`earned`).
    final sponsorAds = FakeAdsService(
      interstitialLoaded: false,
      rewardedResult: RewardedResult.earned,
    );
    await sponsorAds.initialize(
      const AdsInitOptions(
        underAgeOfConsent: false,
        personalizedAllowed: false,
      ),
    );
    final party = await Party.assemble(
      api: e2eApiBaseUrl()!,
      names: const ['Ewa', 'Filip', 'Gabi', 'Hubert'],
      mode: GameMode.whoseSong,
      provider: MusicProviderId.youtubeEmbed,
      audit: audit,
      ads: {1: sponsorAds},
      consent: {
        0: FakeConsentService(statusAfterRefresh: ConsentStatus.required),
      },
      videoPrefix: 'ytC',
    );
    addTearDown(party.dispose);
    addTearDown(() {
      for (final phone in party.phones) {
        printOnFailure(phone.wireSummary());
      }
    });
    final phones = party.phones;
    final dj = party.host;
    final sponsor = phones[1];
    final catalog = readEmojiCatalog(e2eEmojiCatalogFile());

    party.start();
    final starting = await dj.waitMessage<GameStarting>('game.starting');
    for (var index = 0; index < starting.roundsTotal; index++) {
      await _playVideoRound(
        party,
        index,
        consent: index == 0 ? _Consent.decline : null,
        failFirstVideo: false,
        alternates: const {},
      );
    }
    // Declined once: every round reported consent_declined (not the
    // video's fault; the server does not count it) and played the cue.
    final failures = dj.wire.sentOf('round.playback_failed');
    expect(failures, hasLength(starting.roundsTotal));
    for (final f in failures) {
      expect(f.payload.keys, unorderedEquals(['round_id', 'reason']));
      expect(f.payload['reason'], 'consent_declined');
    }

    // The bonus offer: the room provider has paywall_allowed false, and
    // emoji_quiz can play the round, so it is offered.
    final offer = await sponsor.waitMessage<GameBonusOffer>('game.bonus_offer');
    await sponsor.waitGame<GameBonusState>(
      'game.bonus_offer',
      where: (s) => s.phase is BonusOffered,
    );
    await sponsor.game.requestBonus();
    final nonce = await sponsor.waitMessage<BonusNonce>('bonus.nonce');
    expect(sponsorAds.lastRewardNonce, nonce.rewardNonce);
    final adResult = await sponsor.waitFor(
      'bonus.ad_result on the wire',
      () => sponsor.wire.sentOf('bonus.ad_result').lastOrNull,
    );
    expect(adResult.payload, {'bonus_id': offer.bonusId, 'status': 'earned'});
    // No AdMob SSV callback reaches a local server: scripts/e2e.sh turns
    // on ssv_optimistic_grant, so the grant follows after ssv_wait_ms.
    for (final phone in phones) {
      await phone.waitMessage<BonusGranted>(
        'bonus.granted',
        timeout: const Duration(seconds: 15),
      );
    }

    // The bonus round: an emoji round for everyone, no DJ, no video, no
    // cue, nothing to start; the DJ of the video rounds answers too.
    final rounds = {
      for (final phone in phones)
        phone: await phone.waitGame<GameRoundState>(
          'the bonus round',
          where: (s) => s.round.kind == RoundKind.bonus,
        ),
    };
    final bonusId = rounds[dj]!.round.roundId;
    for (final phone in phones) {
      final view = rounds[phone]!.round;
      final frame = receivedFor(phone, 'round.prepare', bonusId).payload;
      expect(view.prompt, RoundPrompt.emojiRound, reason: phone.name);
      expect(view.audioStartSource, AudioStartSource.none);
      expect(view.isDj, isFalse);
      expect(view.djPlayerId, isNull);
      expect(view.youAreOwner, isFalse);
      for (final key in ['video', 'cue', 'clip', 'text_prompt']) {
        expect(frame.containsKey(key), isFalse, reason: '${phone.name} $key');
      }
      expect(rounds[phone]!.djVideo, isNull);
    }
    final emoji = rounds[dj]!.round.emojiPrompt!.emoji;
    final labels = {
      for (final o in rounds[dj]!.round.options) o.optionId: o.label,
    };
    final song = catalog.singleWhere(
      (s) =>
          s.emoji == emoji && labels.containsValue('${s.title} — ${s.artist}'),
    );
    final correct = labels.entries
        .singleWhere((e) => e.value == '${song.title} — ${song.artist}')
        .key;
    for (final (i, phone) in phones.indexed) {
      await phone.waitGame<GameRoundState>(
        'unlocked bonus round',
        where: (s) => s.round.roundId == bonusId && s.phase is RoundOpen,
      );
      // A human reaction after the unlock (below min_reaction_ms the
      // server floors it).
      await Future<void>.delayed(Duration(milliseconds: 350 + 60 * i));
      expect(phone.tapAnswer(bonusId, correct), isNotNull, reason: phone.name);
    }
    final reveal = await dj.waitMessage<RoundReveal>(
      'round.reveal',
      where: (f) => f.payload['round_id'] == bonusId,
    );
    expect(reveal.correctOptionIds, [correct]);
    expect(reveal.track.title, song.title);
    // The provider that actually played the round, not the room's.
    expect(reveal.track.attribution.provider, MusicProviderId.none);
    for (final phone in phones) {
      final result = resultOf(reveal, phone);
      expect(result.correct, isTrue, reason: phone.name);
      expect(result.validation, AnswerValidation.ok, reason: phone.name);
    }

    for (final phone in phones) {
      final finished = await phone.waitGame<GameFinishedState>(
        'game.results',
        timeout: const Duration(seconds: 20),
      );
      expect(finished.roundsPlayed, starting.roundsTotal + 1);
      expect(finished.bonusUsed, isTrue);
      final types = [for (final f in phone.wire.received) f.type];
      expect(
        types.lastIndexOf('game.ad_break'),
        greaterThan(types.lastIndexOf('round.reveal')),
        reason: '${phone.name}: our ad break only after the last round',
      );
      expect(phone.wire.receivedOf('error'), isEmpty, reason: phone.name);
    }
    _expectNoVideoDataInServerAnalytics(party.videos.values.toSet());
  }, skip: e2eSkip());

  test('contract: every frame of the youtube_embed games decodes with the Dart '
      'DTOs, and every message the app sent matches the protocol', () {
    final counts = audit.typeCounts;
    e2eLog('youtube_embed frames by type: $counts');
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
        'round.start',
        'round.answer_ack',
        'round.reveal',
        'game.bonus_offer',
        'bonus.sponsor_locked',
        'bonus.nonce',
        'bonus.granted',
        'bonus.cancelled',
        'game.ad_break',
        'game.results',
      ]),
    );
    expect(counts.keys, isNot(contains('round.voided')));
  }, skip: e2eSkip());
}

/// One youtube_embed round. The DJ (the host) gets `video` + `cue`, answers
/// the consent question when asked ([consent]), optionally reports the
/// first video as failed (IFrame error 150) and gets the fallback video,
/// then taps «Музыка играет!» (dj_tap, outside the player). Everyone who
/// may answer (neither the DJ nor the owner) names the owner.
Future<RoundReveal> _playVideoRound(
  Party party,
  int index, {
  required _Consent? consent,
  required bool failFirstVideo,
  required Map<String, String> alternates,
}) async {
  final phones = party.phones;
  final dj = party.host;
  final rounds = {
    for (final phone in phones) phone: await phone.waitRound(index),
  };
  final roundId = rounds[dj]!.round.roundId;
  expect(rounds[dj]!.round.isDj, isTrue);
  expect(rounds[dj]!.round.djMayAnswer, isFalse);

  // Only the round DJ gets the video and the cue; never a clip.
  for (final phone in phones) {
    final frame = receivedFor(phone, 'round.prepare', roundId).payload;
    expect(rounds[phone]!.round.prompt, RoundPrompt.whoseSong);
    expect(
      rounds[phone]!.round.audioStartSource,
      AudioStartSource.hostReported,
    );
    expect(frame.containsKey('clip'), isFalse, reason: phone.name);
    expect(frame.containsKey('video'), phone == dj, reason: phone.name);
    expect(frame.containsKey('cue'), phone == dj, reason: phone.name);
    if (phone != dj) {
      expect(rounds[phone]!.round.waitsForDj, isTrue);
      expect(rounds[phone]!.djVideo, isNull);
    }
  }
  final prepare = RoundPrepare.fromJson(
    receivedFor(dj, 'round.prepare', roundId).payload,
  );
  final cue = prepare.cue!;
  final video = prepare.video!;
  final song = party.songTitled(cue.title);
  final owner = party.ownerOfTitle(cue.title);
  // The owner's own pick first, then other links of the song.
  expect(video.videoId, party.videos[song.songId]);
  expect(video.startS, greaterThanOrEqualTo(0));
  if (alternates.isNotEmpty) {
    expect(video.fallbackVideoIds, contains(alternates[song.songId]));
  }

  // The DJ's screen before any player: the consent question where it
  // applies. Nothing can be started while it is open.
  var state = dj.gameState as GameRoundState;
  expect(state.round.roundId, roundId);
  expect(state.phase, isA<RoundDjCue>());
  final failedBefore = dj.wire.sentOf('round.playback_failed').length;
  switch (consent) {
    case _Consent.grant || _Consent.decline:
      expect(state.djVideo, isA<DjVideoConsent>());
      expect(
        dj.game.djStarted(
          roundId: roundId,
          audioStartMonoUs: dj.clock.nowMonoUs,
        ),
        isFalse,
        reason: 'no start before the consent answer',
      );
      dj.game.youTubeConsentAnswered(
        roundId: roundId,
        granted: consent == _Consent.grant,
      );
    case null:
      break;
  }
  state = dj.gameState as GameRoundState;
  final stage = state.djVideo;
  if (stage is DjVideoCueFallback) {
    // Declined (now or earlier in this app session): the BYOP cue, and
    // the server hears why.
    expect(stage.reason, VideoPlaybackFailureReason.consentDeclined);
    final failed = await dj.waitFor(
      'round.playback_failed{consent_declined}',
      () => dj.wire
          .sentOf('round.playback_failed')
          .where((f) => f.payload['round_id'] == roundId)
          .lastOrNull,
    );
    expect(failed.payload, {'round_id': roundId, 'reason': 'consent_declined'});
  } else {
    // The official player for the owner's pick, from the start offset.
    expect(stage, isA<DjVideoPlayer>());
    final player = stage! as DjVideoPlayer;
    expect(player.videoId, video.videoId);
    expect(player.startS, video.startS);
    expect(player.attempt, 0);
    if (failFirstVideo) {
      // The IFrame player refuses it (error 150): reported with the raw
      // code and the id, then the first fallback video is loaded.
      dj.game.youTubeVideoFailed(
        roundId: roundId,
        videoId: video.videoId,
        code: _embedDisabledCode,
      );
      final failed = await dj.waitFor(
        'round.playback_failed{embed_disabled}',
        () => dj.wire
            .sentOf('round.playback_failed')
            .where((f) => f.payload['round_id'] == roundId)
            .lastOrNull,
      );
      expect(failed.payload, {
        'round_id': roundId,
        'reason': 'embed_disabled',
        'code': _embedDisabledCode,
        'video_id': video.videoId,
      });
      final next = (dj.gameState as GameRoundState).djVideo;
      expect(next, isA<DjVideoPlayer>());
      final fallback = next! as DjVideoPlayer;
      expect(fallback.videoId, video.fallbackVideoIds.first);
      expect(fallback.attempt, 1);
      // A failed video never voids the round (unlike a failed clip).
      await Future<void>.delayed(const Duration(milliseconds: 300));
      for (final phone in phones) {
        expect(phone.wire.receivedOf('round.voided'), isEmpty);
      }
    } else {
      expect(dj.wire.sentOf('round.playback_failed'), hasLength(failedBefore));
    }
  }

  // The DJ presses play in the player (ads may run first), then taps
  // «Музыка играет!» below it: the round starts on that pointer time.
  await Future<void>.delayed(const Duration(milliseconds: 150));
  final djTapMonoUs = await dj.djTap(roundId);
  expect(djTapMonoUs, isNotNull);
  final djStartUs = dj.clock.e2eUsOf(djTapMonoUs!);
  final started = sentFor(dj, 'round.playback_started', roundId).payload;
  expect(started['source'], 'dj_tap');
  expect(started['audio_start_mono_us'], djTapMonoUs);

  final answerers = [
    for (final p in phones)
      if (p != owner && p != dj) p,
  ];
  expect(answerers.length, greaterThanOrEqualTo(2));
  for (final phone in answerers) {
    await phone.waitGame<GameRoundState>(
      'unlocked round $index',
      where: (s) => s.round.roundId == roundId && s.phase is RoundOpen,
    );
  }
  final correct = optionLabelled(rounds[answerers.first]!, owner.name).optionId;
  final taps = <E2ePhone, int>{};
  for (final (i, phone) in answerers.indexed) {
    await sleepUntil(
      djStartUs + (_firstTapAfterStartMs + i * _tapStepMs) * 1000,
    );
    final option = optionLabelled(rounds[phone]!, owner.name).optionId;
    expect(option, correct);
    taps[phone] = phone.tapAnswer(roundId, option)!;
  }
  expect(dj.tapAnswer(roundId, correct), isNull, reason: 'the DJ watches');

  final reveal = await dj.waitMessage<RoundReveal>(
    'round.reveal',
    where: (f) => f.payload['round_id'] == roundId,
  );
  for (final phone in phones) {
    await phone.waitGameSeen<GameRevealState>(
      'round.reveal #$index',
      where: (s) => s.reveal.round.roundId == roundId,
    );
  }
  expect(
    (serverMsToE2eUs(
              owner,
              (await owner.waitMessage<RoundStart>(
                'round.start',
                where: (f) => f.payload['round_id'] == roundId,
              )).audioStartServerMs,
            ) -
            djStartUs)
        .abs(),
    lessThan(reactionToleranceMs * 1000),
    reason: 'audio_start_server_ms is the DJ tap time',
  );
  expect(reveal.correctOptionIds, [correct]);
  expect(reveal.ownerPlayerIds, [owner.playerId]);
  expect(reveal.track.title, cue.title);
  expect(reveal.track.artists, cue.artists);
  expect(reveal.track.attribution.provider, MusicProviderId.youtubeEmbed);
  int? previous;
  for (final phone in answerers) {
    final result = resultOf(reveal, phone);
    final truthMs = (phone.clock.e2eUsOf(taps[phone]!) - djStartUs) / 1000;
    expect(result.correct, isTrue, reason: phone.name);
    expect(result.validation, AnswerValidation.ok, reason: phone.name);
    expect(
      (result.reactionMs! - truthMs).abs(),
      lessThan(reactionToleranceMs),
      reason: '${phone.name}: reaction ${result.reactionMs} ms, true $truthMs',
    );
    if (previous != null) expect(result.reactionMs, greaterThan(previous));
    previous = result.reactionMs;
  }
  expect(resultOf(reveal, dj).optionId, isNull);
  expect(resultOf(reveal, owner).points, 0);
  e2eLog(
    'youtube round $index: owner ${owner.name}, video '
    '${state.djVideo.runtimeType}, answered by '
    '${[for (final p in answerers) '${p.name} ${resultOf(reveal, p).reactionMs} ms']}',
  );
  return reveal;
}

/// Server analytics never carry video data (content guard, hard rule 3).
void _expectNoVideoDataInServerAnalytics(Set<String> videoIds) {
  final log = e2eServerLog();
  if (log == null) return;
  for (final line in serverAnalyticsLines(log)) {
    expect(line, isNot(contains('youtube.com')));
    expect(line, isNot(contains('youtu.be')));
    for (final id in videoIds) {
      expect(line, isNot(contains(id)));
    }
  }
}
