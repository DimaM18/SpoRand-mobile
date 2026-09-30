import 'package:package_info_plus/package_info_plus.dart';

import 'package:sporand/core/platform/app_platform.dart';

/// Static facts about the installed build.
final class AppInfo {
  const AppInfo({
    required this.version,
    required this.buildNumber,
    required this.platform,
  });

  /// Marketing version (`CFBundleShortVersionString` / `versionName`), semver.
  final String version;
  final String buildNumber;
  final AppPlatform platform;
}

/// Source of [AppInfo]; the real one asks the platform, tests use a fake.
abstract interface class AppInfoSource {
  Future<AppInfo> load();
}

final class PackageInfoAppInfoSource implements AppInfoSource {
  PackageInfoAppInfoSource(this._platform);

  final AppPlatform _platform;
  AppInfo? _cached;

  @override
  Future<AppInfo> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final info = await PackageInfo.fromPlatform();
    return _cached = AppInfo(
      version: info.version,
      buildNumber: info.buildNumber,
      platform: _platform,
    );
  }
}

final class FakeAppInfoSource implements AppInfoSource {
  const FakeAppInfoSource(this.info);

  final AppInfo info;

  @override
  Future<AppInfo> load() async => info;
}
