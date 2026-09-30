/// Warm-up work for the `warmup` stage. The interface is pure Dart so the
/// pipeline stays unit-testable; the Flutter implementation lives next to it.
abstract interface class ResourceWarmer {
  Future<void> precacheImages();

  Future<void> loadFonts();

  Future<void> loadSoundEffects();

  Future<void> loadAnimations();

  Future<void> warmUpShaders();
}

final class FakeResourceWarmer implements ResourceWarmer {
  FakeResourceWarmer({this.delay = Duration.zero});

  final Duration delay;
  final List<String> calls = [];

  Future<void> _record(String name) async {
    calls.add(name);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<void> precacheImages() => _record('images');

  @override
  Future<void> loadFonts() => _record('fonts');

  @override
  Future<void> loadSoundEffects() => _record('sfx');

  @override
  Future<void> loadAnimations() => _record('animations');

  @override
  Future<void> warmUpShaders() => _record('shaders');
}
