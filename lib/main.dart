import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:workmanager/workmanager.dart';
import 'core/services/device_notification_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/session_service.dart';
import 'core/services/theme_service.dart';
import 'core/theme/app_theme.dart';
import 'screens/login/login_screen.dart';
import 'screens/main_navigation/main_navigation_screen.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      // Inicializar dependencias en el isolate secundario de segundo plano
      await SessionService.init();
      await DeviceNotificationService.instance.init();
      await NotificationService.instance.fetchNotifications(isBackgroundPoll: true);

      // Programar la siguiente verificación rápida (OneOff) para reintentar en 1 minuto
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Workmanager().registerOneOffTask(
          'valencia_oneoff_${DateTime.now().millisecondsSinceEpoch}',
          'check_pyme_notifications',
          initialDelay: const Duration(minutes: 1),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(
            networkType: NetworkType.connected,
          ),
        );
      }
    } catch (e) {
      debugPrint('[Workmanager Task Error]: $e');
    }
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bloquear orientación vertical para experiencia móvil consistente
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar estado de sesión persistente
  await SessionService.init();

  // Restaurar apariencia (claro / oscuro)
  await ThemeService.init();

  // Inicializar servicio de notificaciones del dispositivo (pantalla de bloqueo / sistema)
  await DeviceNotificationService.instance.init();

  // Inicializar sincronización en segundo plano cuando la app esté cerrada o minimizada
  if (!kIsWeb &&
      (Platform.isAndroid || Platform.isIOS) &&
      !Platform.environment.containsKey('FLUTTER_TEST')) {
    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );
      await Workmanager().registerPeriodicTask(
        'valencia_notif_sync_task',
        'check_pyme_notifications',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      // Tarea rápida para activar sondeo de segundo plano tras 1 minuto
      await Workmanager().registerOneOffTask(
        'valencia_oneoff_initial',
        'check_pyme_notifications',
        initialDelay: const Duration(minutes: 1),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
    } catch (e) {
      debugPrint('[Workmanager] Inicialización omitida: $e');
    }
  }

  runApp(const ValenciaApp());
}

class ValenciaApp extends StatelessWidget {
  const ValenciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: SessionService.isLoggedInNotifier,
      builder: (context, isLoggedIn, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: ThemeService.darkNotifier,
          builder: (context, isDark, _) {
            return MaterialApp(
              navigatorKey: SessionService.navigatorKey,
              title: 'Comercial Valencia IA',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              home:
                  isLoggedIn
                      ? const MainNavigationScreen()
                      : const LoginScreen(),
            );
          },
        );
      },
    );
  }
}
