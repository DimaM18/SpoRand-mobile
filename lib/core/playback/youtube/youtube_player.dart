/// The embedded YouTube player behind an interface (wave 4, provider
/// `youtube_embed`) [новое имя — согласовать]. The real implementation
/// ([IframeYouTubePlayerFactory]) wraps the pinned `youtube_player_iframe`
/// package; tests use [FakeYouTubePlayerFactory] (there is no WebView in
/// `flutter test`).
///
/// YouTube API Services policy rules this layer keeps (checked 2026-09-30):
/// - the official IFrame player only, visible, at least 200x200 px and never
///   hidden, off-screen, zero-size or overlaid (III.I.6, III.I.7, III.I.9);
/// - the app identifies itself: origin and Referer `https://<bundle id>`
///   (a missing identity is player error 153);
/// - no autoplay: the DJ presses play inside the player;
/// - nothing is downloaded, cached or proxied, and no YouTube image is shown
///   outside the player.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:sporand/core/net/protocol/ws_enums.dart';

/// The IFrame API player states (`YT.PlayerState`), for diagnostics only:
/// pre-roll ads make them useless for timing, so the round start stays the
/// DJ's «Музыка играет!» tap.
enum YouTubePlayerState {
  unknown,
  unstarted,
  ended,
  playing,
  paused,
  buffering,
  cued,
}

/// Something the player reported.
sealed class YouTubePlayerEvent {
  const YouTubePlayerEvent();
}

/// The player is ready to receive API calls.
final class YouTubePlayerReady extends YouTubePlayerEvent {
  const YouTubePlayerReady();
}

final class YouTubePlayerStateChanged extends YouTubePlayerEvent {
  const YouTubePlayerStateChanged(this.state);

  final YouTubePlayerState state;
}

/// An IFrame API `onError`. [code] is the raw code when known (2, 5, 100,
/// 101, 150, 152, 153, …); null when the player gave none.
final class YouTubePlayerFailed extends YouTubePlayerEvent {
  const YouTubePlayerFailed(this.code);

  final int? code;
}

/// Known IFrame API error codes.
abstract final class YouTubeErrorCodes {
  static const invalidParam = 2;
  static const html5 = 5;
  static const notFound = 100;
  static const notEmbeddable = 101;
  static const cannotFind = 105;
  static const notEmbeddable150 = 150;
  static const notEmbeddable152 = 152;

  /// The embed request carried no app identity (origin / Referer). The
  /// pinned package does not know this code and reports it as unknown(-1).
  static const missingIdentity = 153;
}

/// Maps a player error to `round.playback_failed.reason`.
VideoPlaybackFailureReason videoFailureReasonFor(int? code) => switch (code) {
  YouTubeErrorCodes.notFound ||
  YouTubeErrorCodes.cannotFind => VideoPlaybackFailureReason.notFound,
  YouTubeErrorCodes.notEmbeddable ||
  YouTubeErrorCodes.notEmbeddable150 ||
  YouTubeErrorCodes.notEmbeddable152 =>
    VideoPlaybackFailureReason.embedDisabled,
  YouTubeErrorCodes.missingIdentity => VideoPlaybackFailureReason.noIdentity,
  _ => VideoPlaybackFailureReason.other,
};

/// What a player is created with.
final class YouTubePlayerSpec {
  const YouTubePlayerSpec({
    required this.videoId,
    required this.startS,
    required this.origin,
    this.interfaceLanguage = 'en',
  });

  final String videoId;

  /// The player's `start` parameter (whole seconds, about ±2 s).
  final int startS;

  /// `https://<bundle id>`: the player's `origin` / `widget_referrer` and
  /// the WebView's base URL (Referer).
  final String origin;

  /// The player UI language (`hl`).
  final String interfaceLanguage;
}

/// One embedded player for one video. Created only after the consent check
/// (the player contacts Google as soon as it loads) and disposed as soon as
/// it leaves the screen.
abstract interface class YouTubeEmbedPlayer {
  String get videoId;

  Stream<YouTubePlayerEvent> get events;

  /// The official player itself: fills the box it is given (the caller
  /// sizes it, 16:9, and never draws on top of it).
  Widget buildView(BuildContext context);

  Future<void> dispose();
}

abstract interface class YouTubePlayerFactory {
  YouTubeEmbedPlayer create(YouTubePlayerSpec spec);
}

/// The YouTube minimum is 200x200 px; at 16:9 that needs 356 px of width.
const youTubePlayerFloorWidthDp = 356.0;

/// The player box for [availableWidth]: always the full width at 16:9, or
/// null when the screen is narrower than the YouTube floor (the DJ then gets
/// the cue).
///
/// Deviation, reported to the owner: `youtube_player_min_width_dp`
/// ([minWidthDp], default 480) is the width we aim for, but phones are
/// 360–430 dp wide in portrait, so a narrower screen still gets its full
/// width as long as it clears the 356 dp floor ([youTubePlayerFloorWidthDp]).
Size? youTubePlayerSize(double availableWidth, {required int minWidthDp}) {
  if (!availableWidth.isFinite || availableWidth < youTubePlayerFloorWidthDp) {
    return null;
  }
  return Size(availableWidth, availableWidth * 9 / 16);
}

/// Whether [size] reaches the configured target width.
bool youTubePlayerMeetsTarget(Size size, {required int minWidthDp}) =>
    size.width >= minWidthDp;

/// A scriptable player for tests and builds without a WebView: a plain box
/// with a key per video.
final class FakeYouTubePlayer implements YouTubeEmbedPlayer {
  FakeYouTubePlayer(this.spec);

  final YouTubePlayerSpec spec;
  final StreamController<YouTubePlayerEvent> _events =
      StreamController.broadcast(sync: true);
  bool disposed = false;

  @override
  String get videoId => spec.videoId;

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  void emit(YouTubePlayerEvent event) {
    if (!disposed) _events.add(event);
  }

  void fail(int? code) => emit(YouTubePlayerFailed(code));

  @override
  Widget buildView(BuildContext context) => SizedBox.expand(
    child: ColoredBox(
      key: ValueKey('youtube-player-$videoId'),
      color: const Color(0xFF000000),
    ),
  );

  @override
  Future<void> dispose() async {
    if (disposed) return;
    disposed = true;
    await _events.close();
  }
}

final class FakeYouTubePlayerFactory implements YouTubePlayerFactory {
  final List<FakeYouTubePlayer> created = [];

  /// Players not disposed yet.
  List<FakeYouTubePlayer> get live => [
    for (final p in created)
      if (!p.disposed) p,
  ];

  FakeYouTubePlayer? get last => created.isEmpty ? null : created.last;

  @override
  YouTubeEmbedPlayer create(YouTubePlayerSpec spec) {
    final player = FakeYouTubePlayer(spec);
    created.add(player);
    return player;
  }
}
