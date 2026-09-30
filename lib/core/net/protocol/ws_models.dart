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
    this.emojiMarkets,
    this.emojiMaxDifficulty,
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
    emojiMarkets: json.optList(
      'emoji_markets',
      (item) => parseWire(EmojiMarket.values, item),
    ),
    emojiMaxDifficulty: json.optInt('emoji_max_difficulty'),
  );

  final GameMode mode;
  final int roundsTotal;
  final int? maxPlayers;
  final ShuffleStrategy? shuffleStrategy;
  final bool explicitFilter;
  final List<PoolSource> poolSources;
  final String? packId;

  /// emoji_quiz: the effective catalogue markets (the host's choice, else
  /// the server's `emoji_markets_by_locale` for the host locale), in order of
  /// preference. Other modes may omit it [новое имя — согласовать].
  final List<EmojiMarket>? emojiMarkets;

  /// emoji_quiz: the hardest puzzles played, 1 (easy) to 3 (hard; the
  /// default) [новое имя — согласовать].
  final int? emojiMaxDifficulty;

  JsonMap toJson() => {
    'mode': mode.wire,
    'rounds_total': roundsTotal,
    'max_players': ?maxPlayers,
    'shuffle_strategy': ?shuffleStrategy?.wire,
    'explicit_filter': explicitFilter,
    'pool_sources': [for (final s in poolSources) s.wire],
    'pack_id': ?packId,
    'emoji_markets': ?emojiMarkets?.map((m) => m.wire).toList(),
    'emoji_max_difficulty': ?emojiMaxDifficulty,
  };
}

/// Limits of the emoji_quiz lobby settings (packages/protocol
/// `EMOJI_MIN_DIFFICULTY`, `EMOJI_MAX_DIFFICULTY`,
/// `EMOJI_DEFAULT_MAX_DIFFICULTY`).
abstract final class EmojiDifficulty {
  static const min = 1;
  static const max = 3;
  static const defaultMax = 3;
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
    bool? canDj,
    this.ready = false,
    this.poolTrackCount = 0,
    this.entitlements = EntitlementsSnapshot.none,
  }) : canDj = canDj ?? role == PlayerRole.host;

  factory PlayerSnapshot.fromJson(JsonMap json) {
    final entitlements = json.optObj('entitlements_snapshot');
    return PlayerSnapshot(
      playerId: json.str('player_id'),
      displayName: json.str('display_name'),
      role: json.wire('role', PlayerRole.values),
      isContributor: json.boolean('is_contributor'),
      isPlaybackDevice: json.boolean('is_playback_device'),
      // Required since wave 3; an older server gets the protocol defaults.
      canDj: json.optBool('can_dj'),
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

  /// The room playback device (the host). In BYOP rooms the round's DJ is
  /// `round.prepare.dj_player_id`, not this flag.
  final bool isPlaybackDevice;

  /// Opted in to the DJ role (`lobby.set_can_dj`): the server may pick this
  /// player as a round DJ when `byop_dj_rotation` is on. Defaults: true for
  /// the host, false for guests [новое имя — согласовать].
  final bool canDj;
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
        canDj: canDj,
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
    'can_dj': canDj,
    'connection': connection.wire,
    'platform': platform.wire,
    'ready': ready,
    'pool_track_count': poolTrackCount,
    'entitlements_snapshot': entitlements.toJson(),
  };
}

/// `RoomSnapshot.provider_capabilities` (addendum A2): what the room's
/// provider can do. Clients branch on these, never on the provider id.
/// Protocol name `ProviderCapabilities` [новое имя — согласовать].
final class ProviderCapabilities {
  const ProviderCapabilities({
    required this.playback,
    required this.audioSource,
    required this.allowsMonetization,
    required this.allowsPrefetch,
    required this.allowsCustomOffset,
    required this.revealsMetadataDuringPlay,
    required this.licensedTerritories,
    required this.requiresPremiumHost,
    required this.supportsSearch,
    this.maxClipMs,
    this.titleVisibleDuringPlay,
    this.requiresVisiblePlayer,
    this.requiresConsentBeforeLoad,
    this.thirdPartyAdsPossible,
    this.paywallAllowed,
    this.startAccuracyMs,
  });

