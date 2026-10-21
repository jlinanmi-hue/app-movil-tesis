import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';
import '../../../models/resumen_jornada_model.dart';
import '../../ai_chat/ai_chat_screen.dart';
import '../../erp/erp_operaciones.dart';
import '../indicators_screen.dart';

/// Bloque Ejecutivo: "Resumen de la Jornada" (Métricas operativas del día).
/// Refleja fielmente las 6 tarjetas de la web en una cuadrícula moderna y mate
/// con interacción directa y retroalimentación táctil.
class ResumenJornadaWidget extends StatelessWidget {
  final ResumenJornadaModel data;
  final bool wide;
  final VoidCallback? onRefresh;

  const ResumenJornadaWidget({
    super.key,
    required this.data,
    this.wide = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark;

    final cards = <_ResumenCardItem>[
      _ResumenCardItem(
        label: 'Pedidos Hoy',
        valor: '${data.pedidosConteo} pedidos',
        sub: FormatUtils.formatPEN(data.montoFacturado),
        icon: Icons.shopping_bag_outlined,
        iconColor: const Color(0xFF0284C7),
        bgColor: isDark
            ? const Color(0xFF0284C7).withValues(alpha: 0.18)
            : const Color(0xFFE0F2FE),
        borderColor: isDark
            ? const Color(0xFF0284C7).withValues(alpha: 0.35)
            : const Color(0xFFBAE6FD),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PedidosHubScreen(initialIndex: 0),
            ),
          );
        },
      ),
      _ResumenCardItem(
        label: 'Clientes Atendidos',
        valor: '${data.clientesAtendidos}',
        sub: 'Clientes únicos',
        icon: Icons.people_alt_outlined,
        iconColor: const Color(0xFF7C3AED),
        bgColor: isDark
            ? const Color(0xFF7C3AED).withValues(alpha: 0.18)
            : const Color(0xFFF3E8FF),
        borderColor: isDark
            ? const Color(0xFF7C3AED).withValues(alpha: 0.35)
            : const Color(0xFFE9D5FF),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ClientesScreen(),
            ),
          );
        },
      ),
      _ResumenCardItem(
        label: 'Tiempo Medio',
        valor: '${data.tiempoMedioSeg}s',
        sub: 'Por cada pedido',
        icon: Icons.timer_outlined,
        iconColor: const Color(0xFF059669),
        bgColor: isDark
            ? const Color(0xFF059669).withValues(alpha: 0.18)
            : const Color(0xFFD1FAE5),
        borderColor: isDark
            ? const Color(0xFF059669).withValues(alpha: 0.35)
            : const Color(0xFFA7F3D0),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const IndicatorsScreen(),
            ),
          );
        },
      ),
      _ResumenCardItem(
        label: 'Asistidos por IA',
        valor: '${data.porcentajeIa.toStringAsFixed(1)}%',
        sub: 'Vía Valencia AI',
        icon: Icons.auto_awesome_rounded,
        iconColor: const Color(0xFF4F46E5),
        bgColor: isDark
            ? const Color(0xFF4F46E5).withValues(alpha: 0.18)
            : const Color(0xFFE0E7FF),
        borderColor: isDark
            ? const Color(0xFF4F46E5).withValues(alpha: 0.35)
            : const Color(0xFFC7D2FE),
        onTap: () {
          HapticFeedback.mediumImpact();
          AiChatScreen.show(context);
        },
      ),
      _ResumenCardItem(
        label: 'Alertas Activas',
        valor: '${data.alertasActivas}',
        sub: data.alertasActivas == 0 ? 'Sin incidencias' : 'Bajo stock mínimo',
        icon: data.alertasActivas > 0
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded,
        iconColor: data.alertasActivas > 0
            ? const Color(0xFFD97706)
            : const Color(0xFF059669),
        bgColor: isDark
            ? (data.alertasActivas > 0
                ? const Color(0xFFD97706).withValues(alpha: 0.18)
                : const Color(0xFF059669).withValues(alpha: 0.18))
            : (data.alertasActivas > 0
                ? const Color(0xFFFEF3C7)
                : const Color(0xFFD1FAE5)),
        borderColor: isDark
            ? (data.alertasActivas > 0
                ? const Color(0xFFD97706).withValues(alpha: 0.35)
                : const Color(0xFF059669).withValues(alpha: 0.35))
            : (data.alertasActivas > 0
                ? const Color(0xFFFDE68A)
                : const Color(0xFFA7F3D0)),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const InventarioHubScreen(initialIndex: 2),
            ),
          );
        },
      ),
      _ResumenCardItem(
        label: 'Despachos a Tiempo',
        valor: '${data.slaCumplimiento.toStringAsFixed(0)}%',
        sub: 'Cumplimiento SLA',
        icon: Icons.local_shipping_outlined,
        iconColor: const Color(0xFF0D9488),
        bgColor: isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.18)
            : const Color(0xFFCCFBF1),
        borderColor: isDark
            ? const Color(0xFF0D9488).withValues(alpha: 0.35)
            : const Color(0xFF99F6E4),
        onTap: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const PedidosHubScreen(initialIndex: 1),
            ),
          );
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabecera con título, subtítulo y badge en vivo
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 9),
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.celesteDeep,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resumen de la Jornada',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Métricas operativas del día de hoy',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF10B981).withValues(alpha: 0.4)
                      : const Color(0xFFA7F3D0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'EN VIVO • HOY',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: isDark
                          ? const Color(0xFF34D399)
                          : const Color(0xFF065F46),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Grid 2 columnas (móvil) o 3 columnas (tableta/ancho)
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 3 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 84,
          ),
          itemCount: cards.length,
          itemBuilder: (_, i) => _buildCardTile(cards[i]),
        ),
      ],
    );
  }

  Widget _buildCardTile(_ResumenCardItem item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: item.borderColor, width: 0.8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(item.icon, size: 14, color: item.iconColor),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textDark,
                    fontFamily: 'monospace',
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 1.5),
                Text(
                  item.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSubtle,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResumenCardItem {
  final String label;
  final String valor;
  final String sub;
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _ResumenCardItem({
    required this.label,
    required this.valor,
    required this.sub,
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });
}
