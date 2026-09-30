/// Shared protocol DTOs (wire projections of the brief §4.1 entities), as
/// used inside WebSocket payloads (§4.3). Hand-written mirror of
/// packages/protocol, replaced later by the generated lib/contracts/ code.
///
/// Parsing is lenient where the brief and packages/protocol differ (fields
/// the brief does not list get defaults); serialization always writes every
/// field so fixtures round-trip.
library;

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/platform/app_platform.dart';

final class EntitlementsSnapshot {
  const EntitlementsSnapshot({this.noAds = false, this.premium = false});

  factory EntitlementsSnapshot.fromJson(JsonMap json) => EntitlementsSnapshot(
    noAds: json.boolean('no_ads'),
    premium: json.boolean('premium'),
  );

  static const none = EntitlementsSnapshot();

  final bool noAds;
  final bool premium;

  JsonMap toJson() => {'no_ads': noAds, 'premium': premium};
}

final class RoomSettings {
  const RoomSettings({
    required this.mode,
    required this.roundsTotal,
    required this.explicitFilter,
    required this.poolSources,
    this.maxPlayers,
    this.shuffleStrategy,
    this.packId,
  });

  factory RoomSettings.fromJson(JsonMap json) => RoomSettings(
    mode: json.wire('mode', GameMode.values),
    roundsTotal: json.integer('rounds_total'),
    maxPlayers: json.optInt('max_players'),
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
  final int? maxPlayers;
  final ShuffleStrategy? shuffleStrategy;
  final bool explicitFilter;
  final List<PoolSource> poolSources;
  final String? packId;

  JsonMap toJson() => {
    'mode': mode.wire,
    'rounds_total': roundsTotal,
    'max_players': ?maxPlayers,
    'shuffle_strategy': ?shuffleStrategy?.wire,
    'explicit_filter': explicitFilter,
    'pool_sources': [for (final s in poolSources) s.wire],
    'pack_id': ?packId,
  };
}

final class PlayerSnapshot {
  const PlayerSnapshot({
    required this.playerId,
    required this.displayName,
    required this.role,
    required this.isContributor,
    required this.isPlaybackDevice,
    required this.connection,
    required this.platform,
    this.ready = false,
    this.poolTrackCount = 0,
    this.entitlements = EntitlementsSnapshot.none,
  });

  factory PlayerSnapshot.fromJson(JsonMap json) {
    final entitlements = json.optObj('entitlements_snapshot');
    return PlayerSnapshot(
      playerId: json.str('player_id'),
      displayName: json.str('display_name'),
      role: json.wire('role', PlayerRole.values),
      isContributor: json.boolean('is_contributor'),
      isPlaybackDevice: json.boolean('is_playback_device'),
      connection: json.wire('connection', PlayerConnection.values),
      platform: json.wire('platform', AppPlatform.values),
      ready: json.optBool('ready') ?? false,
      poolTrackCount: json.optInt('pool_track_count') ?? 0,
      entitlements: entitlements == null
          ? EntitlementsSnapshot.none
          : EntitlementsSnapshot.fromJson(entitlements),
    );
  }

  final String playerId;
  final String displayName;
  final PlayerRole role;
  final bool isContributor;
  final bool isPlaybackDevice;
  final PlayerConnection connection;
  final AppPlatform platform;
  final bool ready;
  final int poolTrackCount;
  final EntitlementsSnapshot entitlements;

  bool get isHost => role == PlayerRole.host;

  PlayerSnapshot copyWith({EntitlementsSnapshot? entitlements}) =>
      PlayerSnapshot(
        playerId: playerId,
        displayName: displayName,
        role: role,
        isContributor: isContributor,
        isPlaybackDevice: isPlaybackDevice,
        connection: connection,
        platform: platform,
        ready: ready,
        poolTrackCount: poolTrackCount,
        entitlements: entitlements ?? this.entitlements,
      );

