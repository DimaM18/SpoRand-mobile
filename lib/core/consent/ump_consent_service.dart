import 'dart:async';

import 'package:google_mobile_ads/google_mobile_ads.dart' as gma;

import 'package:sporand/core/consent/consent_service.dart';

/// UMP adapter (google_mobile_ads 9.x bundles the UMP SDK).
///
/// Consent flow order (brief §7): age gate -> UMP -> Firebase `setConsent`
/// -> ads init. No ATT prompt on iOS in the MVP (Q12).
final class UmpConsentService implements ConsentService {
  UmpConsentService({this.debugGeographyEea = false, this.testDeviceIds});

  /// Dev only: force the EEA flow on test devices.
  final bool debugGeographyEea;
  final List<String>? testDeviceIds;

  ConsentInfo _current = ConsentInfo.unknown;

  @override
  ConsentInfo get current => _current;

  @override
  Future<ConsentInfo> refresh({required bool underAgeOfConsent}) async {
    final params = gma.ConsentRequestParameters(
      tagForUnderAgeOfConsent: underAgeOfConsent,
      consentDebugSettings: debugGeographyEea
          ? gma.ConsentDebugSettings(
              debugGeography: gma.DebugGeography.debugGeographyEea,
              testIdentifiers: testDeviceIds,
            )
          : null,
    );
    final completer = Completer<void>();
    gma.ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      completer.complete,
      (error) => completer.completeError(
        StateError('UMP update failed: ${error.errorCode} ${error.message}'),
      ),
    );
    await completer.future;
    return _current = await _read();
  }

  @override
  Future<ConsentInfo> showFormIfRequired() async {
    final completer = Completer<void>();
    await gma.ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      // A form error still leaves a valid consent state; read it below.
      completer.complete();
    });
    await completer.future;
    return _current = await _read();
  }

  @override
  Future<ConsentInfo> showPrivacyOptions() async {
    final completer = Completer<void>();
    await gma.ConsentForm.showPrivacyOptionsForm((_) => completer.complete());
    await completer.future;
    return _current = await _read();
  }

  Future<ConsentInfo> _read() async {
    final info = gma.ConsentInformation.instance;
    final status = await info.getConsentStatus();
    final canRequestAds = await info.canRequestAds();
    final privacy = await info.getPrivacyOptionsRequirementStatus();
    return ConsentInfo(
      status: switch (status) {
        gma.ConsentStatus.required => ConsentStatus.required,
        gma.ConsentStatus.notRequired => ConsentStatus.notRequired,
        gma.ConsentStatus.obtained => ConsentStatus.obtained,
        gma.ConsentStatus.unknown => ConsentStatus.unknown,
      },
      canRequestAds: canRequestAds,
      privacyOptionsRequired:
          privacy == gma.PrivacyOptionsRequirementStatus.required,
    );
  }
}
