import 'package:mobile_kit/mobile_kit.dart' as kit;

export 'package:mobile_kit/mobile_kit.dart'
    show AnalyticsConsent, AnalyticsContentGuard, ContentValueDetector;

/// Client analytics facade (brief §4.5): mobile_kit's `AnalyticsService`
/// (wave 8b) with SpoRand's content guard, under its old constructor.
///
/// The kit validates names against the GA4 limits, applies the content
/// guard (assert in debug, dropped in release) and gates collection on
/// consent: events are buffered until consent is known, flushed when
/// granted and dropped when denied or disabled.
///
/// The static helpers keep the old names that tests call; the kit's own
/// instance methods are `allowsParamName` and `sanitize`.
class AnalyticsService extends kit.AnalyticsService {
  AnalyticsService({required super.backend, super.maxBuffered})
    : super(contentGuard: sporandContentGuard);

  static const maxNameLength = kit.AnalyticsService.maxNameLength;
  static const maxParams = kit.AnalyticsService.maxParams;
  static const maxStringValueLength = kit.AnalyticsService.maxStringValueLength;

  /// GA4 automatically collected / reserved event names.
  static const reservedEventNames = kit.AnalyticsService.reservedEventNames;

  /// Converts and checks parameters like every [logEvent] does.
  static final kit.AnalyticsService _guarded = kit.AnalyticsService(
    backend: kit.InMemoryAnalyticsBackend(),
    contentGuard: sporandContentGuard,
  );

  /// A value that looks like YouTube content: a YouTube link, or a mixed-case
  /// 11-character value shaped like a video id (packages/protocol
  /// `isYouTubeContentValue`, the `youtube_ref` detector of the content
  /// guard). Such values are never logged (YouTube API policy; hard rule 3).
  /// Our own 11-character values (`guess_track`, `emo_pl_0001`) are
  /// single-case and pass.
  static bool isYouTubeContentValue(String value) =>
      _youTubeReference.hasMatch(value) ||
      (_videoIdShape.hasMatch(value) &&
          value.contains(RegExp('[a-z]')) &&
          value.contains(RegExp('[A-Z]')));

  /// Whether the content guard lets [name] through as a parameter name
  /// (Spotify Terms IV.2.5: no track, artist, title, playlist, video or
  /// Spotify/YouTube data). `pool_submit.track_count_bucket` carries only a
  /// count bucket and is explicitly allowed.
  static bool isAllowedParamName(String name) =>
      !sporandContentGuard.isForbiddenName(name);

  /// Validates parameter names and converts values to GA4 types: booleans
  /// become 1/0 (GA4 has no boolean type), strings are truncated to 100
  /// characters, nulls are dropped; names and values the content guard
  /// rejects are dropped (and assert in debug builds).
  static Map<String, Object> sanitizeParams(Map<String, Object?> params) =>
      _guarded.sanitize(params);
}

final _spotifyReference = RegExp(
  r'spotify:|open\.spotify\.com|spotify\.link',
  caseSensitive: false,
);
final _youTubeReference = RegExp(
  r'youtube\.com|youtu\.be|youtube-nocookie\.com|ytimg\.com|googlevideo\.com',
  caseSensitive: false,
);
final _videoIdShape = RegExp(r'^[A-Za-z0-9_-]{11}$');

bool _isSpotifyReference(String value) => _spotifyReference.hasMatch(value);

/// The Dart mirror of `SPORAND_CONTENT_GUARD` (packages/protocol
/// `src/analytics/rules.ts`, published in `generated/client-registry.json`):
/// no track, artist, title, playlist, video or Spotify/YouTube data in
/// analytics (Spotify Terms IV.2.5, YouTube API policies; hard rule 4).
///
/// A parameter name is refused when one of its words (`_` segments and
/// camelCase parts) is a token, or it contains `spotify` or `youtube`; a
/// string value when a detector matches it. [новое имя — согласовать]
const sporandContentGuard = kit.AnalyticsContentGuard(
  nameTokens: {
    'track',
    'artist',
    'playlist',
    'title',
    'spotify',
    'album',
    'song',
    'isrc',
    'uri',
    'video',
    'youtube',
  },
  nameSubstrings: ['spotify', 'youtube'],
  allowParams: {'track_count_bucket'},
  valueDetectors: [
    kit.ContentValueDetector(id: 'spotify_ref', test: _isSpotifyReference),
    kit.ContentValueDetector(
      id: 'youtube_ref',
      test: AnalyticsService.isYouTubeContentValue,
    ),
  ],
  reason:
      'no track, artist, title, playlist, video or Spotify/YouTube data in '
      'analytics: Spotify Terms IV.2.5, YouTube API policies',
);
