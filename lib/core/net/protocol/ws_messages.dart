/// Every WebSocket message of brief §4.3 as a typed class: sealed
/// [ServerMessage] (server -> client) and [ClientMessage] (client -> server),
/// each with `fromJson` (payload) and `toJson` (payload).
///
/// Hand-written mirror of packages/protocol; replaced by the generated
/// lib/contracts/ code later. Type strings and field names are canonical.
library;

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/net/protocol/ws_protocol.dart';
import 'package:sporand/core/platform/app_platform.dart';

// ===========================================================================
// Server -> client
// ===========================================================================

sealed class ServerMessage {
  const ServerMessage();

  String get type;

  /// The `payload` object.
  JsonMap toJson();

  WsEnvelope toEnvelope(int seq) =>
      WsEnvelope(type: type, seq: seq, payload: toJson());

  /// Parses a payload by message type. Unknown types (added by a newer
  /// server) become [UnknownServerMessage] instead of failing.
  static ServerMessage fromJson(String type, JsonMap payload) => switch (type) {
    WsServerMessage.welcome => Welcome.fromJson(payload),
    WsServerMessage.clockPing => ClockPing.fromJson(payload),
    WsServerMessage.clockResult => ClockResult.fromJson(payload),
    WsServerMessage.roomState => RoomStateMessage.fromJson(payload),
    WsServerMessage.roomPlayerJoined => RoomPlayerJoined.fromJson(payload),
    WsServerMessage.roomPlayerLeft => RoomPlayerLeft.fromJson(payload),
    WsServerMessage.roomPlayerUpdated => RoomPlayerUpdated.fromJson(payload),
    WsServerMessage.roomClosed => RoomClosed.fromJson(payload),
    WsServerMessage.gameStarting => GameStarting.fromJson(payload),
    WsServerMessage.roundPrepare => RoundPrepare.fromJson(payload),
    WsServerMessage.roundStart => RoundStart.fromJson(payload),
    WsServerMessage.roundAnswerAck => RoundAnswerAck.fromJson(payload),
    WsServerMessage.roundProgress => RoundProgress.fromJson(payload),
    WsServerMessage.roundVoided => RoundVoided.fromJson(payload),
    WsServerMessage.roundReveal => RoundReveal.fromJson(payload),
    WsServerMessage.gameBonusOffer => GameBonusOffer.fromJson(payload),
    WsServerMessage.bonusSponsorLocked => BonusSponsorLocked.fromJson(payload),
    WsServerMessage.bonusNonce => BonusNonce.fromJson(payload),
    WsServerMessage.bonusGranted => BonusGranted.fromJson(payload),
    WsServerMessage.bonusCancelled => BonusCancelled.fromJson(payload),
    WsServerMessage.gameAdBreak => GameAdBreak.fromJson(payload),
    WsServerMessage.gameResults => GameResults.fromJson(payload),
    WsServerMessage.playerEntitlementsUpdated =>
      PlayerEntitlementsUpdated.fromJson(payload),
    WsServerMessage.serverDraining => ServerDraining.fromJson(payload),
    WsServerMessage.error => ServerError.fromJson(payload),
    _ => UnknownServerMessage(type, payload),
  };

  static ServerMessage fromEnvelope(WsEnvelope envelope) =>
      fromJson(envelope.type, envelope.payload);
}

/// A type this client does not know yet; ignored by controllers.
final class UnknownServerMessage extends ServerMessage {
  const UnknownServerMessage(this.type, this.payload);

  @override
  final String type;
  final JsonMap payload;

  @override
  JsonMap toJson() => payload;
}

final class Welcome extends ServerMessage {
  const Welcome({
    required this.playerId,
    required this.room,
    required this.config,
    required this.configVersion,
    required this.serverVersion,
  });

  factory Welcome.fromJson(JsonMap json) => Welcome(
    playerId: json.str('player_id'),
    room: RoomSnapshot.fromJson(json.obj('room')),
    config: RoomConfig(json.obj('config')),
    configVersion: json.str('config_version'),
    serverVersion: json.str('server_version'),
  );

  final String playerId;
  final RoomSnapshot room;
  final RoomConfig config;
  final String configVersion;
  final String serverVersion;

  @override
  String get type => WsServerMessage.welcome;

  @override
  JsonMap toJson() => {
    'player_id': playerId,
    'room': room.toJson(),
    'config': config.toJson(),
    'config_version': configVersion,
    'server_version': serverVersion,
  };
}

