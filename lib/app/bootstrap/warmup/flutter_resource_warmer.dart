import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'package:sporand/app/bootstrap/warmup/resource_warmer.dart';
import 'package:sporand/app/theme/tokens.dart';

/// Warm-up for the `warmup` stage.
///
/// The splash and the MVP UI are code-drawn, so there are no image, Lottie
/// or Rive assets yet; those hooks stay cheap until assets are added.
final class FlutterResourceWarmer implements ResourceWarmer {
  FlutterResourceWarmer({this.imageAssets = const []});

  /// Asset paths to decode into the image cache before the first screen.
  final List<String> imageAssets;

  @override
  Future<void> precacheImages() async {
    await Future.wait(imageAssets.map((path) => _resolve(AssetImage(path))));
  }

  static Future<void> _resolve(ImageProvider provider) {
    final done = Completer<void>();
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (_, _) {
        if (!done.isCompleted) done.complete();
        stream.removeListener(listener);
      },
      onError: (Object error, StackTrace? stack) {
        if (!done.isCompleted) done.completeError(error, stack);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return done.future;
  }

  /// Lays out text in every script we ship (Cyrillic, Latin, Polish
  /// diacritics) at the display weights, so the first real screen does not
  /// pay for font fallback resolution and glyph rasterization.
  @override
  Future<void> loadFonts() async {
    const sample =
        'Чья это песня? Whose song? Czyja to piosenka? ąęłńóśźż 0123';
    for (final weight in const [
      FontWeight.w400,
      FontWeight.w700,
      FontWeight.w900,
    ]) {
      final painter = TextPainter(
        text: TextSpan(
          text: sample,
          style: TextStyle(fontSize: 24, fontWeight: weight),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.dispose();
      // Yield between layouts so the splash keeps animating.
      await Future<void>.delayed(Duration.zero);
    }
  }

  // TODO(part2): preload UI sound effects once the audio player lands
  // (never over a snippet: Spotify III.7 forbids mixing with its audio).
  @override
  Future<void> loadSoundEffects() async {}

  @override
  Future<void> loadAnimations() async {}

  /// Rasterizes the gradients, blurs and arcs the app uses into a tiny
  /// offscreen image so their pipelines are compiled before first use.
  @override
  Future<void> warmUpShaders() async {
    const size = 96.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const rect = Rect.fromLTWH(0, 0, size, size);
    canvas.drawCircle(
      rect.center,
      size / 2,
      Paint()
        ..shader = const RadialGradient(
          colors: [BrandColors.violet, Color(0x00000000)],
        ).createShader(rect),
    );
    canvas.drawArc(
      rect.deflate(8),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..shader = const SweepGradient(
          colors: [BrandColors.cyan, BrandColors.violet, BrandColors.magenta],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(24), const Radius.circular(8)),
      Paint()
        ..shader = const LinearGradient(
          colors: [BrandColors.magenta, BrandColors.amber],
        ).createShader(rect),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    image.dispose();
    picture.dispose();
  }
}
