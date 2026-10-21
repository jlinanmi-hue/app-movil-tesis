import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import '../../models/notification_model.dart';
import '../../screens/notifications/notifications_sheet.dart';
import 'notification_pop_manager.dart';

/// Ícono de Campana de Notificaciones con Badge en Vivo y Pop estilo Messenger
class NotificationBellWidget extends StatefulWidget {
  final Color iconColor;
  final Color? backgroundColor;
  final Color? borderColor;
  final double size;
  final double? buttonSize;
  final VoidCallback? onTapped;

  const NotificationBellWidget({
    super.key,
    this.iconColor = Colors.white,
    this.backgroundColor,
    this.borderColor,
    this.size = 20,
    this.buttonSize,
    this.onTapped,
  });

  @override
  State<NotificationBellWidget> createState() => _NotificationBellWidgetState();
}

class _NotificationBellWidgetState extends State<NotificationBellWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;
  StreamSubscription<AppNotificationModel>? _notificationSubscription;

  @override
  void initState() {
    super.initState();

    // Animación de campanilleo / vibración elástica (estilo Messenger)
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _wiggleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.25), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.25), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.20), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.20, end: 0.20), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.20, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _wiggleController,
      curve: Curves.easeInOut,
    ));

    // Suscribirse a eventos de notificaciones entrantes en vivo
    _notificationSubscription =
        NotificationService.instance.onNewNotification.listen((notif) {
      if (!mounted) return;
      _triggerArrival(notif);
    });
  }

  void _triggerArrival(AppNotificationModel notif) {
    if (!mounted) return;

    // Si este widget se encuentra en una pestaña inactiva (TickerMode deshabilitado en IndexedStack),
    // no debe disparar el pop para no sobreescribir la posición de la campana activa en pantalla.
    final isTickerEnabled = TickerMode.valuesOf(context).enabled;
    if (!isTickerEnabled) {
      return;
    }

    // 1. Feedback háptico
    HapticFeedback.lightImpact();

    // 2. Campanilleo animado
    _wiggleController.forward(from: 0.0);

    // 3. Emerge el pop único estilo Messenger mediante el NotificationPopManager
    _showPop(notif);
  }

  void _showPop(AppNotificationModel notif) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final pos = renderBox.localToGlobal(Offset.zero);
      NotificationPopManager.showPop(
        context: context,
        notification: notif,
        anchorPosition: pos,
        anchorSize: renderBox.size,
      );
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final rb = context.findRenderObject() as RenderBox?;
        if (rb != null && rb.hasSize) {
          final pos = rb.localToGlobal(Offset.zero);
          NotificationPopManager.showPop(
            context: context,
            notification: notif,
            anchorPosition: pos,
            anchorSize: rb.size,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: NotificationService.instance.unreadCountNotifier,
      builder: (context, unreadCount, _) {
        final hasUnread = unreadCount > 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.borderColor ?? Colors.white.withValues(alpha: 0.30),
                  width: 1,
                ),
              ),
              child: AnimatedBuilder(
                animation: _wiggleAnimation,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _wiggleAnimation.value * (math.pi / 4),
                    child: child,
                  );
                },
                child: IconButton(
                  onPressed: () {
                    NotificationPopManager.dismissCurrent();
                    widget.onTapped?.call();
                    NotificationsSheet.show(context);
                  },
                  icon: Icon(
                    hasUnread
                        ? Icons.notifications_active_rounded
                        : Icons.notifications_outlined,
                    color: widget.iconColor,
                    size: widget.size,
                  ),
                  tooltip: hasUnread
                      ? 'Notificaciones ($unreadCount pendientes)'
                      : 'Notificaciones',
                  visualDensity: VisualDensity.compact,
                  constraints: widget.buttonSize == null
                      ? null
                      : BoxConstraints.tightFor(
                          width: widget.buttonSize,
                          height: widget.buttonSize,
                        ),
                  padding:
                      widget.buttonSize == null ? null : EdgeInsets.zero,
                ),
              ),
            ),

            // Badge numérico si hay notificaciones sin leer con animación elástica de entrada
            if (hasUnread)
              Positioned(
                top: -3,
                right: -3,
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(unreadCount),
                  tween: Tween<double>(begin: 0.6, end: 1.0),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  builder: (context, scale, child) {
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444), // Rojo vibrante
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