final class ClockPing extends ServerMessage {
  const ClockPing({required this.pingId, required this.t1ServerUs});

  factory ClockPing.fromJson(JsonMap json) => ClockPing(
    pingId: json.str('ping_id'),
    t1ServerUs: json.integer('t1_server_us'),
  );

  final String pingId;
  final int t1ServerUs;

  @override
  String get type => WsServerMessage.clockPing;

  @override
  JsonMap toJson() => {'ping_id': pingId, 't1_server_us': t1ServerUs};
}

final class ClockResult extends ServerMessage {
  const ClockResult({
    required this.offsetUs,
    required this.rttMinUs,
    required this.samples,
    required this.quality,
  });

  factory ClockResult.fromJson(JsonMap json) => ClockResult(
    offsetUs: json.integer('offset_us'),
    rttMinUs: json.integer('rtt_min_us'),
    samples: json.integer('samples'),
    quality: json.wire('quality', ClockQuality.values),
  );

  /// Device clock ≈ server clock + offset (brief §5).
  final int offsetUs;
  final int rttMinUs;
  final int samples;
  final ClockQuality quality;

  @override
  String get type => WsServerMessage.clockResult;

  @override
  JsonMap toJson() => {
    'offset_us': offsetUs,
    'rtt_min_us': rttMinUs,
    'samples': samples,
    'quality': quality.wire,
  };
}

/// `room.state`: the full snapshot.
final class RoomStateMessage extends ServerMessage {
  const RoomStateMessage(this.room);

  factory RoomStateMessage.fromJson(JsonMap json) =>
      RoomStateMessage(RoomSnapshot.fromJson(json));

  final RoomSnapshot room;

  @override
  String get type => WsServerMessage.roomState;

  @override
  JsonMap toJson() => room.toJson();
}

final class RoomPlayerJoined extends ServerMessage {
  const RoomPlayerJoined(this.player);

  factory RoomPlayerJoined.fromJson(JsonMap json) =>
      RoomPlayerJoined(PlayerSnapshot.fromJson(json.obj('player')));

  final PlayerSnapshot player;

  @override
  String get type => WsServerMessage.roomPlayerJoined;

  @override
  JsonMap toJson() => {'player': player.toJson()};
}

final class RoomPlayerLeft extends ServerMessage {
  const RoomPlayerLeft({required this.playerId, required this.reason});

  factory RoomPlayerLeft.fromJson(JsonMap json) => RoomPlayerLeft(
    playerId: json.str('player_id'),
    reason: json.wire(
      'reason',
      PlayerLeftReason.values,
      fallback: PlayerLeftReason.unknown,
    ),
  );

  final String playerId;
  final PlayerLeftReason reason;

  @override
  String get type => WsServerMessage.roomPlayerLeft;

  @override
  JsonMap toJson() => {'player_id': playerId, 'reason': reason.wire};
}

final class RoomPlayerUpdated extends ServerMessage {
  const RoomPlayerUpdated(this.player);

  factory RoomPlayerUpdated.fromJson(JsonMap json) =>
      RoomPlayerUpdated(PlayerSnapshot.fromJson(json.obj('player')));

  final PlayerSnapshot player;

  @override
  String get type => WsServerMessage.roomPlayerUpdated;

  @override
  JsonMap toJson() => {'player': player.toJson()};
}

final class RoomClosed extends ServerMessage {
  const RoomClosed(this.reason);

  factory RoomClosed.fromJson(JsonMap json) => RoomClosed(
    json.wire(
      'reason',
      RoomClosedReason.values,
      fallback: RoomClosedReason.unknown,
    ),
  );

  final RoomClosedReason reason;

  @override
  String get type => WsServerMessage.roomClosed;

  @override
  JsonMap toJson() => {'reason': reason.wire};
}

final class GameStarting extends ServerMessage {
  const GameStarting({
    required this.gameId,
    required this.roundsTotal,
    required this.countdownMs,
    this.prefetch = const [],
  });

  factory GameStarting.fromJson(JsonMap json) => GameStarting(
    gameId: json.str('game_id'),
    roundsTotal: json.integer('rounds_total'),
    countdownMs: json.integer('countdown_ms'),
    prefetch:
        json.optList(
          'prefetch',
          (item) => PrefetchClip.fromJson(asObject(item)),
        ) ??
        const [],
  );

  final String gameId;
  final int roundsTotal;
  final int countdownMs;

