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

  String? get displayName => _store.getString(PrefKeys.displayName);

  /// The account (`user_id`) whose server profile already has [ageBand];
  /// null until the first `PATCH /v1/me` succeeds.
  String? get ageBandSyncedFor => _store.getString(PrefKeys.ageBandSyncedFor);

  Future<void> markAgeBandSynced(String userId) =>
      _store.setString(PrefKeys.ageBandSyncedFor, userId);

  Future<void> saveDisplayName(String name) =>
      _store.setString(PrefKeys.displayName, name);

  Future<void> saveAgeBand(AgeBand band) async {
    await _store.setString(PrefKeys.ageBand, band.wireName);
    if (band.isBlocked) await _store.setBool(PrefKeys.ageGateBlocked, true);
  }

  Future<void> saveAnalyticsConsent(bool granted) =>
      _store.setBool(PrefKeys.analyticsConsent, granted);

  Future<void> markOnboardingCompleted() =>
      _store.setBool(PrefKeys.onboardingCompleted, true);
}
