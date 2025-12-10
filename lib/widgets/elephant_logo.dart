import 'package:flutter/material.dart';
import 'dart:math' as math;

class ElephantLogo extends StatelessWidget {
  final double size;
  
  const ElephantLogo({
    super.key,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ElephantPainter(),
      ),
    );
  }
}

class ElephantPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final accentPaint = Paint()
      ..color = const Color(0xFFCDDC39)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Draw outer circles
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius - 5, paint);

    // Draw decorative elements on circle
    _drawCircleDecorations(canvas, center, radius, paint);

    // Draw elephant head outline
    _drawElephantHead(canvas, center, size, paint);
  }

  void _drawCircleDecorations(Canvas canvas, Offset center, double radius, Paint paint) {
    // Top decoration
    final topPath = Path();
    topPath.moveTo(center.dx, center.dy - radius + 2);
    topPath.lineTo(center.dx - 4, center.dy - radius + 8);
    topPath.lineTo(center.dx + 4, center.dy - radius + 8);
    topPath.close();
    canvas.drawPath(topPath, paint..style = PaintingStyle.fill);
    paint.style = PaintingStyle.stroke;

    // Side decorations (small ornamental symbols)
    for (var angle in [-90, 0, 90, 180]) {
      final radian = angle * math.pi / 180;
      final x = center.dx + (radius - 8) * math.cos(radian);
      final y = center.dy + (radius - 8) * math.sin(radian);
      
      // Small decorative symbol
      canvas.drawCircle(Offset(x, y), 2, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
    }
  }

  void _drawElephantHead(Canvas canvas, Offset center, Size size, Paint paint) {
    final headWidth = size.width * 0.6;
    final headHeight = size.height * 0.5;
    
    // Left ear
    final leftEarPath = Path();
    leftEarPath.moveTo(center.dx - headWidth * 0.35, center.dy - headHeight * 0.15);
    leftEarPath.quadraticBezierTo(
      center.dx - headWidth * 0.42, center.dy - headHeight * 0.05,
      center.dx - headWidth * 0.40, center.dy + headHeight * 0.20,
    );
    leftEarPath.quadraticBezierTo(
      center.dx - headWidth * 0.35, center.dy + headHeight * 0.25,
      center.dx - headWidth * 0.28, center.dy + headHeight * 0.15,
    );
    
    // Inner ear curves
    for (var i = 0; i < 3; i++) {
      final offset = i * 8.0;
      final innerPath = Path();
      innerPath.moveTo(center.dx - headWidth * 0.38 + offset, center.dy - headHeight * 0.10);
      innerPath.quadraticBezierTo(
        center.dx - headWidth * 0.40 + offset, center.dy,
        center.dx - headWidth * 0.36 + offset, center.dy + headHeight * 0.15,
      );
      canvas.drawPath(innerPath, paint);
    }
    canvas.drawPath(leftEarPath, paint);

    // Right ear (mirrored)
    final rightEarPath = Path();
    rightEarPath.moveTo(center.dx + headWidth * 0.35, center.dy - headHeight * 0.15);
    rightEarPath.quadraticBezierTo(
      center.dx + headWidth * 0.42, center.dy - headHeight * 0.05,
      center.dx + headWidth * 0.40, center.dy + headHeight * 0.20,
    );
    rightEarPath.quadraticBezierTo(
      center.dx + headWidth * 0.35, center.dy + headHeight * 0.25,
      center.dx + headWidth * 0.28, center.dy + headHeight * 0.15,
    );
    
    // Inner ear curves
    for (var i = 0; i < 3; i++) {
      final offset = i * 8.0;
      final innerPath = Path();
      innerPath.moveTo(center.dx + headWidth * 0.38 - offset, center.dy - headHeight * 0.10);
      innerPath.quadraticBezierTo(
        center.dx + headWidth * 0.40 - offset, center.dy,
        center.dx + headWidth * 0.36 - offset, center.dy + headHeight * 0.15,
      );
      canvas.drawPath(innerPath, paint);
    }
    canvas.drawPath(rightEarPath, paint);

    // Head/Face outline
    final headPath = Path();
    headPath.moveTo(center.dx - headWidth * 0.25, center.dy - headHeight * 0.20);
    headPath.quadraticBezierTo(
      center.dx, center.dy - headHeight * 0.25,
      center.dx + headWidth * 0.25, center.dy - headHeight * 0.20,
    );
    canvas.drawPath(headPath, paint);

    // Diamond pattern on forehead
    final diamondPath = Path();
    diamondPath.moveTo(center.dx, center.dy - headHeight * 0.15);
    diamondPath.lineTo(center.dx + 12, center.dy - headHeight * 0.05);
    diamondPath.lineTo(center.dx, center.dy + headHeight * 0.05);
    diamondPath.lineTo(center.dx - 12, center.dy - headHeight * 0.05);
    diamondPath.close();
    canvas.drawPath(diamondPath, paint);
    
    // Inner diamond
    final innerDiamondPath = Path();
    innerDiamondPath.moveTo(center.dx, center.dy - headHeight * 0.10);
    innerDiamondPath.lineTo(center.dx + 6, center.dy - headHeight * 0.05);
    innerDiamondPath.lineTo(center.dx, center.dy);
    innerDiamondPath.lineTo(center.dx - 6, center.dy - headHeight * 0.05);
    innerDiamondPath.close();
    canvas.drawPath(innerDiamondPath, paint);

    // Trunk
    final trunkPath = Path();
    trunkPath.moveTo(center.dx, center.dy + headHeight * 0.05);
    trunkPath.quadraticBezierTo(
      center.dx - 8, center.dy + headHeight * 0.15,
      center.dx - 4, center.dy + headHeight * 0.25,
    );
    trunkPath.quadraticBezierTo(
      center.dx + 4, center.dy + headHeight * 0.32,
      center.dx, center.dy + headHeight * 0.38,
    );
    canvas.drawPath(trunkPath, paint);

    // Trunk segments
    for (var i = 1; i <= 5; i++) {
      final y = center.dy + headHeight * (0.08 + i * 0.05);
      canvas.drawLine(
        Offset(center.dx - 6, y),
        Offset(center.dx + 2, y),
        paint,
      );
    }

    // Left tusk
    final leftTuskPath = Path();
    leftTuskPath.moveTo(center.dx - 15, center.dy + headHeight * 0.05);
    leftTuskPath.quadraticBezierTo(
      center.dx - 20, center.dy + headHeight * 0.20,
      center.dx - 18, center.dy + headHeight * 0.30,
    );
    canvas.drawPath(leftTuskPath, paint);

    // Right tusk
    final rightTuskPath = Path();
    rightTuskPath.moveTo(center.dx + 15, center.dy + headHeight * 0.05);
    rightTuskPath.quadraticBezierTo(
      center.dx + 20, center.dy + headHeight * 0.20,
      center.dx + 18, center.dy + headHeight * 0.30,
    );
    canvas.drawPath(rightTuskPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
