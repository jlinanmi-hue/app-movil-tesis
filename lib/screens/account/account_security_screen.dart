import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _correoCtrl;
  final _nuevaPasswordCtrl = TextEditingController();
  final _confirmarPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser;
    _correoCtrl = TextEditingController(text: user?.empleado?.correo ?? '');
  }

  @override
  void dispose() {
    _correoCtrl.dispose();
    _nuevaPasswordCtrl.dispose();
    _confirmarPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarSeguridad() async {
    if (!_formKey.currentState!.validate()) return;

    final user = SessionService.currentUser;
    final empId = user?.empleado?.id;
    if (empId == null || empId.isEmpty) {
      _showSnackbar('No se encontró identificador de empleado.', isError: true);
      return;
    }

    final nuevoCorreo = _correoCtrl.text.trim();
    final nuevaPassword = _nuevaPasswordCtrl.text;
    final confirmarPassword = _confirmarPasswordCtrl.text;

    final correoHaCambiado = nuevoCorreo != (user?.empleado?.correo ?? '');
    final passwordIngresada = nuevaPassword.isNotEmpty || confirmarPassword.isNotEmpty;

    if (!correoHaCambiado && !passwordIngresada) {
      _showSnackbar('No has realizado cambios en el correo ni en la contraseña.');
      return;
    }

    setState(() => _isSaving = true);
    FocusScope.of(context).unfocus();

    try {
      // 1. Si cambió el correo, actualizar datos de empleado
      if (correoHaCambiado) {
        final updatedEmp = await ApiService().updatePersonal(empId, {
          'EmpleadoCorreo': nuevoCorreo,
        });
        final updatedUser = user!.copyWith(
          empleado: updatedEmp.copyWith(
            cargo: user.empleado?.cargo,
          ),
        );
        await SessionService.updateUser(updatedUser);
      }

      // 2. Si se ingresó contraseña, actualizar credencial cifrada
      if (passwordIngresada) {
        await ApiService().updatePersonalPassword(
          empId,
          password: nuevaPassword,
          passwordConfirmation: confirmarPassword,
        );
        _nuevaPasswordCtrl.clear();
        _confirmarPasswordCtrl.clear();
      }

      if (mounted) {
        _showSnackbar('¡Seguridad de la cuenta actualizada exitosamente!');
      }
    } on ApiException catch (e) {
      if (mounted) _showSnackbar(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnackbar('Error al actualizar seguridad: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnackbar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? AppColors.error : AppColors.successDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = SessionService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Seguridad & Contraseña',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        child: Column(
          children: [
            // ==========================================
            // TARJETA DE SEGURIDAD EXCLUSIVA
            // ==========================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF5FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shield_outlined, size: 20, color: Color(0xFF7C3AED)),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguridad de la Cuenta',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            Text(
                              'Actualiza tu correo y clave de acceso',
                              style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: AppColors.borderLight),

                    // Usuario actual (Solo lectura informativo)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, size: 18, color: Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          const Text(
                            'Usuario de acceso: ',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          Text(
                            '@${user?.userName ?? 'admin'}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Campo 1: Correo Electrónico
                    _buildFieldLabel('Correo Electrónico de la Cuenta *'),
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'El correo no puede estar vacío';
                        if (!v.contains('@') || !v.contains('.')) return 'Ingresa un correo electrónico válido';
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: 'correo@ejemplo.com',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 20),
                    const Divider(height: 1, color: AppColors.borderLight),
                    const SizedBox(height: 16),

                    const Text(
                      'Cambio de Contraseña (Opcional)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Deja estos campos en blanco si solo deseas modificar tu correo electrónico.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                    ),
                    const SizedBox(height: 14),

                    // Campo 2: Nueva Contraseña
                    _buildFieldLabel('Nueva Contraseña'),
                    TextFormField(
                      controller: _nuevaPasswordCtrl,
                      obscureText: _obscurePassword,
                      validator: (v) {
                        if (v != null && v.isNotEmpty && v.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: 'Mínimo 6 caracteres',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.textSubtle,
                          ),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo 3: Confirmar Contraseña
                    _buildFieldLabel('Confirmar Nueva Contraseña'),
                    TextFormField(
                      controller: _confirmarPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      validator: (v) {
                        if (_nuevaPasswordCtrl.text.isNotEmpty) {
                          if (v == null || v.isEmpty) return 'Confirma tu nueva contraseña';
                          if (v != _nuevaPasswordCtrl.text) return 'Las contraseñas no coinciden';
                        }
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: 'Repite la nueva contraseña',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            size: 18,
                            color: AppColors.textSubtle,
                          ),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Botón de Guardar Seguridad
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _guardarSeguridad,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.key_rounded, size: 18),
                        label: Text(
                          _isSaving ? 'Guardando cambios...' : 'Actualizar Credenciales',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B132B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF64748B)),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }
}
