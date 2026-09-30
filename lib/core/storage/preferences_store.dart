import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret local preferences (onboarding state, consent choices).
/// Secrets go to [SecureStore] instead.
abstract interface class PreferencesStore {
  Future<void> open();

  bool get isOpen;

  bool? getBool(String key);

  String? getString(String key);

  int? getInt(String key);

  Future<void> setBool(String key, bool value);

  Future<void> setString(String key, String value);

  Future<void> setInt(String key, int value);

  Future<void> remove(String key);
}

/// Every key the app stores; SharedPreferencesWithCache requires the list.
abstract final class PrefKeys {
  static const ageBand = 'age_band';
  static const ageGateBlocked = 'age_gate_blocked';
  static const onboardingCompleted = 'onboarding_completed';
  static const analyticsConsent = 'analytics_consent';

  /// Last display name typed at create/join [новое имя — согласовать].
  static const displayName = 'display_name';

  /// The `user_id` whose server profile already has [ageBand]
  /// (`PATCH /v1/me`, see `AgeBandSync`) [новое имя — согласовать].
  static const ageBandSyncedFor = 'age_band_synced_for';

  static const all = {
    ageBand,
    ageGateBlocked,
    onboardingCompleted,
    analyticsConsent,
    displayName,
    ageBandSyncedFor,
  };
}

final class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesWithCache? _prefs;

  SharedPreferencesWithCache get _require {
    final prefs = _prefs;
    if (prefs == null) throw StateError('PreferencesStore is not open');
    return prefs;
  }

  @override
  bool get isOpen => _prefs != null;

  @override
  Future<void> open() async {
    _prefs ??= await SharedPreferencesWithCache.create(
      cacheOptions: const SharedPreferencesWithCacheOptions(
        allowList: PrefKeys.all,
      ),
    );
  }

  // Reads before open() return null so that early UI never crashes.
  @override
  bool? getBool(String key) => _prefs?.getBool(key);

  @override
  String? getString(String key) => _prefs?.getString(key);

  @override
  int? getInt(String key) => _prefs?.getInt(key);

  @override
  Future<void> setBool(String key, bool value) => _require.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _require.setString(key, value);

  @override
  Future<void> setInt(String key, int value) => _require.setInt(key, value);

  @override
  Future<void> remove(String key) => _require.remove(key);
}

final class InMemoryPreferencesStore implements PreferencesStore {
  InMemoryPreferencesStore({
    Map<String, Object>? initial,
    this.failOpen = false,
  }) : values = {...?initial};

  final Map<String, Object> values;
  bool failOpen;
  bool _open = false;

  @override
  bool get isOpen => _open;

  @override
  Future<void> open() async {
    if (failOpen) throw StateError('preferences unavailable');
    _open = true;
  }

  @override
  bool? getBool(String key) => values[key] as bool?;

  @override
  String? getString(String key) => values[key] as String?;

  @override
  int? getInt(String key) => values[key] as int?;

  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> setInt(String key, int value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
