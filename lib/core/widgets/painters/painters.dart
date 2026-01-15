import 'package:flutter/material.dart';
import 'package:sabi_wallet/core/constants/colors.dart';

// All shared painters here (no duplicates!)
class ShieldIconPainter extends CustomPainter {
  const ShieldIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(size.width * 0.833, size.height * 0.542);
    path.cubicTo(
      size.width * 0.833,
      size.height * 0.75,
      size.width * 0.687,
      size.height * 0.853,
      size.width * 0.515,
      size.height * 0.915,
    );
    path.cubicTo(
      size.width * 0.507,
      size.height * 0.918,
      size.width * 0.493,
      size.height * 0.918,
      size.width * 0.486,
      size.height * 0.914,
    );
    path.cubicTo(
      size.width * 0.313,
      size.height * 0.853,
      size.width * 0.167,
      size.height * 0.75,
      size.width * 0.167,
      size.height * 0.542,
    );
    path.lineTo(size.width * 0.167, size.height * 0.25);
    path.cubicTo(
      size.width * 0.167,
      size.height * 0.227,
      size.width * 0.176,
      size.height * 0.206,
      size.width * 0.191,
      size.height * 0.191,
    );
    path.cubicTo(
      size.width * 0.206,
      size.height * 0.176,
      size.width * 0.227,
      size.height * 0.167,
      size.width * 0.25,
      size.height * 0.167,
    );
    path.cubicTo(
      size.width * 0.333,
      size.height * 0.167,
      size.width * 0.479,
      size.height * 0.095,
      size.width * 0.57,
      size.height * 0.012,
    );
    path.cubicTo(
      size.width * 0.582,
      size.height * 0.002,
      size.width * 0.599,
      size.height * -0.004,
      size.width * 0.617,
      size.height * -0.004,
    );
    path.cubicTo(
      size.width * 0.635,
      size.height * -0.004,
      size.width * 0.652,
      size.height * 0.002,
      size.width * 0.664,
      size.height * 0.012,
    );
    path.cubicTo(
      size.width * 0.755,
      size.height * 0.095,
      size.width * 0.896,
      size.height * 0.167,
      size.width * 0.979,
      size.height * 0.167,
    );
    path.cubicTo(
      size.width * 1.002,
      size.height * 0.167,
      size.width * 1.023,
      size.height * 0.176,
      size.width * 1.038,
      size.height * 0.191,
    );
    path.cubicTo(
      size.width * 1.053,
      size.height * 0.206,
      size.width * 1.062,
      size.height * 0.227,
      size.width * 1.062,
      size.height * 0.25,
    );
    path.lineTo(size.width * 1.062, size.height * 0.542);
    canvas.drawPath(path, paint);

    final checkPath = Path();
    checkPath.moveTo(size.width * 0.375, size.height * 0.5);
    checkPath.lineTo(size.width * 0.458, size.height * 0.583);
    checkPath.lineTo(size.width * 0.625, size.height * 0.417);
    canvas.drawPath(checkPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BitcoinLogoPainter extends CustomPainter {
  const BitcoinLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;

    final path = Path();
    final scaleX = size.width / 160;
    final scaleY = size.height / 160;

    // Main Bitcoin B path (abbreviated for brevity - use full from your original)
    path.moveTo(109.895 * scaleX, 72.1283 * scaleY);
    // ... (copy the full path from your original onboarding_screen.dart BitcoinLogoPainter)
    // For full path, paste the entire path.moveTo and cubicTo chains here

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Add LightningPainter, HandshakePainter similarly - copy from original
class LightningPainter extends CustomPainter {
  const LightningPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(43.7767, 7.93);
    // ... (full path from original)
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HandshakePainter extends CustomPainter {
  const HandshakePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(68, 31);
    // ... (full path from original)
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