  JsonMap toJson() => {
    'player_id': playerId,
    'display_name': displayName,
    'role': role.wire,
    'is_contributor': isContributor,
    'is_playback_device': isPlaybackDevice,
    'connection': connection.wire,
    'platform': platform.wire,
    'ready': ready,
    'pool_track_count': poolTrackCount,
    'entitlements_snapshot': entitlements.toJson(),
  };
}

/// Full room snapshot: `room.state` payload and `welcome.room`.
final class RoomSnapshot {
  const RoomSnapshot({
    required this.state,
    required this.hostPlayerId,
    required this.players,
    required this.settings,
    required this.mode,
    required this.provider,
    required this.audioMode,
    this.roomId,
    this.roomCode,
    this.hostTier = HostTier.free,
    this.locked = false,
    this.currentGameId,
  });

  factory RoomSnapshot.fromJson(JsonMap json) => RoomSnapshot(
    roomId: json.optStr('room_id'),
    roomCode: json.optStr('room_code'),
    state: json.wire('state', RoomState.values),
    hostPlayerId: json.str('host_player_id'),
    players: json.list(
      'players',
      (item) => PlayerSnapshot.fromJson(asObject(item)),
    ),
    settings: RoomSettings.fromJson(json.obj('settings')),
    mode: json.wire('mode', GameMode.values),
    provider: json.wire('provider', MusicProviderId.values),
    audioMode: json.wire('audio_mode', AudioMode.values),
    hostTier: json.optWire('host_tier', HostTier.values) ?? HostTier.free,
    locked: json.optBool('locked') ?? false,
    currentGameId: json.optStr('current_game_id'),
  );

  final String? roomId;
  final String? roomCode;
  final RoomState state;
  final String hostPlayerId;
  final List<PlayerSnapshot> players;
  final RoomSettings settings;
  final GameMode mode;
  final MusicProviderId provider;
  final AudioMode audioMode;
  final HostTier hostTier;
  final bool locked;
  final String? currentGameId;

  PlayerSnapshot? player(String playerId) {
    for (final p in players) {
      if (p.playerId == playerId) return p;
    }
    return null;
  }

  RoomSnapshot copyWith({List<PlayerSnapshot>? players}) => RoomSnapshot(
    roomId: roomId,
    roomCode: roomCode,
    state: state,
    hostPlayerId: hostPlayerId,
    players: players ?? this.players,
    settings: settings,
    mode: mode,
    provider: provider,
    audioMode: audioMode,
    hostTier: hostTier,
    locked: locked,
    currentGameId: currentGameId,
  );

  JsonMap toJson() => {
    'room_id': ?roomId,
    'room_code': ?roomCode,
    'state': state.wire,
    'host_player_id': hostPlayerId,
    'players': [for (final p in players) p.toJson()],
    'settings': settings.toJson(),
    'mode': mode.wire,
    'provider': provider.wire,
    'audio_mode': audioMode.wire,
    'host_tier': hostTier.wire,
    'locked': locked,
    'current_game_id': ?currentGameId,
  };
}

final class Standing {
  const Standing({
    required this.playerId,
    required this.rank,
    required this.points,
    required this.correctCount,
    required this.correctReactionMsSum,
  });

  factory Standing.fromJson(JsonMap json) => Standing(
    playerId: json.str('player_id'),
    rank: json.integer('rank'),
    points: json.integer('points'),
    correctCount: json.integer('correct_count'),
    correctReactionMsSum: json.integer('correct_reaction_ms_sum'),
  );

  final String playerId;
  final int rank;
  final int points;
  final int correctCount;
  final int correctReactionMsSum;

  JsonMap toJson() => {
    'player_id': playerId,
    'rank': rank,
    'points': points,
    'correct_count': correctCount,
    'correct_reaction_ms_sum': correctReactionMsSum,
  };
}

final class RoundOption {
  const RoundOption({required this.optionId, required this.label, this.avatar});

