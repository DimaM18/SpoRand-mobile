import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:sporand/app/theme/tokens.dart';

/// Full-screen background of the boot screens: the launch-screen color with
/// two soft, slowly breathing glows.
///
/// The first frame is exactly the native launch color (glows fade in from
/// zero), so the native -> Flutter hand-over has no visible flash.
class BootBackdrop extends StatefulWidget {
  const BootBackdrop({super.key, required this.animate});

  final bool animate;

  @override
  State<BootBackdrop> createState() => _BootBackdropState();
}

class _BootBackdropState extends State<BootBackdrop>
    with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: Motion.glowBreath,
  );
  late final AnimationController _fadeIn = AnimationController(
    vsync: this,
    duration: Motion.slow,
  );
  late final CurvedAnimation _breathCurve = CurvedAnimation(
    parent: _breath,
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(BootBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animate != widget.animate) _sync();
  }

  void _sync() {
    if (widget.animate) {
      _fadeIn.forward();
      _breath.repeat(reverse: true);
    } else {
      _fadeIn.value = 1;
      _breath
        ..stop()
        ..value = 0.5;
    }
  }

  @override
  void dispose() {
    _breathCurve.dispose();
    _breath.dispose();
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final party = PartyColors.of(context);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _GlowPainter(
          breath: _breathCurve,
          fadeIn: _fadeIn,
          background: party.launchBackground,
          glow: party.glow,
          secondaryGlow: party.secondaryGlow,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  _GlowPainter({
    required this.breath,
    required this.fadeIn,
    required this.background,
    required this.glow,
    required this.secondaryGlow,
  }) : super(repaint: Listenable.merge([breath, fadeIn]));

  final Animation<double> breath;
  final Animation<double> fadeIn;
  final Color background;
  final Color glow;
  final Color secondaryGlow;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final opacity = fadeIn.value;
    if (opacity <= 0) return;
    final shortest = size.shortestSide;
    final scale = 0.94 + 0.12 * breath.value;

    void glowAt(Offset center, double radius, Color color) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: color.a * opacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    glowAt(
      Offset(size.width / 2, size.height * 0.42),
      shortest * 0.75 * scale,
      glow,
    );
    // Counter-phase secondary glow keeps the light moving.
    glowAt(
      Offset(size.width * 0.88, size.height * 0.92),
      shortest * 0.6 * (2.0 - scale),
      secondaryGlow,
    );
    glowAt(
      Offset(size.width * 0.08, size.height * 0.1),
      shortest * 0.45 * math.max(scale, 1),
      secondaryGlow.withValues(alpha: secondaryGlow.a * 0.6),
    );
  }

  @override
  bool shouldRepaint(_GlowPainter old) =>
      old.background != background ||
      old.glow != glow ||
      old.secondaryGlow != secondaryGlow ||
      old.breath != breath ||
      old.fadeIn != fadeIn;
}
