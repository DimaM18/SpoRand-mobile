import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_kit/mobile_kit.dart' show ProductCatalog;
import 'package:mobile_kit/testing.dart';

import 'package:sporand/app/bootstrap/bootstrap.dart';
import 'package:sporand/app/bootstrap/steps/boot_steps.dart';
import 'package:sporand/core/analytics/analytics_service.dart';
import 'package:sporand/features/paywall/domain/paywall_placement.dart';
import 'package:sporand/features/paywall/presentation/paywall_page.dart';

// Wave 8b: the app's Dart mirrors against packages/protocol's generated
// client-registry.json (mobile_kit's `expectClientRegistryMatches`). The
// config keys are not compared yet: the registry also lists
// `youtube_embed_enabled`, which the app does not read (RcKeys pins 18 keys).
final _registry = File(
  '../../packages/protocol/generated/client-registry.json',
);
final _skip = _registry.existsSync() ? false : 'packages/protocol is missing';

void main() {
  test('the content guard of the app config is SPORAND_CONTENT_GUARD', () {
    final guard = appContentGuard(sporandAppConfig);
    expect(guard, same(sporandContentGuard));
    expectClientRegistryMatches(
      readClientRegistry(_registry.path),
      contentGuard: guard,
    );
  }, skip: _skip);

  test('boot steps, features, paywall placements and products match', () {
    expectClientRegistryMatches(
      readClientRegistry(_registry.path),
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