  /// Playback device only, and only if the provider allows prefetching.
  final List<PrefetchClip> prefetch;

  @override
  String get type => WsServerMessage.gameStarting;

  @override
  JsonMap toJson() => {
    'game_id': gameId,
    'rounds_total': roundsTotal,
    'countdown_ms': countdownMs,
    'prefetch': [for (final p in prefetch) p.toJson()],
  };
}

/// `round.prepare`: personalized per player.
final class RoundPrepare extends ServerMessage {
  const RoundPrepare({
    required this.roundId,
    required this.roundIndex,
    required this.kind,
    required this.nonce,
    required this.prompt,
    required this.options,
    required this.youAreOwner,
    required this.startAtServerMs,
    required this.startAtMonoUs,
    required this.answerWindowMs,
    required this.audioStartSource,
    required this.commitHash,
    this.clip,
  });

  factory RoundPrepare.fromJson(JsonMap json) {
    final clip = json.optObj('clip');
    return RoundPrepare(
      roundId: json.str('round_id'),
      roundIndex: json.integer('round_index'),
      kind: json.wire('kind', RoundKind.values),
      nonce: json.str('nonce'),
      prompt: json.wire('prompt', GameMode.values),
      options: json.list(
        'options',
        (item) => RoundOption.fromJson(asObject(item)),
      ),
      youAreOwner: json.boolean('you_are_owner'),
      startAtServerMs: json.integer('start_at_server_ms'),
      startAtMonoUs: json.integer('start_at_mono_us'),
      answerWindowMs: json.integer('answer_window_ms'),
      audioStartSource: json.wire(
        'audio_start_source',
        AudioStartSource.values,
      ),
      commitHash: json.str('commit_hash'),
      clip: clip == null ? null : RoundClip.fromJson(clip),
    );
  }

  final String roundId;
  final int roundIndex;
  final RoundKind kind;
  final String nonce;
  final GameMode prompt;

  /// Already shuffled for this player; shown in this order.
  final List<RoundOption> options;
  final bool youAreOwner;
  final int startAtServerMs;

  /// [startAtServerMs] converted by the server to this device's input clock.
  final int startAtMonoUs;
  final int answerWindowMs;
  final AudioStartSource audioStartSource;
  final String commitHash;

  /// Playback device only.
  final RoundClip? clip;

  @override
  String get type => WsServerMessage.roundPrepare;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'round_index': roundIndex,
    'kind': kind.wire,
    'nonce': nonce,
    'prompt': prompt.wire,
    'options': [for (final o in options) o.toJson()],
    'you_are_owner': youAreOwner,
    'start_at_server_ms': startAtServerMs,
    'start_at_mono_us': startAtMonoUs,
    'answer_window_ms': answerWindowMs,
    'audio_start_source': audioStartSource.wire,
    'commit_hash': commitHash,
    'clip': ?clip?.toJson(),
  };
}

final class RoundStart extends ServerMessage {
  const RoundStart({required this.roundId, required this.audioStartServerMs});

  factory RoundStart.fromJson(JsonMap json) => RoundStart(
    roundId: json.str('round_id'),
    audioStartServerMs: json.integer('audio_start_server_ms'),
  );

  final String roundId;
  final int audioStartServerMs;

  @override
  String get type => WsServerMessage.roundStart;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'audio_start_server_ms': audioStartServerMs,
  };
}

final class RoundAnswerAck extends ServerMessage {
  const RoundAnswerAck({
    required this.roundId,
    required this.accepted,
    this.reason,
  });

  factory RoundAnswerAck.fromJson(JsonMap json) => RoundAnswerAck(
    roundId: json.str('round_id'),
    accepted: json.boolean('accepted'),
    reason: json.optWire('reason', AnswerValidation.values),
  );

  final String roundId;
  final bool accepted;
  final AnswerValidation? reason;

  @override
  String get type => WsServerMessage.roundAnswerAck;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'accepted': accepted,
    'reason': ?reason?.wire,
  };
}

final class RoundProgress extends ServerMessage {
  const RoundProgress({
    required this.roundId,
    required this.answeredCount,
    required this.eligibleCount,
  });

  factory RoundProgress.fromJson(JsonMap json) => RoundProgress(
    roundId: json.str('round_id'),
    answeredCount: json.integer('answered_count'),
    eligibleCount: json.integer('eligible_count'),
  );

