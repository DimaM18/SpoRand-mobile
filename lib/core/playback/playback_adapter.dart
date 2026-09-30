import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';

export 'package:sporand/core/net/protocol/ws_enums.dart' show MusicProviderId;

/// What the playback device must play for one round (`round.prepare.clip`).
typedef PlaybackClip = RoundClip;

/// Outcome of a preload (`round.preloaded{ok, preload_ms}`).
final class PreloadOutcome {
  const PreloadOutcome({required this.ok, required this.preloadMs, this.error});

  final bool ok;
  final int preloadMs;

  /// snake_case reason for `round.playback_failed` when [ok] is false.
  final String? error;
}

/// `round.playback_started` data.
final class PlaybackStarted {
  const PlaybackStarted({
    required this.audioStartMonoUs,
    required this.outputLatencyMs,
    required this.outputRoute,
    required this.source,
  });

  /// When the audio actually started, on the input clock.
  final int audioStartMonoUs;
  final int outputLatencyMs;
  final OutputRoute outputRoute;
  final PlaybackStartSource source;
}

/// Playback failed; [reason] goes to `round.playback_failed.reason`.
final class PlaybackFailure implements Exception {
  const PlaybackFailure(this.reason);

  static const clipLoadFailed = 'clip_load_failed';
  static const playerError = 'player_error';
  static const notPrepared = 'not_prepared';
  static const spotifyNotRunning = 'spotify_not_running';
  static const startTimeout = 'start_timeout';

  /// The room's provider plays no audio in the app (external_player, none).
  static const noAudio = 'no_audio';

  final String reason;

  @override
  String toString() => 'PlaybackFailure($reason)';
}

/// Client-side playback abstraction (brief §1.3 `PlaybackAdapter`): game
/// logic never reads provider-specific fields.
///
/// Licensing rules built in (brief §1.3, point 7): at most the snippet is
/// played, and clips live only in memory or temporary cache until
/// [dispose].
abstract interface class PlaybackAdapter {
  MusicProviderId get provider;

  /// `scheduled` for clip providers, `host_reported` for Spotify and
  /// external_player, `none` for text rounds.
  AudioStartSource get startSource;

  /// Prepares the provider (audio session, native bridge). Never plays.
  Future<void> initialize();

  /// Caches a `game.starting` prefetch entry (only if the provider allows it).
  Future<PreloadOutcome> prefetch(PrefetchClip clip);

  /// Loads [clip] and positions it at the snippet. Never plays.
  Future<PreloadOutcome> prepare(PlaybackClip clip);

  /// Starts the prepared clip at [startAtMonoUs] on the input clock and
  /// completes once audio has started. Throws [PlaybackFailure].
  Future<PlaybackStarted> playAt(int startAtMonoUs);

  Future<void> stop();

  /// Releases the player and purges cached clips.
  Future<void> dispose();
}

/// `external_player` (BYOP) and `none` (text rounds): the app plays nothing
/// (docs/LEGAL_PLAYBACK.md). For external_player the DJ starts the song in
/// their own music app and reports it with `dj_tap` from the round screen,
/// so this adapter only fails loudly if something asks it to play.
/// [новое имя — согласовать]
final class NoAudioPlaybackAdapter implements PlaybackAdapter {
  const NoAudioPlaybackAdapter(this.provider);

  static const _noAudio = PreloadOutcome(
    ok: false,
    preloadMs: 0,
    error: PlaybackFailure.noAudio,
  );

  @override
  final MusicProviderId provider;

  @override
  AudioStartSource get startSource => provider == MusicProviderId.none
      ? AudioStartSource.none
      : AudioStartSource.hostReported;

  @override
  Future<void> initialize() async {}

  @override
  Future<PreloadOutcome> prefetch(PrefetchClip clip) async => _noAudio;

  @override
  Future<PreloadOutcome> prepare(PlaybackClip clip) async => _noAudio;

  @override
  Future<PlaybackStarted> playAt(int startAtMonoUs) async =>
      throw const PlaybackFailure(PlaybackFailure.noAudio);

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

/// Scriptable fake for tests and for builds without a playback device.
final class FakePlaybackAdapter implements PlaybackAdapter {
  FakePlaybackAdapter({
    this.provider = MusicProviderId.testCatalog,
    this.startSource = AudioStartSource.scheduled,
    this.prepareOk = true,
    this.playFailure,
    this.outputRoute = OutputRoute.speaker,
    this.outputLatencyMs = 0,
  });

  @override
  final MusicProviderId provider;

  @override
  final AudioStartSource startSource;

  bool prepareOk;
  String? playFailure;
  OutputRoute outputRoute;
  int outputLatencyMs;

  bool initialized = false;
  bool disposed = false;
  int stops = 0;
  final List<PrefetchClip> prefetched = [];
  final List<PlaybackClip> prepared = [];
  final List<int> playedAt = [];

  @override
  Future<void> initialize() async => initialized = true;

  @override
  Future<PreloadOutcome> prefetch(PrefetchClip clip) async {
    prefetched.add(clip);
    return const PreloadOutcome(ok: true, preloadMs: 5);
  }

  @override
  Future<PreloadOutcome> prepare(PlaybackClip clip) async {
    prepared.add(clip);
    return PreloadOutcome(
      ok: prepareOk,
      preloadMs: 12,
      error: prepareOk ? null : PlaybackFailure.clipLoadFailed,
    );
  }

  @override
  Future<PlaybackStarted> playAt(int startAtMonoUs) async {
    final failure = playFailure;
    if (failure != null) throw PlaybackFailure(failure);
    playedAt.add(startAtMonoUs);
    return PlaybackStarted(
      audioStartMonoUs: startAtMonoUs,
      outputLatencyMs: outputLatencyMs,
      outputRoute: outputRoute,
      source: startSource == AudioStartSource.scheduled
          ? PlaybackStartSource.scheduled
          : PlaybackStartSource.playerState,
    );
  }

  @override
  Future<void> stop() async => stops++;

  @override
  Future<void> dispose() async => disposed = true;
}
