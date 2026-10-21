import 'dart:io' show File, Platform;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/notification_model.dart';

/// Servicio de Notificaciones Nativas del Dispositivo (Android / iOS)
/// Permite alertar al usuario cuando la app está cerrada, en segundo plano o en pantalla de bloqueo.
class DeviceNotificationService {
  static final DeviceNotificationService instance =
      DeviceNotificationService._internal();
  factory DeviceNotificationService() => instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  DeviceNotificationService._internal();

  /// Inicializa los canales y permisos nativos en el dispositivo
  Future<void> init() async {
    if (_isInitialized) return;
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const linuxSettings = LinuxInitializationSettings(
        defaultActionName: 'Open notification',
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
        linux: linuxSettings,
      );

      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (response) {
          debugPrint('[DeviceNotificationService] Notificación tocada: ${response.payload}');
        },
      );

      // Crear canal de alta prioridad para Android (pantalla de bloqueo y sonido)
      if (Platform.isAndroid) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'valencia_pyme_alerts',
              'Alertas de Pyme Valencia',
              description:
                  'Notificaciones en tiempo real sobre ingresos, pedidos, ventas y mermas.',
              importance: Importance.max,
              enableVibration: true,
              playSound: true,
              showBadge: true,
            ),
          );

          // Solicitar permiso explícito en Android 13+
          await androidPlugin.requestNotificationsPermission();
        }
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('[DeviceNotificationService] Error al inicializar: $e');
    }
  }

  Color _getBadgeColor(AppNotificationModel n) {
    if (n.tipo == 'merma' ||
        n.tipo == 'danger' ||
        n.tipo == 'error' ||
        n.categoria == 'URGENTE') {
      return const Color(0xFFEF4444);
    }
    if (n.tipo == 'warning') {
      return const Color(0xFFF59E0B);
    }
    if (n.tipo == 'success') {
      return const Color(0xFF10B981);
    }
    switch (n.categoria) {
      case 'INVENTARIO':
        return const Color(0xFF0096C7);
      case 'COMPRAS':
        return const Color(0xFF10B981);
      case 'VENTAS':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF008F9D);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return 'ahora';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 90 && diff.inSeconds >= -5) return 'ahora';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Genera un banner gráfico de alta resolución idéntico a la tarjeta flotante del sistema
  Future<String?> _generateBannerFile(
    AppNotificationModel notif,
    Color badgeColor,
    String timeStr,
  ) async {
    try {
      const width = 640.0;
      const height = 240.0;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));

      // 1. Fondo translúcido blanco satinado
      final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
      final cardRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(6, 6, width - 12, height - 12),
        const Radius.circular(22),
      );
      canvas.drawRRect(cardRRect, bgPaint);

      // 2. Borde suave satinado
      final borderPaint = Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(cardRRect, borderPaint);

      // 3. Cuadrado redondeado con color de categoría
      final badgePaint = Paint()..color = badgeColor;
      final badgeRRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 28, 64, 64),
        const Radius.circular(16),
      );
      canvas.drawRRect(badgeRRect, badgePaint);

      // Símbolo del badge
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

      // 4. Fila superior: "Notificación • Comercial Valencia" + Hora
      final categoryText =
          notif.categoria.isNotEmpty ? notif.categoria : 'GENERAL';
      final tpHeader = TextPainter(
        text: TextSpan(
          text: 'Comercial Valencia • $categoryText',
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
          text: notif.titulo,
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
          text: notif.mensaje,
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
        const Rect.fromLTWH(28, 186, 240, 32),
        const Radius.circular(8),
      );
      canvas.drawRRect(chipRect, chipPaint);

      final chipText = '$categoryText • ${notif.referenciaId ?? notif.id}';
      final tpChip = TextPainter(
        text: TextSpan(
          text: chipText,
          style: TextStyle(
            color: badgeColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpChip.paint(canvas, const Offset(40, 193));

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) return null;

      final dir = await getTemporaryDirectory();
      final bannerFile = File('${dir.path}/valencia_banner_${notif.id}.png');
      await bannerFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
      return bannerFile.path;
    } catch (e) {
      debugPrint('[DeviceNotificationService] Error al generar banner: $e');
      return null;
    }
  }

  /// Muestra una notificación nativa del sistema operativo en el teléfono
  Future<void> showNativeNotification(AppNotificationModel notif) async {
    if (kIsWeb || Platform.environment.containsKey('FLUTTER_TEST')) return;
    if (!_isInitialized) {
      await init();
    }

    try {
      final notifNumericId =
          int.tryParse(notif.id.replaceAll(RegExp(r'[^0-9]'), '')) ??
              DateTime.now().millisecondsSinceEpoch.remainder(100000);

      final notifTimestamp = notif.fecha?.millisecondsSinceEpoch ??
          DateTime.now().millisecondsSinceEpoch;
      final categoryText =
          notif.categoria.isNotEmpty ? notif.categoria : 'COMERCIAL VALENCIA';

      final title =
          notif.titulo.isNotEmpty ? notif.titulo : 'Comercial Valencia';
      final body = notif.mensaje.isNotEmpty
          ? notif.mensaje
          : 'Hay una nueva novedad registrada en tu negocio.';

      final badgeColor = _getBadgeColor(notif);
      final timeStr = _formatTime(notif.fecha);

      // Generar el banner visual con diseño idéntico al Pop in-app
      final bannerPath = await _generateBannerFile(notif, badgeColor, timeStr);

      final androidDetails = AndroidNotificationDetails(
        'valencia_pyme_alerts',
        'Alertas de Pyme Valencia',
        channelDescription:
            'Notificaciones en tiempo real sobre ingresos, pedidos, ventas y mermas.',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        icon: '@mipmap/ic_launcher',
        color: badgeColor,
        colorized: false, // NO oscurecer la tarjeta en bloque negro
        showWhen: true,
        when: notifTimestamp,
        subText: 'Comercial Valencia • $categoryText',
        enableVibration: true,
        playSound: true,
        styleInformation: bannerPath != null
            ? BigPictureStyleInformation(
                FilePathAndroidBitmap(bannerPath),
                contentTitle: title,
                summaryText: 'Comercial Valencia • $categoryText',
                hideExpandedLargeIcon: true,
              )
            : BigTextStyleInformation(
                body,
                contentTitle: title,
                summaryText: categoryText,
              ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _plugin.show(
        id: notifNumericId,
        title: title,
        body: body,
        notificationDetails: details,
        payload: notif.id,
      );
    } catch (e) {
      debugPrint(
          '[DeviceNotificationService] Error al emitir notificación nativa: $e');
    }
  }
}
