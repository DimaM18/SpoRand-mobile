import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';

/// A spinning vinyl record inside a gradient progress ring.
///
/// [progress] is the real weighted boot progress. The ring eases toward it
/// and never moves backwards. Neither the spin nor the easing rebuilds
/// widgets, and a spin frame repaints nothing (see the layering in build).
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
    // Layering keeps the 60 fps spin off the paint path: the ring repaints
    // only while progress eases; the disc and its sheen are recorded once;
    // the label turns as a compositor transform over its cached layer, so a
    // rotation frame re-records nothing but that transform.
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
              painter: const _DiscPainter(),
              foregroundPainter: _SheenPainter(hole: party.launchBackground),
              child: RepaintBoundary(
                child: RotationTransition(
                  turns: _spin,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _LabelPainter(colors: party.gradient),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The record itself: body, grooves and rim. Static.
class _DiscPainter extends CustomPainter {
  const _DiscPainter();

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
  }

  @override
  bool shouldRepaint(_DiscPainter old) => false;
}

/// The label and its marker; rotated by a transform, never repainted.
class _LabelPainter extends CustomPainter {
  const _LabelPainter({required this.colors});

  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final labelRadius = r * 0.36;
    canvas.drawCircle(
      center,
      labelRadius,
      Paint()
        ..shader = SweepGradient(colors: [...colors, colors.first])
            .createShader(Rect.fromCircle(center: center, radius: labelRadius)),
    );
    canvas.drawCircle(
      center,
      labelRadius * 0.74,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.012)
        ..color = const Color(0x59FFFFFF),
    );
    canvas.drawCircle(
      center + Offset(0, -labelRadius * 0.52),
      r * 0.032,
      Paint()..color = const Color(0xE6FFFFFF),
    );
  }

  @override
  bool shouldRepaint(_LabelPainter old) => !listEquals(old.colors, colors);
}

/// Spindle hole and a fixed sheen above the turning label, like a real
/// light on a spinning record. Static.
class _SheenPainter extends CustomPainter {
  const _SheenPainter({required this.hole});

  final Color hole;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.shortestSide / 2;
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
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.hole != hole;
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
