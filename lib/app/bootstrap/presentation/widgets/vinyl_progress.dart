import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';

/// A spinning vinyl record inside a gradient progress ring.
///
/// [progress] is the real weighted boot progress. The ring eases toward it
/// and never moves backwards. Rotation and easing run in painters bound to
/// animations, so a tick repaints this boundary only and rebuilds nothing.
class VinylProgress extends StatefulWidget {
  const VinylProgress({
    super.key,
    required this.progress,
    required this.animate,
    this.size = 220,
  });

  final double progress;
  final bool animate;
  final double size;

  @override
  State<VinylProgress> createState() => _VinylProgressState();
}

class _VinylProgressState extends State<VinylProgress>
    with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: Motion.vinylTurn,
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: Motion.slow,
    value: widget.progress.clamp(0.0, 1.0),
  );

  @override
  void initState() {
    super.initState();
    _syncSpin();
  }

  @override
  void didUpdateWidget(VinylProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _syncSpin();
    _easeTo(widget.progress);
  }

  void _syncSpin() {
    if (widget.animate) {
      _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  void _easeTo(double target) {
    // Never backwards: a retry keeps finished steps, so progress only grows.
    final next = math.max(target.clamp(0.0, 1.0), _ring.value);
    if (next == _ring.value) return;
    if (widget.animate) {
      _ring.animateTo(next, curve: Curves.easeOutCubic);
    } else {
      _ring.value = next;
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final party = PartyColors.of(context);
    final ringWidth = widget.size * 0.03;
    return RepaintBoundary(
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: _ring,
            colors: party.gradient,
            track: party.ringTrack,
            strokeWidth: ringWidth,
          ),
          child: Padding(
            padding: EdgeInsets.all(ringWidth * 3.2),
            child: CustomPaint(
              painter: _VinylPainter(
                rotation: _spin,
                labelColors: party.gradient,
                hole: party.launchBackground,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}

class _VinylPainter extends CustomPainter {
  _VinylPainter({
    required this.rotation,
    required this.labelColors,
    required this.hole,
  }) : super(repaint: rotation);

  final Animation<double> rotation;
  final List<Color> labelColors;
  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final disc = Rect.fromCircle(center: center, radius: r);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFF1C1929), BrandColors.vinyl],
          stops: [0.35, 1],
        ).createShader(disc),
    );

    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.6, r * 0.006)
      ..color = const Color(0x12FFFFFF);
    for (var radius = r * 0.42; radius < r * 0.96; radius += r * 0.034) {
      canvas.drawCircle(center, radius, groove);
    }
    canvas.drawCircle(
      center,
      r - 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = BrandColors.vinylEdge,
    );

    // Label and marker rotate; the sheen below stays put like a real light.
    final labelRadius = r * 0.36;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..rotate(rotation.value * 2 * math.pi);
    canvas.drawCircle(
      Offset.zero,
      labelRadius,
      Paint()
        ..shader = SweepGradient(colors: [...labelColors, labelColors.first])
            .createShader(
              Rect.fromCircle(center: Offset.zero, radius: labelRadius),
            ),
    );
    canvas.drawCircle(
      Offset.zero,
      labelRadius * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.012)
        ..color = const Color(0x59FFFFFF),
    );
    canvas.drawCircle(
      Offset(0, -labelRadius * 0.52),
      r * 0.032,
      Paint()..color = const Color(0xE6FFFFFF),
    );
    canvas.restore();

    canvas.drawCircle(center, r * 0.05, Paint()..color = hole);

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0x00FFFFFF),
            Color(0x1FFFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x14FFFFFF),
            Color(0x00FFFFFF),
          ],
          stops: [0, 0.07, 0.16, 0.5, 0.57, 0.66],
          transform: GradientRotation(-math.pi / 3),
        ).createShader(disc),
    );
  }

  @override
  bool shouldRepaint(_VinylPainter old) =>
      old.rotation != rotation ||
      old.hole != hole ||
      !listEquals(old.labelColors, labelColors);
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.colors,
    required this.track,
    required this.strokeWidth,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final List<Color> colors;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - strokeWidth * 1.6;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = track,
    );

    final value = progress.value.clamp(0.0, 1.0);
    if (value <= 0) return;
    const start = -math.pi / 2;
    final sweep = 2 * math.pi * value;
    final shader = SweepGradient(
      colors: [...colors, colors.first],
      transform: const GradientRotation(start),
    ).createShader(rect);

    // Soft glow under the arc, then the crisp arc on top.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 2.2
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..color = const Color(0x8C000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 1.4),
    );
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    final head = center + Offset.fromDirection(start + sweep, radius);
    canvas.drawCircle(
      head,
      strokeWidth * 0.95,
      Paint()
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.6),
    );
    canvas.drawCircle(head, strokeWidth * 0.45, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.strokeWidth != strokeWidth ||
      !listEquals(old.colors, colors);
}
