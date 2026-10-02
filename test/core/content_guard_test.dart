import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_kit/testing.dart';

import 'package:sporand/core/analytics/analytics_backend.dart';
import 'package:sporand/core/analytics/analytics_service.dart';

// Wave 8b: the Dart content guard is the mirror of SPORAND_CONTENT_GUARD
// (packages/protocol), which generate publishes in client-registry.json.
final _registry = File(
  'contract/generated/client-registry.json',
);

void main() {
  test('sporandContentGuard mirrors SPORAND_CONTENT_GUARD (tokens, '
      'substrings, allowed params, detectors on their samples)', () {
    expectClientRegistryMatches(
      readClientRegistry(_registry.path),
      contentGuard: sporandContentGuard,
    );
  }, skip: _registry.existsSync() ? false : 'contract/ is missing (tool/contract.sh sync)');

  test('the analytics service always uses it', () {
    final analytics = AnalyticsService(backend: InMemoryAnalyticsBackend());
    expect(analytics.contentGuard, same(sporandContentGuard));
  });

  test('names are compared by words, like the server guard', () {
    for (final name in [
      'track_id',
      'song_title',
      'spotify_uri',
      'TrackName',
      'trackName',
      'spotifyURI',
      'video_id',
      'youtube_url',
      'mySpotifyThing',
    ]) {
      expect(sporandContentGuard.isForbiddenName(name), isTrue, reason: name);
    }
    for (final name in ['track_count_bucket', 'soundtrack_id', 'placement']) {
      expect(sporandContentGuard.isForbiddenName(name), isFalse, reason: name);
    }
  });

  test('Spotify and YouTube references are never logged as values', () {
    for (final value in [
      'spotify:track:abc',
      'https://open.spotify.com/track/abc',
      'https://youtu.be/tEsTvIdEo01',
    ]) {
      expect(
        sporandContentGuard.isForbiddenValue(value),
        isTrue,
        reason: value,
      );
      expect(
        () => AnalyticsService.sanitizeParams({'placement': value}),
        throwsA(isA<AssertionError>()),
        reason: value,
      );
    }
    expect(sporandContentGuard.isForbiddenValue('lobby_rounds'), isFalse);
  });
}
