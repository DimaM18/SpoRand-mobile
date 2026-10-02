import 'package:mobile_kit/mobile_kit.dart' show KitUserPrefs;

import 'package:sporand/core/storage/preferences_store.dart';

// Wave 8b: the privacy and onboarding state lives in mobile_kit's
// `KitUserPrefs` (mobile-template); SpoRand adds the last display name.
export 'package:mobile_kit/mobile_kit.dart' show KitUserPrefs;

/// Typed access to the user's local privacy/onboarding state: mobile_kit's
/// [KitUserPrefs] (standard age policy) plus SpoRand's display name, under
/// the old constructor.
class UserPrefsRepository extends KitUserPrefs {
  UserPrefsRepository(super.store, {super.policy});

  /// The last display name typed at create/join.
  String? get displayName => SporandPrefs(this).displayName;

  Future<void> saveDisplayName(String name) =>
      SporandPrefs(this).saveDisplayName(name);
}

/// SpoRand's own preferences on the kit's user prefs (any [KitUserPrefs],
/// e.g. the one mobile_kit's `userPrefsProvider` builds); the keys are in
/// [PrefKeys.all] [новое имя — согласовать].
extension SporandPrefs on KitUserPrefs {
  /// The last display name typed at create/join.
  String? get displayName => store.getString(PrefKeys.displayName);

  Future<void> saveDisplayName(String name) =>
      store.setString(PrefKeys.displayName, name);
}
