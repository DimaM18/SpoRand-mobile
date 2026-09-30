import 'package:flutter/services.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/playback/playback_adapter.dart';
import 'package:sporand_native/sporand_native.dart';

/// `test_catalog` / `licensed_clips`: scheduled playback through the Pigeon
/// `ClipPlayerApi` (package sporand_native).
///
/// iOS plays with `AVAudioPlayer.play(atTime:)` mapped through
/// `deviceCurrentTime`; Android starts a prepared media3 ExoPlayer with
/// `Handler.postAtTime` on the uptime clock (brief §5).
final class ClipPlayerAdapter implements PlaybackAdapter {
  ClipPlayerAdapter(this.provider, {ClipPlayerApi? api})
    : _api = api ?? ClipPlayerApi();

  final ClipPlayerApi _api;

  @override
  final MusicProviderId provider;

  @override
  AudioStartSource get startSource => AudioStartSource.scheduled;

  @override
  Future<void> initialize() async {
    // Nothing to warm up: the audio session is configured per clip, so the
    // app never takes audio focus before a game.
  }

  @override
  Future<PreloadOutcome> prefetch(PrefetchClip clip) async {
    try {
      return _outcome(await _api.prefetch(clip.clipRef, clip.clipUrl));
    } on PlatformException catch (e) {
      return PreloadOutcome(ok: false, preloadMs: 0, error: _reason(e));
    }
  }

  @override
  Future<PreloadOutcome> prepare(PlaybackClip clip) async {
    if (clip is! UrlRoundClip) {
      return const PreloadOutcome(
        ok: false,
        preloadMs: 0,
        error: PlaybackFailure.playerError,
      );
    }
    try {
      return _outcome(
        await _api.prepare(
          ClipSourceMessage(
            clipUrl: clip.clipUrl,
            clipRef: clip.clipRef,
            snippetStartMs: clip.snippetStartMs,
            snippetDurationMs: clip.snippetDurationMs,
          ),
        ),
      );
    } on PlatformException catch (e) {
      return PreloadOutcome(ok: false, preloadMs: 0, error: _reason(e));
    }
  }

  @override
  Future<PlaybackStarted> playAt(int startAtMonoUs) async {
    final PlaybackStartedMessage started;
    try {
      started = await _api.playAt(startAtMonoUs);
    } on PlatformException catch (e) {
      throw PlaybackFailure(_reason(e));
    }
    return PlaybackStarted(
      audioStartMonoUs: started.audioStartMonoUs,
      outputLatencyMs: started.outputLatencyMs,
      outputRoute: switch (started.outputRoute) {
        OutputRouteMessage.speaker => OutputRoute.speaker,
        OutputRouteMessage.wired => OutputRoute.wired,
        OutputRouteMessage.bluetooth => OutputRoute.bluetooth,
        OutputRouteMessage.airplay => OutputRoute.airplay,
        OutputRouteMessage.other => OutputRoute.other,
      },
      source: PlaybackStartSource.scheduled,
    );
  }

  @override
  Future<void> stop() async {
    try {
      await _api.stop();
    } on PlatformException {
      // Nothing was playing.
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await _api.dispose();
    } on PlatformException {
      // Already released.
    }
  }

  static PreloadOutcome _outcome(PreloadResultMessage result) => PreloadOutcome(
    ok: result.ok,
    preloadMs: result.preloadMs,
    error: result.ok
        ? null
        : (result.errorCode ?? PlaybackFailure.clipLoadFailed),
  );

  /// Native error codes are already snake_case failure reasons.
  static String _reason(PlatformException e) =>
      RegExp(r'^[a-z][a-z0-9_]{0,63}$').hasMatch(e.code)
      ? e.code
      : PlaybackFailure.playerError;
}