  final String roundId;
  final int answeredCount;
  final int eligibleCount;

  @override
  String get type => WsServerMessage.roundProgress;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'answered_count': answeredCount,
    'eligible_count': eligibleCount,
  };
}

final class RoundVoided extends ServerMessage {
  const RoundVoided({required this.roundId, required this.reason});

  factory RoundVoided.fromJson(JsonMap json) => RoundVoided(
    roundId: json.str('round_id'),
    reason: json.wire(
      'reason',
      RoundVoidReason.values,
      fallback: RoundVoidReason.unknown,
    ),
  );

  final String roundId;
  final RoundVoidReason reason;

  @override
  String get type => WsServerMessage.roundVoided;

  @override
  JsonMap toJson() => {'round_id': roundId, 'reason': reason.wire};
}

final class RoundReveal extends ServerMessage {
  const RoundReveal({
    required this.roundId,
    required this.correctOptionIds,
    required this.commitSalt,
    required this.track,
    required this.ownerPlayerIds,
    required this.results,
    required this.standings,
  });

  factory RoundReveal.fromJson(JsonMap json) => RoundReveal(
    roundId: json.str('round_id'),
    correctOptionIds: json.list('correct_option_ids', asString),
    commitSalt: json.str('commit_salt'),
    track: RevealTrack.fromJson(json.obj('track')),
    ownerPlayerIds: json.list('owner_player_ids', asString),
    results: json.list(
      'results',
      (item) => RoundResult.fromJson(asObject(item)),
    ),
    standings: json.list(
      'standings',
      (item) => Standing.fromJson(asObject(item)),
    ),
  );

  final String roundId;
  final List<String> correctOptionIds;
  final String commitSalt;
  final RevealTrack track;

  /// Empty in `guess_track`.
  final List<String> ownerPlayerIds;
  final List<RoundResult> results;
  final List<Standing> standings;

  @override
  String get type => WsServerMessage.roundReveal;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'correct_option_ids': correctOptionIds,
    'commit_salt': commitSalt,
    'track': track.toJson(),
    'owner_player_ids': ownerPlayerIds,
    'results': [for (final r in results) r.toJson()],
    'standings': [for (final s in standings) s.toJson()],
  };
}

final class GameBonusOffer extends ServerMessage {
  const GameBonusOffer({
    required this.bonusId,
    required this.expiresAtServerMs,
    required this.eligiblePlayerIds,
  });

  factory GameBonusOffer.fromJson(JsonMap json) => GameBonusOffer(
    bonusId: json.str('bonus_id'),
    expiresAtServerMs: json.integer('expires_at_server_ms'),
    eligiblePlayerIds: json.list('eligible_player_ids', asString),
  );

  final String bonusId;
  final int expiresAtServerMs;
  final List<String> eligiblePlayerIds;

  @override
  String get type => WsServerMessage.gameBonusOffer;

  @override
  JsonMap toJson() => {
    'bonus_id': bonusId,
    'expires_at_server_ms': expiresAtServerMs,
    'eligible_player_ids': eligiblePlayerIds,
  };
}

final class BonusSponsorLocked extends ServerMessage {
  const BonusSponsorLocked({
    required this.bonusId,
    required this.sponsorPlayerId,
    required this.expiresAtServerMs,
  });

  factory BonusSponsorLocked.fromJson(JsonMap json) => BonusSponsorLocked(
    bonusId: json.str('bonus_id'),
    sponsorPlayerId: json.str('sponsor_player_id'),
    expiresAtServerMs: json.integer('expires_at_server_ms'),
  );

  final String bonusId;
  final String sponsorPlayerId;
  final int expiresAtServerMs;

  @override
  String get type => WsServerMessage.bonusSponsorLocked;

  @override
  JsonMap toJson() => {
    'bonus_id': bonusId,
    'sponsor_player_id': sponsorPlayerId,
    'expires_at_server_ms': expiresAtServerMs,
  };
}

/// Sent to the sponsor only.
final class BonusNonce extends ServerMessage {
  const BonusNonce({
    required this.bonusId,
    required this.rewardNonce,
    required this.ssvUserId,
  });

  factory BonusNonce.fromJson(JsonMap json) => BonusNonce(
    bonusId: json.str('bonus_id'),
    rewardNonce: json.str('reward_nonce'),
    ssvUserId: json.str('ssv_user_id'),
  );

  final String bonusId;
  final String rewardNonce;

