/// UMP consent status (mirrors the SDK enum).
enum ConsentStatus { unknown, required, notRequired, obtained }

/// Snapshot of the ads consent state after a UMP info refresh.
final class ConsentInfo {
  const ConsentInfo({
    required this.status,
    required this.canRequestAds,
    this.privacyOptionsRequired = false,
  });

  static const unknown = ConsentInfo(
    status: ConsentStatus.unknown,
    canRequestAds: false,
  );

  final ConsentStatus status;

  /// UMP `canRequestAds()`; `MobileAds.initialize` runs only when true
  /// (brief §6 "Ads consent").
  final bool canRequestAds;

  /// Whether a privacy options entry point must be shown in settings.
  final bool privacyOptionsRequired;

  /// A consent form still has to be shown (EEA/UK, not answered yet).
  bool get formRequired => status == ConsentStatus.required;

  /// Consent is not required in the user's region (outside EEA/UK).
  bool get notRequired => status == ConsentStatus.notRequired;
}

/// Google UMP (User Messaging Platform) behind an interface.
abstract interface class ConsentService {
  ConsentInfo get current;

  /// UMP consent info update. Cheap; runs during boot. Never shows UI.
  Future<ConsentInfo> refresh({required bool underAgeOfConsent});

  /// Shows the consent form if UMP says it is required. Runs in onboarding
  /// (after the age gate) or after boot for returning users.
  Future<ConsentInfo> showFormIfRequired();

  /// Re-opens the consent choices (settings entry point).
  Future<ConsentInfo> showPrivacyOptions();
}

/// Scriptable fake for tests, the spotifyProto flavor (no ads at all) and
/// builds without the ads SDK.
final class FakeConsentService implements ConsentService {
  FakeConsentService({
    this.statusAfterRefresh = ConsentStatus.notRequired,
    this.canRequestAdsAfterRefresh = true,
    this.statusAfterForm = ConsentStatus.obtained,
    this.failRefresh = false,
  });

  ConsentStatus statusAfterRefresh;
  bool canRequestAdsAfterRefresh;
  ConsentStatus statusAfterForm;
  bool failRefresh;

  int refreshCount = 0;
  int formShownCount = 0;
  bool? lastUnderAgeOfConsent;

  ConsentInfo _current = ConsentInfo.unknown;

  @override
  ConsentInfo get current => _current;

  @override
  Future<ConsentInfo> refresh({required bool underAgeOfConsent}) async {
    refreshCount++;
    lastUnderAgeOfConsent = underAgeOfConsent;
    if (failRefresh) throw StateError('UMP refresh failed');
    return _current = ConsentInfo(
      status: statusAfterRefresh,
      canRequestAds: canRequestAdsAfterRefresh,
    );
  }

  @override
  Future<ConsentInfo> showFormIfRequired() async {
    if (_current.formRequired) {
      formShownCount++;
      _current = ConsentInfo(status: statusAfterForm, canRequestAds: true);
    }
    return _current;
  }

  @override
  Future<ConsentInfo> showPrivacyOptions() async {
    formShownCount++;
    return _current;
  }
}