  factory ProviderCapabilities.fromJson(JsonMap json) => ProviderCapabilities(
    playback: json.wire('playback', AudioStartSource.values),
    audioSource: json.wire('audio_source', AudioSource.values),
    allowsMonetization: json.boolean('allows_monetization'),
    allowsPrefetch: json.boolean('allows_prefetch'),
    allowsCustomOffset: json.boolean('allows_custom_offset'),
    maxClipMs: json.optInt('max_clip_ms'),
    revealsMetadataDuringPlay: json.boolean('reveals_metadata_during_play'),
    licensedTerritories: json.list('licensed_territories', asString),
    requiresPremiumHost: json.boolean('requires_premium_host'),
    supportsSearch: json.boolean('supports_search'),
    titleVisibleDuringPlay: json.optBool('title_visible_during_play'),
    requiresVisiblePlayer: json.optBool('requires_visible_player'),
    requiresConsentBeforeLoad: json.optBool('requires_consent_before_load'),
    thirdPartyAdsPossible: json.optBool('third_party_ads_possible'),
    paywallAllowed: json.optBool('paywall_allowed'),
    startAccuracyMs: json.optInt('start_accuracy_ms'),
  );

  /// For a snapshot without `provider_capabilities` (a server older than
  /// A2): the design doc's capability matrix (S2.4.2) for [provider].
  factory ProviderCapabilities.fallbackFor(MusicProviderId provider) =>
      switch (provider) {
        MusicProviderId.testCatalog ||
        MusicProviderId.licensedClips => ProviderCapabilities(
          playback: AudioStartSource.scheduled,
          audioSource: AudioSource.inApp,
          allowsMonetization: provider == MusicProviderId.testCatalog,
          allowsPrefetch: true,
          allowsCustomOffset: true,
          maxClipMs: 30000,
          revealsMetadataDuringPlay: false,
          licensedTerritories: const ['*'],
          requiresPremiumHost: false,
          supportsSearch: true,
        ),
        MusicProviderId.spotifyAppRemote => const ProviderCapabilities(
          playback: AudioStartSource.hostReported,
          audioSource: AudioSource.inApp,
          allowsMonetization: false,
          allowsPrefetch: false,
          allowsCustomOffset: true,
          maxClipMs: 30000,
          revealsMetadataDuringPlay: true,
          licensedTerritories: [],
          requiresPremiumHost: true,
          supportsSearch: false,
        ),
        MusicProviderId.externalPlayer => const ProviderCapabilities(
          playback: AudioStartSource.hostReported,
          audioSource: AudioSource.externalApp,
          allowsMonetization: true,
          allowsPrefetch: false,
          allowsCustomOffset: false,
          revealsMetadataDuringPlay: true,
          licensedTerritories: ['*'],
          requiresPremiumHost: false,
          supportsSearch: true,
        ),
        MusicProviderId.youtubeEmbed => const ProviderCapabilities(
          playback: AudioStartSource.hostReported,
          audioSource: AudioSource.externalApp,
          allowsMonetization: true,
          allowsPrefetch: false,
          allowsCustomOffset: true,
          revealsMetadataDuringPlay: true,
          licensedTerritories: ['*'],
          requiresPremiumHost: false,
          supportsSearch: true,
          titleVisibleDuringPlay: true,
          requiresVisiblePlayer: true,
          requiresConsentBeforeLoad: true,
          thirdPartyAdsPossible: true,
          paywallAllowed: false,
          startAccuracyMs: 2000,
        ),
        MusicProviderId.none => const ProviderCapabilities(
          playback: AudioStartSource.none,
          audioSource: AudioSource.none,
          allowsMonetization: true,
          allowsPrefetch: false,
          allowsCustomOffset: false,
          revealsMetadataDuringPlay: false,
          licensedTerritories: ['*'],
          requiresPremiumHost: false,
          supportsSearch: true,
        ),
      };

