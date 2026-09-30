import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secret storage for tokens (brief §7 "Token storage on the device").
abstract interface class SecureStore {
  /// Opens the store and surfaces keystore/keychain errors early (the
  /// `storage_open` boot step).
  Future<void> open();

  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// Keychain / Keystore via flutter_secure_storage 11.
///
/// - iOS: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, not synced to
///   iCloud, so tokens never leave the device through backups.
/// - Android: Keystore-backed ciphers (EncryptedSharedPreferences is not
///   used); app backups are disabled in AndroidManifest.xml.
final class FlutterSecureStore implements SecureStore {
  FlutterSecureStore()
    : _storage = const FlutterSecureStorage(
        iOptions: IOSOptions(
          accessibility: KeychainAccessibility.first_unlock_this_device,
          synchronizable: false,
        ),
        aOptions: AndroidOptions(migrateWithBackup: false),
      );

  static const _probeKey = 'secure_store_probe';

  final FlutterSecureStorage _storage;

  @override
  Future<void> open() async {
    await _storage.read(key: _probeKey);
  }

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

final class InMemorySecureStore implements SecureStore {
  InMemorySecureStore({Map<String, String>? initial, this.failOpen = false})
    : values = {...?initial};

  final Map<String, String> values;
  bool failOpen;

  @override
  Future<void> open() async {
    if (failOpen) throw StateError('secure storage unavailable');
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}
