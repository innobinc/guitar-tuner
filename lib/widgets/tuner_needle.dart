import 'dart:math';
import 'package:flutter/material.dart';

class TunerNeedle extends StatelessWidget {
  final double cents; // -50 to +50

  const TunerNeedle({super.key, required this.cents});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: cents.clamp(-50.0, 50.0)),
      curve: Curves.easeOut,
      duration: const Duration(milliseconds: 200),
      builder: (_, value, __) => CustomPaint(
        size: const Size(300, 160),
        painter: _NeedlePainter(value),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final double cents;
  _NeedlePainter(this.cents);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height - 8;
    final radius = size.height - 16;

    // Arc background — gradient from red-left through green-center to red-right
    final arcRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    const startAngle = pi; // -180° (left = flat)
    const sweepAngle = pi; // 180° sweep

    // Draw colored arc segments
    final colors = [
      const Color(0xFFE53935), // -50 red
      const Color(0xFFFF7043), // -30 orange
      const Color(0xFFFFEE58), // -10 yellow
      const Color(0xFF66BB6A), // 0 green
      const Color(0xFFFFEE58), // +10 yellow
      const Color(0xFFFF7043), // +30 orange
      const Color(0xFFE53935), // +50 red
    ];
    final stops = [0.0, 0.17, 0.33, 0.5, 0.67, 0.83, 1.0];
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..shader = SweepGradient(
        colors: colors,
        stops: stops,
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
      ).createShader(arcRect);

    canvas.drawArc(arcRect, startAngle, sweepAngle, false, arcPaint);

    // Tick marks
    final tickPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;
    for (final c in [-50.0, -40, -30, -20, -10, 0, 10, 20, 30, 40, 50.0]) {
      final angle = startAngle + ((c + 50) / 100) * sweepAngle;
      final inner = radius - 12;
      final outer = radius + 2;
      canvas.drawLine(
        Offset(cx + inner * cos(angle), cy + inner * sin(angle)),
        Offset(cx + outer * cos(angle), cy + outer * sin(angle)),
        tickPaint,
      );
    }

    // Center tick label "0"
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '0',
        style: TextStyle(color: Colors.white54, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas,
        Offset(cx - textPainter.width / 2, cy - radius - 22));

    // Needle
    final needleAngle = startAngle + ((cents.clamp(-50, 50) + 50) / 100) * sweepAngle;
    final inTune = cents.abs() < 5;
    final needlePaint = Paint()
      ..color = inTune ? const Color(0xFF66BB6A) : const Color(0xFFFFCC02)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + (radius - 4) * cos(needleAngle),
          cy + (radius - 4) * sin(needleAngle)),
      needlePaint,
    );

    // Pivot dot
    canvas.drawCircle(
        Offset(cx, cy),
        6,
        Paint()
          ..color = inTune ? const Color(0xFF66BB6A) : const Color(0xFFFFCC02));
  }

  @override
  bool shouldRepaint(_NeedlePainter old) => old.cents != cents;
}