  final AudioStartSource playback;
  final AudioSource audioSource;
  final bool allowsMonetization;
  final bool allowsPrefetch;
  final bool allowsCustomOffset;

  /// Absent when unlimited or not applicable (external_player, none).
  final int? maxClipMs;

  /// Consumer music apps show title and artist while playing.
  final bool revealsMetadataDuringPlay;

  /// ISO 3166-1 alpha-2 codes, or `["*"]` for everywhere.
  final List<String> licensedTerritories;
  final bool requiresPremiumHost;
  final bool supportsSearch;

  // Wave 4 flags (optional on the wire; absent = the behaviour before wave
  // 4, see the getters below) [новое имя — согласовать].
  final bool? titleVisibleDuringPlay;
  final bool? requiresVisiblePlayer;
  final bool? requiresConsentBeforeLoad;
  final bool? thirdPartyAdsPossible;
  final bool? paywallAllowed;

  /// Expected error of the start offset; null when exact or not applicable.
  final int? startAccuracyMs;

  /// The DJ's device plays the song in a third-party player (their own music
  /// app in BYOP, the embedded YouTube player in youtube_embed).
  bool get isExternalApp => audioSource == AudioSource.externalApp;

  /// The player must stay visible while playing (YouTube III.I.7 / III.I.9):
  /// never hidden, off-screen or overlaid.
  bool get needsVisiblePlayer => requiresVisiblePlayer ?? false;

  /// Where consent applies, it must be given before the player is created
  /// (YouTube III.E.4.i).
  bool get needsConsentBeforeLoad => requiresConsentBeforeLoad ?? false;

  /// The player may show its own ads, which are never blocked or skipped.
  bool get mayShowThirdPartyAds => thirdPartyAdsPossible ?? false;

  /// Rounds of this provider may be paid for or unlocked by a rewarded ad.
  bool get allowsPaywall => paywallAllowed ?? true;

  /// The playing device shows the song title.
  bool get showsTitleDuringPlay =>
      titleVisibleDuringPlay ?? revealsMetadataDuringPlay;

  JsonMap toJson() => {
    'playback': playback.wire,
    'audio_source': audioSource.wire,
    'allows_monetization': allowsMonetization,
    'allows_prefetch': allowsPrefetch,
    'allows_custom_offset': allowsCustomOffset,
    'max_clip_ms': ?maxClipMs,
    'reveals_metadata_during_play': revealsMetadataDuringPlay,
    'licensed_territories': licensedTerritories,
    'requires_premium_host': requiresPremiumHost,
    'supports_search': supportsSearch,
    'title_visible_during_play': ?titleVisibleDuringPlay,
    'requires_visible_player': ?requiresVisiblePlayer,
    'requires_consent_before_load': ?requiresConsentBeforeLoad,
    'third_party_ads_possible': ?thirdPartyAdsPossible,
    'paywall_allowed': ?paywallAllowed,
    'start_accuracy_ms': ?startAccuracyMs,
  };
}

/// Full room snapshot: `room.state` payload, `welcome.room` and
/// `GET /v1/rooms/{room_id}`.
final class RoomSnapshot {
  const RoomSnapshot({
    required this.state,
    required this.hostPlayerId,
    required this.players,
    required this.settings,
    required this.mode,
    required this.provider,
    required this.audioMode,
    this.providerCapabilities,
    this.roomId,
    this.roomCode,
    this.hostTier = HostTier.free,
    this.locked = false,
    this.currentGameId,
  });