  /// Opaque HMAC of the user id for SSV `userId`; never the raw id.
  final String ssvUserId;

  @override
  String get type => WsServerMessage.bonusNonce;

  @override
  JsonMap toJson() => {
    'bonus_id': bonusId,
    'reward_nonce': rewardNonce,
    'ssv_user_id': ssvUserId,
  };
}

final class BonusGranted extends ServerMessage {
  const BonusGranted({
    required this.bonusId,
    required this.sponsorPlayerId,
    required this.roundsAdded,
  });

  factory BonusGranted.fromJson(JsonMap json) => BonusGranted(
    bonusId: json.str('bonus_id'),
    sponsorPlayerId: json.str('sponsor_player_id'),
    roundsAdded: json.integer('rounds_added'),
  );

  final String bonusId;
  final String sponsorPlayerId;
  final int roundsAdded;

  @override
  String get type => WsServerMessage.bonusGranted;

  @override
  JsonMap toJson() => {
    'bonus_id': bonusId,
    'sponsor_player_id': sponsorPlayerId,
    'rounds_added': roundsAdded,
  };
}

final class BonusCancelled extends ServerMessage {
  const BonusCancelled({required this.bonusId, required this.reason});

  factory BonusCancelled.fromJson(JsonMap json) => BonusCancelled(
    bonusId: json.str('bonus_id'),
    reason: json.wire(
      'reason',
      BonusCancelReason.values,
      fallback: BonusCancelReason.unknown,
    ),
  );

  final String bonusId;
  final BonusCancelReason reason;

  @override
  String get type => WsServerMessage.bonusCancelled;

  @override
  JsonMap toJson() => {'bonus_id': bonusId, 'reason': reason.wire};
}

/// Per player: whether to try an interstitial and show the upsell card.
final class GameAdBreak extends ServerMessage {
  const GameAdBreak({
    required this.gameId,
    required this.resultsRevealAtServerMs,
    required this.showInterstitial,
    required this.showRemoveAdsUpsell,
  });

  factory GameAdBreak.fromJson(JsonMap json) => GameAdBreak(
    gameId: json.str('game_id'),
    resultsRevealAtServerMs: json.integer('results_reveal_at_server_ms'),
    showInterstitial: json.boolean('show_interstitial'),
    showRemoveAdsUpsell: json.boolean('show_remove_ads_upsell'),
  );

  final String gameId;
  final int resultsRevealAtServerMs;
  final bool showInterstitial;
  final bool showRemoveAdsUpsell;

  @override
  String get type => WsServerMessage.gameAdBreak;

  @override
  JsonMap toJson() => {
    'game_id': gameId,
    'results_reveal_at_server_ms': resultsRevealAtServerMs,
    'show_interstitial': showInterstitial,
    'show_remove_ads_upsell': showRemoveAdsUpsell,
  };
}

final class GameResults extends ServerMessage {
  const GameResults({
    required this.gameId,
    required this.standings,
    required this.roundsPlayed,
    required this.bonusUsed,
  });

  factory GameResults.fromJson(JsonMap json) => GameResults(
    gameId: json.str('game_id'),
    standings: json.list(
      'standings',
      (item) => Standing.fromJson(asObject(item)),
    ),
    roundsPlayed: json.integer('rounds_played'),
    bonusUsed: json.boolean('bonus_used'),
  );

  final String gameId;
  final List<Standing> standings;
  final int roundsPlayed;
  final bool bonusUsed;

  @override
  String get type => WsServerMessage.gameResults;

  @override
  JsonMap toJson() => {
    'game_id': gameId,
    'standings': [for (final s in standings) s.toJson()],
    'rounds_played': roundsPlayed,
    'bonus_used': bonusUsed,
  };
}

final class PlayerEntitlementsUpdated extends ServerMessage {
  const PlayerEntitlementsUpdated({
    required this.playerId,
    required this.noAds,
    required this.premium,
  });

  factory PlayerEntitlementsUpdated.fromJson(JsonMap json) =>
      PlayerEntitlementsUpdated(
        playerId: json.str('player_id'),
        noAds: json.boolean('no_ads'),
        premium: json.boolean('premium'),
      );

  final String playerId;
  final bool noAds;
  final bool premium;

  @override
  String get type => WsServerMessage.playerEntitlementsUpdated;

  @override
  JsonMap toJson() => {
    'player_id': playerId,
    'no_ads': noAds,
    'premium': premium,
  };
}

