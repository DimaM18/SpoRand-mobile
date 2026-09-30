/// REST bodies (brief §4.2) the app sends or reads: hand-written mirror of
/// packages/protocol `src/rest/*`, replaced later by the generated
/// lib/contracts/ code. Field names are canonical.
///
/// Conventions (packages/protocol "Wire policies"):
/// - request bodies are strict: [JsonRead.expectOnly] rejects unknown fields
///   and explicit nulls when a body is parsed (tests, tools);
/// - responses are open: unknown fields are ignored;
/// - optional fields are omitted on the wire, never `null`;
/// - `*_at` timestamps stay RFC 3339 strings (the app only displays or
///   forwards them).
library;

import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand/core/privacy/age_band.dart';

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// `POST /v1/auth/guest` body.
final class GuestAuthRequest {
  const GuestAuthRequest({
    required this.platform,
    required this.appVersion,
    required this.osVersion,
    required this.locale,
  });

  factory GuestAuthRequest.fromJson(JsonMap json) => GuestAuthRequest(
    platform: (json..expectOnly(_keys)).wire('platform', AppPlatform.values),
    appVersion: json.str('app_version'),
    osVersion: json.str('os_version'),
    locale: json.str('locale'),
  );

  static const _keys = {'platform', 'app_version', 'os_version', 'locale'};

  final AppPlatform platform;
  final String appVersion;
  final String osVersion;

  /// BCP 47 tag, e.g. `pl-PL`.
  final String locale;

  JsonMap toJson() => {
    'platform': platform.wire,
    'app_version': appVersion,
    'os_version': osVersion,
    'locale': locale,
  };
}

/// `POST /v1/auth/refresh` and `POST /v1/auth/logout` body.
final class RefreshTokenRequest {
  const RefreshTokenRequest(this.refreshToken);

  factory RefreshTokenRequest.fromJson(JsonMap json) => RefreshTokenRequest(
    (json..expectOnly(const {'refresh_token'})).str('refresh_token'),
  );

  final String refreshToken;

  JsonMap toJson() => {'refresh_token': refreshToken};
}

/// `UserProfile` inside auth and `/v1/me` responses.
final class UserProfile {
  const UserProfile({
    required this.userId,
    required this.createdAt,
    required this.locale,
    required this.consentAnalytics,
    required this.consentAdsPersonalized,
    required this.gamesCompleted,
    this.displayName,
    this.ageBand,
    this.countryCode,
    this.consentUpdatedAt,
    this.analyticsUid,
  });

  factory UserProfile.fromJson(JsonMap json) => UserProfile(
    userId: json.str('user_id'),
    createdAt: json.str('created_at'),
    displayName: json.optStr('display_name'),
    locale: json.str('locale'),
    ageBand: json.optStr('age_band'),
    countryCode: json.optStr('country_code'),
    consentAnalytics: json.boolean('consent_analytics'),
    consentAdsPersonalized: json.boolean('consent_ads_personalized'),
    consentUpdatedAt: json.optStr('consent_updated_at'),
    gamesCompleted: json.integer('games_completed'),
    analyticsUid: json.optStr('analytics_uid'),
  );

  final String userId;
  final String createdAt;
  final String? displayName;
  final String locale;

  /// `AgeBand` wire value (see `core/privacy/age_band.dart`).
  final String? ageBand;
  final String? countryCode;
  final bool consentAnalytics;
  final bool consentAdsPersonalized;
  final String? consentUpdatedAt;
  final int gamesCompleted;

  /// HMAC of `user_id` for GA4 `setUserId` (brief §4.1 `User`). Contract
  /// gap: packages/protocol `UserProfile` does not define it yet, so the
  /// server may never send it; the app then simply sets no analytics user.
  final String? analyticsUid;

  JsonMap toJson() => {
    'user_id': userId,
    'created_at': createdAt,
    'display_name': ?displayName,
    'locale': locale,
    'age_band': ?ageBand,
    'country_code': ?countryCode,
    'consent_analytics': consentAnalytics,
    'consent_ads_personalized': consentAdsPersonalized,
    'consent_updated_at': ?consentUpdatedAt,
    'games_completed': gamesCompleted,
    'analytics_uid': ?analyticsUid,
  };
}

/// `POST /v1/auth/guest` (`GuestAuthResponse`) and `POST /v1/auth/refresh`
/// (`TokenPair`) responses. Parsing is lenient where the app has fallbacks:
/// the TTL may come from the JWT and the refresh response has no user.
final class AuthTokensResponse {
  const AuthTokensResponse({
    required this.accessToken,
    required this.refreshToken,
    this.accessTokenTtlMs,
    this.installationId,
    this.user,
  });

  factory AuthTokensResponse.fromJson(JsonMap json) {
    final user = json.optObj('user');
    return AuthTokensResponse(
      accessToken: json.str('access_token'),
      refreshToken: json.str('refresh_token'),
      accessTokenTtlMs: json.optInt('access_token_ttl_ms'),
      installationId: json.optStr('installation_id'),
      user: user == null ? null : UserProfile.fromJson(user),
    );
  }

