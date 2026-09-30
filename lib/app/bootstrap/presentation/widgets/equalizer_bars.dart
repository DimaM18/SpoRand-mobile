import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';

/// A small animated equalizer. Each bar mixes two sine waves with integer
/// frequencies over one loop, so the loop is seamless and never looks like
/// a metronome. With reduced motion the bars freeze in a static pattern.
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.animate,
    this.width = 104,
    this.height = 32,
  });

  final bool animate;
  final double width;
  final double height;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Motion.equalizerLoop,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _loop.repeat();
    } else {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _EqualizerPainter(
            phase: _loop,
            animate: widget.animate,
            colors: PartyColors.of(context).gradient,
          ),
        ),
      ),
    );
  }
}

class _EqualizerPainter extends CustomPainter {
  _EqualizerPainter({
    required this.phase,
    required this.animate,
    required this.colors,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final bool animate;
  final List<Color> colors;

  static const _bars = 7;
  static const _static = [0.35, 0.6, 0.85, 1.0, 0.8, 0.55, 0.3];
  static const _f1 = [1, 2, 3, 2, 1, 3, 2];
  static const _f2 = [3, 1, 2, 4, 3, 1, 3];
  static const _offsets = [0.0, 1.3, 2.1, 0.7, 2.9, 1.9, 0.4];

  double _level(int i) {
    if (!animate) return _static[i];
    final t = phase.value * 2 * math.pi;
    final wave =
        0.6 * math.sin(_f1[i] * t + _offsets[i]) +
        0.4 * math.sin(_f2[i] * t + _offsets[i] * 1.7);
    return 0.22 + 0.78 * (0.5 + 0.5 * wave);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const gapRatio = 0.6;
    final barWidth = size.width / (_bars + (_bars - 1) * gapRatio);
    final gap = barWidth * gapRatio;
    final shader = LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: colors,
    ).createShader(Offset.zero & size);
    final paint = Paint()..shader = shader;
    for (var i = 0; i < _bars; i++) {
      final height = math.max(barWidth, size.height * _level(i));
      final left = i * (barWidth + gap);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_EqualizerPainter old) =>
      old.phase != phase ||
      old.animate != animate ||
      !listEquals(old.colors, colors);
}