final class ServerDraining extends ServerMessage {
  const ServerDraining({required this.reconnectAfterMs});

  factory ServerDraining.fromJson(JsonMap json) =>
      ServerDraining(reconnectAfterMs: json.integer('reconnect_after_ms'));

  final int reconnectAfterMs;

  @override
  String get type => WsServerMessage.serverDraining;

  @override
  JsonMap toJson() => {'reconnect_after_ms': reconnectAfterMs};
}

/// `error` (named ServerError to avoid clashing with dart:core Error).
final class ServerError extends ServerMessage {
  const ServerError({required this.code, required this.message, this.refType});

  factory ServerError.fromJson(JsonMap json) => ServerError(
    code: json.str('code'),
    message: json.str('message'),
    refType: json.optStr('ref_type'),
  );

  /// See [ErrorCodes].
  final String code;

  /// Not localized; the UI maps [code] to text.
  final String message;
  final String? refType;

  @override
  String get type => WsServerMessage.error;

  @override
  JsonMap toJson() => {'code': code, 'message': message, 'ref_type': ?refType};
}

// ===========================================================================
// Client -> server
// ===========================================================================

sealed class ClientMessage {
  const ClientMessage();

  String get type;

  JsonMap toJson();

  WsEnvelope toEnvelope(int seq) =>
      WsEnvelope(type: type, seq: seq, payload: toJson());

  /// Used by tests and tools that play the server's side.
  static ClientMessage fromJson(String type, JsonMap payload) => switch (type) {
    WsClientMessage.hello => Hello.fromJson(payload),
    WsClientMessage.clockPong => ClockPong.fromJson(payload),
    WsClientMessage.appState => AppStateMessage.fromJson(payload),
    WsClientMessage.lobbyReady => LobbyReady.fromJson(payload),
    WsClientMessage.lobbyUpdateSettings => LobbyUpdateSettings.fromJson(
      payload,
    ),
    WsClientMessage.lobbyKick => LobbyKick.fromJson(payload),
    WsClientMessage.gameStart => const GameStart(),
    WsClientMessage.roundPreloaded => RoundPreloaded.fromJson(payload),
    WsClientMessage.roundPlaybackStarted => RoundPlaybackStarted.fromJson(
      payload,
    ),
    WsClientMessage.roundPlaybackFailed => RoundPlaybackFailed.fromJson(
      payload,
    ),
    WsClientMessage.roundAnswer => RoundAnswer.fromJson(payload),
    WsClientMessage.bonusRequest => BonusRequest.fromJson(payload),
    WsClientMessage.bonusAdResult => BonusAdResult.fromJson(payload),
    WsClientMessage.adInterstitialResult => AdInterstitialResult.fromJson(
      payload,
    ),
    WsClientMessage.gamePlayAgain => const GamePlayAgain(),
    WsClientMessage.roomLeave => const RoomLeave(),
    _ => throw ProtocolFormatException('unknown client message "$type"'),
  };

  static ClientMessage fromEnvelope(WsEnvelope envelope) =>
      fromJson(envelope.type, envelope.payload);
}

final class Hello extends ClientMessage {
  const Hello({
    required this.ticket,
    required this.appVersion,
    required this.platform,
    this.lastSeq,
  });

  factory Hello.fromJson(JsonMap json) => Hello(
    ticket: json.str('ticket'),
    appVersion: json.str('app_version'),
    platform: json.wire('platform', AppPlatform.values),
    lastSeq: json.optInt('last_seq'),
  );

  /// Single-use ticket from `POST /v1/rooms/{room_id}/ws-ticket`; sent here,
  /// never in the URL (brief §7).
  final String ticket;
  final String appVersion;
  final AppPlatform platform;

  /// Last server seq received; asks the server to replay after it.
  final int? lastSeq;

  @override
  String get type => WsClientMessage.hello;

  @override
  JsonMap toJson() => {
    'ticket': ticket,
    'app_version': appVersion,
    'platform': platform.wire,
    'last_seq': ?lastSeq,
  };
}

final class ClockPong extends ClientMessage {
  const ClockPong({
    required this.pingId,
    required this.t1ServerUs,
    required this.t2MonoUs,
  });

  factory ClockPong.fromJson(JsonMap json) => ClockPong(
    pingId: json.str('ping_id'),
    t1ServerUs: json.integer('t1_server_us'),
    t2MonoUs: json.integer('t2_mono_us'),
  );

  final String pingId;

