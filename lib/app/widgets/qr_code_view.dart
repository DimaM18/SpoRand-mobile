import 'package:material_ui/material_ui.dart';
import 'package:qr/qr.dart';

/// A QR code drawn in code (the `qr` package only encodes). Dark modules
/// on a light quiet zone in both themes so every camera can read it.
class QrCodeView extends StatelessWidget {
  const QrCodeView({
    super.key,
    required this.data,
    required this.semanticLabel,
    this.size = 180,
  });

  final String data;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final image = QrImage(QrCode(payload: QrPayload.fromString(data)));
    return Semantics(
      label: semanticLabel,
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size / 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size / 10),
        ),
        child: RepaintBoundary(child: CustomPaint(painter: _QrPainter(image))),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter(this.image);

  final QrImage image;

  @override
  void paint(Canvas canvas, Size size) {
    final count = image.moduleCount;
    final cell = size.shortestSide / count;
    final paint = Paint()
      ..color = const Color(0xFF0E0B1F)
      ..isAntiAlias = false;
    final path = Path();
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < count; col++) {
        if (image.isDark(row, col)) {
          // Slight overlap avoids hairline gaps between modules.
          path.addRect(
            Rect.fromLTWH(col * cell, row * cell, cell + 0.5, cell + 0.5),
          );
        }
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_QrPainter oldDelegate) => oldDelegate.image != image;
}
