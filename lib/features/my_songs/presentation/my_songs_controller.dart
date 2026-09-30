import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/features/lobby/presentation/active_room_controller.dart';
import 'package:sporand/features/my_songs/data/my_songs_api.dart';
import 'package:sporand/features/my_songs/domain/picks_limits.dart';

final mySongsApiProvider = Provider<MySongsApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return client == null ? FakeMySongsApi() : HttpMySongsApi(client);
});

/// The id a pick is saved and removed by.
String pickId(CatalogPick pick) => switch (pick) {
  SongPick(:final song) => song.songId,
  LegacyCatalogPick(:final track) => track.catalogTrackId,
};

/// What identifies a saved pick: its id and its linked video.
String pickKey(CatalogPick pick) => switch (pick) {
  SongPick(:final song, :final youtubeVideoId) =>
    '${song.songId}|${youtubeVideoId ?? ''}',
  LegacyCatalogPick(:final track) => track.catalogTrackId,
};

/// The first YouTube link in pasted or shared text (a share often adds a
/// title around it), or null. The server does the real parsing and
/// normalization (`parseYouTubeUrl`); this only picks the candidate.
/// [новое имя — согласовать]
String? extractYouTubeLink(String text) {
  final match = RegExp(
    r'(?:https?://)?(?:[a-z0-9-]+\.)*(?:youtube\.com|youtube-nocookie\.com|youtu\.be)/\S+',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(0);
}

/// The result of resolving a pasted YouTube link. [новое имя — согласовать]
sealed class YouTubeLinkResult {
  const YouTubeLinkResult();
}

final class YouTubeLinkResolved extends YouTubeLinkResult {
  const YouTubeLinkResolved(this.video);

  final YouTubeResolveResponse video;
}

enum YouTubeLinkError { invalid, notFound, notEmbeddable, failed }

final class YouTubeLinkFailed extends YouTubeLinkResult {
  const YouTubeLinkFailed(this.error);

  final YouTubeLinkError error;
}

final class MySongsState {
  const MySongsState({
    required this.limits,
    this.loading = true,
    this.loadFailed = false,
    this.picks = const [],
    this.savedIds = const [],
    this.query = '',
    this.results = const [],
    this.searching = false,
    this.searchFailed = false,
    this.saving = false,
    this.videos = const {},
  });

  final PicksLimits limits;
  final bool loading;
  final bool loadFailed;

  /// The current selection, in order.
  final List<CatalogPick> picks;

  /// [pickKey]s as last loaded or saved (to know whether there is anything
  /// to save).
  final List<String> savedIds;
  final String query;
  final List<Song> results;
  final bool searching;
  final bool searchFailed;
  final bool saving;

  /// Title and channel of videos linked in this session, by song id: shown
  /// as text only, kept in memory only (nothing of YouTube is stored on the
  /// device).
  final Map<String, YouTubeResolveResponse> videos;

  int get count => picks.length;
  bool get full => count >= limits.max;
  int get missing => math.max(0, limits.min - count);

  /// Legacy catalogue picks cannot be saved as songs: they must be replaced.
  bool get hasLegacy => picks.any((p) => p is LegacyCatalogPick);

  bool get dirty {
    if (savedIds.length != picks.length) return true;
    for (var i = 0; i < picks.length; i++) {
      if (pickKey(picks[i]) != savedIds[i]) return true;
    }
    return false;
  }

  bool get canSave =>
      !loading &&
      !saving &&
      dirty &&
      !hasLegacy &&
      count >= limits.min &&
      count <= limits.max;

  bool isPicked(String songId) => picks.any((p) => pickId(p) == songId);

  MySongsState copyWith({
    bool? loading,
    bool? loadFailed,
    List<CatalogPick>? picks,
    List<String>? savedIds,
    String? query,
    List<Song>? results,
    bool? searching,
    bool? searchFailed,
    bool? saving,
    Map<String, YouTubeResolveResponse>? videos,
  }) => MySongsState(
    limits: limits,
    loading: loading ?? this.loading,
    loadFailed: loadFailed ?? this.loadFailed,
    picks: picks ?? this.picks,
    savedIds: savedIds ?? this.savedIds,
    query: query ?? this.query,
    results: results ?? this.results,
    searching: searching ?? this.searching,
    searchFailed: searchFailed ?? this.searchFailed,
    saving: saving ?? this.saving,
    videos: videos ?? this.videos,
  );
}

final mySongsControllerProvider =
    NotifierProvider.autoDispose<MySongsController, MySongsState>(
      MySongsController.new,
    );

/// «Мои песни» (addendum A2.3): search songs (debounced), pick
/// [PicksLimits.min]–[PicksLimits.max] of them and save them to the profile
/// with `PUT /v1/me/picks`. No artwork anywhere: songs are shown as
/// generated cards.
class MySongsController extends Notifier<MySongsState> {
  /// Wait this long after the last keystroke before searching.
  static const debounce = Duration(milliseconds: 350);

  /// Shorter queries are not sent (the search would match everything).
  static const minQueryLength = 2;

  Timer? _debounce;

  /// Bumped by every search, so a slow older response cannot replace the
  /// results of a newer query.
  int _searchSeq = 0;

  MySongsApi get _api => ref.read(mySongsApiProvider);

  @override
  MySongsState build() {
    ref.onDispose(() => _debounce?.cancel());
    final config = ref.read(roomSessionProvider)?.config;
    unawaited(Future.microtask(load));
    return MySongsState(limits: PicksLimits.of(config));
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, loadFailed: false);
    try {
      final picks = await _api.picks();
      if (!ref.mounted) return;
      state = state.copyWith(
        loading: false,
        picks: picks,
        savedIds: [for (final p in picks) pickKey(p)],
      );
    } on Object {
      if (ref.mounted) state = state.copyWith(loading: false, loadFailed: true);
    }
  }

  /// The search field changed.
  void setQuery(String raw) {
    final query = raw.trim();
    _debounce?.cancel();
    if (query == state.query) return;
    if (query.length < minQueryLength) {
      _searchSeq++;
      state = state.copyWith(
        query: query,
        results: const [],
        searching: false,
        searchFailed: false,
      );
      return;
    }
    state = state.copyWith(query: query);
    _debounce = Timer(debounce, () => unawaited(_search(query)));
  }

  Future<void> _search(String query) async {
    final seq = ++_searchSeq;
    state = state.copyWith(searching: true, searchFailed: false);
    try {
      final results = await _api.search(query);
      if (!ref.mounted || seq != _searchSeq) return;
      state = state.copyWith(results: results, searching: false);
    } on Object {
      if (!ref.mounted || seq != _searchSeq) return;
      state = state.copyWith(
        results: const [],
        searching: false,
        searchFailed: true,
      );
    }
  }

  /// Returns false when the selection is full or already has [song].
  bool add(Song song) {
    if (state.full || state.isPicked(song.songId)) return false;
    state = state.copyWith(
      picks: [
        ...state.picks,
        SongPick(position: state.count + 1, song: song),
      ],
    );
    return true;
  }

  void remove(String id) {
    final picks = [
      for (final p in state.picks)
        if (pickId(p) != id) p,
    ];
    state = state.copyWith(
      picks: [
        for (final (index, p) in picks.indexed)
          switch (p) {
            SongPick() => p.withPosition(index + 1),
            LegacyCatalogPick(:final track) => LegacyCatalogPick(
              position: index + 1,
              track: track,
            ),
          },
      ],
    );
  }

  /// Resolves pasted or shared text with a YouTube link
  /// (`POST /v1/songs/youtube/resolve`); nothing is linked yet.
  Future<YouTubeLinkResult> resolveYouTube(String text) async {
    final link = extractYouTubeLink(text.trim());
    if (link == null) return const YouTubeLinkFailed(YouTubeLinkError.invalid);
    try {
      return YouTubeLinkResolved(await _api.resolveYouTube(link));
    } on ApiError catch (error) {
      return YouTubeLinkFailed(switch (error.status) {
        400 => YouTubeLinkError.invalid,
        404 => YouTubeLinkError.notFound,
        409 => YouTubeLinkError.notEmbeddable,
        _ => YouTubeLinkError.failed,
      });
    } on Object {
      return const YouTubeLinkFailed(YouTubeLinkError.failed);
    }
  }

  /// Links [video] to the picked song [songId] (saved with «Сохранить»).
  void linkVideo(String songId, YouTubeResolveResponse video) =>
      _setVideo(songId, video);

  void unlinkVideo(String songId) => _setVideo(songId, null);

  void _setVideo(String songId, YouTubeResolveResponse? video) {
    if (!state.isPicked(songId)) return;
    state = state.copyWith(
      picks: [
        for (final p in state.picks)
          if (p is SongPick && p.song.songId == songId)
            p.withVideo(video?.videoId)
          else
            p,
      ],
      videos: {
        for (final MapEntry(:key, :value) in state.videos.entries)
          if (key != songId) key: value,
        songId: ?video,
      },
    );
  }

  /// `PUT /v1/me/picks` with the selection in order. True on success.
  Future<bool> save() async {
    if (!state.canSave) return false;
    state = state.copyWith(saving: true);
    try {
      final saved = await _api.savePicks(
        [for (final p in state.picks) pickId(p)],
        videos: {
          for (final p in state.picks)
            if (p case SongPick(:final song, :final youtubeVideoId?))
              song.songId: youtubeVideoId,
        },
      );
      if (!ref.mounted) return true;
      state = state.copyWith(
        saving: false,
        picks: saved,
        savedIds: [for (final p in saved) pickKey(p)],
      );
      return true;
    } on Object {
      if (ref.mounted) state = state.copyWith(saving: false);
      return false;
    }
  }
}
