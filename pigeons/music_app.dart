// Pigeon definition of the hand-off to the DJ's own music app
// (external_player / BYOP, addendum A2.2). The app never plays the song: it
// only asks the system to find it in whatever music app the DJ uses.
//
// Regenerate from apps/mobile:
//   dart run pigeon --input pigeons/music_app.dart
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    copyrightHeader: 'pigeons/copyright.txt',
    dartPackageName: 'sporand_native',
    dartOut: 'packages/sporand_native/lib/src/music_app_api.g.dart',
    kotlinOut: 'packages/sporand_native/android/src/main/kotlin/dev/brandtbd/sporand_native/MusicAppApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'dev.brandtbd.sporand_native',
      errorClassName: 'NativeBridgeError',
      includeErrorClass: false,
    ),
    swiftOut: 'packages/sporand_native/ios/sporand_native/Sources/sporand_native/MusicAppApi.g.swift',
    swiftOptions: SwiftOptions(
      errorClassName: 'NativeBridgeError',
      includeErrorClass: false,
    ),
  ),
)
/// The song of `round.prepare.cue` as a system media search.
class MusicSearchMessage {
  MusicSearchMessage({
    required this.title,
    required this.artist,
    required this.query,
  });

  String title;

  /// The first credited artist.
  String artist;

  /// Free-text search, e.g. "Northern Lights Test Artist".
  String query;
}

/// [новое имя — согласовать] `MusicAppApi`.
@HostApi()
abstract class MusicAppApi {
  /// Android: starts `MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH` with
  /// `EXTRA_MEDIA_FOCUS` = audio (`Audio.Media.ENTRY_CONTENT_TYPE`),
  /// `EXTRA_MEDIA_TITLE`, `EXTRA_MEDIA_ARTIST` and `SearchManager.QUERY`.
  /// Returns false when no installed app handles it.
  ///
  /// iOS has no equivalent system intent: always false; the Dart side opens
  /// the cue's `hint_url` instead.
  bool playFromSearch(MusicSearchMessage search);
}
