import 'package:mobile_kit/mobile_kit.dart' show FlavorRegistry, FlavorSpec;

/// Build flavors (wave 8b: mobile_kit's `FlavorSpec`s plus `spotifyProto`).
/// Chosen at build time with `--dart-define=FLAVOR=<name>`; there is one
/// entry point for all of them.
///
/// A class with static constants rather than an enum: the kit's `AppEnv`
/// holds a `FlavorSpec`, and code and tests compare it with [Flavor.prod]
/// and build `const AppEnv(flavor: Flavor.dev, …)`. The production env is
/// parsed from [registry], so its flavor is one of these instances.
class Flavor extends FlavorSpec {
  const Flavor._({
    required super.name,
    super.isDev,
    super.allowsMonetization,
    super.firebaseEnabledByDefault,
    super.configDefaults,
  });

  static const dev = Flavor._(
    name: 'dev',
    isDev: true,
    firebaseEnabledByDefault: false,
  );
  static const staging = Flavor._(name: 'staging');
  static const prod = Flavor._(name: 'prod');

  /// No ads, no purchases and no paywall: Spotify forbids commercializing a
  /// streaming SDA. Its client defaults turn the prototype on and
  /// monetization off (`spotify_proto_enabled`, `monetization_enabled`).
  static const spotifyProto = Flavor._(
    name: 'spotifyProto',
    allowsMonetization: false,
    configDefaults: {
      'spotify_proto_enabled': true,
      'monetization_enabled': false,
    },
  );

  static const values = <Flavor>[dev, staging, prod, spotifyProto];

  /// What `runKitApp` parses `FLAVOR` with (`KitAppConfig.flavors`).
  static const registry = FlavorRegistry(values);

  /// Unknown or empty values fall back to [Flavor.dev] so that a plain
  /// `flutter run` always works.
  static Flavor parse(String raw) => registry.parse(raw) as Flavor;

  @override
  String toString() => 'Flavor.$name';
}
