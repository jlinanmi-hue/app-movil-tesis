import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<File> renderNotificationBanner({
  required String title,
  required String message,
  required String category,
  required String timeStr,
  required Color badgeColor,
}) async {
  const width = 640.0;
  const height = 240.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

  // 1. Fondo satinado blanco translúcido
  final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
  final cardRRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(6, 6, width - 12, height - 12),
    const Radius.circular(22),
  );
  canvas.drawRRect(cardRRect, bgPaint);

  // 2. Borde sutil elegante
  final borderPaint = Paint()
    ..color = const Color(0xFFCBD5E1)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0;
  canvas.drawRRect(cardRRect, borderPaint);

  // 3. Cuadrado con color distintivo de categoría (estilo Messenger)
  final badgePaint = Paint()..color = badgeColor;
  final badgeRRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(28, 28, 64, 64),
    const Radius.circular(16),
  );
  canvas.drawRRect(badgeRRect, badgePaint);

  // Ícono de campana o categoría en el badge
  final tpBadgeIcon = TextPainter(
    text: const TextSpan(
      text: '★',
      style: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tpBadgeIcon.paint(canvas, const Offset(46, 42));

  // 4. Fila superior: "Notificación • Comercial Valencia" y Hora
  final tpHeader = TextPainter(
    text: TextSpan(
      text: 'Comercial Valencia • $category',
      style: TextStyle(
        color: badgeColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tpHeader.paint(canvas, const Offset(106, 28));

  final tpTime = TextPainter(
    text: TextSpan(
      text: timeStr,
      style: const TextStyle(
        color: Color(0xFF64748B),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tpTime.paint(canvas, Offset(width - 32 - tpTime.width, 28));

  // 5. Título del movimiento
  final tpTitle = TextPainter(
    text: TextSpan(
      text: title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
    ),
    maxLines: 1,
    ellipsis: '...',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 138);
  tpTitle.paint(canvas, const Offset(106, 56));

  // 6. Mensaje explicativo
  final tpMsg = TextPainter(
    text: TextSpan(
      text: message,
      style: const TextStyle(
        color: Color(0xFF334155),
        fontSize: 18,
        height: 1.25,
        fontWeight: FontWeight.w500,
      ),
    ),
    maxLines: 3,
    ellipsis: '...',
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width - 56);
  tpMsg.paint(canvas, const Offset(28, 110));

  // 7. Chip inferior
  final chipPaint = Paint()..color = badgeColor.withValues(alpha: 0.12);
  final chipRect = RRect.fromRectAndRadius(
    const Rect.fromLTWH(28, 186, 200, 32),
    const Radius.circular(8),
  );
  canvas.drawRRect(chipRect, chipPaint);

  final tpChip = TextPainter(
    text: TextSpan(
      text: 'EN VIVO • VALENCIA MOVIL',
      style: TextStyle(
        color: badgeColor,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tpChip.paint(canvas, const Offset(42, 193));

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.toInt(), height.toInt());
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

  final tempFile = File('${Directory.systemTemp.path}/test_valencia_notif.png');
  await tempFile.writeAsBytes(byteData!.buffer.asUint8List());
  return tempFile;
}

void main() {
  test('Generación de banner visual de notificación en memoria', () async {
    final file = await renderNotificationBanner(
      title: 'Ingreso de Mercadería: Agua Cielo 2500 ml',
      message: 'Se ingresaron 40.00 unidades al stock desde la OC OC-00184.',
      category: 'COMPRAS',
      timeStr: '07:30',
      badgeColor: const Color(0xFF008F9D),
    );

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), greaterThan(1000));
  });
}
