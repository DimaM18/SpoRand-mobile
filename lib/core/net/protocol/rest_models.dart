/// REST bodies (brief §4.2) the app sends or reads: hand-written mirror of
/// packages/protocol `src/rest/*`, replaced later by the generated
/// lib/contracts/ code. Field names are canonical.
///
/// Wave 8b: the shared bodies (auth, `/v1/me`, consent, RFC 9457 problems)
/// are the kit DTOs of mobile_kit, re-exported here. They keep SpoRand's
/// account fields (`games_completed`, `music_links`) in `extras` and write
/// them back; [SporandUserProfile] and [SporandMeResponse] read them under
/// the old names. The game bodies below stay SpoRand's.
///
/// Conventions (packages/protocol "Wire policies"):
/// - request bodies are strict: [JsonRead.expectOnly] rejects unknown fields
///   and explicit nulls when a body is parsed (tests, tools);
/// - responses are open: unknown fields are ignored;
/// - optional fields are omitted on the wire, never `null`;
/// - `*_at` timestamps stay RFC 3339 strings (the app only displays or
///   forwards them).
library;

import 'package:mobile_kit/mobile_kit.dart' show MeResponse, UserProfile;

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';

export 'package:mobile_kit/mobile_kit.dart'
    show
        AuthTokensResponse,
        ConsentSource,
        ConsentState,
        ConsentUpdateRequest,
        EntitlementRecord,
        EntitlementsState,
        GuestAuthRequest,
        MePatchRequest,
        MeResponse,
        Problem,
        ProblemFieldError,
        RefreshTokenRequest,
        UserProfile;

// ---------------------------------------------------------------------------
// Account fields of SpoRand (`profileExtra`, `meExtra`)
// ---------------------------------------------------------------------------

/// `UserProfile.games_completed` (SpoRand's `profileExtra`), read from the
/// kit DTO's `extras` [новое имя — согласовать].
extension SporandUserProfile on UserProfile {
  /// Games this account finished; 0 when the field is absent.
  int get gamesCompleted => extras.readInt('games_completed') ?? 0;
}

/// `MeResponse.music_links` (SpoRand's `meExtra`), read from the kit DTO's
/// `extras` [новое имя — согласовать].
extension SporandMeResponse on MeResponse {
  /// The account's music links, as they arrived; empty when absent.
  List<Object?> get musicLinks =>
      extras.readList('music_links') ?? const <Object?>[];
}

// ---------------------------------------------------------------------------
// Rooms
// ---------------------------------------------------------------------------

/// `POST /v1/rooms` optional settings; omitted fields come from the frozen
/// config.
final class RoomSettingsInput {
  const RoomSettingsInput({
    this.roundsTotal,
    this.shuffleStrategy,
    this.explicitFilter,
    this.poolSources,
    this.packId,
  });

  factory RoomSettingsInput.fromJson(JsonMap json) => RoomSettingsInput(
    roundsTotal: (json..expectOnly(_keys)).optInt('rounds_total'),
    shuffleStrategy: json.optWire('shuffle_strategy', ShuffleStrategy.values),
    explicitFilter: json.optBool('explicit_filter'),
    poolSources: json.optList(
      'pool_sources',
      (item) => parseWire(PoolSource.values, item),
    ),
    packId: json.optStr('pack_id'),
  );

  static const _keys = {
    'rounds_total',
    'shuffle_strategy',
    'explicit_filter',
    'pool_sources',
    'pack_id',
  };

  final int? roundsTotal;
  final ShuffleStrategy? shuffleStrategy;
  final bool? explicitFilter;
  final List<PoolSource>? poolSources;
  final String? packId;

  JsonMap toJson() => {
    'rounds_total': ?roundsTotal,
    'shuffle_strategy': ?shuffleStrategy?.wire,
    'explicit_filter': ?explicitFilter,
    'pool_sources': ?poolSources?.map((s) => s.wire).toList(),
    'pack_id': ?packId,
  };
}

/// `POST /v1/rooms` body (limited-use App Check token).
final class RoomCreateRequest {
  const RoomCreateRequest({
    required this.mode,
    required this.provider,
    this.settings,
    this.displayName,
  });

  factory RoomCreateRequest.fromJson(JsonMap json) {
    final settings = (json..expectOnly(_keys)).optObj('settings');
    return RoomCreateRequest(
      mode: json.wire('mode', GameMode.values),
      provider: json.wire('provider', MusicProviderId.values),
      settings: settings == null ? null : RoomSettingsInput.fromJson(settings),
      displayName: json.optStr('display_name'),
    );
  }

