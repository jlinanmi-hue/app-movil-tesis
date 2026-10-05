import 'package:flutter/material.dart';
import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';
import '../../models/user_model.dart';
import '../login/login_screen.dart';
import '../login/widgets/server_config_dialog.dart';
import 'personal_data_screen.dart';
import 'account_security_screen.dart';
import 'user_role_info_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Future<void> _confirmLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            SizedBox(width: 8),
            Text('Cerrar Sesión', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar la sesión activa de Comercial Valencia?',
          style: TextStyle(fontSize: 13, color: AppColors.textDark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSubtle)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ApiService().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _abrirDatosPersonales() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PersonalDataScreen()),
    );
    if (mounted) setState(() {});
  }

  void _abrirSeguridad() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountSecurityScreen()),
    );
    if (mounted) setState(() {});
  }

  void _abrirInfoUsuario() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UserRoleInfoScreen()),
    );
  }

  void _mostrarInfoSistema() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primaryBlue, size: 22),
                SizedBox(width: 8),
                Text(
                  'Acerca del Sistema',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Sistema de Información Híbrido con Inteligencia Artificial',
              style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
            const Divider(height: 24, color: AppColors.borderLight),
            _buildSystemRow('Aplicación', 'Comercial Valencia Móvil'),
            _buildSystemRow('Versión', '1.0.0 (Investigación Tesis)'),
            _buildSystemRow('Motor IA', 'Modelo LLM Empresarial (SSE & Audio)'),
            _buildSystemRow('Backend', 'Laravel 11 REST API & Function Calling'),
            _buildSystemRow('Base de Datos', 'SQL Server / MySQL'),
            _buildSystemRow('Indicadores Tesis', 'PODE, PEOR, PRS, TBPP'),
          ],
        ),
      ),
    );
  }

  void _mostrarInfoAi() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Row(
              children: [
                Icon(Icons.smart_toy_outlined, color: Color(0xFF0F766E), size: 22),
                SizedBox(width: 8),
                Text(
                  'Valencia AI & Preferencias',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Asistente Inteligente y Herramientas Operativas',
              style: TextStyle(fontSize: 12, color: AppColors.textSubtle),
            ),
            const Divider(height: 24, color: AppColors.borderLight),
            _buildSystemRow('Estado del Asistente', 'En línea (Asistente IA)'),
            _buildSystemRow('Modo de Respuesta', 'Streaming Progresivo SSE'),
            _buildSystemRow('Transcriptor de Voz', 'Activo (Notas de Audio m4a/wav)'),
            _buildSystemRow('Herramientas Activas', 'Consultas, Stock, Pedidos, KPIs'),
            _buildSystemRow('Métricas de Consumo', 'Dashboard / Control de Tokens'),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemRow(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSubtle)),
          Flexible(
            child: Text(
              val,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserModel?>(
      valueListenable: SessionService.currentUserNotifier,
      builder: (context, user, _) {
        user ??= SessionService.currentUser;
        final empleado = user?.empleado;
        final nombreCompleto = user?.nombreCompleto ?? 'Colaborador Valencia';
        final cargo = user?.cargo ?? 'Personal Autorizado';
        final iniciales = nombreCompleto.isNotEmpty
            ? nombreCompleto.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
            : 'CV';

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: AppColors.headerNavy,
            elevation: 0,
            title: const Text(
              'Mi Cuenta',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            actions: [
              // Botón Configuración de Servidor
              IconButton(
                onPressed: () => ServerConfigDialog.show(context).then((_) => setState(() {})),
                icon: const Icon(Icons.settings_outlined, color: Colors.white, size: 20),
                tooltip: 'Configuración de Servidor',
              ),
              // Botón de Editar Perfil con estilo cuadrado redondeado
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: IconButton(
                  onPressed: _abrirDatosPersonales,
                  icon: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 16),
                  ),
                  tooltip: 'Editar Perfil',
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ==========================================
                // 1. ÁREA DE PERFIL CENTRAL (AVATAR + INFO)
                // ==========================================
                Center(
                  child: Column(
                    children: [
                      // Avatar circular grande
                      Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1A65FF), Color(0xFF0B132B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1A65FF).withValues(alpha: 0.3),
                                  blurRadius: 18,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                              border: Border.all(color: Colors.white, width: 3.5),
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
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: AppColors.successDark,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Nombre del Colaborador
                      Text(
                        nombreCompleto,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Subtítulo: Cargo • Comercial Valencia
                      Text(
                        '$cargo • Comercial Valencia',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSubtle,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Insignias: ID Empleado & Usuario
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              empleado?.id ?? 'EMP-001',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Text(
                              '@${user?.userName ?? 'admin'}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),


                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.borderLight),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Opción 1: Datos del Colaborador (Exclusivo datos personales)
                      _buildMenuTile(
                        icon: Icons.person_outline_rounded,
                        iconColor: AppColors.primaryBlue,
                        iconBg: const Color(0xFFEFF6FF),
                        title: 'Datos del Colaborador',
                        subtitle: 'Nombre, apellidos, DNI, teléfono y género',
                        onTap: _abrirDatosPersonales,
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.borderLight),

                      // Opción 2: Seguridad & Contraseña (Exclusivo correo y password)
                      _buildMenuTile(
                        icon: Icons.lock_outline_rounded,
                        iconColor: const Color(0xFF7C3AED),
                        iconBg: const Color(0xFFF5F3FF),
                        title: 'Seguridad & Contraseña',
                        subtitle: 'Actualización de correo y clave de acceso',
                        onTap: _abrirSeguridad,
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.borderLight),

                      // Opción 3: Información del Usuario (Exclusivo rol, cargo y fecha de ingreso)
                      _buildMenuTile(
                        icon: Icons.badge_outlined,
                        iconColor: const Color(0xFFD97706),
                        iconBg: const Color(0xFFFEF3C7),
                        title: 'Información del Usuario',
                        subtitle: 'Rol de acceso, cargo y fecha de ingreso',
                        onTap: _abrirInfoUsuario,
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.borderLight),

                      // Opción 4: Infraestructura y Red (Servidor API)
                      _buildMenuTile(
                        icon: Icons.lan_outlined,
                        iconColor: const Color(0xFF0284C7),
                        iconBg: const Color(0xFFF0F9FF),
                        title: 'Infraestructura y Red',
                        subtitle: ApiConfig.currentBaseUrl,
                        trailingBadge: 'Config',
                        onTap: () => ServerConfigDialog.show(context).then((_) => setState(() {})),
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.borderLight),

                      // Opción 5: Valencia AI & Preferencias
                      _buildMenuTile(
                        icon: Icons.smart_toy_outlined,
                        iconColor: const Color(0xFF0D9488),
                        iconBg: const Color(0xFFF0FDFA),
                        title: 'Valencia AI & Preferencias',
                        subtitle: 'Modelo LLM • Streaming & Audio',
                        onTap: _mostrarInfoAi,
                      ),
                      const Divider(height: 1, indent: 64, color: AppColors.borderLight),

                      // Opción 6: Acerca del Sistema
                      _buildMenuTile(
                        icon: Icons.info_outline_rounded,
                        iconColor: const Color(0xFF64748B),
                        iconBg: const Color(0xFFF8FAFC),
                        title: 'Acerca del Sistema',
                        subtitle: 'Versión 1.0.0 • Tesis Comercial Valencia',
                        onTap: _mostrarInfoSistema,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ==========================================
                // 4. TARJETA CERRAR SESIÓN
                // ==========================================
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFEE2E2)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: _buildMenuTile(
                    icon: Icons.logout_rounded,
                    iconColor: AppColors.error,
                    iconBg: const Color(0xFFFEF2F2),
                    title: 'Cerrar Sesión',
                    subtitle: 'Finalizar sesión activa en este dispositivo',
                    isDestructive: true,
                    onTap: _confirmLogout,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    String? trailingBadge,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            // Icono redondeado con fondo coloreado
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 20, color: iconColor),
            ),
            const SizedBox(width: 14),

            // Textos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDestructive ? AppColors.error : AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDestructive ? AppColors.error.withValues(alpha: 0.8) : AppColors.textSubtle,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Badge opcional
            if (trailingBadge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  trailingBadge,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 6),
            ],

            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDestructive ? AppColors.error.withValues(alpha: 0.6) : const Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

