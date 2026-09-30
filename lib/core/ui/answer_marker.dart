import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:sporand/core/l10n/l10n.dart';

/// The shape of an answer slot, so colour is never the only signal:
/// A circle, B triangle, C square, D diamond, E hexagon, F star.
enum AnswerShape {
  circle,
  triangle,
  square,
  diamond,
  hexagon,
  star;

  static AnswerShape forIndex(int index) => values[index % values.length];

  /// The slot letter: A..F.
  static String letterFor(int index) =>
      String.fromCharCode(0x41 + index % values.length);

  /// The localized shape name, for screen readers.
  String label(AppLocalizations l10n) => switch (this) {
    circle => l10n.gameMarkerCircle,
    triangle => l10n.gameMarkerTriangle,
    square => l10n.gameMarkerSquare,
    diamond => l10n.gameMarkerDiamond,
    hexagon => l10n.gameMarkerHexagon,
    star => l10n.gameMarkerStar,
  };

  /// The shape as a path filling [size] (centred, same visual weight).
  Path path(Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    switch (this) {
      case circle:
        return Path()..addOval(Rect.fromCircle(center: c, radius: r * 0.92));
      case square:
        final s = r * 0.82;
        return Path()..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s * 2, height: s * 2),
            Radius.circular(r * 0.22),
          ),
        );
      case triangle:
        return _polygon(c, r * 1.08, 3, -math.pi / 2, dy: r * 0.14);
      case diamond:
        return _polygon(c, r, 4, -math.pi / 2);
      case hexagon:
        return _polygon(c, r * 0.98, 6, 0);
      case star:
        return _star(c, r, r * 0.55);
    }
  }

  static Path _polygon(
    Offset c,
    double r,
    int sides,
    double start, {
    double dy = 0,
  }) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = start + i * 2 * math.pi / sides;
      final p = Offset(c.dx + r * math.cos(a), c.dy + dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static Path _star(Offset c, double outer, double inner) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }
}

/// A 40 dp marker disc: the slot's filled shape with its letter inside.
/// Decorative for screen readers (the tile's label names the shape).
class AnswerMarker extends StatelessWidget {
  const AnswerMarker({
    super.key,
    required this.index,
    required this.color,
    required this.onColor,
    this.size = 40,
  });

  final int index;

  /// Shape fill and letter color.
  final Color color;
  final Color onColor;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shape = AnswerShape.forIndex(index);
    final letterStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: onColor,
      fontWeight: FontWeight.w900,
      height: 1,
      // Star and triangle leave less room for the letter.
      fontSize: size * (shape == AnswerShape.star ? 0.3 : 0.38),
    );
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ShapePainter(shape: shape, color: color),
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(
                top: shape == AnswerShape.triangle ? size * 0.16 : 0,
              ),
              // The letter is a fixed-size glyph inside a fixed-size shape.
              child: MediaQuery.withNoTextScaling(
                child: Text(AnswerShape.letterFor(index), style: letterStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShapePainter extends CustomPainter {
  const _ShapePainter({required this.shape, required this.color});

  final AnswerShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      shape.path(size),
      Paint()
        ..color = color
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(_ShapePainter old) =>
      old.shape != shape || old.color != color;
}