  static const _keys = {'mode', 'provider', 'settings', 'display_name'};

  final GameMode mode;

  /// The requested provider; the server may fall back to `default_provider`
  /// when it is not enabled for the host's country (A2.5).
  final MusicProviderId provider;
  final RoomSettingsInput? settings;
  final String? displayName;

  JsonMap toJson() => {
    'mode': mode.wire,
    'provider': provider.wire,
    'settings': ?settings?.toJson(),
    'display_name': ?displayName,
  };
}

/// `POST /v1/rooms` response.
final class RoomCreateResponse {
  const RoomCreateResponse({
    required this.roomId,
    required this.roomCode,
    required this.playerId,
    required this.config,
    required this.configVersion,
  });

  factory RoomCreateResponse.fromJson(JsonMap json) => RoomCreateResponse(
    roomId: json.str('room_id'),
    roomCode: json.str('room_code'),
    playerId: json.str('player_id'),
    config: RoomConfig(json.obj('config_snapshot')),
    configVersion: json.str('config_version'),
  );

  final String roomId;
  final String roomCode;
  final String playerId;

  /// `config_snapshot`: the room's frozen server-template values.
  final RoomConfig config;
  final String configVersion;

  JsonMap toJson() => {
    'room_id': roomId,
    'room_code': roomCode,
    'player_id': playerId,
    'config_snapshot': config.toJson(),
    'config_version': configVersion,
  };
}

/// `POST /v1/rooms/join` body.
final class RoomJoinRequest {
  const RoomJoinRequest({required this.roomCode, required this.displayName});

  factory RoomJoinRequest.fromJson(JsonMap json) => RoomJoinRequest(
    roomCode: (json..expectOnly(const {'room_code', 'display_name'})).str(
      'room_code',
    ),
    displayName: json.str('display_name'),
  );

  final String roomCode;
  final String displayName;

  JsonMap toJson() => {'room_code': roomCode, 'display_name': displayName};
}

/// `POST /v1/rooms/join` response.
final class RoomJoinResponse {
  const RoomJoinResponse({required this.roomId, required this.playerId});

  factory RoomJoinResponse.fromJson(JsonMap json) => RoomJoinResponse(
    roomId: json.str('room_id'),
    playerId: json.str('player_id'),
  );

  final String roomId;
  final String playerId;

  JsonMap toJson() => {'room_id': roomId, 'player_id': playerId};
}

/// `POST /v1/rooms/{room_id}/ws-ticket` response.
final class WsTicketResponse {
  const WsTicketResponse({
    required this.ticket,
    required this.ticketTtlMs,
    this.wsUrl,
  });

  factory WsTicketResponse.fromJson(JsonMap json) => WsTicketResponse(
    ticket: json.str('ticket'),
    ticketTtlMs: json.integer('ticket_ttl_ms'),
    wsUrl: json.optStr('ws_url'),
  );

  /// Single-use; sent in `hello`, never in the URL.
  final String ticket;
  final int ticketTtlMs;
  final String? wsUrl;

  JsonMap toJson() => {
    'ticket': ticket,
    'ticket_ttl_ms': ticketTtlMs,
    'ws_url': ?wsUrl,
  };
}

/// `POST /v1/rooms/{room_id}/reports` body.
final class ReportCreateRequest {
  const ReportCreateRequest({
    required this.reportedPlayerId,
    required this.reason,
    this.comment,
  });

  factory ReportCreateRequest.fromJson(JsonMap json) => ReportCreateRequest(
    reportedPlayerId: (json..expectOnly(_keys)).str('reported_player_id'),
    reason: json.str('reason'),
    comment: json.optStr('comment'),
  );

  static const _keys = {'reported_player_id', 'reason', 'comment'};

  final String reportedPlayerId;

  /// `ReportReason` wire value.
  final String reason;
  final String? comment;

  JsonMap toJson() => {
    'reported_player_id': reportedPlayerId,
    'reason': reason,
    'comment': ?comment,
  };
}

/// `POST /v1/rooms/{room_id}/reports` response.
final class ReportCreateResponse {
  const ReportCreateResponse(this.reportId);

  factory ReportCreateResponse.fromJson(JsonMap json) =>
      ReportCreateResponse(json.str('report_id'));

  final String reportId;

  JsonMap toJson() => {'report_id': reportId};
}