  factory RoundOption.fromJson(JsonMap json) => RoundOption(
    optionId: json.str('option_id'),
    label: json.str('label'),
    avatar: json.optStr('avatar'),
  );

  final String optionId;

  /// `whose_song`: the player's display name; `guess_track`: «Title — Artist».
  final String label;
  final String? avatar;

  JsonMap toJson() => {
    'option_id': optionId,
    'label': label,
    'avatar': ?avatar,
  };
}

/// `round.prepare.clip`: sent to the playback device only.
sealed class RoundClip {
  const RoundClip({
    required this.snippetStartMs,
    required this.snippetDurationMs,
  });

  factory RoundClip.fromJson(JsonMap json) {
    if (json.containsKey('spotify_uri')) {
      return SpotifyRoundClip(
        spotifyUri: json.str('spotify_uri'),
        snippetStartMs: json.integer('snippet_start_ms'),
        snippetDurationMs: json.integer('snippet_duration_ms'),
      );
    }
    return UrlRoundClip(
      clipUrl: json.str('clip_url'),
      clipRef: json.optStr('clip_ref'),
      snippetStartMs: json.integer('snippet_start_ms'),
      snippetDurationMs: json.integer('snippet_duration_ms'),
    );
  }

  final int snippetStartMs;
  final int snippetDurationMs;

  JsonMap toJson();
}

/// `test_catalog` / `licensed_clips`: a signed clip URL.
final class UrlRoundClip extends RoundClip {
  const UrlRoundClip({
    required this.clipUrl,
    required super.snippetStartMs,
    required super.snippetDurationMs,
    this.clipRef,
  });

  final String clipUrl;
  final String? clipRef;

  @override
  JsonMap toJson() => {
    'clip_url': clipUrl,
    'clip_ref': ?clipRef,
    'snippet_start_ms': snippetStartMs,
    'snippet_duration_ms': snippetDurationMs,
  };
}

/// `spotify_app_remote` (spotifyProto only).
final class SpotifyRoundClip extends RoundClip {
  const SpotifyRoundClip({
    required this.spotifyUri,
    required super.snippetStartMs,
    required super.snippetDurationMs,
  });

  final String spotifyUri;

  @override
  JsonMap toJson() => {
    'spotify_uri': spotifyUri,
    'snippet_start_ms': snippetStartMs,
    'snippet_duration_ms': snippetDurationMs,
  };
}

/// `game.starting.prefetch[]`.
final class PrefetchClip {
  const PrefetchClip({
    required this.clipRef,
    required this.clipUrl,
    required this.expiresAtServerMs,
    this.roundId,
  });

  factory PrefetchClip.fromJson(JsonMap json) => PrefetchClip(
    clipRef: json.str('clip_ref'),
    clipUrl: json.str('clip_url'),
    expiresAtServerMs: json.integer('expires_at_server_ms'),
    roundId: json.optStr('round_id'),
  );

  final String clipRef;
  final String clipUrl;
  final int expiresAtServerMs;
  final String? roundId;

  JsonMap toJson() => {
    'clip_ref': clipRef,
    'clip_url': clipUrl,
    'expires_at_server_ms': expiresAtServerMs,
    'round_id': ?roundId,
  };
}

final class TrackAttribution {
  const TrackAttribution({required this.provider, this.text, this.url});

  factory TrackAttribution.fromJson(JsonMap json) => TrackAttribution(
    provider: json.wire('provider', MusicProviderId.values),
    text: json.optStr('text'),
    url: json.optStr('url'),
  );

  final MusicProviderId provider;

  /// The attribution line the provider's licence requires.
  final String? text;

  /// e.g. «Открыть в Spotify» in spotifyProto.
  final String? url;

