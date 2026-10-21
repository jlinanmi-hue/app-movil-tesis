import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/erp_ui.dart';

class UserRoleInfoScreen extends StatelessWidget {
  const UserRoleInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;
    final empleado = user?.empleado;
    final nombreCompleto = user?.nombreCompleto ?? 'Colaborador';
    final cargo = user?.cargo ?? 'Personal Autorizado';
    final rol = user?.rol ?? 'Administrador';
    final fechaIngreso = empleado?.fechaIngreso ?? '2026-01-01';
    final iniciales = nombreCompleto.isNotEmpty
        ? nombreCompleto.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          const ErpHeader(title: 'Información del Usuario'),
          Expanded(
            child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        child: Column(
          children: [
            // ==========================================
            // CABECERA CON AVATAR E IDENTIFICACIÓN
            // ==========================================
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.celesteDeep,
                      border: Border.all(color: AppColors.backgroundLight, width: 3),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      iniciales,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nombreCompleto,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.celesteTint,
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: AppColors.celesteBg),
                        ),
                        child: Text(
                          empleado?.id ?? 'EMP-00001',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.celesteDeep,
                            letterSpacing: .3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '@${user?.userName ?? 'admin'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSubtle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // TARJETA DE ROL Y CARGO ASIGNADOS
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.lock_rounded,
                            size: 18, color: AppColors.warningDark),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rol y Cargo Asignados',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                          Text(
                            'Administrado institucionalmente',
                            style: TextStyle(fontSize: 11, color: AppColors.warningDark, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cartel explicativo
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.celesteTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.celesteBg),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: AppColors.celesteDeep),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Por políticas de seguridad, tu Rol y Cargo no pueden ser alterados desde tu cuenta. Solo el Administrador puede reasignarlos.',
                            style: TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Fila 1: Cargo Institucional
                  _buildDetailRow(
                    icon: Icons.work_outline_rounded,
                    label: 'Cargo Institucional',
                    value: cargo,
                    badgeText: 'Fijo',
                  ),
                  const SizedBox(height: 10),

                  // Fila 2: Rol de Acceso / Permiso
                  _buildDetailRow(
                    icon: Icons.shield_outlined,
                    label: 'Rol de Acceso / Permiso',
                    value: rol,
                    badgeText: 'Fijo',
                  ),
                  const SizedBox(height: 10),

                  // Fila 3: Fecha de Ingreso Oficial
                  _buildDetailRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Fecha de Ingreso Oficial',
                    value: fechaIngreso,
                    badgeText: 'Fijo',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==========================================
            // TARJETA DE RESUMEN INSTITUCIONAL
            // ==========================================
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Identidad en la Organización',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                  const SizedBox(height: 12),
                  _buildMetaRow('Organización', 'Comercial Valencia S.A.C.'),
                  const SizedBox(height: 8),
                  _buildMetaRow('Código Empleado', empleado?.id ?? 'EMP-00001'),
                  const SizedBox(height: 8),
                  _buildMetaRow('Cuenta de Acceso', '@${user?.userName ?? 'admin'}'),
                  const SizedBox(height: 8),
                  _buildMetaRow('Estado en Sistema', 'Activo 🟢'),
                ],
              ),
            ),
          ],
        ),
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required String badgeText,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.celesteDeep),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 11, color: AppColors.textSubtle),
                const SizedBox(width: 4),
                Text(
                  badgeText,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSubtle)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark)),
      ],
    );
  }
}
