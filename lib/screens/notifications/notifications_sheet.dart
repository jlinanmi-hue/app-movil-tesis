import 'package:flutter/material.dart';
import '../../core/services/notification_service.dart';
import '../../models/notification_model.dart';

/// Modal Bottom Sheet para la Bandeja de Notificaciones en Vivo
class NotificationsSheet extends StatefulWidget {
  const NotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationsSheet(),
    );
  }

  @override
  State<NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<NotificationsSheet> {
  final NotificationService _service = NotificationService.instance;
  String _selectedCategory = 'TODAS'; // TODAS, NO_LEIDAS, INVENTARIO, COMPRAS, VENTAS
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service.fetchNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<AppNotificationModel> _filterList(List<AppNotificationModel> list) {
    return list.where((n) {
      if (_selectedCategory == 'NO_LEIDAS' && n.leida) return false;
      if (_selectedCategory == 'INVENTARIO' && n.categoria != 'INVENTARIO') {
        return false;
      }
      if (_selectedCategory == 'COMPRAS' && n.categoria != 'COMPRAS' && n.categoria != 'COMPRA_RAPIDA') {
        return false;
      }
      if (_selectedCategory == 'VENTAS' && n.categoria != 'VENTAS') {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchTitle = n.titulo.toLowerCase().contains(q);
        final matchMsg = n.mensaje.toLowerCase().contains(q);
        final matchRef = n.referenciaId?.toLowerCase().contains(q) ?? false;
        if (!matchTitle && !matchMsg && !matchRef) return false;
      }
      return true;
    }).toList();
  }

  Color _getCategoryColor(AppNotificationModel n) {
    if (n.tipo == 'compra_rapida' || n.categoria == 'COMPRA_RAPIDA') {
      return const Color(0xFF0284C7);
    }
    if (n.tipo == 'merma' || n.tipo == 'danger' || n.tipo == 'error') {
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
      case 'COMPRA_RAPIDA':
        return const Color(0xFF0284C7);
      case 'VENTAS':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(AppNotificationModel n) {
    if (n.tipo == 'compra_rapida' || n.categoria == 'COMPRA_RAPIDA') return Icons.bolt_rounded;
    if (n.tipo == 'merma') return Icons.trending_down_rounded;
    if (n.tipo == 'warning') return Icons.warning_amber_rounded;
    if (n.tipo == 'success') return Icons.check_circle_outline_rounded;
    if (n.tipo == 'danger' || n.tipo == 'error') return Icons.error_outline_rounded;
    switch (n.categoria) {
      case 'INVENTARIO':
        return Icons.inventory_2_outlined;
      case 'COMPRAS':
        return Icons.shopping_bag_outlined;
      case 'VENTAS':
        return Icons.point_of_sale_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final screenHeight = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: screenHeight * 0.88,
        decoration: const BoxDecoration(
          color: Color(0xFFF8FAFC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle superior
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Encabezado
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 14, 10),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Centro de Notificaciones',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        ValueListenableBuilder<int>(
                          valueListenable: _service.unreadCountNotifier,
                          builder: (_, unread, child) {
                            return Text(
                              unread > 0
                                  ? '$unread notificaciones no leídas'
                                  : 'Todas leídas • Al día',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: unread > 0
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF10B981),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  // Botón marcar todas como leídas
                  ValueListenableBuilder<int>(
                    valueListenable: _service.unreadCountNotifier,
                    builder: (_, unread, child) {
                      if (unread == 0) return const SizedBox.shrink();
                      return TextButton.icon(
                        onPressed: () async {
                          await _service.markAllAsRead();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Todas las notificaciones marcadas como leídas.'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.done_all_rounded, size: 16),
                        label: const Text(
                          'Marcar leídas',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0077B6),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      );
                    },
                  ),

                  IconButton(
                    tooltip: 'Probar Pop flotante',
                    icon: const Icon(Icons.flash_on_rounded, color: Color(0xFF0077B6), size: 20),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _service.triggerTestNotification();
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),

            // Buscador dentro de notificaciones
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: 'Buscar por orden, código, producto...',
                    hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                ),
              ),
            ),

            // Chips de Categorías
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ValueListenableBuilder<int>(
                  valueListenable: _service.unreadCountNotifier,
                  builder: (_, unread, child) {
                    return Row(
                      children: [
                        _buildFilterChip('Todas', 'TODAS'),
                        const SizedBox(width: 6),
                        _buildFilterChip(
                          unread > 0 ? 'No leídas ($unread)' : 'No leídas',
                          'NO_LEIDAS',
                          isAlert: unread > 0,
                        ),
                        const SizedBox(width: 6),
                        _buildFilterChip('Inventario', 'INVENTARIO'),
                        const SizedBox(width: 6),
                        _buildFilterChip('Compras', 'COMPRAS'),
                        const SizedBox(width: 6),
                        _buildFilterChip('Ventas', 'VENTAS'),
                      ],
                    );
                  },
                ),
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Lista de Notificaciones
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _service.fetchNotifications(),
                color: const Color(0xFF0096C7),
                child: ValueListenableBuilder<List<AppNotificationModel>>(
                  valueListenable: _service.notificationsNotifier,
                  builder: (context, allList, _) {
                    final filtered = _filterList(allList);

                    if (filtered.isEmpty) {
                      return ListView(
                        children: [
                          SizedBox(height: screenHeight * 0.15),
                          Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.notifications_off_outlined,
                                    size: 32,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Sin notificaciones en esta categoría',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'No hay alertas o avisos pendientes para mostrar.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        return _buildNotificationCard(notif);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {bool isAlert = false}) {
    final isSelected = _selectedCategory == value;
    return InkWell(
      onTap: () => setState(() => _selectedCategory = value),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0A3642)
              : (isAlert ? const Color(0xFFFEF2F2) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0A3642)
                : (isAlert ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0)),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A3642).withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isAlert ? const Color(0xFFDC2626) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotificationModel notif) {
    final themeColor = _getCategoryColor(notif);
    final icon = _getCategoryIcon(notif);
    final isUnread = !notif.leida;

    return Dismissible(
      key: ValueKey(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      onDismissed: (_) {
        _service.deleteNotification(notif.id);
      },
      child: InkWell(
        onTap: () {
          if (isUnread) {
            _service.markAsRead(notif.id);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnread ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread ? themeColor.withValues(alpha: 0.45) : const Color(0xFFE2E8F0),
              width: isUnread ? 1.4 : 1.0,
            ),
            boxShadow: isUnread
                ? [
                    BoxShadow(
                      color: themeColor.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icono con fondo tonal
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: themeColor, size: 20),
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila de Categoría, Referencia y Tiempo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notif.categoria,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: themeColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                        if (notif.referenciaId != null && notif.referenciaId!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notif.referenciaId!,
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          notif.tiempoRelativo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF00B4D8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),

                    // Título
                    Text(
                      notif.titulo,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isUnread ? FontWeight.w800 : FontWeight.w600,
                        color: const Color(0xFF0F172A),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Mensaje
                    Text(
                      notif.mensaje,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),

                    // Impacto Financiero si existe
                    if (notif.impactoFinancieroTexto != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Text(
                          notif.impactoFinancieroTexto!,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Botón rápido marcar leída si está pendiente
              if (isUnread) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Marcar como leída',
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: Color(0xFF0096C7), size: 18),
                  onPressed: () => _service.markAsRead(notif.id),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
