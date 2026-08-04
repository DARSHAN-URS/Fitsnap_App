import 'package:flutter/material.dart';

class SabtrackLogo extends StatelessWidget {

  final double size;
  final Color? color;

  const SabtrackLogo({
    super.key,
    this.size = 120.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
    );
  }
}

class _SabtrackLogoPainter extends CustomPainter {
  final Color color;

  _SabtrackLogoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Paints
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // 1. Draw the Road / Path line at the bottom
    final roadPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    // Road path: slight curve or straight line representing the running road
    canvas.drawLine(
      Offset(w * 0.15, h * 0.82),
      Offset(w * 0.85, h * 0.82),
      roadPaint,
    );

    // 2. Draw the "S" Fork shape
    // Path for the main "S" line
    final sPath = Path();
    // Start at top right loop of S
    sPath.moveTo(w * 0.70, h * 0.25);
    // Top curve to left
    sPath.cubicTo(
      w * 0.60, h * 0.12, // Control 1
      w * 0.30, h * 0.15, // Control 2
      w * 0.30, h * 0.32, // End point
    );
    // Center diagonal cross
    sPath.cubicTo(
      w * 0.30, h * 0.48, // Control 1
      w * 0.70, h * 0.44, // Control 2
      w * 0.70, h * 0.60, // End point
    );
    // Bottom curve to left
    sPath.cubicTo(
      w * 0.70, h * 0.72, // Control 1
      w * 0.48, h * 0.78, // Control 2
      w * 0.38, h * 0.74, // End point
    );
    canvas.drawPath(sPath, strokePaint);

    // Draw the Fork Tines (Prongs) at the top start of the "S"
    // We draw three simple, bold vertical prongs at the top of the S
    final tinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.045
      ..strokeCap = StrokeCap.round;

    final double forkYStart = h * 0.23;
    final double forkYEnd = h * 0.12;
    // Left prong
    canvas.drawLine(Offset(w * 0.62, forkYStart), Offset(w * 0.60, forkYEnd), tinePaint);
    // Center prong
    canvas.drawLine(Offset(w * 0.70, forkYStart), Offset(w * 0.70, forkYEnd), tinePaint);
    // Right prong
    canvas.drawLine(Offset(w * 0.78, forkYStart), Offset(w * 0.80, forkYEnd), tinePaint);

    // 3. Draw the Running Person on the road
    // We place the running person on the right side of the road
    final double pX = w * 0.68;
    final double pY = h * 0.80; // Bottom of feet is on the road (y = 0.82)

    // Head
    canvas.drawCircle(Offset(pX, pY - h * 0.18), w * 0.045, fillPaint);

    // Torso (slanted forward)
    final bodyPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.05
      ..strokeCap = StrokeCap.round;
    
    final Offset neck = Offset(pX, pY - h * 0.13);
    final Offset hip = Offset(pX - w * 0.05, pY - h * 0.05);
    canvas.drawLine(neck, hip, bodyPaint);

    // Arms (swinging action)
    final limbsPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.035
      ..strokeCap = StrokeCap.round;

    // Arm 1 (forward/up)
    canvas.drawLine(neck, Offset(pX + w * 0.05, pY - h * 0.10), limbsPaint);
    // Arm 2 (backward/down)
    canvas.drawLine(neck, Offset(pX - w * 0.07, pY - h * 0.08), limbsPaint);

    // Legs (running strides)
    // Leg 1 (forward stride, bent knee)
    final Offset knee1 = Offset(pX + w * 0.03, pY - h * 0.03);
    final Offset foot1 = Offset(pX + w * 0.05, pY - h * 0.005);
    canvas.drawLine(hip, knee1, limbsPaint);
    canvas.drawLine(knee1, foot1, limbsPaint);

    // Leg 2 (backward stride, bent knee)
    final Offset knee2 = Offset(pX - w * 0.08, pY - h * 0.04);
    final Offset foot2 = Offset(pX - w * 0.06, pY - h * 0.02);
    canvas.drawLine(hip, knee2, limbsPaint);
    canvas.drawLine(knee2, foot2, limbsPaint);
  }

  @override
  bool shouldRepaint(covariant _SabtrackLogoPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