// ---------------------------------------------------------------------------
// Songs and «Мои песни» (A2.3)
// ---------------------------------------------------------------------------

/// `Song`: song identity separate from any audio (MusicBrainz CC0 core
/// data). There is no artwork on purpose: cover images are not cleared, so
/// the app renders generated cards. Protocol name `Song` [новое имя —
/// согласовать].
final class Song {
  const Song({
    required this.songId,
    required this.title,
    required this.artistCredit,
    required this.artists,
    required this.primaryArtist,
    required this.explicit,
    required this.isrcs,
    this.year,
    this.mbid,
  });

  factory Song.fromJson(JsonMap json) => Song(
    songId: json.str('song_id'),
    title: json.str('title'),
    artistCredit: json.str('artist_credit'),
    artists: json.list('artists', asString),
    primaryArtist: json.str('primary_artist'),
    year: json.optInt('year'),
    explicit: json.boolean('explicit'),
    isrcs: json.list('isrcs', asString),
    mbid: json.optStr('mbid'),
  );

  final String songId;
  final String title;

  /// As displayed, e.g. «Queen & David Bowie».
  final String artistCredit;
  final List<String> artists;
  final String primaryArtist;
  final int? year;
  final bool explicit;
  final List<String> isrcs;

  /// MusicBrainz recording id.
  final String? mbid;

  JsonMap toJson() => {
    'song_id': songId,
    'title': title,
    'artist_credit': artistCredit,
    'artists': artists,
    'primary_artist': primaryArtist,
    'year': ?year,
    'explicit': explicit,
    'isrcs': isrcs,
    'mbid': ?mbid,
  };
}

/// `GET /v1/songs/search` query.
final class SongSearchQuery {
  const SongSearchQuery({required this.q, this.limit});

  factory SongSearchQuery.fromJson(JsonMap json) => SongSearchQuery(
    q: (json..expectOnly(const {'q', 'limit'})).str('q'),
    limit: json.optInt('limit'),
  );

  /// 1–100 characters.
  final String q;

  /// 1–25; the server defaults to 10.
  final int? limit;

  JsonMap toJson() => {'q': q, 'limit': ?limit};

  Map<String, String> toQueryParameters() => {
    'q': q,
    if (limit != null) 'limit': '$limit',
  };
}

/// `GET /v1/songs/search` response.
final class SongSearchResponse {
  const SongSearchResponse(this.items);

  factory SongSearchResponse.fromJson(JsonMap json) => SongSearchResponse(
    json.list('items', (item) => Song.fromJson(asObject(item))),
  );

  final List<Song> items;

  JsonMap toJson() => {
    'items': [for (final s in items) s.toJson()],
  };
}

/// A legacy catalogue track (`test_catalog` / `licensed_clips`).
final class CatalogTrack {
  const CatalogTrack({
    required this.catalogTrackId,
    required this.provider,
    required this.title,
    required this.artists,
    required this.primaryArtist,
    required this.durationMs,
    required this.explicit,
    this.artworkUrl,
  });

  factory CatalogTrack.fromJson(JsonMap json) => CatalogTrack(
    catalogTrackId: json.str('catalog_track_id'),
    provider: json.wire('provider', MusicProviderId.values),
    title: json.str('title'),
    artists: json.list('artists', asString),
    primaryArtist: json.str('primary_artist'),
    durationMs: json.integer('duration_ms'),
    explicit: json.boolean('explicit'),
    artworkUrl: json.optStr('artwork_url'),
  );

  final String catalogTrackId;
  final MusicProviderId provider;
  final String title;
  final List<String> artists;
  final String primaryArtist;
  final int durationMs;
  final bool explicit;

  /// Round-tripped only; the app never shows artwork (A2.3).
  final String? artworkUrl;

  JsonMap toJson() => {
    'catalog_track_id': catalogTrackId,
    'provider': provider.wire,
    'title': title,
    'artists': artists,
    'primary_artist': primaryArtist,
    'duration_ms': durationMs,
    'explicit': explicit,
    'artwork_url': ?artworkUrl,
  };
}

/// One entry of «Мои песни»: a song pick {position, song_id, song} (A2.3)
/// or a legacy catalogue pick {position, catalog_track_id, track}; never
/// both (packages/protocol `catalogPickIssues`).
sealed class CatalogPick {
  const CatalogPick({required this.position});

