import 'package:sporand/core/privacy/age_band.dart';
import 'package:sporand/core/storage/preferences_store.dart';

/// Typed access to the user's local privacy/onboarding state.
class UserPrefsRepository {
  UserPrefsRepository(this._store);

  final PreferencesStore _store;

  AgeBand? get ageBand => AgeBand.fromWire(_store.getString(PrefKeys.ageBand));

  /// Once an under-13 answer is given the gate stays closed, so the age
  /// cannot be retried with another year (neutral age gate practice).
  bool get ageGateBlocked => _store.getBool(PrefKeys.ageGateBlocked) ?? false;

  bool get onboardingCompleted =>
      _store.getBool(PrefKeys.onboardingCompleted) ?? false;

  /// The user's own analytics choice; null when never asked.
  bool? get analyticsConsent => _store.getBool(PrefKeys.analyticsConsent);

  Future<void> saveAgeBand(AgeBand band) async {
    await _store.setString(PrefKeys.ageBand, band.wireName);
    if (band.isBlocked) await _store.setBool(PrefKeys.ageGateBlocked, true);
  }

  Future<void> saveAnalyticsConsent(bool granted) =>
      _store.setBool(PrefKeys.analyticsConsent, granted);

  Future<void> markOnboardingCompleted() =>
      _store.setBool(PrefKeys.onboardingCompleted, true);
}
