import 'dart:io';

/// The server under test: `--dart-define=API_BASE_URL=http://127.0.0.1:<port>`
/// (what `scripts/e2e.sh` passes), else the `E2E_API_BASE_URL` environment
/// variable. Null when neither is set: the suites then skip.
Uri? e2eApiBaseUrl() {
  const defined = String.fromEnvironment('API_BASE_URL');
  final raw = defined.isNotEmpty
      ? defined
      : Platform.environment['E2E_API_BASE_URL'] ?? '';
  return raw.isEmpty ? null : Uri.parse(raw);
}

/// The second server of `scripts/e2e.sh` (`E2E_GUESS_TRACK_API_BASE_URL`):
/// the same config plus the hidden mode guess_track in `modes_enabled`
/// (wave 4 hides it by default). Null when it is not running.
/// [новое имя — согласовать]
Uri? e2eGuessTrackApiBaseUrl() {
  final raw = Platform.environment['E2E_GUESS_TRACK_API_BASE_URL'] ?? '';
  return raw.isEmpty ? null : Uri.parse(raw);
}

/// `skip:` value for the guess_track suite.
Object e2eGuessTrackSkip() => e2eGuessTrackApiBaseUrl() == null
    ? 'no guess_track server: run scripts/e2e.sh (or set '
          'E2E_GUESS_TRACK_API_BASE_URL to a server whose modes_enabled '
          'includes guess_track)'
    : false;

/// `skip:` value for every end-to-end test.
Object e2eSkip() => e2eApiBaseUrl() == null
    ? 'no server: run scripts/e2e.sh (or pass '
          '--dart-define=API_BASE_URL=http://127.0.0.1:<port>)'
    : false;

/// Fails fast if HTTP is mocked.
///
/// `flutter test` itself does not mock the network, but
/// `TestWidgetsFlutterBinding` does: once initialized (by `testWidgets` or
/// `ensureInitialized`) it sets [HttpOverrides.global] to a client that
/// answers every request, and every WebSocket upgrade, with 400. These suites
/// therefore use plain `test()` and never initialize the widgets binding;
/// this guard turns an accidental binding into a clear error instead of
/// confusing 400s.
void requireRealNetwork() {
  if (HttpOverrides.current != null) {
    throw StateError(
      'HttpOverrides are installed (${HttpOverrides.current.runtimeType}): '
      'the end-to-end suites need real sockets. Do not use testWidgets or '
      'TestWidgetsFlutterBinding in test_e2e/.',
    );
  }
}

/// One clock for the whole test process: the simulated phones' input clocks
/// and every wire timestamp are read from it, so the suites can compare
/// times across phones exactly.
final Stopwatch _e2eWatch = Stopwatch()..start();

/// Microseconds since the test process started (shared by all phones).
int e2eNowUs() => _e2eWatch.elapsedMicroseconds;

/// Writes a progress line to stderr (visible with `--reporter expanded`).
void e2eLog(String line) {
  final ms = (e2eNowUs() / 1000).toStringAsFixed(1).padLeft(9);
  stderr.writeln('[e2e $ms ms] $line');
}

/// The server's log file (`E2E_SERVER_LOG`, set by `scripts/e2e.sh`). The
/// server runs with `ANALYTICS_SINK=console`, so every server analytics
/// event that passed validation and the consent gate is one
/// `{"analytics": {...}}` line in it. Null when the suite runs against a
/// server started some other way.
File? e2eServerLog() {
  final path = Platform.environment['E2E_SERVER_LOG'] ?? '';
  return path.isEmpty ? null : File(path);
}

/// The emoji catalogue the server loaded (`E2E_EMOJI_CATALOG`, passed as
/// `EMOJI_CATALOG_PATH` to the server by `scripts/e2e.sh`), else the seed
/// file in the repository.
File e2eEmojiCatalogFile() {
  final path = Platform.environment['E2E_EMOJI_CATALOG'] ?? '';
  return File(path.isNotEmpty ? path : '../server/data/emoji-songs.seed.json');
}
