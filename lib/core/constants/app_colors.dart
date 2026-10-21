import 'package:flutter/material.dart';

// Paleta oficial: CELESTE + BLANCO (Comercial Valencia)
// Toda la UI de marca usa solo estas dos bases.
// Los colores de estado (success/warning/error) se reservan
// únicamente para semáforos de KPIs, no para branding.
//
// MODO OSCURO: los tokens de superficie/texto/borde se resuelven según
// [isDark] (petróleo profundo + celeste mate, sin reflejos). Los tonos de
// marca (celeste, celesteDark, celesteDeep, celesteLight) se mantienen
// idénticos para conservar la identidad en ambos modos.
class AppColors {
  AppColors._();

  static bool _dark = false;

  /// Modo oscuro activo. Lo controla [ThemeService].
  static bool get isDark => _dark;
  static void setDark(bool value) => _dark = value;

  /// Elige el tono según el modo activo.
  static Color _c(Color light, Color dark) => _dark ? dark : light;

  // Celestes principales de marca (idénticos en ambos modos)
  static const Color celeste = Color(0xFF00B4D8);
  static const Color celesteDark = Color(0xFF0096C7);
  static const Color celesteDeep = Color(0xFF0077B6);
  static const Color celesteLight = Color(0xFF48CAE8);

  static Color get celesteSoft =>
      _c(const Color(0xFF90E0EF), const Color(0xFF2C6E84));
  static Color get celesteBg =>
      _c(const Color(0xFFCAF0F8), const Color(0xFF174A5C));
  static Color get celesteTint =>
      _c(const Color(0xFFEAF9FE), const Color(0xFF0C3442));

  // Aliases de compatibilidad (toda la app apunta a celeste)
  static const Color headerNavy = celesteDark;
  static const Color primaryBlue = celeste;
  static const Color primaryBlueHover = celesteDark;
  static const Color accentBlue = celesteLight;

  // Fondos y superficies (solo blancos + tinte celeste)
  static Color get backgroundLight =>
      _c(const Color(0xFFFFFFFF), const Color(0xFF041C25));
  static Color get surfaceLight =>
      _c(const Color(0xFFFFFFFF), const Color(0xFF072B38));
  static Color get surfaceMuted => celesteTint;
  static Color get borderLight => celesteBg;
  static Color get borderSoft =>
      _c(const Color(0xFFE6F7FC), const Color(0xFF103946));

  /// Línea capilar para superficies planas (estilo mate).
  static Color get hairline =>
      _c(const Color(0xFFD9ECF3), const Color(0xFF17495A));

  /// Fondo de la cabecera única (barra de marca).
  static Color get headerSurface =>
      _c(celesteDark, const Color(0xFF062733));

  /// Superficie de la barra de navegación inferior.
  static Color get navSurface =>
      _c(const Color(0xFFFFFFFF), const Color(0xFF072B38));

  /// Velo de modales (siempre oscuro, más intenso en modo oscuro).
  static Color get scrim =>
      _c(const Color(0x520A3642), const Color(0x99000000));

  // Fondos y superficies (Modo Oscuro -> celeste profundo + blanco)
  static const Color backgroundDark = Color(0xFF041C25);
  static const Color surfaceDark = Color(0xFF072B38);
  static const Color surfaceMutedDark = Color(0xFF0C3442);
  static Color get borderDark => celesteBg;

  // Textos en escala celeste-petróleo (legibles sobre blanco)
  static Color get textDark =>
      _c(const Color(0xFF0A3642), const Color(0xFFEAF9FE));
  static Color get textMuted =>
      _c(const Color(0xFF4A7C8E), const Color(0xFFA6C9D5));
  static Color get textSubtle =>
      _c(const Color(0xFF8AB4C2), const Color(0xFF7AA3B2));
  static const Color textLight = Color(0xFFF8FEFF);

  // Colores de estado / semáforo (KPIs y alertas)
  static const Color success = Color(0xFF10B981);
  /// Verde sólido para fondos con texto blanco (p. ej. snackbars de éxito).
  static const Color successFill = Color(0xFF059669);
  static Color get successBg =>
      _c(const Color(0xFFECFDF5), const Color(0xFF0B3A2E));
  static Color get successBorder =>
      _c(const Color(0xFFA7F3D0), const Color(0xFF1C6B52));
  static Color get successDark =>
      _c(const Color(0xFF059669), const Color(0xFF6EE7B7));

  static const Color warning = Color(0xFFF59E0B);
  static Color get warningBg =>
      _c(const Color(0xFFFFFBEB), const Color(0xFF3A2A0B));
  static Color get warningBorder =>
      _c(const Color(0xFFFDE68A), const Color(0xFF7A5A17));
  static Color get warningDark =>
      _c(const Color(0xFFD97706), const Color(0xFFFCD34D));

  static const Color error = Color(0xFFEF4444);
  static Color get errorBg =>
      _c(const Color(0xFFFEF2F2), const Color(0xFF3A1418));
  static Color get errorBorder =>
      _c(const Color(0xFFFECACA), const Color(0xFF7A2A32));
  static Color get errorDark =>
      _c(const Color(0xFFB91C1C), const Color(0xFFFCA5A5));

  // Colores de módulos específicos -> solo variantes de celeste
  static const Color purple = celesteDark;
  static Color get purpleBg => celesteTint;
  static const Color indigo = celesteDeep;
  static Color get indigoBg => celesteTint;
  static const Color cyan = celeste;
  static const Color amber = celesteDark;

  // Paleta Chatbot & Login -> unificada a celeste
  static const Color midnightNavy = celesteDark;
  static const Color chatBackground = celeste;
  static const Color chatBackgroundDark = celesteDark;
  static const Color chatBotBubble = Color(0xFFEAF9FE);
  static const Color chatUserBubble = celeste;
  static const Color chatTealAccent = celesteLight;

  // ---------------------------------------------------------------------------
  // PALETA FIJA (experiencias de marca que no cambian con el modo oscuro):
  // login, asistente de IA y Métricas. Reproducen exactamente el modo claro.
  // ---------------------------------------------------------------------------
  static const Color fixedSurface = Color(0xFFFFFFFF);
  static const Color fixedSurfaceMuted = Color(0xFFEAF9FE);
  static const Color fixedBorderLight = Color(0xFFCAF0F8);
  static const Color fixedBorderSoft = Color(0xFFE6F7FC);
  static const Color fixedHairline = Color(0xFFD9ECF3);
  static const Color fixedTextDark = Color(0xFF0A3642);
  static const Color fixedTextMuted = Color(0xFF4A7C8E);
  static const Color fixedTextSubtle = Color(0xFF8AB4C2);
  static const Color fixedSuccessBg = Color(0xFFECFDF5);
  static const Color fixedSuccessBorder = Color(0xFFA7F3D0);
  static const Color fixedSuccessDark = Color(0xFF059669);
  static const Color fixedWarningBg = Color(0xFFFFFBEB);
  static const Color fixedWarningBorder = Color(0xFFFDE68A);
  static const Color fixedWarningDark = Color(0xFFD97706);
  static const Color fixedErrorBg = Color(0xFFFEF2F2);
  static const Color fixedErrorBorder = Color(0xFFFECACA);
  static const Color fixedErrorDark = Color(0xFFB91C1C);
}
