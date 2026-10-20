import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';
import '../main_navigation/main_navigation_screen.dart';
import 'widgets/server_config_dialog.dart';

/// Login rediseñado (referencia tipo "Dotcom"): logo arriba, título,
/// campos redondeados, botón pill y enlace secundario al pie.
/// Conserva la paleta CELESTE + BLANCO y toda la lógica existente.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final reason = SessionService.logoutReasonNotifier.value;
    if (reason != null && reason.isNotEmpty) {
      _errorMessage = reason;
      SessionService.logoutReasonNotifier.value = null;
    }
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await ApiService().login(
        _usuarioController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text('¡Bienvenido, ${user.nombreCompleto}!'),
              ),
            ],
          ),
          backgroundColor: AppColors.fixedSuccessDark,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    } on DeferredActivationException catch (e) {
      setState(() {
        _errorMessage =
            '${e.message} (Fecha: ${e.fechaIngreso ?? 'Próxima'} - Faltan ${e.diasRestantes ?? 0} días)';
      });
    } on ApiException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Ocurrió un error inesperado al iniciar sesión.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Borde estándar de los campos (estilo referencia: redondeado suave).
  OutlineInputBorder _border(Color color, [double width = 1.4]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 14, color: AppColors.fixedTextSubtle),
      prefixIcon: Icon(icon, size: 20, color: AppColors.fixedTextSubtle),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: _border(AppColors.fixedBorderLight),
      enabledBorder: _border(AppColors.fixedBorderLight),
      focusedBorder: _border(AppColors.celeste, 1.6),
      errorBorder: _border(AppColors.fixedErrorBorder),
      focusedErrorBorder: _border(AppColors.error, 1.6),
    );
  }

  /// Logo provisional: badge celeste con iniciales "CV"
  /// (se reemplaza por el PNG oficial cuando esté disponible).
  Widget _logo() {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.celesteLight, AppColors.celesteDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.celeste.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Text(
        'CV',
        style: TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.fixedErrorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fixedErrorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 18, color: AppColors.fixedErrorDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(
                color: AppColors.fixedErrorDark,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rememberRow() {
    return GestureDetector(
      onTap: () => setState(() => _rememberMe = !_rememberMe),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _rememberMe ? AppColors.celeste : Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _rememberMe ? AppColors.celeste : AppColors.fixedBorderLight,
                  width: 1.6,
                ),
              ),
              child: _rememberMe
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              'Recordar sesión',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.fixedTextMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.celeste,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.celesteLight,
          elevation: 5,
          shadowColor: AppColors.celeste.withValues(alpha: 0.45),
          shape: const StadiumBorder(),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Autenticando...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Iniciar Sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 18),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Logo de marca
                    Center(child: _logo()),
                    const SizedBox(height: 16),
                    Text(
                      'Comercial Valencia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.fixedTextDark,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'SISTEMA HÍBRIDO IA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.fixedTextSubtle,
                        letterSpacing: 1.8,
                      ),
                    ),

                    const SizedBox(height: 30),

                    // 2. Título
                    Text(
                      'Iniciar Sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.celesteDark,
                        letterSpacing: -0.4,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // 3. Error inline
                    if (_errorMessage != null) _errorBanner(),

                    // 4. Campo usuario
                    TextFormField(
                      controller: _usuarioController,
                      textInputAction: TextInputAction.next,
                      style: TextStyle(
                          fontSize: 14, color: AppColors.fixedTextDark),
                      decoration: _fieldDecoration(
                        hint: 'e-mail / usuario',
                        icon: Icons.person_outline_rounded,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Por favor ingresa tu usuario';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // 5. Campo contraseña (con ojo para ver/ocultar)
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      style: TextStyle(
                          fontSize: 14, color: AppColors.fixedTextDark),
                      decoration: _fieldDecoration(
                        hint: 'password / contraseña',
                        icon: Icons.lock_outline_rounded,
                        suffix: IconButton(
                          onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 19,
                            color: AppColors.fixedTextSubtle,
                          ),
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Por favor ingresa tu contraseña';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 10),

                    // 6. Recordar sesión
                    _rememberRow(),

                    const SizedBox(height: 18),

                    // 7. Botón principal (pill)
                    _submitButton(),

                    const SizedBox(height: 16),

                    // 8. Enlace secundario al pie
                    Center(
                      child: TextButton(
                        onPressed: () => ServerConfigDialog.show(context),
                        child: Text(
                          'Configurar Servidor Local',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.fixedTextMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
