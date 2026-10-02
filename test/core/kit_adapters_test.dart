// Wave 8b: SpoRand's adapters over mobile_kit keep the old constructors and
// names, and add only SpoRand's keys and fields.
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_kit/mobile_kit.dart' as kit;

import 'package:sporand/core/net/protocol/rest_models.dart';
import 'package:sporand/core/net/protocol/ws_enums.dart';
import 'package:sporand/core/remote_config/remote_config_backend.dart';
import 'package:sporand/core/remote_config/remote_config_keys.dart';
import 'package:sporand/core/remote_config/remote_config_service.dart';
import 'package:sporand/core/storage/preferences_store.dart';
import 'package:sporand/core/storage/user_prefs_repository.dart';

void main() {
  group('preferences', () {
    test('the allow list holds the kit keys and the game keys, with the '
        'persistent names', () {
      expect(PrefKeys.all, containsAll(KitPrefKeys.all));
      expect(
        PrefKeys.all,
        containsAll(['display_name', 'youtube_player_consent']),
      );
      expect(PrefKeys.all, hasLength(KitPrefKeys.all.length + 2));
      expect(SharedPreferencesStore().allowList, PrefKeys.all);
    });

    test(
      'UserPrefsRepository is the kit prefs plus the display name',
      () async {
        final store = InMemoryPreferencesStore();
        await store.open();
        final prefs = UserPrefsRepository(store);
        expect(prefs, isA<KitUserPrefs>());
        await prefs.saveDisplayName('Bartek');
        expect(store.getString(PrefKeys.displayName), 'Bartek');
        // The same value through the kit's own type.
        expect(KitUserPrefs(store).displayName, 'Bartek');
      },
    );
  });

  group('Remote Config', () {
    test('the adapter reads every SpoRand key; the game getters agree with '
        'the extension on a kit-built service', () {
      final backend = InMemoryRemoteConfigBackend()
        ..pushUpdate({
          'modes_enabled': '["guess_track","whose_song"]',
          'youtube_player_min_width_dp': '600',
          'spotify_proto_enabled': 'true',
        });
      final adapter = RemoteConfigService(backend: backend);
      final base = kit.RemoteConfigService(backend: backend, keys: RcKeys.all);
      expect(adapter.keys, RcKeys.all);
      expect(adapter.modesEnabled, [GameMode.whoseSong, GameMode.guessTrack]);
      expect(base.modesEnabled, adapter.modesEnabled);
      expect(base.youtubePlayerMinWidthDp, 600);
      expect(base.spotifyProtoEnabled, isTrue);
      expect(base.licensedProviderEnabled, isFalse);
    });
  });

  group('REST extras', () {
    final me = {
      'user': {
        'user_id': '0192b1a0-0000-7000-8000-000000000201',
        'analytics_uid': 'a1f3c9e07b5d4e2f8c6a0b1d9e7f3a5c',
        'created_at': '2026-09-30T10:00:00Z',
        'locale': 'pl-PL',
        'consent_analytics': true,
        'consent_ads_personalized': false,
        'games_completed': 3,
      },
      'entitlements': {'no_ads': true, 'premium': false, 'items': <Object?>[]},
      'music_links': [
        {'provider': 'spotify_app_remote'},
      ],
    };

    test('games_completed and music_links keep their old names', () {
      final response = MeResponse.fromJson(me);
      expect(response.user.gamesCompleted, 3);
      expect(response.musicLinks, hasLength(1));
      expect(response.entitlements.isActive('no_ads'), isTrue);
      expect(response.toJson()['music_links'], me['music_links']);
      expect(
        (response.toJson()['user']! as Map<String, Object?>)['games_completed'],
        3,
      );
    });

    test('absent fields read as empty', () {
      final user = UserProfile.fromJson(
        {...(me['user']! as Map<String, Object?>)}..remove('games_completed'),
      );
      expect(user.gamesCompleted, 0);
      expect(
        MeResponse.fromJson({...me}..remove('music_links')).musicLinks,
        isEmpty,
      );
    });
  });
}
