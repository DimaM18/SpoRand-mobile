/// The platform the app runs on, with the wire names used in the protocol
/// (`hello.platform`, analytics `platform`).
enum AppPlatform {
  ios('ios'),
  android('android'),
  other('other');

  const AppPlatform(this.wireName);

  final String wireName;
}