  JsonMap toJson() => {'provider': provider.wire, 'text': ?text, 'url': ?url};
}

/// `round.reveal.track`.
final class RevealTrack {
  const RevealTrack({
    required this.title,
    required this.artists,
    required this.attribution,
    this.artworkUrl,
  });

  factory RevealTrack.fromJson(JsonMap json) => RevealTrack(
    title: json.str('title'),
    artists: json.list('artists', asString),
    attribution: TrackAttribution.fromJson(json.obj('attribution')),
    artworkUrl: json.optStr('artwork_url'),
  );

  final String title;
  final List<String> artists;
  final TrackAttribution attribution;
  final String? artworkUrl;

  JsonMap toJson() => {
    'title': title,
    'artists': artists,
    'attribution': attribution.toJson(),
    'artwork_url': ?artworkUrl,
  };
}

/// `round.reveal.results[]`.
final class RoundResult {
  const RoundResult({
    required this.playerId,
    required this.correct,
    required this.points,
    required this.streak,
    this.optionId,
    this.reactionMs,
    this.validation,
  });

  factory RoundResult.fromJson(JsonMap json) => RoundResult(
    playerId: json.str('player_id'),
    optionId: json.optStr('option_id'),
    correct: json.boolean('correct'),
    reactionMs: json.optInt('reaction_ms'),
    points: json.integer('points'),
    streak: json.integer('streak'),
    validation: json.optWire('validation', AnswerValidation.values),
  );

  final String playerId;

  /// Absent when the player did not answer.
  final String? optionId;
  final bool correct;
  final int? reactionMs;
  final int points;
  final int streak;
  final AnswerValidation? validation;

  JsonMap toJson() => {
    'player_id': playerId,
    'option_id': ?optionId,
    'correct': correct,
    'reaction_ms': ?reactionMs,
    'points': points,
    'streak': streak,
    'validation': ?validation?.wire,
  };
}

/// `welcome.config`: the room's frozen server-template values (brief §4.6,
/// reader S/B). Kept as the raw map (round-trips unchanged); typed getters
/// fall back to the brief's defaults for anything missing.
final class RoomConfig {
  const RoomConfig(this.values);

  static const defaults = RoomConfig({});

  final JsonMap values;

  int _int(String key, int fallback) {
    final value = values[key];
    return value is num ? value.toInt() : fallback;
  }

  bool _bool(String key, bool fallback) {
    final value = values[key];
    return value is bool ? value : fallback;
  }

  List<int> _ints(String key, List<int> fallback) {
    final value = values[key];
    if (value is! List<Object?>) return fallback;
    final result = [
      for (final item in value)
        if (item is num) item.toInt(),
    ];
    return result.isEmpty ? fallback : result;
  }

  List<int> get roundsFreeOptions => _ints('rounds_free_options', [5, 10]);
  int get roundsFreeDefault => _int('rounds_free_default', 10);
  List<int> get roundsPremiumOptions =>
      _ints('rounds_premium_options', [5, 10, 15, 25, 50]);
  int get roundsPremiumDefault => _int('rounds_premium_default', 15);
  int get roomMaxPlayersFree => _int('room_max_players_free', 8);
  int get roomMaxPlayersPremium => _int('room_max_players_premium', 12);
  int get whoseSongMinContributors => _int('whose_song_min_contributors', 3);
  int get answerWindowMs => _int('answer_window_ms', 15000);
  int get revealDurationMs => _int('reveal_duration_ms', 5000);
  int get startingCountdownMs => _int('starting_countdown_ms', 3000);
  int get playbackStartTimeoutMs => _int('playback_start_timeout_ms', 5000);
  bool get monetizationEnabled => _bool('monetization_enabled', true);
  bool get rewardedEnabled => _bool('rewarded_enabled', true);
  bool get interstitialEnabled => _bool('interstitial_enabled', true);
  bool get removeAdsUpsellEnabled => _bool('remove_ads_upsell_enabled', true);

  JsonMap toJson() => values;
}
