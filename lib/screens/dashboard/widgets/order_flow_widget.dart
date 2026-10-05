import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/indicator_model.dart';

class OrderFlowWidget extends StatelessWidget {
  final OrderFlowResponse? data;
  final bool loading;

  const OrderFlowWidget({
    super.key,
    required this.data,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera del Módulo
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Flujo General de Órdenes en Tiempo Real',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Trazabilidad por etapas del ciclo logístico asistido por IA.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderLight),
                  ),
                  child: Text(
                    'Total: ${data?.totalPedidosFormateado ?? '21'}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Cuadrícula 2x2 de Etapas Operativas
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 12) / 2;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildStageCard(
                      title: 'Recepción por IA',
                      subtitle: 'Entrada multicanal',
                      badge: data?.recepcionIa.badge ?? 'Registrados: 21',
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.primaryBlue,
                      bgColor: const Color(0xFFEFF6FF),
                      width: itemWidth,
                    ),
                    _buildStageCard(
                      title: 'Validación de Pedido',
                      subtitle: 'Filtro stock y precios',
                      badge: data?.validacion.badge ?? 'Pendientes: 6',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.warning,
                      bgColor: AppColors.warningBg,
                      width: itemWidth,
                    ),
                    _buildStageCard(
                      title: 'Preparación Almacén',
                      subtitle: 'Picking y empaque',
                      badge: data?.preparacion.badge ?? 'En Proceso: 11',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.purple,
                      bgColor: AppColors.purpleBg,
                      width: itemWidth,
                    ),
                    _buildStageCard(
                      title: 'Pedido Despachado',
                      subtitle: 'Salida transportista',
                      badge: data?.despachado.badge ?? 'Completados: 5',
                      icon: Icons.local_shipping_outlined,
                      color: AppColors.success,
                      bgColor: AppColors.successBg,
                      width: itemWidth,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStageCard({
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSubtle,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
