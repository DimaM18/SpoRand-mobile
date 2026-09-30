// Pigeon definition of the Spotify App Remote bridge (spotifyProto flavor
// only, brief §3). NOT generated yet: TODO(owner, Q1) add ConfigurePigeon
// outputs once the SpotifyiOS.xcframework is vendored (the spotify_sdk 4.0.0
// iOS package ships an empty one, issue #272 / brief F16) and the Android
// App Remote AAR is added. The Dart side (SpotifyRemoteBridge,
// SpotifyRemotePlaybackAdapter) is already written against this shape.
import 'package:pigeon/pigeon.dart';

class SpotifyPlayerStateMessage {
  SpotifyPlayerStateMessage({
    required this.isPaused,
    required this.playbackPositionMs,
    required this.receiptOsUs,
    this.trackUri,
  });

  bool isPaused;
  int playbackPositionMs;

  /// Stamped natively on the raw OS input clock when the callback arrived;
  /// the Dart side converts it with `InputClock.fromOsUs`.
  int receiptOsUs;
  String? trackUri;
}

@HostApi()
abstract class SpotifyRemoteApi {
  @async
  void connect();

  @async
  void play(String spotifyUri);

  @async
  void seekTo(int positionMs);

  @async
  void pause();

  @async
  void disconnect();
}

@FlutterApi()
abstract class SpotifyPlayerStateListener {
  void onPlayerState(SpotifyPlayerStateMessage state);
}
