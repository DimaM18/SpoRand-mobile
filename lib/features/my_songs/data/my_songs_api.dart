import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/json_read.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';

/// «Мои песни» endpoints (addendum A2.3): the MusicBrainz-backed song search
/// and the player's saved picks. [новое имя — согласовать] `MySongsApi`.
abstract interface class MySongsApi {
  /// `GET /v1/songs/search?q=&limit=`.
  Future<List<Song>> search(String query, {int limit = 10});

  /// `GET /v1/me/picks`, ordered by position.
  Future<List<CatalogPick>> picks();

  /// `PUT /v1/me/picks` with `song_ids` in this order.
  Future<List<CatalogPick>> savePicks(List<String> songIds);
}

final class HttpMySongsApi implements MySongsApi {
  HttpMySongsApi(this._client);

  final ApiClient _client;

  @override
  Future<List<Song>> search(String query, {int limit = 10}) async {
    final json = await _client.get(
      '/v1/songs/search',
      query: SongSearchQuery(q: query, limit: limit).toQueryParameters(),
    );
    return _parse(json, SongSearchResponse.fromJson).items;
  }

  @override
  Future<List<CatalogPick>> picks() async => _sorted(
    _parse(await _client.get('/v1/me/picks'), PicksResponse.fromJson),
  );

  @override
  Future<List<CatalogPick>> savePicks(List<String> songIds) async {
    final json = await _client.put(
      '/v1/me/picks',
      body: PicksUpdateRequest.songs(songIds).toJson(),
    );
    return _sorted(_parse(json, PicksResponse.fromJson));
  }

  static List<CatalogPick> _sorted(PicksResponse response) =>
      [...response.picks]..sort((a, b) => a.position.compareTo(b.position));

  static T _parse<T>(JsonMap json, T Function(JsonMap json) fromJson) {
    try {
      return fromJson(json);
    } on ProtocolFormatException {
      throw const ApiError(code: ApiError.invalidResponse);
    }
  }
}

/// In-memory songs for dev builds without a backend and for tests: search
/// matches titles and artists case-insensitively.
final class FakeMySongsApi implements MySongsApi {
  FakeMySongsApi({List<Song>? catalog, List<CatalogPick>? picks})
    : catalog = catalog ?? sampleSongs,
      _picks = picks ?? const [];

  static final sampleSongs = [
    for (final (index, (title, artist, year)) in const [
      ('Northern Lights', 'Test Artist', 2019),
      ('Paper Boats', 'Sample Band', 2021),
      ('Neon Rain', 'Placeholder Trio', 2015),
      ('Slow River', 'Test Artist', 2008),
      ('Glass Hearts', 'Example Choir', 2012),
      ('Midnight Tram', 'Sample Band', 2017),
      ('Orange Skies', 'Demo Quartet', 2003),
      ('Silver Lining', 'Test Artist', 2023),
      ('Harbour Lights', 'Example Choir', 1998),
      ('City Echoes', 'Placeholder Trio', 2011),
      ('Wild Mint', 'Demo Quartet', 2020),
      ('Last Summer', 'Sample Band', 2009),
    ].indexed)
      Song(
        songId:
            '0192b1a0-0000-7000-8000-000000000d${(index + 1).toRadixString(16).padLeft(2, '0')}',
        title: title,
        artistCredit: artist,
        artists: [artist],
        primaryArtist: artist,
        year: year,
        explicit: false,
        isrcs: const [],
      ),
  ];

  final List<Song> catalog;
  List<CatalogPick> _picks;
  final List<String> queries = [];
  final List<List<String>> saved = [];

  /// Thrown by the next calls, e.g. `ApiError(code: ApiError.network)`.
  Object? failWith;

  @override
  Future<List<Song>> search(String query, {int limit = 10}) async {
    queries.add(query);
    final error = failWith;
    if (error != null) throw error;
    final q = query.toLowerCase();
    return [
      for (final song in catalog)
        if (song.title.toLowerCase().contains(q) ||
            song.artistCredit.toLowerCase().contains(q))
          song,
    ].take(limit).toList();
  }

  @override
  Future<List<CatalogPick>> picks() async {
    final error = failWith;
    if (error != null) throw error;
    return _picks;
  }

  @override
  Future<List<CatalogPick>> savePicks(List<String> songIds) async {
    final error = failWith;
    if (error != null) throw error;
    saved.add(songIds);
    final byId = {for (final s in catalog) s.songId: s};
    return _picks = [
      for (final (index, id) in songIds.indexed)
        if (byId[id] case final song?)
          SongPick(position: index + 1, song: song),
    ];
  }
}
