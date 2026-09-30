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
