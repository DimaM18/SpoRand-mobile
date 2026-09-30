import 'dart:async';

import 'package:sporand/core/clock/input_clock.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/playback_adapter.dart';

/// A Spotify App Remote player-state callback, stamped by native code on
/// the raw OS input clock the moment it arrived.
final class SpotifyPlayerState {
  const SpotifyPlayerState({
    required this.isPaused,
    required this.playbackPositionMs,
    required this.receiptOsUs,
    this.trackUri,
  });

  final bool isPaused;
  final int playbackPositionMs;

  /// Raw OS time; converted with `InputClock.fromOsUs` before use.
  final int receiptOsUs;
  final String? trackUri;
}

/// Brief §5, host-reported source, steps 2–3. Returns `audio_start_mono_us`
/// for the first usable player state, or null when [state] does not qualify
/// ([receiptMonoUs] is its receipt time through the process anchor):
/// - it must be playing (`isPaused == false`);
/// - its position must be at least `snippet_start_ms − 250`, which skips the
///   states from before the seek (App Remote briefly plays the track start
///   after `play`, brief F15);
/// - it must be the expected track when both URIs are known.
///
/// `audio_start_mono_us = receipt − (playbackPosition − snippet_start_ms) × 1000`
/// backdates the receipt to the moment the snippet start was playing.
int? computeAudioStartFromPlayerState({
  required SpotifyPlayerState state,
  required int receiptMonoUs,
  required int snippetStartMs,
  String? expectedUri,
  int positionToleranceMs = 250,
}) {
  if (state.isPaused) return null;
  final uri = state.trackUri;
  if (expectedUri != null && uri != null && uri != expectedUri) return null;
  if (state.playbackPositionMs < snippetStartMs - positionToleranceMs) {
    return null;
  }
  return receiptMonoUs - (state.playbackPositionMs - snippetStartMs) * 1000;
}

/// Dart side of the future Pigeon `SpotifyRemoteApi` (brief §3, spotifyProto
/// flavor only).
///
/// TODO(owner, Q1): implement with Pigeon (`pigeons/spotify_remote.dart`)
/// and the vendored `SpotifyiOS.xcframework` + Android App Remote AAR. The
/// `spotify_sdk` package is deliberately NOT a dependency: its published
/// 4.0.0 iOS package ships an empty `SpotifyiOS.xcframework` (issue #272,
/// brief F16), so it cannot be used as-is; it serves only as a reference.
abstract interface class SpotifyRemoteBridge {
  Future<void> connect();

  Future<void> play(String spotifyUri);

  Future<void> seekTo(int positionMs);

  Future<void> pause();

  /// Player states with native receipt timestamps (raw OS input clock).
  Stream<SpotifyPlayerState> get playerStates;

  Future<void> disconnect();
}

/// Used until the native bridge exists: every call fails with
/// `spotify_not_running`, so the server voids the round cleanly.
final class UnavailableSpotifyRemoteBridge implements SpotifyRemoteBridge {
  const UnavailableSpotifyRemoteBridge();

  Never _fail() =>
      throw const PlaybackFailure(PlaybackFailure.spotifyNotRunning);

  @override
  Future<void> connect() async => _fail();

  @override
  Future<void> play(String spotifyUri) async => _fail();

  @override
  Future<void> seekTo(int positionMs) async => _fail();

  @override
  Future<void> pause() async {}

  @override
  Stream<SpotifyPlayerState> get playerStates => const Stream.empty();

  @override
  Future<void> disconnect() async {}
}

/// `spotify_app_remote` on the host phone (spotifyProto only). The start is
/// host-reported: play → seek → first qualifying player state.
final class SpotifyRemotePlaybackAdapter implements PlaybackAdapter {
  SpotifyRemotePlaybackAdapter({
    required this._bridge,
    required this._clock,
    this.startTimeout = const Duration(milliseconds: 5000),
  });

  final SpotifyRemoteBridge _bridge;
  final InputClock _clock;

  /// `playback_start_timeout_ms`: after it the server voids the round.
  final Duration startTimeout;

  SpotifyRoundClip? _clip;
  Timer? _snippetEnd;
  bool _playing = false;

  /// From the first qualifying player state until a successful pause.
  @override
  bool get isPlaying => _playing;

  @override
  MusicProviderId get provider => MusicProviderId.spotifyAppRemote;

  @override
  AudioStartSource get startSource => AudioStartSource.hostReported;

  @override
  Future<void> initialize() async {}

  @override
  Future<PreloadOutcome> prefetch(PrefetchClip clip) async =>
      // Spotify content is never prefetched (brief §1.3).
      const PreloadOutcome(
        ok: false,
        preloadMs: 0,
        error: 'prefetch_unsupported',
      );

  @override
  Future<PreloadOutcome> prepare(PlaybackClip clip) async {
    if (clip is! SpotifyRoundClip) {
      return const PreloadOutcome(
        ok: false,
        preloadMs: 0,
        error: PlaybackFailure.playerError,
      );
    }
    final started = await _clock.nowMicros();
    try {
      await _bridge.connect();
    } on PlaybackFailure catch (e) {
      return PreloadOutcome(ok: false, preloadMs: 0, error: e.reason);
    }
    _clip = clip;
    final done = await _clock.nowMicros();
    return PreloadOutcome(ok: true, preloadMs: (done - started) ~/ 1000);
  }

  @override
  Future<PlaybackStarted> playAt(int startAtMonoUs) async {
    final clip = _clip;
    if (clip == null) {
      throw const PlaybackFailure(PlaybackFailure.notPrepared);
    }
    final waitUs = startAtMonoUs - await _clock.nowMicros();
    if (waitUs > 0) await Future<void>.delayed(Duration(microseconds: waitUs));

    // Listen before play so the first qualifying state cannot be missed.
    final first = Completer<int>();
    final sub = _bridge.playerStates.listen((state) {
      final start = computeAudioStartFromPlayerState(
        state: state,
        receiptMonoUs: _clock.fromOsUs(state.receiptOsUs),
        snippetStartMs: clip.snippetStartMs,
        expectedUri: clip.spotifyUri,
      );
      if (start != null && !first.isCompleted) first.complete(start);
    });
    try {
      await _bridge.play(clip.spotifyUri);
      await _bridge.seekTo(clip.snippetStartMs);
      final audioStart = await first.future.timeout(
        startTimeout,
        onTimeout: () =>
            throw const PlaybackFailure(PlaybackFailure.startTimeout),
      );
      _playing = true;
      _scheduleSnippetEnd(audioStart, clip.snippetDurationMs);
      return PlaybackStarted(
        audioStartMonoUs: audioStart,
        outputLatencyMs: 0,
        outputRoute: OutputRoute.other,
        source: PlaybackStartSource.playerState,
      );
    } finally {
      // Not awaited: nothing depends on the cancellation finishing.
      unawaited(sub.cancel());
    }
  }

  void _scheduleSnippetEnd(int audioStartMonoUs, int durationMs) {
    _snippetEnd?.cancel();
    unawaited(
      _clock.nowMicros().then((now) {
        final remainingUs = audioStartMonoUs + durationMs * 1000 - now;
        _snippetEnd = Timer(
          Duration(microseconds: remainingUs < 0 ? 0 : remainingUs),
          () => unawaited(stop()),
        );
      }),
    );
  }

  @override
  Future<void> stop() async {
    _snippetEnd?.cancel();
    try {
      await _bridge.pause();
    } on PlaybackFailure {
      // Not connected: nothing is playing.
    }
    _playing = false;
  }

  @override
  Future<void> dispose() async {
    await stop();
    _clip = null;
    await _bridge.disconnect();
  }
}
