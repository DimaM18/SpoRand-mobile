import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:sporand/core/playback/youtube/youtube_player.dart';
import 'package:youtube_player_iframe/webview.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;

/// [YouTubePlayerFactory] over the pinned `youtube_player_iframe` package: a
/// thin wrapper, not a fork. [НЕ ПРОВЕРЕНО на устройствах]
///
/// What it changes from the package defaults:
/// - `origin` / `widget_referrer` and the WebView base URL (Referer) are
///   `https://<bundle id>` ([YouTubePlayerSpec.origin]); without them the
///   package loads youtube-nocookie with no identity and the player fails
///   with error 153;
/// - it renders the package's WebView itself (a plain `WebViewWidget` in the
///   box the caller sizes) instead of the package's `YoutubePlayer` widget,
///   which paints a Flutter thumbnail over the player while loading and
///   moves the WebView into an app-wide overlay for its fullscreen handling;
/// - no autoplay (`cueVideoById`: the DJ presses play), no fullscreen button;
/// - error 153: the package maps unknown codes to `unknown(-1)`, so the raw
///   `onError` code is forwarded through an extra JavaScript channel.
final class IframeYouTubePlayerFactory implements YouTubePlayerFactory {
  const IframeYouTubePlayerFactory();

  @override
  YouTubeEmbedPlayer create(YouTubePlayerSpec spec) =>
      _IframeYouTubePlayer(spec);
}

final class _IframeYouTubePlayer implements YouTubeEmbedPlayer {
  _IframeYouTubePlayer(this.spec)
    : controller = yt.YoutubePlayerController(
        params: yt.YoutubePlayerParams(
          origin: spec.origin,
          interfaceLanguage: spec.interfaceLanguage,
          // youtube.com with an explicit origin; the Referer comes from the
          // WebView base URL below.
          privacyEnhancedMode: false,
          showFullscreenButton: false,
          strictRelatedVideos: true,
        ),
        key: spec.videoId,
      ) {
    controller.webViewController.addJavaScriptChannel(
      _errorChannel,
      onMessageReceived: _onRawError,
    );
    _valueSub = controller.listen(_onValue);
    unawaited(_load());
  }

  static const _errorChannel = 'SporandYouTubeError';

  final YouTubePlayerSpec spec;
  final yt.YoutubePlayerController controller;
  final StreamController<YouTubePlayerEvent> _events =
      StreamController.broadcast();
  StreamSubscription<yt.YoutubePlayerValue>? _valueSub;
  yt.PlayerState _lastState = yt.PlayerState.unknown;
  int? _lastRawCode;
  bool _disposed = false;

  @override
  String get videoId => spec.videoId;

  @override
  Stream<YouTubePlayerEvent> get events => _events.stream;

  Future<void> _load() async {
    try {
      await controller.initWithParams(
        params: controller.params,
        baseUrl: spec.origin,
      );
      await controller.cueVideoById(
        videoId: spec.videoId,
        startSeconds: spec.startS.toDouble(),
      );
      if (_disposed) return;
      _emit(const YouTubePlayerReady());
      // Mirror every PlayerError message of the package's page to our own
      // channel with the raw code (the page calls `sendMessage` by name).
      await controller.webViewController.runJavaScript('''
(function () {
  if (window.__sporandErrorHook) return;
  window.__sporandErrorHook = true;
  var original = sendMessage;
  sendMessage = function (key, data) {
    if (key === 'PlayerError') $_errorChannel.postMessage(String(data));
    original(key, data);
  };
})();
''');
    } on Object catch (error) {
      if (kDebugMode) debugPrint('[youtube] load failed: $error');
      _emit(const YouTubePlayerFailed(null));
    }
  }

  void _onRawError(JavaScriptMessage message) {
    final code = int.tryParse(message.message.trim());
    if (code == null || code == _lastRawCode) return;
    _lastRawCode = code;
    _emit(YouTubePlayerFailed(code));
  }

  void _onValue(yt.YoutubePlayerValue value) {
    if (value.playerState != _lastState) {
      _lastState = value.playerState;
      _emit(YouTubePlayerStateChanged(_mapState(value.playerState)));
    }
    final error = value.error;
    if (error == yt.YoutubeError.none) return;
    // Known codes arrive here; an unknown one (153) through the channel,
    // which may be a moment later: give it the chance to win.
    if (error == yt.YoutubeError.unknown) {
      Timer(const Duration(milliseconds: 300), () {
        if (_lastRawCode == null) _emit(const YouTubePlayerFailed(null));
      });
      return;
    }
    if (error.code == _lastRawCode) return;
    _lastRawCode = error.code;
    _emit(YouTubePlayerFailed(error.code));
  }

  static YouTubePlayerState _mapState(yt.PlayerState state) => switch (state) {
    yt.PlayerState.unStarted => YouTubePlayerState.unstarted,
    yt.PlayerState.ended => YouTubePlayerState.ended,
    yt.PlayerState.playing => YouTubePlayerState.playing,
    yt.PlayerState.paused => YouTubePlayerState.paused,
    yt.PlayerState.buffering => YouTubePlayerState.buffering,
    yt.PlayerState.cued => YouTubePlayerState.cued,
    _ => YouTubePlayerState.unknown,
  };

  void _emit(YouTubePlayerEvent event) {
    if (!_disposed && !_events.isClosed) _events.add(event);
  }

  @override
  Widget buildView(BuildContext context) =>
      WebViewWidget(controller: controller.webViewController);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _valueSub?.cancel();
    await _events.close();
    // Blank the page first: that stops the video and its audio at once,
    // whatever state the player is in.
    try {
      await controller.webViewController.loadRequest(Uri.parse('about:blank'));
    } on Object {
      // Nothing left to unload.
    }
    // `close` may wait for a player that never became ready; the view is
    // already gone, so it runs in the background.
    unawaited(controller.close().catchError((Object _) {}));
  }
}
