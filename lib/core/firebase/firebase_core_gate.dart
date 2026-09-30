import 'package:firebase_core/firebase_core.dart';

/// Initializes Firebase once and shares the result with every Firebase
/// adapter. Without GoogleService-Info.plist / google-services.json the
/// initialization fails; each adapter then reports a degraded boot step and
/// behaves as a no-op instead of crashing.
///
/// TODO(owner): add ios/Runner/GoogleService-Info.plist and
/// android/app/google-services.json (they are git-ignored), or generate
/// `firebase_options.dart` with `flutterfire configure` and pass the options
/// here.
final class FirebaseCoreGate {
  Future<bool>? _ready;

  /// Completes with true when Firebase is usable. Never throws.
  Future<bool> ensureInitialized() => _ready ??= _initialize();

  Future<bool> _initialize() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return true;
    } on Object {
      return false;
    }
  }

  /// Throws a [StateError] when Firebase is unavailable, so that the calling
  /// boot step is recorded as degraded.
  Future<void> require() async {
    if (!await ensureInitialized()) {
      throw StateError('Firebase is not configured for this build');
    }
  }
}