  factory CatalogPick.fromJson(JsonMap json) {
    final position = json.integer('position');
    final hasSong = json.containsKey('song_id') || json.containsKey('song');
    final hasTrack =
        json.containsKey('catalog_track_id') || json.containsKey('track');
    if (hasSong == hasTrack) {
      throw const ProtocolFormatException(
        'a pick is either {song_id, song} or {catalog_track_id, track}',
      );
    }
    if (hasSong) {
      final song = Song.fromJson(json.obj('song'));
      if (json.str('song_id') != song.songId) {
        throw const ProtocolFormatException('song_id differs from song');
      }
      final videoId = json.optStr('youtube_video_id');
      if (videoId != null) checkYouTubeVideoId('youtube_video_id', videoId);
      return SongPick(position: position, song: song, youtubeVideoId: videoId);
    }
    if (json.containsKey('youtube_video_id')) {
      throw const ProtocolFormatException(
        'youtube_video_id only goes with a song pick',
      );
    }
    final track = CatalogTrack.fromJson(json.obj('track'));
    if (json.str('catalog_track_id') != track.catalogTrackId) {
      throw const ProtocolFormatException(
        'catalog_track_id differs from track',
      );
    }
    return LegacyCatalogPick(position: position, track: track);
  }

  /// 1-based.
  final int position;

  String get title;
  List<String> get artists;

  JsonMap toJson();
}

/// A song pick (A2.3); protocol fields `song_id` / `song` [новое имя —
/// согласовать].
final class SongPick extends CatalogPick {
  const SongPick({
    required super.position,
    required this.song,
    this.youtubeVideoId,
  });

  final Song song;

  /// The YouTube video the owner linked for this song (wave 4,
  /// youtube_embed) [новое имя — согласовать].
  final String? youtubeVideoId;

  SongPick withPosition(int position) =>
      SongPick(position: position, song: song, youtubeVideoId: youtubeVideoId);

  SongPick withVideo(String? videoId) =>
      SongPick(position: position, song: song, youtubeVideoId: videoId);

  @override
  String get title => song.title;

  @override
  List<String> get artists => song.artists;

  @override
  JsonMap toJson() => {
    'position': position,
    'song_id': song.songId,
    'song': song.toJson(),
    'youtube_video_id': ?youtubeVideoId,
  };
}

/// A legacy catalogue pick; still valid for `test_catalog` /
/// `licensed_clips` rooms.
final class LegacyCatalogPick extends CatalogPick {
  const LegacyCatalogPick({required super.position, required this.track});

  final CatalogTrack track;

  @override
  String get title => track.title;

  @override
  List<String> get artists => track.artists;

  @override
  JsonMap toJson() => {
    'catalog_track_id': track.catalogTrackId,
    'position': position,
    'track': track.toJson(),
  };
}

/// `GET /v1/me/picks` and `PUT /v1/me/picks` response.
final class PicksResponse {
  const PicksResponse(this.picks);

  factory PicksResponse.fromJson(JsonMap json) => PicksResponse(
    json.list('picks', (item) => CatalogPick.fromJson(asObject(item))),
  );

  final List<CatalogPick> picks;

  JsonMap toJson() => {
    'picks': [for (final p in picks) p.toJson()],
  };
}

/// One entry of `PicksUpdateRequest.song_picks` (wave 4): a song with an
/// optional YouTube video. Protocol `SongPickInput` [новое имя — согласовать].
final class SongPickInput {
  const SongPickInput({required this.songId, this.youtubeVideoId});

  factory SongPickInput.fromJson(JsonMap json) {
    json.expectOnly(const {'song_id', 'youtube_video_id'});
    final videoId = json.optStr('youtube_video_id');
    if (videoId != null) checkYouTubeVideoId('youtube_video_id', videoId);
    return SongPickInput(songId: json.str('song_id'), youtubeVideoId: videoId);
  }

  final String songId;
  final String? youtubeVideoId;

  JsonMap toJson() => {'song_id': songId, 'youtube_video_id': ?youtubeVideoId};
}

/// `PUT /v1/me/picks` body: exactly one ordered list: `song_ids` (A2.3),
/// `song_picks` (wave 4: songs with an optional YouTube video each) or the
/// legacy `catalog_track_ids`.
final class PicksUpdateRequest {
  const PicksUpdateRequest.songs(List<String> this.songIds)
    : songPicks = null,
      catalogTrackIds = null;

  const PicksUpdateRequest.songPicks(List<SongPickInput> this.songPicks)
    : songIds = null,
      catalogTrackIds = null;

  const PicksUpdateRequest.legacyCatalog(List<String> this.catalogTrackIds)
    : songIds = null,
      songPicks = null;