  factory RoomSnapshot.fromJson(JsonMap json) {
    final capabilities = json.optObj('provider_capabilities');
    return RoomSnapshot(
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
      providerCapabilities: capabilities == null
          ? null
          : ProviderCapabilities.fromJson(capabilities),
      audioMode: json.wire('audio_mode', AudioMode.values),
      hostTier: json.optWire('host_tier', HostTier.values) ?? HostTier.free,
      locked: json.optBool('locked') ?? false,
      currentGameId: json.optStr('current_game_id'),
    );
  }

  final String? roomId;
  final String? roomCode;
  final RoomState state;
  final String hostPlayerId;
  final List<PlayerSnapshot> players;
  final RoomSettings settings;
  final GameMode mode;
  final MusicProviderId provider;

  /// Required by packages/protocol since A2; null only from an older server
  /// (see [capabilities]).
  final ProviderCapabilities? providerCapabilities;
  final AudioMode audioMode;
  final HostTier hostTier;
  final bool locked;
  final String? currentGameId;

  /// What the provider can do; derived from [provider] when the server did
  /// not send `provider_capabilities`.
  ProviderCapabilities get capabilities =>
      providerCapabilities ?? ProviderCapabilities.fallbackFor(provider);

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
    providerCapabilities: providerCapabilities,
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
    'provider_capabilities': ?providerCapabilities?.toJson(),
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

/// `round.prepare.cue` (A2.2, A2.6): sent only to the DJ of an
/// `external_player` room instead of a clip. The app never plays the song:
/// the DJ starts it in their own music app. Protocol schema title
/// `RoundCue` [новое имя — согласовать].
final class RoundCue {
  const RoundCue({required this.title, required this.artists, this.hintUrl});

  factory RoundCue.fromJson(JsonMap json) => RoundCue(
    title: json.str('title'),
    artists: json.list('artists', asString),
    hintUrl: json.optStr('hint_url'),
  );

  final String title;
  final List<String> artists;

  /// A search or share link the DJ may open (iOS: the only way to hand the
  /// song to a music app).
  final String? hintUrl;

  JsonMap toJson() => {
    'title': title,
    'artists': artists,
    'hint_url': ?hintUrl,
  };
}

/// `round.prepare.video` (wave 4, youtube_embed): the video the round's DJ
/// plays in the official embedded YouTube player, visible on their screen.
/// Sent to the DJ only and always with the cue (the BYOP fallback). Protocol
/// `RoundVideo` [новое имя — согласовать].
final class RoundVideo {
  const RoundVideo({
    required this.videoId,
    required this.startS,
    this.fallbackVideoIds = const [],
  });

  static final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  factory RoundVideo.fromJson(JsonMap json) {
    String id(Object? item) {
      final value = asString(item);
      if (!_videoId.hasMatch(value)) {
        throw const ProtocolFormatException(
          'video ids are 11-character YouTube ids',
        );
      }
      return value;
    }

    final startS = json.integer('start_s');
    if (startS < 0) throw const ProtocolFormatException('"start_s" < 0');
    final video = RoundVideo(
      videoId: id(json['video_id']),
      startS: startS,
      fallbackVideoIds: json.list('fallback_video_ids', id),
    );
    if (video.fallbackVideoIds.length > maxFallbacks) {
      throw const ProtocolFormatException('too many fallback_video_ids');
    }
    return video;
  }

  /// Protocol `ROUND_VIDEO_MAX_FALLBACKS`.
  static const maxFallbacks = 3;

  final String videoId;

  /// The player's `start` parameter, whole seconds (accuracy about 2 s).
  final int startS;

  /// Tried in order when [videoId] fails; never repeats it.
  final List<String> fallbackVideoIds;

  /// [videoId] then [fallbackVideoIds].
  List<String> get candidates => [videoId, ...fallbackVideoIds];

  JsonMap toJson() => {
    'video_id': videoId,
    'start_s': startS,
    'fallback_video_ids': fallbackVideoIds,
  };
}

/// `round.prepare.text_prompt`: the song every player reads in a
/// whose_song text round (provider `none`). Protocol name
/// `RoundTextPrompt` [новое имя — согласовать].
final class RoundTextPrompt {
  const RoundTextPrompt({required this.title, required this.artists});

