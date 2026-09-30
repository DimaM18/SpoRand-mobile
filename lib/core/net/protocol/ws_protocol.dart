/// Hand-written mirror of the WebSocket protocol (brief §4.3).
///
/// Temporary: replaced by the Dart models generated from packages/protocol
/// into lib/contracts/ (quicktype). Names are canonical; do not rename.
library;

/// `{"v":1,"type":"<type>","seq":<int>,"payload":{...}}`
final class WsEnvelope {
  const WsEnvelope({
    required this.type,
    required this.seq,
    this.payload = const {},
    this.v = protocolVersion,
  });

  static const protocolVersion = 1;

  final int v;
  final String type;
  final int seq;
  final Map<String, Object?> payload;

  Map<String, Object?> toJson() => {
    'v': v,
    'type': type,
    'seq': seq,
    'payload': payload,
  };

  /// Null for anything that is not a v1 envelope.
  static WsEnvelope? tryParse(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final v = json['v'];
    final type = json['type'];
    final seq = json['seq'];
    final payload = json['payload'];
    // Only protocol v1 exists; a frame of another version cannot be read.
    if (v != protocolVersion || type is! String || seq is! int) return null;
    return WsEnvelope(
      v: protocolVersion,
      type: type,
      seq: seq,
      payload: payload is Map<String, Object?> ? payload : const {},
    );
  }
}

/// Client -> server message types.
abstract final class WsClientMessage {
  static const hello = 'hello';
  static const clockPong = 'clock.pong';
  static const appState = 'app.state';
  static const lobbyReady = 'lobby.ready';
  static const lobbyUpdateSettings = 'lobby.update_settings';
  static const lobbyKick = 'lobby.kick';

  /// [новое имя — согласовать]
  static const lobbySetCanDj = 'lobby.set_can_dj';
  static const gameStart = 'game.start';
  static const roundPreloaded = 'round.preloaded';
  static const roundPlaybackStarted = 'round.playback_started';
  static const roundPlaybackFailed = 'round.playback_failed';
  static const roundAnswer = 'round.answer';
  static const bonusRequest = 'bonus.request';
  static const bonusAdResult = 'bonus.ad_result';
  static const adInterstitialResult = 'ad.interstitial_result';
  static const gamePlayAgain = 'game.play_again';
  static const roomLeave = 'room.leave';
}

/// Server -> client message types.
abstract final class WsServerMessage {
  static const welcome = 'welcome';
  static const clockPing = 'clock.ping';
  static const clockResult = 'clock.result';
  static const roomState = 'room.state';
  static const roomPlayerJoined = 'room.player_joined';
  static const roomPlayerLeft = 'room.player_left';
  static const roomPlayerUpdated = 'room.player_updated';
  static const roomClosed = 'room.closed';
  static const gameStarting = 'game.starting';
  static const roundPrepare = 'round.prepare';
  static const roundStart = 'round.start';
  static const roundAnswerAck = 'round.answer_ack';
  static const roundProgress = 'round.progress';
  static const roundVoided = 'round.voided';
  static const roundReveal = 'round.reveal';
  static const gameBonusOffer = 'game.bonus_offer';
  static const bonusSponsorLocked = 'bonus.sponsor_locked';
  static const bonusNonce = 'bonus.nonce';
  static const bonusGranted = 'bonus.granted';
  static const bonusCancelled = 'bonus.cancelled';
  static const gameAdBreak = 'game.ad_break';
  static const gameResults = 'game.results';
  static const playerEntitlementsUpdated = 'player.entitlements_updated';
  static const serverDraining = 'server.draining';
  static const error = 'error';
}

/// WebSocket close codes.
abstract final class WsCloseCode {
  static const unauthorized = 4401;
  static const forbidden = 4403;
  static const helloTimeout = 4408;
  static const replaced = 4409;
  static const versionUnsupported = 4426;
  static const rateLimited = 4429;
  static const internalError = 4500;
  static const serverDraining = 4503;
}

/// Protocol limits.
abstract final class WsLimits {
  static const maxFrameBytes = 8 * 1024;
  static const maxMessagesPerSecond = 20;
  static const helloTimeout = Duration(seconds: 5);
}