  /// Echoed from `clock.ping`.
  final int t1ServerUs;

  /// `InputClockApi.nowMicros()` when the ping arrived.
  final int t2MonoUs;

  @override
  String get type => WsClientMessage.clockPong;

  @override
  JsonMap toJson() => {
    'ping_id': pingId,
    't1_server_us': t1ServerUs,
    't2_mono_us': t2MonoUs,
  };
}

/// `app.state`.
final class AppStateMessage extends ClientMessage {
  const AppStateMessage(this.state);

  factory AppStateMessage.fromJson(JsonMap json) =>
      AppStateMessage(json.wire('state', AppStateSignal.values));

  final AppStateSignal state;

  @override
  String get type => WsClientMessage.appState;

  @override
  JsonMap toJson() => {'state': state.wire};
}

final class LobbyReady extends ClientMessage {
  const LobbyReady({required this.ready});

  factory LobbyReady.fromJson(JsonMap json) =>
      LobbyReady(ready: json.boolean('ready'));

  final bool ready;

  @override
  String get type => WsClientMessage.lobbyReady;

  @override
  JsonMap toJson() => {'ready': ready};
}

/// Host only; the server validates against tier and config.
final class LobbyUpdateSettings extends ClientMessage {
  const LobbyUpdateSettings({
    required this.mode,
    required this.roundsTotal,
    required this.explicitFilter,
    required this.poolSources,
    this.shuffleStrategy,
    this.packId,
  });

  factory LobbyUpdateSettings.fromJson(JsonMap json) => LobbyUpdateSettings(
    mode: json.wire('mode', GameMode.values),
    roundsTotal: json.integer('rounds_total'),
    shuffleStrategy: json.optWire('shuffle_strategy', ShuffleStrategy.values),
    explicitFilter: json.boolean('explicit_filter'),
    poolSources: json.list(
      'pool_sources',
      (item) => parseWire(PoolSource.values, item),
    ),
    packId: json.optStr('pack_id'),
  );

  final GameMode mode;
  final int roundsTotal;
  final ShuffleStrategy? shuffleStrategy;
  final bool explicitFilter;
  final List<PoolSource> poolSources;
  final String? packId;

  @override
  String get type => WsClientMessage.lobbyUpdateSettings;

  @override
  JsonMap toJson() => {
    'mode': mode.wire,
    'rounds_total': roundsTotal,
    'shuffle_strategy': ?shuffleStrategy?.wire,
    'explicit_filter': explicitFilter,
    'pool_sources': [for (final s in poolSources) s.wire],
    'pack_id': ?packId,
  };
}

final class LobbyKick extends ClientMessage {
  const LobbyKick({required this.playerId});

  factory LobbyKick.fromJson(JsonMap json) =>
      LobbyKick(playerId: json.str('player_id'));

  final String playerId;

  @override
  String get type => WsClientMessage.lobbyKick;

  @override
  JsonMap toJson() => {'player_id': playerId};
}

final class GameStart extends ClientMessage {
  const GameStart();

  @override
  String get type => WsClientMessage.gameStart;

  @override
  JsonMap toJson() => const {};
}

final class RoundPreloaded extends ClientMessage {
  const RoundPreloaded({
    required this.roundId,
    required this.ok,
    required this.preloadMs,
  });

  factory RoundPreloaded.fromJson(JsonMap json) => RoundPreloaded(
    roundId: json.str('round_id'),
    ok: json.boolean('ok'),
    preloadMs: json.integer('preload_ms'),
  );

  final String roundId;
  final bool ok;
  final int preloadMs;

  @override
  String get type => WsClientMessage.roundPreloaded;

  @override
  JsonMap toJson() => {'round_id': roundId, 'ok': ok, 'preload_ms': preloadMs};
}

final class RoundPlaybackStarted extends ClientMessage {
  const RoundPlaybackStarted({
    required this.roundId,
    required this.audioStartMonoUs,
    required this.outputLatencyMs,
    required this.outputRoute,
    required this.source,
  });

  factory RoundPlaybackStarted.fromJson(JsonMap json) => RoundPlaybackStarted(
    roundId: json.str('round_id'),
    audioStartMonoUs: json.integer('audio_start_mono_us'),
    outputLatencyMs: json.integer('output_latency_ms'),
    outputRoute: json.wire('output_route', OutputRoute.values),
    source: json.wire('source', PlaybackStartSource.values),
  );

