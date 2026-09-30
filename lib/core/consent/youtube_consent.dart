import 'package:sporand/core/consent/consent_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';

/// What the round DJ's phone may do before creating the embedded YouTube
/// player (wave 4) [новое имя — согласовать].
enum YouTubeConsentDecision {
  /// Create the player: no consent is required here, or it was given.
  allowed,

  /// EU/EEA or region unknown and no answer yet: ask first.
  ask,

  /// Declined in this app session: the DJ gets the BYOP cue.
  declined,
}

/// Consent to load the YouTube player (YouTube API policy III.E.4.i): the
/// player sends data to Google as soon as it loads, so where consent applies
/// it must be given before the player is created.
///
/// - Outside the EEA/UK (UMP `notRequired`) the player loads right away.
/// - Otherwise (EEA/UK, or the region is still unknown) the DJ is asked
///   once; a «yes» is stored, a «no» holds for this app session only, so a
///   DJ who declined is not asked again every round but can change their
///   mind next time. [новое имя — согласовать]
class YouTubeConsentGate {
  YouTubeConsentGate({required this._ump, required this._prefs});

  final ConsentService _ump;
  final PreferencesStore _prefs;
  bool _declinedThisSession = false;

  YouTubeConsentDecision get decision {
    if (_ump.current.notRequired) return YouTubeConsentDecision.allowed;
    if (_prefs.getBool(PrefKeys.youtubePlayerConsent) ?? false) {
      return YouTubeConsentDecision.allowed;
    }
    return _declinedThisSession
        ? YouTubeConsentDecision.declined
        : YouTubeConsentDecision.ask;
  }

  Future<void> grant() async {
    _declinedThisSession = false;
    try {
      await _prefs.setBool(PrefKeys.youtubePlayerConsent, true);
    } on Object {
      // Not persisted (storage unavailable): asked again next launch.
    }
  }

  void decline() => _declinedThisSession = true;
}
