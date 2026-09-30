/// Canonical protocol enums (brief §4.1, §4.3, §4.9). Wire values are
/// binding; Dart names are camelCase.
library;

import 'package:sporand/core/net/protocol/json_read.dart';

/// Music provider ids (brief §1.3).
enum MusicProviderId implements WireEnum {
  testCatalog('test_catalog'),
  spotifyAppRemote('spotify_app_remote'),
  licensedClips('licensed_clips');

  const MusicProviderId(this.wire);

  @override
  final String wire;

  /// Kept for code written against the part 1 name.
  String get wireName => wire;

  /// Every monetization path is off for Spotify (brief §6 "Principles").
  bool get allowsMonetization => this != spotifyAppRemote;
}

enum GameMode implements WireEnum {
  whoseSong('whose_song'),
  guessTrack('guess_track');

  const GameMode(this.wire);

  @override
  final String wire;
}

/// `Room.state` (brief §4.4).
enum RoomState implements WireEnum {
  lobby('lobby'),
  starting('starting'),
  roundPrepare('round_prepare'),
  roundPlaying('round_playing'),
  roundReveal('round_reveal'),
  bonusOffer('bonus_offer'),
  adBreak('ad_break'),
  results('results'),
  paused('paused'),
  closed('closed');

  const RoomState(this.wire);

  @override
  final String wire;

  /// A game is running (the lobby is locked).
  bool get inGame => switch (this) {
    lobby || results || closed => false,
    _ => true,
  };
}

enum RoundKind implements WireEnum {
  regular('regular'),
  bonus('bonus'),
  spare('spare');

  const RoundKind(this.wire);

  @override
  final String wire;
}

/// How the server learns when the audio started (brief §5).
enum AudioStartSource implements WireEnum {
  scheduled('scheduled'),
  hostReported('host_reported');

  const AudioStartSource(this.wire);

  @override
  final String wire;
}

/// `round.playback_started.source`.
enum PlaybackStartSource implements WireEnum {
  scheduled('scheduled'),
  playerState('player_state');

  const PlaybackStartSource(this.wire);

  @override
  final String wire;
}

enum OutputRoute implements WireEnum {
  speaker('speaker'),
  wired('wired'),
  bluetooth('bluetooth'),
  airplay('airplay'),
  other('other');

  const OutputRoute(this.wire);

  @override
  final String wire;
}

/// `app.state.state`.
enum AppStateSignal implements WireEnum {
  foreground('foreground'),
  background('background'),
  networkChanged('network_changed');

  const AppStateSignal(this.wire);

  @override
  final String wire;
}

enum ClockQuality implements WireEnum {
  good('good'),
  fair('fair'),
  poor('poor');

  const ClockQuality(this.wire);

  @override
  final String wire;
}

enum PlayerRole implements WireEnum {
  host('host'),
  guest('guest');

  const PlayerRole(this.wire);

  @override
  final String wire;
}

enum PlayerConnection implements WireEnum {
  connected('connected'),
  reconnecting('reconnecting'),
  left('left'),
  kicked('kicked');

  const PlayerConnection(this.wire);

  @override
  final String wire;
}

enum AudioMode implements WireEnum {
  hostDevice('host_device'),
  eachDevice('each_device'),
  none('none');

  const AudioMode(this.wire);

  @override
  final String wire;
}

enum HostTier implements WireEnum {
  free('free'),
  premium('premium');

  const HostTier(this.wire);

  @override
  final String wire;
}

/// Brief §4.8.
enum ShuffleStrategy implements WireEnum {
  uniform('uniform'),
  roundRobinByOwner('round_robin_by_owner'),
  spreadConstrained('spread_constrained'),
  weightedRarity('weighted_rarity'),
  difficultyCurve('difficulty_curve');

  const ShuffleStrategy(this.wire);

  @override
  final String wire;
}

