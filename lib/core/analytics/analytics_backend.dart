/// Consent Mode signals forwarded to the analytics SDK.
final class AnalyticsConsentSignals {
  const AnalyticsConsentSignals({
    required this.analyticsStorage,
    required this.adStorage,
    required this.adUserData,
    required this.adPersonalization,
  });

  /// EEA default until the user decides (brief §7 "Legal bases").
  static const denied = AnalyticsConsentSignals(
    analyticsStorage: false,
    adStorage: false,
    adUserData: false,
    adPersonalization: false,
  );

  final bool analyticsStorage;
  final bool adStorage;
  final bool adUserData;
  final bool adPersonalization;
}

/// Vendor adapter behind [AnalyticsService]. Parameters arrive already
/// validated and converted to GA4-compatible types (String or num).
abstract interface class AnalyticsBackend {
  Future<void> initialize();
  Future<void> setCollectionEnabled(bool enabled);
  Future<void> setConsent(AnalyticsConsentSignals signals);
  Future<void> logEvent(String name, Map<String, Object> params);
  Future<void> setUserId(String? id);
  Future<void> setUserProperty(String name, String? value);
}

/// Recorded call for [InMemoryAnalyticsBackend].
final class RecordedEvent {
  const RecordedEvent(this.name, this.params);

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => '$name $params';
}

/// Debug/in-memory backend: used by tests and by builds without Firebase.
final class InMemoryAnalyticsBackend implements AnalyticsBackend {
  InMemoryAnalyticsBackend({this.onEvent, this.failInitialize = false});

  /// Optional sink (e.g. `debugPrint`) so events are visible in dev builds.
  final void Function(String line)? onEvent;
  bool failInitialize;

  final List<RecordedEvent> events = [];
  final Map<String, String?> userProperties = {};
  bool initialized = false;
  bool collectionEnabled = true;
  String? userId;
  AnalyticsConsentSignals? consent;

  @override
  Future<void> initialize() async {
    if (failInitialize) throw StateError('analytics unavailable');
    initialized = true;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    collectionEnabled = enabled;
  }

  @override
  Future<void> setConsent(AnalyticsConsentSignals signals) async {
    consent = signals;
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    events.add(RecordedEvent(name, params));
    onEvent?.call('[analytics] $name $params');
  }

  @override
  Future<void> setUserId(String? id) async {
    userId = id;
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    userProperties[name] = value;
  }

  Iterable<RecordedEvent> named(String name) =>
      events.where((event) => event.name == name);
}
