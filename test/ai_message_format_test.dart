import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tesis/core/services/notification_service.dart';
import 'package:app_tesis/models/chat_message_model.dart';
import 'package:app_tesis/screens/ai_chat/widgets/ai_message_content_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    NotificationService.instance.unreadCountNotifier.value = 2;
  });

  tearDown(() {
    NotificationService.instance.unreadCountNotifier.value = 0;
  });

  const sample = '''
Sí, hay 25 notificaciones pendientes/no leídas.

Resumen principal:

- 1 orden de cliente despachada
  - PED-20261007-008 completada y entregada por S/ 7,349.81.

- Ingresos de mercadería a stock
  - Guaraná 500ml: +15 UND desde OC-00032.
  - Pepsi 500ml: +15 UND desde OC-00030.
  - Arroz Delite: varios ingresos desde OC-00033, OC-00028, OC-00022, OC-00020, OC-00018.
  - Aceite Chef 900ml y Bonle 400 ml: ingresos menores de +1 UND.

- Advertencias en compras
  - Recepciones anuladas con contra-movimientos en Kárdex:
    - OC-00022
    - OC-00020
    - OC-00019
    - OC-00018

- Advertencias de inventario
  - La orden PED-00004 aparece como "por expirar" en 2 notificaciones antiguas.
  - Ajuste revertido AJU-00005 para Aceite Chef 900ml, con reintegro de +1 UND.
''';

  ChatMessageModel mensaje() {
    return ChatMessageModel(
      id: 'msg_test',
      sender: 'assistant',
      text: sample.trim(),
      timestamp: DateTime(2026, 10, 20, 9, 30),
    );
  }

  Future<void> mostrar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 326,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F3F7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: AiMessageContentWidget(message: mensaje()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('estructura la respuesta del bot y muestra el acceso a notificaciones',
      (tester) async {
    await mostrar(tester);

    expect(find.text('2 notificaciones sin leer'), findsOneWidget);
    expect(find.text('Toca para abrir la bandeja'), findsOneWidget);
    expect(find.text('Resumen principal:'), findsOneWidget);
    expect(find.text('1 orden de cliente despachada'), findsOneWidget);
    expect(find.text('Ingresos de mercadería a stock'), findsOneWidget);
    expect(find.text('Advertencias en compras'), findsOneWidget);
    expect(find.text('Advertencias de inventario'), findsOneWidget);
    expect(find.text('S/ 7,349.81'), findsOneWidget);
    expect(find.text('OC-00019'), findsOneWidget);
    expect(find.text('Copiar'), findsOneWidget);
    expect(
      find.textContaining('Sí, hay 25', findRichText: true),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('el acceso a notificaciones abre la bandeja real de la app',
      (tester) async {
    await mostrar(tester);

    await tester.tap(find.text('Toca para abrir la bandeja'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Centro de Notificaciones'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
