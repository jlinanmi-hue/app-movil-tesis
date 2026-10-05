import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombresCtrl;
  late final TextEditingController _apellidosCtrl;
  late final TextEditingController _dniCtrl;
  late final TextEditingController _telefonoCtrl;
  late final TextEditingController _correoCtrl;
  String _sexo = 'M';

  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = SessionService.currentUser;
    final emp = user?.empleado;

    _nombresCtrl = TextEditingController(text: emp?.nombres ?? '');
    _apellidosCtrl = TextEditingController(text: emp?.apellidos ?? '');
    _dniCtrl = TextEditingController(text: emp?.dni ?? '');
    _telefonoCtrl = TextEditingController(text: emp?.telefono ?? '');
    _correoCtrl = TextEditingController(text: emp?.correo ?? '');
    _sexo = (emp?.sexo != null && emp!.sexo!.isNotEmpty) ? emp.sexo!.toUpperCase() : 'M';

    _cargarPerfilCompleto();
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _dniCtrl.dispose();
    _telefonoCtrl.dispose();
    _correoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfilCompleto() async {
    final user = SessionService.currentUser;
    final empId = user?.empleado?.id;
    if (empId == null || empId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final freshEmp = await ApiService().getPersonal(empId);
      if (mounted) {
        setState(() {
          if (freshEmp.nombres.isNotEmpty) _nombresCtrl.text = freshEmp.nombres;
          if (freshEmp.apellidos.isNotEmpty) _apellidosCtrl.text = freshEmp.apellidos;
          if (freshEmp.dni != null && freshEmp.dni!.isNotEmpty) _dniCtrl.text = freshEmp.dni!;
          if (freshEmp.telefono != null && freshEmp.telefono!.isNotEmpty) _telefonoCtrl.text = freshEmp.telefono!;
          if (freshEmp.correo.isNotEmpty) _correoCtrl.text = freshEmp.correo;
          if (freshEmp.sexo != null && freshEmp.sexo!.isNotEmpty) _sexo = freshEmp.sexo!.toUpperCase();
        });

        final updatedUser = user!.copyWith(empleado: freshEmp);
        await SessionService.updateUser(updatedUser);
      }
    } catch (e) {
      debugPrint('[PersonalDataScreen] Usando datos en caché: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarDatosPersonales() async {
    if (!_formKey.currentState!.validate()) return;

    final user = SessionService.currentUser;
    final empId = user?.empleado?.id;
    if (empId == null || empId.isEmpty) {
      _showSnackbar('No se encontró identificador de empleado.', isError: true);
      return;
    }

    setState(() => _isSaving = true);
    FocusScope.of(context).unfocus();

    try {
      final payload = <String, dynamic>{
        'EmpleadoNombres': _nombresCtrl.text.trim(),
        'EmpleadoApellidos': _apellidosCtrl.text.trim(),
        'EmpleadoDni': _dniCtrl.text.trim(),
        'EmpleadoTelefono': _telefonoCtrl.text.trim().isNotEmpty ? _telefonoCtrl.text.trim() : null,
        'EmpleadoCorreo': _correoCtrl.text.trim(),
        'EmpleadoSexo': _sexo,
      };

      final updatedEmp = await ApiService().updatePersonal(empId, payload);

      final updatedUser = user!.copyWith(
        empleado: updatedEmp.copyWith(
          cargo: user.empleado?.cargo,
        ),
      );
      await SessionService.updateUser(updatedUser);

      if (mounted) {
        _showSnackbar('¡Datos personales actualizados correctamente!');
      }
    } on ApiException catch (e) {
      if (mounted) _showSnackbar(e.message, isError: true);
    } catch (e) {
      if (mounted) _showSnackbar('Error al guardar datos: $e', isError: true);
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
    final empleado = user?.empleado;
    final iniciales = (user?.nombreCompleto.isNotEmpty == true)
        ? user!.nombreCompleto.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

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
          'Datos del Colaborador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
        child: Column(
          children: [
            // ==========================================
            // CABECERA CON AVATAR E IDENTIFICACIÓN
            // ==========================================
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A65FF), Color(0xFF0B132B)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A65FF).withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                          border: Border.all(color: Colors.white, width: 3),
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
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlue,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.nombreCompleto ?? 'Usuario',
                    style: const TextStyle(
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
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          empleado?.id ?? 'EMP-00001',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '@${user?.userName ?? 'admin'}',
                        style: const TextStyle(
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
            // CONTENEDOR EXCLUSIVO: MIS DATOS PERSONALES
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
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.person_rounded, size: 18, color: AppColors.primaryBlue),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mis Datos Personales',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                            ),
                            Text(
                              'Información de contacto modificable',
                              style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: AppColors.borderLight),

                    // Nombres
                    _buildFieldLabel('Nombres *'),
                    TextFormField(
                      controller: _nombresCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tus nombres' : null,
                      decoration: _buildInputDecoration(
                        hint: 'Ej. Juan Carlos',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Apellidos
                    _buildFieldLabel('Apellidos *'),
                    TextFormField(
                      controller: _apellidosCtrl,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa tus apellidos' : null,
                      decoration: _buildInputDecoration(
                        hint: 'Ej. Valencia Rojas',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // DNI y Teléfono en fila
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('DNI / Documento *'),
                              TextFormField(
                                controller: _dniCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(8),
                                ],
                                validator: (v) {
                                  if (v == null || v.trim().length != 8) {
                                    return 'Debe tener 8 dígitos';
                                  }
                                  return null;
                                },
                                decoration: _buildInputDecoration(
                                  hint: '8 dígitos',
                                  icon: Icons.credit_card_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Teléfono / Celular'),
                              TextFormField(
                                controller: _telefonoCtrl,
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(12),
                                ],
                                decoration: _buildInputDecoration(
                                  hint: 'Ej. 987654321',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Correo Electrónico
                    _buildFieldLabel('Correo Electrónico *'),
                    TextFormField(
                      controller: _correoCtrl,
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                        if (!v.contains('@') || !v.contains('.')) return 'Correo no válido';
                        return null;
                      },
                      decoration: _buildInputDecoration(
                        hint: 'correo@ejemplo.com',
                        icon: Icons.mail_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Género / Sexo
                    _buildFieldLabel('Género / Sexo'),
                    Row(
                      children: [
                        Expanded(
                          child: _buildGenderOption(
                            label: 'Masculino',
                            value: 'M',
                            icon: Icons.male_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildGenderOption(
                            label: 'Femenino',
                            value: 'F',
                            icon: Icons.female_rounded,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Botón Guardar Datos Personales
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _guardarDatosPersonales,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Guardar Mis Datos',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.headerNavy,
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
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error, width: 1.4),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _sexo == value;
    return InkWell(
      onTap: () => setState(() => _sexo = value),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : const Color(0xFFE2E8F0),
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppColors.primaryBlue : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primaryBlue : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Alias de retrocompatibilidad
typedef EditProfileScreen = PersonalDataScreen;
