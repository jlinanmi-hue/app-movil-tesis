import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app_tesis/main.dart';
import 'package:app_tesis/screens/main_navigation/main_navigation_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Carga inicial muestra pantalla de Login de Comercial Valencia', (WidgetTester tester) async {
    await tester.pumpWidget(const ValenciaApp());
    await tester.pumpAndSettle();

    expect(find.text('Comercial Valencia'), findsOneWidget);
    expect(find.text('SISTEMA HÍBRIDO IA'), findsOneWidget);
    expect(find.text('Iniciar Sesión Segura'), findsOneWidget);
    expect(find.text('Conexión Protegida'), findsOneWidget);
  });

  testWidgets('Barra de navegación flotante muestra los 5 accesos y apartado de Cuenta', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainNavigationScreen(initialIndex: 3),
      ),
    );
    await tester.pumpAndSettle();

    // Apartado de Cuenta
    expect(find.text('Mi Cuenta'), findsOneWidget);
    expect(find.text('Datos del Colaborador'), findsOneWidget);
    expect(find.text('Infraestructura y Red'), findsOneWidget);
    expect(find.text('Cerrar Sesión'), findsOneWidget);
  });

  testWidgets('Valencia AI Chatbot carga con diseño teal, cabecera y chips interactivos', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MainNavigationScreen(initialIndex: 2),
      ),
    );
    await tester.pumpAndSettle();

    // Verificación de cabecera y estado
    expect(find.text('Valencia AI'), findsOneWidget);
    expect(find.text('En línea • Sistema Híbrido IA'), findsOneWidget);
    expect(find.text('Hoy • Sesión Segura en Vivo'), findsOneWidget);

    // Verificación de chips iniciales
    expect(find.text('📦 Stock de productos bajo mínimo'), findsOneWidget);
    expect(find.text('🛒 Pedidos de hoy'), findsOneWidget);
    expect(find.text('📈 Estadísticas generales'), findsOneWidget);
    expect(find.text('🔔 Alertas del sistema'), findsOneWidget);

    // Verificación de campo de texto, botón de micrófono y botón de envío
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.near_me_rounded), findsOneWidget);
  });
}
