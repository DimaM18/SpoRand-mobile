import 'package:firebase_analytics/firebase_analytics.dart';

import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/firebase/firebase_core_gate.dart';

/// Firebase Analytics (GA4) adapter. Calls before a successful [initialize]
/// are dropped, so a build without Firebase config degrades to a no-op.
final class FirebaseAnalyticsBackend implements AnalyticsBackend {
  FirebaseAnalyticsBackend(this._firebase);

  final FirebaseCoreGate _firebase;
  FirebaseAnalytics? _analytics;

  @override
  Future<void> initialize() async {
    await _firebase.require();
    _analytics = FirebaseAnalytics.instance;
  }

  @override
  Future<void> setCollectionEnabled(bool enabled) async {
    await _analytics?.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> setConsent(AnalyticsConsentSignals signals) async {
    await _analytics?.setConsent(
      analyticsStorageConsentGranted: signals.analyticsStorage,
      adStorageConsentGranted: signals.adStorage,
      adUserDataConsentGranted: signals.adUserData,
      adPersonalizationSignalsConsentGranted: signals.adPersonalization,
    );
  }

  @override
  Future<void> logEvent(String name, Map<String, Object> params) async {
    await _analytics?.logEvent(name: name, parameters: params);
  }

  @override
  Future<void> setUserId(String? id) async {
    await _analytics?.setUserId(id: id);
  }

  @override
  Future<void> setUserProperty(String name, String? value) async {
    await _analytics?.setUserProperty(name: name, value: value);
  }
}