  factory RoundTextPrompt.fromJson(JsonMap json) => RoundTextPrompt(
    title: json.str('title'),
    artists: json.list('artists', asString),
  );

  final String title;
  final List<String> artists;

  JsonMap toJson() => {'title': title, 'artists': artists};
}

/// `round.prepare.emoji_prompt` (emoji_quiz): the 2-6 emoji that encode the
/// song title, sent to every player. Never the title or the artist: they
/// arrive only in `round.reveal`. Protocol name `RoundEmojiPrompt`
/// [новое имя — согласовать].
final class RoundEmojiPrompt {
  const RoundEmojiPrompt({required this.emoji});

  factory RoundEmojiPrompt.fromJson(JsonMap json) =>
      RoundEmojiPrompt(emoji: json.str('emoji'));

  /// Shown as is (spaces between emoji are allowed).
  final String emoji;

  JsonMap toJson() => {'emoji': emoji};
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
    this.year,
  });

  factory RevealTrack.fromJson(JsonMap json) => RevealTrack(
    title: json.str('title'),
    artists: json.list('artists', asString),
    attribution: TrackAttribution.fromJson(json.obj('attribution')),
    artworkUrl: json.optStr('artwork_url'),
    year: json.optInt('year'),
  );

  final String title;
  final List<String> artists;
  final TrackAttribution attribution;

  /// Never shown: cover images are not cleared (A2.3).
  final String? artworkUrl;

  /// Year of first release, when known; always sent in emoji rounds
  /// [новое имя — согласовать].
  final int? year;

  JsonMap toJson() => {
    'title': title,
    'artists': artists,
    'attribution': attribution.toJson(),
    'artwork_url': ?artworkUrl,
    'year': ?year,
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

  /// A2.2: how long the DJ has to start the song before the round is voided.
  int get byopStartTimeoutMs => _int('byop_start_timeout_ms', 20000);

  /// A2.2: whether the round's DJ (external_player) may answer in
  /// guess_track (otherwise the server rejects with `dj_ineligible`).
  bool get guessTrackDjCanAnswer => _bool('guess_track_dj_can_answer', false);

  /// The same for whose_song: the DJ reads the cue before the audio starts,
  /// so by default they do not answer [новое имя — согласовать].
  bool get whoseSongDjCanAnswer => _bool('whose_song_dj_can_answer', false);

  /// The server picks each round's DJ among players with `can_dj`.
  bool get byopDjRotation => _bool('byop_dj_rotation', false);

  /// The pause between `round.voided` and the spare's `round.prepare`; the
  /// app keeps the void notice visible this long [новое имя — согласовать].
  int get voidNoticeMs => _int('void_notice_ms', 1500);
  int get poolMinTracksPerContributor =>
      _int('pool_min_tracks_per_contributor', 5);
  int get poolMaxTracksPerContributor =>
      _int('pool_max_tracks_per_contributor', 50);
  bool get monetizationEnabled => _bool('monetization_enabled', true);
  bool get rewardedEnabled => _bool('rewarded_enabled', true);
  bool get interstitialEnabled => _bool('interstitial_enabled', true);
  bool get removeAdsUpsellEnabled => _bool('remove_ads_upsell_enabled', true);

  /// `modes_enabled` (wave 4, reader B): the modes this room accepts, in
  /// [GameMode] order; null when the snapshot does not carry the key (an
  /// older server), so the caller falls back to Remote Config.
  List<GameMode>? get modesEnabled {
    final value = values['modes_enabled'];
    if (value is! List<Object?>) return null;
    final modes = [
      for (final mode in GameMode.values)
        if (value.contains(mode.wire)) mode,
    ];
    return modes.isEmpty ? null : modes;
  }

  JsonMap toJson() => values;
}
