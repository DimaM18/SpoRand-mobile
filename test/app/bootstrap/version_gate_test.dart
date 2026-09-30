import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/bootstrap/domain/version_gate.dart';
import 'package:sporand/core/platform/app_platform.dart';

bool gate(String min, String current, [AppPlatform p = AppPlatform.ios]) =>
    VersionGate.requiresUpdate(
      minSupportedRaw: min,
      currentVersion: current,
      platform: p,
    );

void main() {
  test('compares semver numerically, not lexically', () {
    expect(gate('1.10.0', '1.9.9'), isTrue);
    expect(gate('1.9.9', '1.10.0'), isFalse);
    expect(gate('2.0.0', '10.0.0'), isFalse);
  });

  test('equal versions pass', () {
    expect(gate('1.2.3', '1.2.3'), isFalse);
  });

  test('pre-releases sort before the release', () {
    expect(gate('1.2.0', '1.2.0-beta.1'), isTrue);
    expect(gate('1.2.0-beta.1', '1.2.0'), isFalse);
  });

  test('build metadata is ignored', () {
    expect(gate('1.2.0+99', '1.2.0'), isFalse);
    expect(gate('1.2.0', '1.2.0+1'), isFalse);
  });

  test('short versions are padded', () {
    expect(gate('2', '1.9.9'), isTrue);
    expect(gate('1.3', '1.3.0'), isFalse);
  });

  test('per-platform JSON picks the running platform', () {
    const value = '{"ios": "2.0.0", "android": "1.0.0"}';
    expect(gate(value, '1.5.0', AppPlatform.ios), isTrue);
    expect(gate(value, '1.5.0', AppPlatform.android), isFalse);
  });

  test('per-platform JSON falls back to "default"', () {
    const value = '{"ios": "1.0.0", "default": "3.0.0"}';
    expect(gate(value, '2.0.0', AppPlatform.android), isTrue);
    expect(gate(value, '2.0.0', AppPlatform.ios), isFalse);
  });

  test('malformed values never block users', () {
    expect(gate('', '1.0.0'), isFalse);
    expect(gate('latest', '1.0.0'), isFalse);
    expect(gate('{"ios": 2}', '1.0.0'), isFalse);
    expect(gate('{broken', '1.0.0'), isFalse);
    expect(gate('2.0.0', 'unknown'), isFalse);
  });
}
