import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tesis/core/constants/app_colors.dart';
import 'package:app_tesis/core/services/theme_service.dart';
import 'package:app_tesis/core/theme/app_theme.dart';
import 'package:app_tesis/core/widgets/erp_ui.dart';
import 'package:app_tesis/core/widgets/valencia_bot_icon.dart';
import 'package:app_tesis/screens/main_navigation/main_navigation_screen.dart';

/// Regresión del modo oscuro: paleta dinámica, tema petróleo mate y
/// persistencia de la preferencia. Las pantallas de marca (login, asistente
/// IA y Métricas) usan la paleta fija y no deben verse afectadas.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppColors.setDark(false);
    ThemeService.darkNotifier.value = false;
  });

  tearDown(() {
    AppColors.setDark(false);
    ThemeService.darkNotifier.value = false;
  });

  BoxDecoration decoracionDe(WidgetTester tester, Type tipo) {
    final contenedor = tester.widget<Container>(
      find
          .descendant(of: find.byType(tipo), matching: find.byType(Container))
          .first,
    );
    return contenedor.decoration! as BoxDecoration;
  }

  test('la paleta alterna superficies/textos sin perder el celeste de marca',
      () {
    expect(AppColors.backgroundLight, const Color(0xFFFFFFFF));
    expect(AppColors.surfaceLight, const Color(0xFFFFFFFF));
    expect(AppColors.textDark, const Color(0xFF0A3642));

    AppColors.setDark(true);

    expect(AppColors.backgroundLight, const Color(0xFF041C25));
    expect(AppColors.surfaceLight, const Color(0xFF072B38));
    expect(AppColors.surfaceMuted, const Color(0xFF0C3442));
    expect(AppColors.textDark, const Color(0xFFEAF9FE));
    expect(AppColors.textMuted, const Color(0xFFA6C9D5));
    // Los celestes de marca no cambian.
    expect(AppColors.celeste, const Color(0xFF00B4D8));
    expect(AppColors.celesteDeep, const Color(0xFF0077B6));
    // La paleta fija de las pantallas de marca tampoco cambia.
    expect(AppColors.fixedTextDark, const Color(0xFF0A3642));
    expect(AppColors.fixedSurface, const Color(0xFFFFFFFF));
  });

  test('el tema oscuro es petróleo mate (sin elevación)', () {
    AppColors.setDark(true);

    final tema = AppTheme.darkTheme;
    expect(tema.brightness, Brightness.dark);
    expect(tema.scaffoldBackgroundColor, const Color(0xFF041C25));
    expect(tema.cardTheme.color, const Color(0xFF072B38));
    expect(tema.cardTheme.elevation, 0);
    expect(tema.dialogTheme.backgroundColor, const Color(0xFF072B38));
  });

  test('las pantallas de marca conservan un tema claro fijo', () {
    AppColors.setDark(true);

    final fijo = AppTheme.fixedLightTheme;
    expect(fijo.brightness, Brightness.light);
    expect(fijo.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
    expect(fijo.colorScheme.onSurface, const Color(0xFF0A3642));
    // Construir el tema fijo no debe alterar la apariencia global.
    expect(AppColors.isDark, isTrue);
  });

  test('la preferencia de apariencia persiste y se restaura', () async {
    expect(ThemeService.isDark, isFalse);

    await ThemeService.setDark(true);
    expect(ThemeService.isDark, isTrue);
    expect(AppColors.isDark, isTrue);

    var prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ui_dark_mode'), isTrue);

    // Simula un arranque nuevo leyendo la preferencia guardada.
    AppColors.setDark(false);
    ThemeService.darkNotifier.value = false;
    SharedPreferences.setMockInitialValues({'ui_dark_mode': true});
    await ThemeService.init();

    expect(ThemeService.isDark, isTrue);
    expect(AppColors.isDark, isTrue);

    await ThemeService.setDark(false);
    prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('ui_dark_mode'), isFalse);
    expect(AppColors.isDark, isFalse);
  });

  testWidgets('cabecera y tarjeta compartidas usan superficies oscuras planas',
      (tester) async {
    AppColors.setDark(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: Column(
            children: [
              ErpHeader(title: 'Prueba'),
              ErpSoftCard(child: Text('Contenido')),
            ],
          ),
        ),
      ),
    );

    final cabecera = decoracionDe(tester, ErpHeader);
    expect(cabecera.gradient, isNull);
    expect(cabecera.boxShadow ?? const [], isEmpty);
    expect(cabecera.color, const Color(0xFF062733));
    expect(cabecera.border, isNotNull);

    final tarjeta = decoracionDe(tester, ErpSoftCard);
    expect(tarjeta.gradient, isNull);
    expect(tarjeta.boxShadow ?? const [], isEmpty);
    expect(tarjeta.color, const Color(0xFF072B38));
    expect(tarjeta.border, isNotNull);
  });

  testWidgets('los botones se mantienen planos en modo oscuro',
      (tester) async {
    AppColors.setDark(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: Column(
            children: [
              ErpPrimaryButton(label: 'Guardar', onTap: () {}),
              ErpSoftButton(label: 'Cancelar', onTap: () {}),
            ],
          ),
        ),
      ),
    );

    final primario = decoracionDe(tester, ErpPrimaryButton);
    expect(primario.gradient, isNull);
    expect(primario.boxShadow ?? const [], isEmpty);
    expect(primario.color, AppColors.celesteDeep);

    final suave = decoracionDe(tester, ErpSoftButton);
    expect(suave.gradient, isNull);
    expect(suave.boxShadow ?? const [], isEmpty);
    expect(suave.color, const Color(0xFF072B38));
  });

  testWidgets('el interruptor de Cuenta activa el modo oscuro en toda la app',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: MainNavigationScreen(initialIndex: 3)),
    );
    // Sin pumpAndSettle: las pestañas hacen peticiones que no resuelven en test.
    await tester.pump();

    expect(find.text('Apariencia'), findsOneWidget);
    expect(AppColors.isDark, isFalse);

    await tester.ensureVisible(find.byType(Switch));
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(ThemeService.isDark, isTrue);
    expect(AppColors.isDark, isTrue);
    expect(
      tester
          .widgetList<Scaffold>(find.byType(Scaffold))
          .any((s) => s.backgroundColor == const Color(0xFF041C25)),
      isTrue,
    );
    // La pestaña activa se conserva tras reconstruir las pestañas.
    expect(find.text('Apariencia'), findsOneWidget);

    // Desmonta el árbol antes de restaurar la paleta en tearDown.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el asistente IA conserva su diseño claro en modo oscuro',
      (tester) async {
    AppColors.setDark(true);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MainNavigationScreen(initialIndex: 0),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(ValenciaBotIcon));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Pregúntale a Valencia AI...'), findsOneWidget);
    final campo = find.byType(TextField).last;
    expect(Theme.of(tester.element(campo)).brightness, Brightness.light);

    await tester.pumpWidget(const SizedBox());
  });
}
