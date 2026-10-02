import 'package:mobile_kit/mobile_kit.dart' as kit;
import 'package:mobile_kit/mobile_kit.dart' show KitPrefKeys, PreferencesStore;

// Wave 8b: the preferences store lives in mobile_kit (mobile-template); this
// path keeps SpoRand's keys and the store's old constructor.
export 'package:mobile_kit/mobile_kit.dart'
    show InMemoryPreferencesStore, KitPrefKeys, PreferencesStore;

/// Every key the app stores; SharedPreferencesWithCache requires the list.
/// The kit's keys ([KitPrefKeys], a persistent format) plus SpoRand's;
/// [all] is the allow list (`prefKeysProvider` of mobile_kit).
abstract final class PrefKeys {
  static const ageBand = KitPrefKeys.ageBand;
  static const ageGateBlocked = KitPrefKeys.ageGateBlocked;
  static const onboardingCompleted = KitPrefKeys.onboardingCompleted;
  static const analyticsConsent = KitPrefKeys.analyticsConsent;

  /// Last display name typed at create/join [новое имя — согласовать].
  static const displayName = 'display_name';

  /// The `user_id` whose server profile already has [ageBand]
  /// (`PATCH /v1/me`, see `AgeBandSync`).
  static const ageBandSyncedFor = KitPrefKeys.ageBandSyncedFor;

  /// The DJ allowed the embedded YouTube player to load (EU/EEA consent,
  /// wave 4) [новое имя — согласовать].
  static const youtubePlayerConsent = 'youtube_player_consent';

  static const all = {...KitPrefKeys.all, displayName, youtubePlayerConsent};
}

/// The kit's `SharedPreferencesStore` with SpoRand's allow list by default
/// ([PrefKeys.all]), so `SharedPreferencesStore()` keeps reading and
/// writing the game's keys. Reads before [open] return null so that early
/// UI never crashes.
final class SharedPreferencesStore implements PreferencesStore {
  SharedPreferencesStore({Set<String> allowList = PrefKeys.all})
    : _store = kit.SharedPreferencesStore(allowList: allowList);

  final kit.SharedPreferencesStore _store;

  /// Every key the app reads or writes.
  Set<String> get allowList => _store.allowList;

  @override
  bool get isOpen => _store.isOpen;

  @override
  Future<void> open() => _store.open();

  @override
  bool? getBool(String key) => _store.getBool(key);

  @override
  String? getString(String key) => _store.getString(key);

  @override
  int? getInt(String key) => _store.getInt(key);

  @override
  Future<void> setBool(String key, bool value) => _store.setBool(key, value);

  @override
  Future<void> setString(String key, String value) =>
      _store.setString(key, value);

  @override
  Future<void> setInt(String key, int value) => _store.setInt(key, value);

  @override
  Future<void> remove(String key) => _store.remove(key);
}