enum PoolSource implements WireEnum {
  spotifyTopShort('spotify_top_short'),
  spotifyTopMedium('spotify_top_medium'),
  spotifyTopLong('spotify_top_long'),
  spotifySaved('spotify_saved'),
  spotifyRecent('spotify_recent'),
  spotifyPlaylist('spotify_playlist'),
  catalogPicks('catalog_picks'),
  catalogPack('catalog_pack');

  const PoolSource(this.wire);

  @override
  final String wire;
}

/// Answer `validation` (brief §4.9); `round.answer_ack.reason` uses the
/// rejecting subset.
enum AnswerValidation implements WireEnum {
  ok('ok'),
  clampedLow('clamped_low'),
  clampedHigh('clamped_high'),
  floored('floored'),
  fallbackServerTime('fallback_server_time'),
  tooEarly('too_early'),
  late('late'),
  duplicate('duplicate'),
  badNonce('bad_nonce'),
  ownerIneligible('owner_ineligible'),
  badOption('bad_option');

  const AnswerValidation(this.wire);

  @override
  final String wire;
}

enum RoomClosedReason implements WireEnum {
  hostLeft('host_left'),
  expired('expired'),
  empty('empty'),
  serverShutdown('server_shutdown'),

  /// A value added by a newer server.
  unknown('unknown');

  const RoomClosedReason(this.wire);

  @override
  final String wire;
}

/// `room.player_left.reason`. Values come from packages/protocol
/// [новое имя — согласовать]; the brief names only the field.
enum PlayerLeftReason implements WireEnum {
  left('left'),
  kicked('kicked'),
  reconnectTimeout('reconnect_timeout'),
  unknown('unknown');

  const PlayerLeftReason(this.wire);

  @override
  final String wire;
}

enum RoundVoidReason implements WireEnum {
  playbackTimeout('playback_timeout'),
  playbackFailed('playback_failed'),
  hostDisconnected('host_disconnected'),
  serverRestart('server_restart'),
  unknown('unknown');

  const RoundVoidReason(this.wire);

  @override
  final String wire;
}

enum BonusCancelReason implements WireEnum {
  offerTimeout('offer_timeout'),
  adNotCompleted('ad_not_completed'),
  ssvTimeout('ssv_timeout'),
  sponsorLeft('sponsor_left'),
  unknown('unknown');

  const BonusCancelReason(this.wire);

  @override
  final String wire;
}

/// `bonus.ad_result.status`.
enum BonusAdStatus implements WireEnum {
  earned('earned'),
  dismissed('dismissed'),
  failedToLoad('failed_to_load'),
  failedToShow('failed_to_show');

  const BonusAdStatus(this.wire);

  @override
  final String wire;
}

/// `ad.interstitial_result.result` (the analytics event additionally has
/// `skipped_not_eligible`, which is never sent to the server).
enum InterstitialWireResult implements WireEnum {
  shown('shown'),
  skippedNotLoaded('skipped_not_loaded'),
  failedToShow('failed_to_show');

  const InterstitialWireResult(this.wire);

  @override
  final String wire;
}

/// `error.code` values (brief §4.3) plus the REST-only problem codes from
/// packages/protocol. Kept as strings: the set is open-ended.
abstract final class ErrorCodes {
  static const unauthorized = 'unauthorized';
  static const ticketInvalid = 'ticket_invalid';
  static const notHost = 'not_host';
  static const versionUnsupported = 'version_unsupported';
  static const roomNotFound = 'room_not_found';
  static const roomFull = 'room_full';
  static const roomLocked = 'room_locked';
  static const invalidState = 'invalid_state';
  static const poolInsufficient = 'pool_insufficient';
  static const playbackUnavailable = 'playback_unavailable';
  static const tierRequired = 'tier_required';
  static const rateLimited = 'rate_limited';
  static const validationFailed = 'validation_failed';
  static const bonusUnavailable = 'bonus_unavailable';
  static const internal = 'internal';
}
