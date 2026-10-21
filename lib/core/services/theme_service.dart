import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';

/// Preferencia de apariencia (modo claro / oscuro) persistente.
///
/// La paleta [AppColors] resuelve sus tonos a partir de [AppColors.isDark],
/// por eso se sincroniza aquí antes de construir la interfaz.
class ThemeService {
  static const String _keyDark = 'ui_dark_mode';

  static final ValueNotifier<bool> darkNotifier = ValueNotifier<bool>(false);

  static bool get isDark => darkNotifier.value;

  /// Restaura la preferencia guardada al arrancar la app.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final dark = prefs.getBool(_keyDark) ?? false;
    AppColors.setDark(dark);
    darkNotifier.value = dark;
  }

  static Future<void> setDark(bool value) async {
    if (darkNotifier.value == value) return;
    AppColors.setDark(value);
    darkNotifier.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDark, value);
  }

  static Future<void> toggle() => setDark(!darkNotifier.value);
}
