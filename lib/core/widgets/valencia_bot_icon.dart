import 'package:flutter/material.dart';

/// Isotipo Oficial y Minimalista de Valencia AI para Flutter
/// Réplica vectorial fiel del logotipo moderno de la IA.
class ValenciaBotIcon extends StatelessWidget {
  final double size;
  final Color headColor;
  final Color visorColor;
  final Color eyeColor;

  const ValenciaBotIcon({
    super.key,
    this.size = 28,
    this.headColor = Colors.white,
    this.visorColor = const Color(0xFF0F172A),
    this.eyeColor = const Color(0xFF38BDF8),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ValenciaBotPainter(
          headColor: headColor,
          visorColor: visorColor,
          eyeColor: eyeColor,
        ),
      ),
    );
  }
}

class _ValenciaBotPainter extends CustomPainter {
  final Color headColor;
  final Color visorColor;
  final Color eyeColor;

  _ValenciaBotPainter({
    required this.headColor,
    required this.visorColor,
    required this.eyeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final headPaint = Paint()
      ..color = headColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final visorPaint = Paint()
      ..color = visorColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final eyePaint = Paint()
      ..color = eyeColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // 1. Esfera de la antena superior
    canvas.drawCircle(
      Offset(w * 0.50, h * 0.115),
      w * 0.055,
      headPaint,
    );

    // 2. Mástil de la antena
    final stemRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.475, h * 0.165, w * 0.05, h * 0.08),
      Radius.circular(w * 0.025),
    );
    canvas.drawRRect(stemRRect, headPaint);

    // 3. Cúpula / Cuello curvo en la base de la antena
    final collarPath = Path()
      ..moveTo(w * 0.37, h * 0.275)
      ..cubicTo(
        w * 0.37, h * 0.21,
        w * 0.425, h * 0.19,
        w * 0.50, h * 0.19,
      )
      ..cubicTo(
        w * 0.575, h * 0.19,
        w * 0.63, h * 0.21,
        w * 0.63, h * 0.275,
      )
      ..cubicTo(
        w * 0.59, h * 0.265,
        w * 0.545, h * 0.26,
        w * 0.50, h * 0.26,
      )
      ..cubicTo(
        w * 0.455, h * 0.26,
        w * 0.41, h * 0.265,
        w * 0.37, h * 0.275,
      )
      ..close();
    canvas.drawPath(collarPath, headPaint);

    // 4. Orejeras laterales simétricas redondeadas
    final leftEar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.09, h * 0.47, w * 0.09, h * 0.17),
      Radius.circular(w * 0.045),
    );
    final rightEar = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.82, h * 0.47, w * 0.09, h * 0.17),
      Radius.circular(w * 0.045),
    );
    canvas.drawRRect(leftEar, headPaint);
    canvas.drawRRect(rightEar, headPaint);

    // 5. Cabeza ovalada suave
    final headRect = Rect.fromCenter(
      center: Offset(w * 0.50, h * 0.56),
      width: w * 0.74,
      height: h * 0.60,
    );
    canvas.drawOval(headRect, headPaint);

    // 6. Visor horizontal tipo cápsula / stadium
    final visorRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.26, h * 0.45, w * 0.48, h * 0.22),
      Radius.circular(h * 0.11),
    );
    canvas.drawRRect(visorRRect, visorPaint);

    // 7. Ojos circulares con brillo IA
    canvas.drawCircle(Offset(w * 0.41, h * 0.56), w * 0.052, eyePaint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.56), w * 0.052, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _ValenciaBotPainter oldDelegate) {
    return oldDelegate.headColor != headColor ||
        oldDelegate.visorColor != visorColor ||
        oldDelegate.eyeColor != eyeColor;
  }
}
