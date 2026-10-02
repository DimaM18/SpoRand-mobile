import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_kit/mobile_kit.dart' show ProductCatalog;
import 'package:mobile_kit/testing.dart';

import 'package:sporand/app/bootstrap/bootstrap.dart';
import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_page.dart';

// Wave 8b: the app's Dart mirrors against packages/protocol's generated
// client-registry.json (mobile_kit's `expectClientRegistryMatches`), config
// keys included (names in the registry's order, reader, type, default, range).
final _registry = File(
  'contract/generated/client-registry.json',
);
final _skip = _registry.existsSync() ? false : 'contract/ is missing (tool/contract.sh sync)';

void main() {
  test('the content guard of the app config is SPORAND_CONTENT_GUARD', () {
    final guard = appContentGuard(sporandAppConfig);
    expect(guard, same(sporandContentGuard));
    expectClientRegistryMatches(
      readClientRegistry(_registry.path),
      contentGuard: guard,
    );
  }, skip: _skip);

  test('config keys, boot steps, features, placements and products match', () {
    expectClientRegistryMatches(
      readClientRegistry(_registry.path),
      rcKeys: RcKeys.all,
      initSteps: buildBootSteps(),
      features: sporandAppConfig.features,
      placements: sporandPaywallConfig.placements,
      catalog: ProductCatalog.standard,
    );
    expect(sporandPaywallConfig.placements, [
      for (final placement in PaywallPlacement.values) placement.wireName,
    ]);
  }, skip: _skip);
}
