import 'package:flutter/material.dart';

// Paleta oficial: CELESTE + BLANCO (Comercial Valencia)
// Toda la UI de marca usa solo estas dos bases.
// Los colores de estado (success/warning/error) se reservan
// únicamente para semáforos de KPIs, no para branding.
class AppColors {
  // Celestes principales de marca
  static const Color celeste = Color(0xFF00B4D8);
  static const Color celesteDark = Color(0xFF0096C7);
  static const Color celesteDeep = Color(0xFF0077B6);
  static const Color celesteLight = Color(0xFF48CAE8);
  static const Color celesteSoft = Color(0xFF90E0EF);
  static const Color celesteBg = Color(0xFFCAF0F8);
  static const Color celesteTint = Color(0xFFEAF9FE);

  // Aliases de compatibilidad (toda la app apunta a celeste)
  static const Color headerNavy = celesteDark;
  static const Color primaryBlue = celeste;
  static const Color primaryBlueHover = celesteDark;
  static const Color accentBlue = celesteLight;

  // Fondos y superficies (solo blancos + tinte celeste)
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceMuted = celesteTint;
  static const Color borderLight = celesteBg;
  static const Color borderSoft = Color(0xFFE6F7FC);

  // Fondos y superficies (Modo Oscuro -> celeste profundo + blanco)
  static const Color backgroundDark = Color(0xFF023E5A);
  static const Color surfaceDark = Color(0xFF034E6E);
  static const Color surfaceMutedDark = Color(0xFF04617F);
  static const Color borderDark = celesteBg;

  // Textos en escala celeste-petróleo (legibles sobre blanco)
  static const Color textDark = Color(0xFF0A3642);
  static const Color textMuted = Color(0xFF4A7C8E);
  static const Color textSubtle = Color(0xFF8AB4C2);
  static const Color textLight = Color(0xFFF8FEFF);

  // Colores de estado / semáforo (KPIs y alertas)
  static const Color success = Color(0xFF10B981);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFFA7F3D0);
  static const Color successDark = Color(0xFF059669);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFDE68A);
  static const Color warningDark = Color(0xFFD97706);

  static const Color error = Color(0xFFEF4444);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color errorDark = Color(0xFFB91C1C);

  // Colores de módulos específicos -> solo variantes de celeste
  static const Color purple = celesteDark;
  static const Color purpleBg = celesteTint;
  static const Color indigo = celesteDeep;
  static const Color indigoBg = celesteTint;
  static const Color cyan = celeste;
  static const Color amber = celesteDark;

  // Paleta Chatbot & Login -> unificada a celeste
  static const Color midnightNavy = celesteDark;
  static const Color chatBackground = celeste;
  static const Color chatBackgroundDark = celesteDark;
  static const Color chatBotBubble = Color(0xFFEAF9FE);
  static const Color chatUserBubble = celeste;
  static const Color chatTealAccent = celesteLight;
}
