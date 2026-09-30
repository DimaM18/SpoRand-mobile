import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sporand/app/di/providers.dart';
import 'package:sporand/app/flavors/flavor.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';

RemoteConfigService serviceWith(Map<String, String> active) {
  final backend = InMemoryRemoteConfigBackend()..pushUpdate(active);
  return RemoteConfigService(backend: backend);
}

void main() {
  group('defaults (brief §4.6, every C and B key)', () {
    final service = RemoteConfigService(backend: InMemoryRemoteConfigBackend());

    test('catalogue holds exactly the client-readable keys', () {
      expect(RcKeys.all.map((k) => k.name).toSet(), {
        'monetization_enabled',
        'rewarded_enabled',
        'interstitial_enabled',
        'remove_ads_upsell_enabled',
        'spotify_proto_enabled',
        'licensed_provider_enabled',
        'max_ad_wait_ms',
        'rewarded_preload_enabled',
        'paywall_variant',
        'min_supported_app_version',
        'maintenance_mode',
        'kill_switch_ads',
        'kill_switch_purchases',
        'boot_config_timeout_ms',
        'boot_min_splash_ms',
        'boot_max_total_ms',
      });
    });

    test('typed getters return the canonical defaults', () {
      expect(service.monetizationEnabled, isTrue);
      expect(service.rewardedEnabled, isTrue);
      expect(service.interstitialEnabled, isTrue);
      expect(service.removeAdsUpsellEnabled, isTrue);
      expect(service.spotifyProtoEnabled, isFalse);
      expect(service.licensedProviderEnabled, isFalse);
      expect(service.maxAdWait, const Duration(milliseconds: 1500));
      expect(service.rewardedPreloadEnabled, isTrue);
      expect(service.paywallVariant, 'a');
      expect(service.minSupportedAppVersion, '1.0.0');
      expect(service.maintenanceMode, isFalse);
      expect(service.killSwitchAds, isFalse);
      expect(service.killSwitchPurchases, isFalse);
      final timings = service.bootTimings;
      expect(timings.configFetchTimeout, const Duration(milliseconds: 2500));
      expect(timings.minSplash, const Duration(milliseconds: 800));
      expect(timings.maxTotal, const Duration(milliseconds: 8000));
    });

    test('bundled defaults are what setDefaults receives', () async {
      final backend = InMemoryRemoteConfigBackend();
      final svc = RemoteConfigService(backend: backend);
      await svc.applyDefaults();
      expect(backend.getRaw('boot_max_total_ms'), '8000');
      expect(backend.getRaw('monetization_enabled'), 'true');
      expect(svc.bundledDefaults.length, RcKeys.all.length);
    });

    test('flavor overrides: spotifyProto turns monetization off', () {
      final svc = RemoteConfigService(
        backend: InMemoryRemoteConfigBackend(),
        defaultOverrides: flavorConfigDefaults(Flavor.spotifyProto),
      );
      expect(svc.monetizationEnabled, isFalse);
      expect(svc.spotifyProtoEnabled, isTrue);
    });

    test('a wrongly typed override is ignored', () {
      final svc = RemoteConfigService(
        backend: InMemoryRemoteConfigBackend(),
        defaultOverrides: {'boot_min_splash_ms': 'soon'},
      );
      expect(svc.bootTimings.minSplash, const Duration(milliseconds: 800));
    });
  });

  group('clamping and parsing', () {
    test('ints are clamped into their range', () {
      final low = serviceWith({
        'boot_config_timeout_ms': '10',
        'boot_min_splash_ms': '-5',
        'boot_max_total_ms': '100',
        'max_ad_wait_ms': '-1',
      });
      expect(low.bootTimings.configFetchTimeout.inMilliseconds, 500);
      expect(low.bootTimings.minSplash.inMilliseconds, 0);
      expect(low.bootTimings.maxTotal.inMilliseconds, 3000);
      expect(low.maxAdWait.inMilliseconds, 0);

      final high = serviceWith({
        'boot_config_timeout_ms': '99999',
        'boot_min_splash_ms': '99999',
        'boot_max_total_ms': '99999',
        'max_ad_wait_ms': '99999',
      });
      expect(high.bootTimings.configFetchTimeout.inMilliseconds, 8000);
      expect(high.bootTimings.minSplash.inMilliseconds, 3000);
      expect(high.bootTimings.maxTotal.inMilliseconds, 20000);
      expect(high.maxAdWait.inMilliseconds, 5000);
    });

    test('in-range values pass through; decimals are rounded', () {
      final svc = serviceWith({
        'boot_min_splash_ms': '1200',
        'max_ad_wait_ms': '999.6',
      });
      expect(svc.bootTimings.minSplash.inMilliseconds, 1200);
      expect(svc.maxAdWait.inMilliseconds, 1000);
    });

    test('malformed values fall back to defaults', () {
      final svc = serviceWith({
        'boot_min_splash_ms': 'fast',
        'maintenance_mode': 'maybe',
        'paywall_variant': '   ',
      });
      expect(svc.bootTimings.minSplash.inMilliseconds, 800);
      expect(svc.maintenanceMode, isFalse);
      expect(svc.paywallVariant, 'a');
    });

    test('booleans accept the usual spellings', () {
      expect(serviceWith({'kill_switch_ads': '1'}).killSwitchAds, isTrue);
      expect(serviceWith({'kill_switch_ads': 'TRUE'}).killSwitchAds, isTrue);
      expect(serviceWith({'kill_switch_ads': 'off'}).killSwitchAds, isFalse);
    });

    test('string keys with an allowed set reject unknown values', () {
      const key = StringRcKey(
        'x',
        'exclude',
        RcReader.client,
        allowed: {'exclude', 'accept_any_owner'},
      );
      expect(key.parse('accept_any_owner'), 'accept_any_owner');
      expect(key.parse('everything'), isNull);
    });
  });

  group('fetch', () {
    test('activates fetched values within the timeout', () async {
      final backend = InMemoryRemoteConfigBackend(
        remote: {'paywall_variant': 'b'},
      );
      final svc = RemoteConfigService(backend: backend);
      final result = await svc.fetchAndActivate(
        timeout: const Duration(seconds: 1),
      );
      expect(result, ConfigFetchResult.activated);
      expect(svc.paywallVariant, 'b');
    });

    test('a late fetch times out and is only applied on the next launch', () {
      fakeAsync((async) {
        final backend = InMemoryRemoteConfigBackend(
          cached: {'paywall_variant': 'cached'},
          remote: {'paywall_variant': 'fresh'},
          fetchDelay: const Duration(seconds: 5),
        );
        final svc = RemoteConfigService(backend: backend);
        ConfigFetchResult? result;
        svc.activateCached();
        svc
            .fetchAndActivate(timeout: const Duration(milliseconds: 2500))
            .then((r) => result = r);
        async.elapse(const Duration(seconds: 3));
        expect(result, ConfigFetchResult.timedOut);
        expect(svc.paywallVariant, 'cached');

        // The fetch lands later but is not activated mid-session...
        async.elapse(const Duration(seconds: 3));
        expect(svc.paywallVariant, 'cached');
        // ...until the next cold start activates it.
        svc.activateCached();
        async.flushMicrotasks();
        expect(svc.paywallVariant, 'fresh');
      });
    });

    test('a failed fetch keeps defaults', () async {
      final svc = RemoteConfigService(
        backend: InMemoryRemoteConfigBackend()..failFetch = true,
      );
      expect(
        await svc.fetchAndActivate(timeout: const Duration(seconds: 1)),
        ConfigFetchResult.failed,
      );
      expect(svc.bootTimings.maxTotal.inMilliseconds, 8000);
    });
  });
}
