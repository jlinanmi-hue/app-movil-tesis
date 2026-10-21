import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../../models/notification_model.dart';

/// Tarjeta flotante interactiva translúcida estilo Messenger / iOS
/// Emerge anclada exactamente debajo del ícono de la campana sin tapar el usuario ni bloquear la pantalla.
class MessengerNotificationPop extends StatefulWidget {
  final AppNotificationModel notification;
  final double cardWidth;
  final double pointerRightOffset;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const MessengerNotificationPop({
    super.key,
    required this.notification,
    this.cardWidth = 275.0,
    this.pointerRightOffset = 22.0,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<MessengerNotificationPop> createState() =>
      _MessengerNotificationPopState();
}

class _MessengerNotificationPopState extends State<MessengerNotificationPop>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );

    _animController.forward();
  }

  Future<void> _animateClose() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  Color _getBadgeColor(AppNotificationModel n) {
    if (n.tipo == 'merma' ||
        n.tipo == 'danger' ||
        n.tipo == 'error' ||
        n.categoria == 'URGENTE') {
      return const Color(0xFFEF4444); // Rojo vibrante (como el corazón de tu referencia)
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

  IconData _getBadgeIcon(AppNotificationModel n) {
    if (n.tipo == 'merma') return Icons.trending_down_rounded;
    if (n.tipo == 'warning') return Icons.warning_amber_rounded;
    if (n.tipo == 'success') return Icons.check_circle_outline_rounded;
    if (n.tipo == 'danger' || n.tipo == 'error') return Icons.error_outline_rounded;
    switch (n.categoria) {
      case 'INVENTARIO':
        return Icons.inventory_2_rounded;
      case 'COMPRAS':
        return Icons.shopping_bag_rounded;
      case 'VENTAS':
        return Icons.point_of_sale_rounded;
      default:
        return Icons.notifications_active_rounded;
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

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.notification;
    final badgeColor = _getBadgeColor(n);
    final badgeIcon = _getBadgeIcon(n);

    // Calcular la alineación exacta de la escala para que nazca justo en la punta que apunta a la campana
    final relativeX =
        1.0 - (2.0 * widget.pointerRightOffset / widget.cardWidth).clamp(0.0, 2.0);

    return Dismissible(
      key: ValueKey('pop_${n.id}'),
      direction: DismissDirection.up,
      onDismissed: (_) => widget.onDismiss(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment(relativeX, -1.0), // Nace exactamente donde está la punta de la campana
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: widget.cardWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Triángulo / puntero alineado matemáticamente con el centro de la campana
                Padding(
                  padding: EdgeInsets.only(right: widget.pointerRightOffset - 7.0),
                  child: CustomPaint(
                    size: const Size(14, 7),
                    painter: _BubbleTrianglePainter(
                      color: Colors.white.withValues(alpha: 0.94),
                    ),
                  ),
                ),

                // Tarjeta principal translúcida (Glassmorphism) idéntica a tu referencia
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _animateClose().then((_) => widget.onTap());
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: widget.cardWidth,
                      decoration: BoxDecoration(
                        // Fondo translúcido blanco satinado (92% opacidad)
                        color: Colors.white.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.90),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: badgeColor.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 9,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ícono en cuadrado redondeado con color de categoría
                                Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: badgeColor,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: badgeColor.withValues(alpha: 0.35),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    badgeIcon,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 9),

                                // Textos: Notificación, hora exacta y mensaje
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Fila superior: "Notificación" + hora + cerrar
                                      Row(
                                        children: [
                                          const Expanded(
                                            child: Text(
                                              'Notificación',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatTime(n.fecha),
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF64748B),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          GestureDetector(
                                            onTap: _animateClose,
                                            behavior: HitTestBehavior.opaque,
                                            child: const Padding(
                                              padding: EdgeInsets.all(1.0),
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 13,
                                                color: Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),

                                      // Título del evento
                                      Text(
                                        n.titulo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF1E293B),
                                          height: 1.2,
                                        ),
                                      ),

                                      // Mensaje descriptivo
                                      if (n.mensaje.isNotEmpty &&
                                          n.mensaje != n.titulo) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          n.mensaje,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: Color(0xFF475569),
                                            height: 1.2,
                                          ),
                                        ),
                                      ],

                                      // Píldora de referencia rápida (ej: APERTURA_TIENDA • USR-00007)
                                      if (n.referenciaId != null &&
                                          n.referenciaId!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(alpha: 0.10),
                                            borderRadius: BorderRadius.circular(5),
                                          ),
                                          child: Text(
                                            '${n.categoria} • ${n.referenciaId}',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              color: badgeColor,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dibuja el pequeño triángulo apuntando hacia arriba al ícono de campana
class _BubbleTrianglePainter extends CustomPainter {
  final Color color;
  const _BubbleTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleTrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
