import 'dart:async';
import 'dart:collection';

import 'package:sporand/core/analytics/analytics_backend.dart';

/// The user's effective analytics consent.
enum AnalyticsConsent {
  /// Not decided yet (UMP/onboarding pending). Events are buffered.
  unknown,

  /// Collection allowed.
  granted,

  /// The user said no. Nothing is sent and the buffer is dropped.
  denied,

  /// Collection is off for policy reasons (13-15 year olds, brief §7 "Age").
  disabled,
}

/// Client analytics facade (brief §4.5) over a vendor [AnalyticsBackend].
///
/// Responsibilities:
/// - validates names against the GA4 limits and our naming rules;
/// - enforces the Spotify Terms IV.2.5 rule: no parameter name may refer to a
///   track, artist, title, playlist or Spotify (assert in debug, stripped in
///   release);
/// - gates collection on consent: events are buffered until consent is
///   known, flushed when granted and dropped when denied or disabled.
class AnalyticsService {
  AnalyticsService({required this._backend, this.maxBuffered = 100});

  final AnalyticsBackend _backend;
  final int maxBuffered;

  static const maxNameLength = 40;
  static const maxParams = 25;
  static const maxStringValueLength = 100;

  static final RegExp _namePattern = RegExp(r'^[a-z][a-z0-9_]*$');
  static const _reservedPrefixes = ['firebase_', 'google_', 'ga_'];

  /// GA4 automatically collected / reserved event names.
  static const reservedEventNames = {
    'ad_activeview',
    'ad_click',
    'ad_exposure',
    'ad_impression',
    'ad_query',
    'ad_reward',
    'adunit_exposure',
    'app_background',
    'app_clear_data',
    'app_exception',
    'app_remove',
    'app_store_refund',
    'app_store_subscription_cancel',
    'app_store_subscription_convert',
    'app_store_subscription_renew',
    'app_update',
    'app_upgrade',
    'error',
    'first_open',
    'first_visit',
    'in_app_purchase',
    'notification_dismiss',
    'notification_foreground',
    'notification_open',
    'notification_receive',
    'os_update',
    'screen_view',
    'session_start',
    'user_engagement',
  };

  /// Fragments that must never appear in a parameter name (Spotify Terms
  /// IV.2.5: no track, artist, playlist or Spotify data in analytics).
  static const forbiddenParamFragments = [
    'track',
    'artist',
    'title',
    'playlist',
    'spotify',
    // Wave 4: no YouTube video data either (protocol content name tokens).
    'video',
    'youtube',
  ];

  static final _youTubeReference = RegExp(
    r'youtube\.com|youtu\.be|youtube-nocookie\.com|ytimg\.com|googlevideo\.com',
    caseSensitive: false,
  );
  static final _videoIdShape = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// A value that looks like YouTube content: a YouTube link, or a mixed-case
  /// 11-character value shaped like a video id (packages/protocol
  /// `isYouTubeContentValue`). Such values are never logged (YouTube API
  /// policy; hard rule 3).
  static bool isYouTubeContentValue(String value) =>
      _youTubeReference.hasMatch(value) ||
      (_videoIdShape.hasMatch(value) &&
          value.contains(RegExp('[a-z]')) &&
          value.contains(RegExp('[A-Z]')));

  /// `pool_submit.track_count_bucket` is canonical (brief §4.5) and carries
  /// only a count bucket, not track data, so it is explicitly allowed.
  static const allowedParamExceptions = {'track_count_bucket'};

  bool _initialized = false;
  AnalyticsConsent _consent = AnalyticsConsent.unknown;
  bool _adsPersonalized = false;
  String? _userId;
  final Queue<RecordedEvent> _buffer = Queue<RecordedEvent>();

  bool get isInitialized => _initialized;
  AnalyticsConsent get consent => _consent;
  int get bufferedCount => _buffer.length;

  /// Initializes the SDK with Consent Mode "denied" defaults (EEA rule); the
  /// `consent` boot step then applies the real decision.
  Future<void> initialize() async {
    await _backend.initialize();
    await _backend.setConsent(AnalyticsConsentSignals.denied);
    _initialized = true;
    await _applyConsentToBackend();
    if (_userId != null) await _applyUserIdToBackend();
    await _flushIfAllowed();
  }

  Future<void> applyConsent(
    AnalyticsConsent consent, {
    bool adsPersonalized = false,
  }) async {
    _consent = consent;
    _adsPersonalized = adsPersonalized;
    if (consent == AnalyticsConsent.denied ||
        consent == AnalyticsConsent.disabled) {
      _buffer.clear();
    }
    if (!_initialized) return;
    await _applyConsentToBackend();
    await _applyUserIdToBackend();
    await _flushIfAllowed();
  }

