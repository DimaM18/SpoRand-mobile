/// Music provider ids (brief §1.3).
enum MusicProviderId {
  testCatalog('test_catalog'),
  spotifyAppRemote('spotify_app_remote'),
  licensedClips('licensed_clips');

  const MusicProviderId(this.wireName);

  final String wireName;
}

/// Client-side playback abstraction (brief §1.3 `PlaybackAdapter`). Game
/// logic never reads provider-specific fields.
abstract interface class PlaybackAdapter {
  MusicProviderId get provider;

  /// Prepares the provider (audio session, native bridge). Never plays audio.
  Future<void> initialize();
}

/// `test_catalog` / `licensed_clips`: scheduled playback through the
/// `ClipPlayerApi` Pigeon bridge (part 2). Nothing to warm up yet.
final class ClipPlaybackAdapter implements PlaybackAdapter {
  ClipPlaybackAdapter(this.provider);

  @override
  final MusicProviderId provider;

  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;
}

final class FakePlaybackAdapter implements PlaybackAdapter {
  FakePlaybackAdapter({this.provider = MusicProviderId.testCatalog});

  @override
  final MusicProviderId provider;
  bool initialized = false;

  @override
  Future<void> initialize() async => initialized = true;
}
