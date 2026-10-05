import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/services/session_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación vertical para experiencia móvil consistente
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar estado de sesión persistente
  await SessionService.init();

  runApp(const ValenciaApp());
}

class ValenciaApp extends StatelessWidget {
  const ValenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionService.isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        return MaterialApp(
          title: 'Comercial Valencia - Sistema Híbrido IA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.light,
          home: isLoggedIn ? const MainNavigationScreen() : const LoginScreen(),
        );
      },
    );
  }
}
