import 'package:sporand/core/net/protocol/json_read.dart';

/// The platform the app runs on, with the wire names used in the protocol
/// (`hello.platform`, analytics `platform`).
enum AppPlatform implements WireEnum {
  ios('ios'),
  android('android'),
  other('other');

  const AppPlatform(this.wireName);

  final String wireName;

  @override
  String get wire => wireName;
}