  Future<void> _applyConsentToBackend() async {
    switch (_consent) {
      case AnalyticsConsent.unknown:
        return;
      case AnalyticsConsent.granted:
        await _backend.setCollectionEnabled(true);
        await _backend.setConsent(
          AnalyticsConsentSignals(
            analyticsStorage: true,
            adStorage: _adsPersonalized,
            adUserData: _adsPersonalized,
            adPersonalization: _adsPersonalized,
          ),
        );
      case AnalyticsConsent.denied || AnalyticsConsent.disabled:
        await _backend.setConsent(AnalyticsConsentSignals.denied);
        await _backend.setCollectionEnabled(false);
    }
  }

  /// `analytics_uid` (HMAC of user_id from the server), never the raw id;
  /// null clears it (logout, account deletion). The SDK gets it only while
  /// analytics consent is granted (S8.6); otherwise its user id is cleared.
  Future<void> setUserId(String? analyticsUid) async {
    _userId = analyticsUid;
    if (_initialized) await _applyUserIdToBackend();
  }

  /// The id the SDK currently should have.
  String? get userId => _userId;

  Future<void> _applyUserIdToBackend() =>
      _backend.setUserId(_consent == AnalyticsConsent.granted ? _userId : null);

  Future<void> setUserProperty(String name, String? value) async {
    _checkName(name, kind: 'user property', maxLength: 24);
    if (_initialized && _consent == AnalyticsConsent.granted) {
      await _backend.setUserProperty(name, value);
    }
  }

  /// Logs an event. Validation runs synchronously, so a naming bug fails
  /// loudly (AssertionError) at the call site in debug builds.
  Future<void> logEvent(String name, [Map<String, Object?> params = const {}]) {
    _checkName(name, kind: 'event', maxLength: maxNameLength);
    assert(
      !reservedEventNames.contains(name),
      'Analytics event "$name" is a GA4 reserved name',
    );
    final sanitized = sanitizeParams(params);
    final event = RecordedEvent(name, sanitized);
    switch (_consent) {
      case AnalyticsConsent.denied || AnalyticsConsent.disabled:
        return Future.value();
      case AnalyticsConsent.unknown:
        _enqueue(event);
        return Future.value();
      case AnalyticsConsent.granted:
        if (!_initialized) {
          _enqueue(event);
          return Future.value();
        }
        return _backend.logEvent(event.name, event.params);
    }
  }

  void _enqueue(RecordedEvent event) {
    _buffer.addLast(event);
    while (_buffer.length > maxBuffered) {
      _buffer.removeFirst();
    }
  }

  Future<void> _flushIfAllowed() async {
    if (!_initialized || _consent != AnalyticsConsent.granted) return;
    while (_buffer.isNotEmpty) {
      final event = _buffer.removeFirst();
      await _backend.logEvent(event.name, event.params);
    }
  }

  static bool isAllowedParamName(String name) {
    if (allowedParamExceptions.contains(name)) return true;
    final lower = name.toLowerCase();
    return !forbiddenParamFragments.any(lower.contains);
  }

  /// Validates parameter names and converts values to GA4 types: booleans
  /// become 1/0 (GA4 has no boolean type), strings are truncated to 100
  /// characters, nulls are dropped.
  static Map<String, Object> sanitizeParams(Map<String, Object?> params) {
    assert(
      params.length <= maxParams,
      'Analytics events take at most $maxParams parameters',
    );
    final result = <String, Object>{};
    for (final MapEntry(:key, :value) in params.entries) {
      assert(
        isAllowedParamName(key),
        'Analytics parameter "$key" looks like music/Spotify data; this is '
        'forbidden by Spotify Terms IV.2.5 (brief §4.5)',
      );
      if (!isAllowedParamName(key) || value == null) continue;
      if (result.length == maxParams) break;
      if (value is String && isYouTubeContentValue(value)) {
        assert(false, 'Analytics parameter "$key" carries YouTube content');
        continue;
      }
      result[key] = switch (value) {
        final bool b => b ? 1 : 0,
        final num n => n,
        final Enum e => e.name,
        final String s => _truncate(s),
        _ => _truncate(value.toString()),
      };
    }
    return result;
  }

  static String _truncate(String value) => value.length <= maxStringValueLength
      ? value
      : value.substring(0, maxStringValueLength);

  static void _checkName(
    String name, {
    required String kind,
    required int maxLength,
  }) {
    assert(
      _namePattern.hasMatch(name) && name.length <= maxLength,
      'Analytics $kind name "$name" must be snake_case, max $maxLength chars',
    );
    assert(
      !_reservedPrefixes.any(name.startsWith),
      'Analytics $kind name "$name" uses a reserved prefix',
    );
  }
}
