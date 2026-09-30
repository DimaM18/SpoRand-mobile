import 'package:sporand/core/net/protocol/ws_messages.dart';
import 'package:sporand/core/playback/playback_adapter.dart';

/// The playback device's (host's) half of a round (brief §5 "When the audio
/// started"): prefetch, prepare, start at `start_at_mono_us`, and report
/// `round.preloaded` / `round.playback_started` / `round.playback_failed`.
class HostPlaybackCoordinator {
  HostPlaybackCoordinator({
    required this._adapter,
    required this._send,
    this._log,
  });

  final PlaybackAdapter _adapter;
  final bool Function(ClientMessage message) _send;
  final void Function(String message)? _log;

  String? _currentRoundId;
  bool _disposed = false;

  PlaybackAdapter get adapter => _adapter;

  /// `game.starting.prefetch`: caches clips (only sent when the provider
  /// allows prefetching) and reports each one that names its round.
  Future<void> prefetch(GameStarting message) async {
    for (final clip in message.prefetch) {
      if (_disposed) return;
      final outcome = await _adapter.prefetch(clip);
      final roundId = clip.roundId;
      if (roundId != null) {
        _send(
          RoundPreloaded(
            roundId: roundId,
            ok: outcome.ok,
            preloadMs: outcome.preloadMs,
          ),
        );
      }
    }
  }

  /// Prepares and starts this round's clip. Returns the start report, or
  /// null when playback failed or a newer round superseded this one.
  Future<PlaybackStarted?> playRound(RoundPrepare message) async {
    final clip = message.clip;
    if (clip == null || _disposed) return null;
    final roundId = message.roundId;
    _currentRoundId = roundId;

    final preload = await _adapter.prepare(clip);
    if (!_isCurrent(roundId)) return null;
    _send(
      RoundPreloaded(
        roundId: roundId,
        ok: preload.ok,
        preloadMs: preload.preloadMs,
      ),
    );
    if (!preload.ok) {
      _send(
        RoundPlaybackFailed(
          roundId: roundId,
          reason: preload.error ?? PlaybackFailure.clipLoadFailed,
        ),
      );
      return null;
    }

    try {
      final started = await _adapter.playAt(message.startAtMonoUs);
      if (!_isCurrent(roundId)) return null;
      _send(
        RoundPlaybackStarted(
          roundId: roundId,
          audioStartMonoUs: started.audioStartMonoUs,
          outputLatencyMs: started.outputLatencyMs,
          outputRoute: started.outputRoute,
          source: started.source,
        ),
      );
      return started;
    } on PlaybackFailure catch (e) {
      _log?.call('playback failed: ${e.reason}');
      if (_isCurrent(roundId)) {
        _send(RoundPlaybackFailed(roundId: roundId, reason: e.reason));
      }
      return null;
    }
  }

  bool _isCurrent(String roundId) => !_disposed && _currentRoundId == roundId;

  /// Silence before ads, on a voided round and at the end of the game.
  Future<void> stop() async {
    _currentRoundId = null;
    await _adapter.stop();
  }

  Future<void> dispose() async {
    _disposed = true;
    _currentRoundId = null;
    await _adapter.stop();
    await _adapter.dispose();
  }
}