  final String roundId;
  final int audioStartMonoUs;
  final int outputLatencyMs;
  final OutputRoute outputRoute;
  final PlaybackStartSource source;

  @override
  String get type => WsClientMessage.roundPlaybackStarted;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'audio_start_mono_us': audioStartMonoUs,
    'output_latency_ms': outputLatencyMs,
    'output_route': outputRoute.wire,
    'source': source.wire,
  };
}

final class RoundPlaybackFailed extends ClientMessage {
  const RoundPlaybackFailed({required this.roundId, required this.reason});

  factory RoundPlaybackFailed.fromJson(JsonMap json) => RoundPlaybackFailed(
    roundId: json.str('round_id'),
    reason: json.str('reason'),
  );

  final String roundId;

  /// snake_case failure code (e.g. `clip_load_failed`, `player_error`).
  final String reason;

  @override
  String get type => WsClientMessage.roundPlaybackFailed;

  @override
  JsonMap toJson() => {'round_id': roundId, 'reason': reason};
}

/// One per player per round; the first one wins.
final class RoundAnswer extends ClientMessage {
  const RoundAnswer({
    required this.roundId,
    required this.nonce,
    required this.optionId,
    required this.tapMonoUs,
    required this.unlockMonoUs,
  });

  factory RoundAnswer.fromJson(JsonMap json) => RoundAnswer(
    roundId: json.str('round_id'),
    nonce: json.str('nonce'),
    optionId: json.str('option_id'),
    tapMonoUs: json.integer('tap_mono_us'),
    unlockMonoUs: json.integer('unlock_mono_us'),
  );

  final String roundId;
  final String nonce;
  final String optionId;

  /// `PointerDownEvent.timeStamp` of the committing tap (OS touch time).
  final int tapMonoUs;

  /// Frame timestamp of the first frame that showed enabled buttons.
  final int unlockMonoUs;

  @override
  String get type => WsClientMessage.roundAnswer;

  @override
  JsonMap toJson() => {
    'round_id': roundId,
    'nonce': nonce,
    'option_id': optionId,
    'tap_mono_us': tapMonoUs,
    'unlock_mono_us': unlockMonoUs,
  };
}

final class BonusRequest extends ClientMessage {
  const BonusRequest({required this.bonusId, required this.appCheckToken});

  factory BonusRequest.fromJson(JsonMap json) => BonusRequest(
    bonusId: json.str('bonus_id'),
    appCheckToken: json.str('app_check_token'),
  );

  final String bonusId;

  /// Limited-use App Check token (brief §7 "Attestation").
  final String appCheckToken;

  @override
  String get type => WsClientMessage.bonusRequest;

  @override
  JsonMap toJson() => {'bonus_id': bonusId, 'app_check_token': appCheckToken};
}

/// Informational only; the round is granted only through SSV.
final class BonusAdResult extends ClientMessage {
  const BonusAdResult({required this.bonusId, required this.status});

  factory BonusAdResult.fromJson(JsonMap json) => BonusAdResult(
    bonusId: json.str('bonus_id'),
    status: json.wire('status', BonusAdStatus.values),
  );

  final String bonusId;
  final BonusAdStatus status;

  @override
  String get type => WsClientMessage.bonusAdResult;

  @override
  JsonMap toJson() => {'bonus_id': bonusId, 'status': status.wire};
}

final class AdInterstitialResult extends ClientMessage {
  const AdInterstitialResult({
    required this.gameId,
    required this.result,
    required this.waitMs,
  });

  factory AdInterstitialResult.fromJson(JsonMap json) => AdInterstitialResult(
    gameId: json.str('game_id'),
    result: json.wire('result', InterstitialWireResult.values),
    waitMs: json.integer('wait_ms'),
  );

  final String gameId;
  final InterstitialWireResult result;
  final int waitMs;

  @override
  String get type => WsClientMessage.adInterstitialResult;

  @override
  JsonMap toJson() => {
    'game_id': gameId,
    'result': result.wire,
    'wait_ms': waitMs,
  };
}

/// Host only; available in `results`.
final class GamePlayAgain extends ClientMessage {
  const GamePlayAgain();

  @override
  String get type => WsClientMessage.gamePlayAgain;

  @override
  JsonMap toJson() => const {};
}

final class RoomLeave extends ClientMessage {
  const RoomLeave();

  @override
  String get type => WsClientMessage.roomLeave;

  @override
  JsonMap toJson() => const {};
}