  factory PicksUpdateRequest.fromJson(JsonMap json) {
    json.expectOnly(const {'song_ids', 'song_picks', 'catalog_track_ids'});
    if (json.length != 1) {
      throw const ProtocolFormatException(
        'exactly one of song_ids, song_picks and catalog_track_ids',
      );
    }
    final songs = json.optList('song_ids', asString);
    if (songs != null) return PicksUpdateRequest.songs(songs);
    final picks = json.optList(
      'song_picks',
      (item) => SongPickInput.fromJson(asObject(item)),
    );
    if (picks != null) {
      final ids = {for (final p in picks) p.songId};
      if (ids.length != picks.length) {
        throw const ProtocolFormatException('song_picks repeat a song_id');
      }
      return PicksUpdateRequest.songPicks(picks);
    }
    return PicksUpdateRequest.legacyCatalog(
      json.list('catalog_track_ids', asString),
    );
  }

  /// Protocol bounds of the list (`PICKS_MIN` / `PICKS_MAX`).
  static const minPicks = 5;
  static const maxPicks = 10;

  final List<String>? songIds;
  final List<SongPickInput>? songPicks;
  final List<String>? catalogTrackIds;

  JsonMap toJson() => {
    'song_ids': ?songIds,
    if (songPicks case final picks?)
      'song_picks': [for (final p in picks) p.toJson()],
    'catalog_track_ids': ?catalogTrackIds,
  };
}

/// Protocol `YOUTUBE_VIDEO_ID_PATTERN`: 11 URL-safe base64 characters.
final youTubeVideoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');

void checkYouTubeVideoId(String field, String value) {
  if (!youTubeVideoIdPattern.hasMatch(value)) {
    throw ProtocolFormatException('"$field" must be an 11-character video id');
  }
}

// ---------------------------------------------------------------------------
// YouTube links (wave 4)
// ---------------------------------------------------------------------------

/// `POST /v1/songs/youtube/resolve` body: a pasted link as is
/// [новое имя — согласовать].
final class YouTubeResolveRequest {
  const YouTubeResolveRequest({required this.url});

  factory YouTubeResolveRequest.fromJson(JsonMap json) =>
      YouTubeResolveRequest(url: (json..expectOnly(const {'url'})).str('url'));

  /// 1–2048 characters.
  final String url;

  JsonMap toJson() => {'url': url};
}

/// `POST /v1/songs/youtube/resolve` response: the video id and its oEmbed
/// title and channel, shown to the owner as text only (never a thumbnail)
/// [новое имя — согласовать].
final class YouTubeResolveResponse {
  const YouTubeResolveResponse({
    required this.videoId,
    required this.title,
    required this.authorName,
    this.embeddableHint,
  });

  factory YouTubeResolveResponse.fromJson(JsonMap json) {
    final videoId = json.str('video_id');
    checkYouTubeVideoId('video_id', videoId);
    return YouTubeResolveResponse(
      videoId: videoId,
      title: json.str('title'),
      authorName: json.str('author_name'),
      embeddableHint: json.optBool('embeddable_hint'),
    );
  }

  final String videoId;
  final String title;

  /// The channel name.
  final String authorName;

  /// Best effort: probably embeddable; null when unknown.
  final bool? embeddableHint;

  JsonMap toJson() => {
    'video_id': videoId,
    'title': title,
    'author_name': authorName,
    'embeddable_hint': ?embeddableHint,
  };
}

// ---------------------------------------------------------------------------
// Room pools
// ---------------------------------------------------------------------------

/// `PoolTrackInput`: a song (external_player / none, A2.3) or a legacy
/// catalogue track. Spotify pool tracks are not built by this app.
sealed class PoolTrackInput {
  const PoolTrackInput({this.rank, this.hidden});

  factory PoolTrackInput.fromJson(JsonMap json) {
    if (json.containsKey('song_id')) {
      json.expectOnly(const {'song_id', 'rank', 'hidden', 'youtube_video_id'});
      final videoId = json.optStr('youtube_video_id');
      if (videoId != null) checkYouTubeVideoId('youtube_video_id', videoId);
      return SongPoolTrack(
        songId: json.str('song_id'),
        rank: json.optInt('rank'),
        hidden: json.optBool('hidden'),
        youtubeVideoId: videoId,
      );
    }
    json.expectOnly(const {'catalog_track_id', 'rank', 'hidden'});
    return CatalogPoolTrack(
      catalogTrackId: json.str('catalog_track_id'),
      rank: json.optInt('rank'),
      hidden: json.optBool('hidden'),
    );
  }

