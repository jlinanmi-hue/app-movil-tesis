import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';
import '../../screens/notifications/notifications_sheet.dart';
import '../services/notification_service.dart';
import 'messenger_notification_pop.dart';

/// Administrador centralizado de la tarjeta Pop estilo Messenger.
/// Garantiza de forma estricta que NUNCA se duplique la tarjeta en pantalla
/// y que nazca geométricamente alineada con el centro del ícono de campana.
class NotificationPopManager {
  static OverlayEntry? _activeOverlayEntry;
  static Timer? _autoDismissTimer;
  static String? _lastShownId;
  static DateTime? _lastShownTime;

  /// Muestra la tarjeta pop anclada a la campana evitando duplicados
  static void showPop({
    required BuildContext context,
    required AppNotificationModel notification,
    required Offset anchorPosition,
    required Size anchorSize,
  }) {
    // 1. Deduplicación por ID y tiempo reciente (evita ráfagas duplicadas)
    final now = DateTime.now();
    if (_lastShownId == notification.id &&
        _lastShownTime != null &&
        now.difference(_lastShownTime!) < const Duration(seconds: 4)) {
      return; // Ya fue mostrada hace instantes, descartar duplicado
    }

    _lastShownId = notification.id;
    _lastShownTime = now;

    // 2. Eliminar cualquier pop activo previo para evitar superposición
    dismissCurrent();

    final overlayState = Overlay.maybeOf(context);
    if (overlayState == null) return;

    final screenWidth = MediaQuery.of(context).size.width;

    // Ancho proporcional y cómodo (330 px) para que tenga presencia elegante sin verse diminuto
    final cardWidth = math.min(330.0, screenWidth - 20.0);

    // Centro horizontal exacto del botón de la campana
    final bellCenterX = anchorPosition.dx + (anchorSize.width / 2);

    // Margen derecho del pop en la pantalla (alineado para abarcar la campana)
    final bellRightEdge = anchorPosition.dx + anchorSize.width;
    final bellDistToRight = screenWidth - bellRightEdge;

    // Margen derecho del pop (con respiro natural respecto al borde de la pantalla)
    final rightMargin = (bellDistToRight - 6.0).clamp(8.0, 24.0);

    // Posición del puntero dentro del card (medido desde el borde derecho del card)
    final cardRightXInScreen = screenWidth - rightMargin;
    final pointerOffsetFromRight =
        (cardRightXInScreen - bellCenterX).clamp(16.0, cardWidth - 24.0);

    final top = anchorPosition.dy + anchorSize.height + 2.0;

    _activeOverlayEntry = OverlayEntry(
      builder: (ctx) {
        return Positioned(
          top: top,
          right: rightMargin,
          width: cardWidth,
          child: MessengerNotificationPop(
            notification: notification,
            cardWidth: cardWidth,
            pointerRightOffset: pointerOffsetFromRight.toDouble(),
            onDismiss: dismissCurrent,
            onTap: () {
              dismissCurrent();
              NotificationService.instance.markAsRead(notification.id);
              NotificationsSheet.show(context);
            },
          ),
        );
      },
    );

    overlayState.insert(_activeOverlayEntry!);

    // 3. Auto-ocultar después de 6.5 segundos
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(milliseconds: 6500), () {
      dismissCurrent();
    });
  }

  /// Cierra y elimina la tarjeta activa si existe
  static void dismissCurrent() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _activeOverlayEntry?.remove();
    _activeOverlayEntry = null;
  }
}
