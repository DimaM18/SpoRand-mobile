import 'package:sporand/core/analytics/analytics_service.dart';

/// Where the initializer sends `app_init_*` events once analytics is up.
abstract interface class BootTelemetry {
  /// False until the `analytics` step has initialized the SDK; until then
  /// the initializer buffers events itself.
  bool get isReady;

  void log(String event, Map<String, Object> params);
}

final class AnalyticsBootTelemetry implements BootTelemetry {
  const AnalyticsBootTelemetry(this._analytics);

  final AnalyticsService _analytics;

  @override
  bool get isReady => _analytics.isInitialized;

  @override
  void log(String event, Map<String, Object> params) {
    // Fire-and-forget: analytics never blocks boot.
    _analytics.logEvent(event, params).ignore();
  }
}

/// Test double that records what reached it and when it became ready.
final class RecordingBootTelemetry implements BootTelemetry {
  RecordingBootTelemetry({this.ready = false});

  bool ready;
  final List<(String, Map<String, Object>)> events = [];

  @override
  bool get isReady => ready;

  @override
  void log(String event, Map<String, Object> params) =>
      events.add((event, params));
}
