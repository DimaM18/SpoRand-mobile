import 'package:flutter/services.dart';

import 'package:sporand/core/links/external_link_launcher.dart';
import 'package:sporand/core/net/protocol/ws_models.dart';
import 'package:sporand/core/platform/app_platform.dart';
import 'package:sporand_native/sporand_native.dart';

/// Hands the DJ's cue (`round.prepare.cue`, addendum A2.2) to the DJ's own
/// music app. The app itself never plays, streams or links audio: the DJ
/// starts the song in their app on their speaker (docs/LEGAL_PLAYBACK.md).
/// [новое имя — согласовать] `MusicAppLauncher`.
abstract interface class MusicAppLauncher {
  /// Whether «Открыть в музыкальном приложении» can do anything for [cue].
  bool canOpen(RoundCue cue);

  /// True when a music app (or the cue's link) was opened.
  Future<bool> open(RoundCue cue);
}

/// Android: `MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH` through the
/// Pigeon `MusicAppApi`. iOS has no such system intent, so it opens the
/// cue's `hint_url` when the server sent one; otherwise the DJ only reads
/// the title and artists.
final class NativeMusicAppLauncher implements MusicAppLauncher {
  NativeMusicAppLauncher({
    required this._platform,
    required this._links,
    MusicAppApi? api,
  }) : _api = api ?? MusicAppApi();

  final AppPlatform _platform;
  final ExternalLinkLauncher _links;
  final MusicAppApi _api;

  @override
  bool canOpen(RoundCue cue) => switch (_platform) {
    AppPlatform.android => true,
    AppPlatform.ios || AppPlatform.other => _hintUri(cue) != null,
  };

  @override
  Future<bool> open(RoundCue cue) async {
    if (_platform == AppPlatform.android) {
      try {
        if (await _api.playFromSearch(searchFor(cue))) return true;
      } on PlatformException {
        // No bridge (or it failed): try the link below.
      }
    }
    final uri = _hintUri(cue);
    return uri != null && await _links.open(uri);
  }

  /// The system media search for [cue].
  static MusicSearchMessage searchFor(RoundCue cue) => MusicSearchMessage(
    title: cue.title,
    artist: cue.artists.isEmpty ? '' : cue.artists.first,
    query: [cue.title, ...cue.artists].join(' '),
  );

  static Uri? _hintUri(RoundCue cue) {
    final uri = Uri.tryParse(cue.hintUrl ?? '');
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    return uri;
  }
}

final class FakeMusicAppLauncher implements MusicAppLauncher {
  FakeMusicAppLauncher({this.available = true, this.opens = true});

  bool available;
  bool opens;
  final List<RoundCue> opened = [];

  @override
  bool canOpen(RoundCue cue) => available;

  @override
  Future<bool> open(RoundCue cue) async {
    opened.add(cue);
    return opens;
  }
}
