import 'dart:async';

import 'package:sporand/core/net/api_client.dart';
import 'package:sporand/core/net/protocol/rest_models.dart';

/// `PUT /v1/me/consent` (brief §4.2, §7; S7.11.2).
abstract interface class ConsentApi {
  Future<void> put(ConsentUpdateRequest request);
}

final class HttpConsentApi implements ConsentApi {
  HttpConsentApi(this._client);

  final ApiClient _client;

  @override
  Future<void> put(ConsentUpdateRequest request) async {
    // The response (`ConsentState`) only echoes what was sent.
    await _client.put('/v1/me/consent', body: request.toJson());
  }
}

/// Records requests; builds without a backend and tests.
final class FakeConsentApi implements ConsentApi {
  FakeConsentApi({this.failures = 0});

  /// The next [failures] calls throw.
  int failures;
  final List<ConsentUpdateRequest> sent = [];
  int calls = 0;

  @override
  Future<void> put(ConsentUpdateRequest request) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const ApiError(code: ApiError.network);
    }
    sent.add(request);
  }
}

/// Tells the server the user's consent choices, so it can honour them in
/// `server_events` and ads decisions (S8.5). [новое имя — согласовать]
///
/// - Debounced: a burst of changes (a toggle flipped twice, the UMP form
///   right after onboarding) sends only the latest state.
/// - Retried once after [retryDelay] on failure, unless a newer state
///   superseded it; after that the choice waits for the next change (the
///   server keeps the previous flags meanwhile).
/// - Never blocks or throws: callers fire and forget.
class ConsentSync {
  ConsentSync({
    required this._api,
    this.debounce = const Duration(milliseconds: 500),
    this.retryDelay = const Duration(seconds: 3),
  });

  final ConsentApi _api;
  final Duration debounce;
  final Duration retryDelay;

  Timer? _timer;
  ConsentUpdateRequest? _pending;
  int _generation = 0;
  bool _disposed = false;

  /// The state waiting for the debounce timer, if any.
  ConsentUpdateRequest? get pending => _pending;

  void schedule({
    required bool analytics,
    required bool adsPersonalized,
    required ConsentSource source,
  }) {
    if (_disposed) return;
    _generation++;
    _pending = ConsentUpdateRequest(
      consentAnalytics: analytics,
      consentAdsPersonalized: adsPersonalized,
      source: source,
    );
    _timer?.cancel();
    _timer = Timer(debounce, () => unawaited(_flush()));
  }

  Future<void> _flush() async {
    final request = _pending;
    final generation = _generation;
    _pending = null;
    if (request == null || _disposed) return;
    if (await _tryPut(request) || _disposed) return;
    // A newer state is already scheduled: it replaces the retry.
    if (generation != _generation) return;
    _timer = Timer(retryDelay, () {
      if (!_disposed && generation == _generation) unawaited(_tryPut(request));
    });
  }

  Future<bool> _tryPut(ConsentUpdateRequest request) async {
    try {
      await _api.put(request);
      return true;
    } on Object {
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    _pending = null;
  }
}