  final String accessToken;
  final String refreshToken;
  final int? accessTokenTtlMs;
  final String? installationId;

  /// Guest creation only.
  final UserProfile? user;

  JsonMap toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'access_token_ttl_ms': ?accessTokenTtlMs,
    'installation_id': ?installationId,
    'user': ?user?.toJson(),
  };
}

/// `PATCH /v1/me` body; at least one field. The server accepts `age_band`
/// only while the account has none (409 `conflict` afterwards), so a band
/// can never be raised past the age gate (brief §7).
final class MePatchRequest {
  const MePatchRequest({this.displayName, this.locale, this.ageBand});

  factory MePatchRequest.fromJson(JsonMap json) {
    json.expectOnly(const {'display_name', 'locale', 'age_band'});
    if (json.isEmpty) {
      throw const ProtocolFormatException('PATCH /v1/me needs a field');
    }
    final band = json.optStr('age_band');
    final ageBand = AgeBand.fromWire(band);
    if (band != null && ageBand == null) {
      throw ProtocolFormatException('unknown age_band "$band"');
    }
    return MePatchRequest(
      displayName: json.optStr('display_name'),
      locale: json.optStr('locale'),
      ageBand: ageBand,
    );
  }

  final String? displayName;
  final String? locale;
  final AgeBand? ageBand;

  JsonMap toJson() => {
    'display_name': ?displayName,
    'locale': ?locale,
    'age_band': ?ageBand?.wireName,
  };
}

// ---------------------------------------------------------------------------
// Problems (RFC 9457)
// ---------------------------------------------------------------------------

final class ProblemFieldError {
  const ProblemFieldError({required this.path, required this.message});

  factory ProblemFieldError.fromJson(JsonMap json) =>
      ProblemFieldError(path: json.str('path'), message: json.str('message'));

  /// JSON Pointer into the request body, e.g. `/room_code`.
  final String path;
  final String message;

  JsonMap toJson() => {'path': path, 'message': message};
}

/// `application/problem+json` error body.
final class Problem {
  const Problem({
    required this.type,
    required this.title,
    required this.status,
    required this.code,
    this.detail,
    this.instance,
    this.errors,
  });

  factory Problem.fromJson(JsonMap json) => Problem(
    type: json.str('type'),
    title: json.str('title'),
    status: json.integer('status'),
    code: json.str('code'),
    detail: json.optStr('detail'),
    instance: json.optStr('instance'),
    errors: json.optList(
      'errors',
      (item) => ProblemFieldError.fromJson(asObject(item)),
    ),
  );

  final String type;
  final String title;
  final int status;

  /// See `ErrorCodes`; the set is open-ended.
  final String code;
  final String? detail;
  final String? instance;

  /// Present for `validation_failed`.
  final List<ProblemFieldError>? errors;

  JsonMap toJson() => {
    'type': type,
    'title': title,
    'status': status,
    'code': code,
    'detail': ?detail,
    'instance': ?instance,
    'errors': ?errors?.map((e) => e.toJson()).toList(),
  };
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
      return SongPick(position: position, song: song);
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
  const SongPick({required super.position, required this.song});

  final Song song;

  @override
  String get title => song.title;

  @override
  List<String> get artists => song.artists;

  @override
  JsonMap toJson() => {
    'position': position,
    'song_id': song.songId,
    'song': song.toJson(),
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

/// `PUT /v1/me/picks` body: exactly one ordered list, `song_ids` (A2.3,
/// preferred) or the legacy `catalog_track_ids`.
final class PicksUpdateRequest {
  const PicksUpdateRequest.songs(List<String> this.songIds)
    : catalogTrackIds = null;

  const PicksUpdateRequest.legacyCatalog(List<String> this.catalogTrackIds)
    : songIds = null;

  factory PicksUpdateRequest.fromJson(JsonMap json) {
    json.expectOnly(const {'song_ids', 'catalog_track_ids'});
    if (json.length != 1) {
      throw const ProtocolFormatException(
        'exactly one of song_ids and catalog_track_ids',
      );
    }
    final songs = json.optList('song_ids', asString);
    return songs != null
        ? PicksUpdateRequest.songs(songs)
        : PicksUpdateRequest.legacyCatalog(
            json.list('catalog_track_ids', asString),
          );
  }

  /// Protocol bounds of the list (`PICKS_MIN` / `PICKS_MAX`).
  static const minPicks = 5;
  static const maxPicks = 10;

  final List<String>? songIds;
  final List<String>? catalogTrackIds;

  JsonMap toJson() => {
    'song_ids': ?songIds,
    'catalog_track_ids': ?catalogTrackIds,
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
      json.expectOnly(const {'song_id', 'rank', 'hidden'});
      return SongPoolTrack(
        songId: json.str('song_id'),
        rank: json.optInt('rank'),
        hidden: json.optBool('hidden'),
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
  const SongPoolTrack({required this.songId, super.rank, super.hidden});

  final String songId;

  @override
  JsonMap toJson() => {'song_id': songId, 'rank': ?rank, 'hidden': ?hidden};
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
