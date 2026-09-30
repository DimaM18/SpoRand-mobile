// Pigeon definition of the scheduled clip player used by the playback device
// for `test_catalog` and `licensed_clips` (brief §5 "When the audio started").
//
// Regenerate from apps/mobile:
//   dart run pigeon --input pigeons/clip_player.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'sporand_native',
    dartOut: 'packages/sporand_native/lib/src/clip_player_api.g.dart',
    kotlinOut: 'packages/sporand_native/android/src/main/kotlin/dev/brandtbd/sporand_native/ClipPlayerApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.brandtbd.sporand_native',
      errorClassName: 'NativeBridgeError',
      includeErrorClass: false,
    ),
    swiftOut: 'packages/sporand_native/ios/sporand_native/Sources/sporand_native/ClipPlayerApi.g.swift',
    swiftOptions: SwiftOptions(
      errorClassName: 'NativeBridgeError',
      includeErrorClass: false,
    ),
  ),
)
/// `round.playback_started.output_route`.
enum OutputRouteMessage { speaker, wired, bluetooth, airplay, other }

/// One snippet of a signed clip URL (`round.prepare.clip`).
class ClipSourceMessage {
  ClipSourceMessage({
    required this.clipUrl,
    required this.snippetStartMs,
    required this.snippetDurationMs,
    this.clipRef,
  });

  String clipUrl;

  /// Matches a `game.starting.prefetch[].clip_ref` already in the cache.
  String? clipRef;
  int snippetStartMs;
  int snippetDurationMs;
}

class PreloadResultMessage {
  PreloadResultMessage({
    required this.ok,
    required this.preloadMs,
    this.errorCode,
  });

  bool ok;
  int preloadMs;

  /// snake_case failure code for `round.playback_failed.reason`.
  String? errorCode;
}

class PlaybackStartedMessage {
  PlaybackStartedMessage({
    required this.audioStartMonoUs,
    required this.outputLatencyMs,
    required this.outputRoute,
  });

  /// When the audio started, on the input clock (InputClockApi base).
  int audioStartMonoUs;

  /// iOS: `AVAudioSession.outputLatency`; Android: best estimate or 0.
  int outputLatencyMs;
  OutputRouteMessage outputRoute;
}

@HostApi()
abstract class ClipPlayerApi {
  /// Downloads a clip into the app's temporary cache (`game.starting`
  /// prefetch). Only called when the provider allows prefetching.
  @async
  PreloadResultMessage prefetch(String clipRef, String clipUrl);

  /// Loads the clip, positions it at the snippet start and prepares the audio
  /// output. Never produces sound.
  @async
  PreloadResultMessage prepare(ClipSourceMessage clip);

  /// Starts the prepared clip at [startAtMonoUs] on the input clock and
  /// completes once playback has started. Plays at most the snippet.
  /// iOS: `AVAudioPlayer.play(atTime:)` mapped through `deviceCurrentTime`.
  /// Android: `Handler.postAtTime` on the uptime clock, then `play()`.
  @async
  PlaybackStartedMessage playAt(int startAtMonoUs);

  /// Stops playback and releases the prepared clip.
  void stop();

  /// Releases the player and deletes every cached clip (licensing: clips are
  /// kept only in memory or temporary cache for the duration of a game).
  void dispose();
}
