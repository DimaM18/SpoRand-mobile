/// Build flavors (brief §3). Chosen at build time with
/// `--dart-define=FLAVOR=<name>`; there is one entry point for all of them.
enum Flavor {
  dev,
  staging,
  prod,
  spotifyProto;

  /// Unknown or empty values fall back to [Flavor.dev] so that a plain
  /// `flutter run` always works.
  static Flavor parse(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final flavor in values) {
      if (flavor.name.toLowerCase() == normalized) return flavor;
    }
    return Flavor.dev;
  }

  /// `spotifyProto` has no ads, no purchases and no paywall: Spotify forbids
  /// commercializing a streaming SDA (brief §1.3, point 3).
  bool get allowsMonetization => this != Flavor.spotifyProto;

  bool get isDev => this == Flavor.dev;
}