  /// 1-based position in the source list; defaults to array order.
  final int? rank;

  /// Hidden by the contributor: never played.
  final bool? hidden;

  JsonMap toJson();
}

/// Protocol name `SongPoolTrack` [новое имя — согласовать].
final class SongPoolTrack extends PoolTrackInput {
  const SongPoolTrack({
    required this.songId,
    super.rank,
    super.hidden,
    this.youtubeVideoId,
  });

  final String songId;

  /// youtube_embed rooms: the video to play for this song (wave 4)
  /// [новое имя — согласовать].
  final String? youtubeVideoId;

  @override
  JsonMap toJson() => {
    'song_id': songId,
    'rank': ?rank,
    'hidden': ?hidden,
    'youtube_video_id': ?youtubeVideoId,
  };
}

final class CatalogPoolTrack extends PoolTrackInput {
  const CatalogPoolTrack({
    required this.catalogTrackId,
    super.rank,
    super.hidden,
  });

  final String catalogTrackId;

  @override
  JsonMap toJson() => {
    'catalog_track_id': catalogTrackId,
    'rank': ?rank,
    'hidden': ?hidden,
  };
}

/// `PUT /v1/rooms/{room_id}/pool` body.
final class PoolPutRequest {
  const PoolPutRequest({required this.poolSource, required this.tracks});

  factory PoolPutRequest.fromJson(JsonMap json) => PoolPutRequest(
    poolSource: (json..expectOnly(const {'pool_source', 'tracks'})).wire(
      'pool_source',
      PoolSource.values,
    ),
    tracks: json.list(
      'tracks',
      (item) => PoolTrackInput.fromJson(asObject(item)),
    ),
  );

  final PoolSource poolSource;
  final List<PoolTrackInput> tracks;

  JsonMap toJson() => {
    'pool_source': poolSource.wire,
    'tracks': [for (final t in tracks) t.toJson()],
  };
}

/// One stored pool entry (only returned to its contributor).
final class PoolEntry {
  const PoolEntry({
    required this.trackRefId,
    required this.rank,
    required this.title,
    required this.artists,
    required this.primaryArtist,
  });

  factory PoolEntry.fromJson(JsonMap json) => PoolEntry(
    trackRefId: json.str('track_ref_id'),
    rank: json.integer('rank'),
    title: json.str('title'),
    artists: json.list('artists', asString),
    primaryArtist: json.str('primary_artist'),
  );

  final String trackRefId;
  final int rank;
  final String title;
  final List<String> artists;
  final String primaryArtist;

  JsonMap toJson() => {
    'track_ref_id': trackRefId,
    'rank': rank,
    'title': title,
    'artists': artists,
    'primary_artist': primaryArtist,
  };
}

/// `PUT /v1/rooms/{room_id}/pool` response: my contribution as stored.
final class PoolContributionView {
  const PoolContributionView({
    required this.poolId,
    required this.roomId,
    required this.playerId,
    required this.provider,
    required this.poolSource,
    required this.entries,
    required this.hiddenTrackRefIds,
    required this.submittedAt,
    required this.expiresAt,
  });

  factory PoolContributionView.fromJson(JsonMap json) => PoolContributionView(
    poolId: json.str('pool_id'),
    roomId: json.str('room_id'),
    playerId: json.str('player_id'),
    provider: json.wire('provider', MusicProviderId.values),
    poolSource: json.wire('pool_source', PoolSource.values),
    entries: json.list('entries', (item) => PoolEntry.fromJson(asObject(item))),
    hiddenTrackRefIds: json.list('hidden_track_ref_ids', asString),
    submittedAt: json.str('submitted_at'),
    expiresAt: json.str('expires_at'),
  );

  final String poolId;
  final String roomId;
  final String playerId;
  final MusicProviderId provider;
  final PoolSource poolSource;
  final List<PoolEntry> entries;
  final List<String> hiddenTrackRefIds;
  final String submittedAt;
  final String expiresAt;

  JsonMap toJson() => {
    'pool_id': poolId,
    'room_id': roomId,
    'player_id': playerId,
    'provider': provider.wire,
    'pool_source': poolSource.wire,
    'entries': [for (final e in entries) e.toJson()],
    'hidden_track_ref_ids': hiddenTrackRefIds,
    'submitted_at': submittedAt,
    'expires_at': expiresAt,
  };
}
