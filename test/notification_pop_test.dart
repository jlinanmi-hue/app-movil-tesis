import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_tesis/core/services/notification_service.dart';
import 'package:app_tesis/core/widgets/notification_bell_widget.dart';
import 'package:app_tesis/core/widgets/messenger_notification_pop.dart';
import 'package:app_tesis/core/widgets/notification_pop_manager.dart';
import 'package:app_tesis/models/notification_model.dart';

void main() {
  testWidgets('NotificationBellWidget muestra badge y emite MessengerNotificationPop único sin duplicados', (tester) async {
    final service = NotificationService.instance;
    service.unreadCountNotifier.value = 3;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [
              NotificationBellWidget(),
              NotificationBellWidget(size: 18), // Segundo widget para probar que NO se duplique
            ],
          ),
          body: const Center(child: Text('Dashboard')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verifica que el badge numérico muestre "3"
    expect(find.text('3'), findsNWidgets(2));

    // Emitir una notificación nueva para probar el Pop emergente estilo Messenger
    final sampleNotif = AppNotificationModel(
      id: 'NOT-TEST-99',
      titulo: 'Ingreso de Mercadería: Agua Cielo 2500 ml',
      mensaje: 'Se ingresaron 40.00 unidades al stock desde la OC OC-00184.',
      tipo: 'success',
      categoria: 'COMPRAS',
      referenciaId: 'OC-00184',
      leida: false,
      fecha: DateTime.now(),
    );

    service.emitNewNotification(sampleNotif);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // El pop emergente debe estar presente exactamente UNA vez (evita duplicados)
    expect(find.byType(MessengerNotificationPop), findsOneWidget);
    expect(find.text('Notificación'), findsOneWidget);
    expect(find.text('ahora'), findsOneWidget);
    expect(find.text('Ingreso de Mercadería: Agua Cielo 2500 ml'), findsOneWidget);

    // Intentar emitir de nuevo la misma notificación: debe ser ignorada por el debouncer
    service.emitNewNotification(sampleNotif);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(MessengerNotificationPop), findsOneWidget);

    // Limpieza de overlays y timers
    NotificationPopManager.dismissCurrent();
    await tester.pumpAndSettle();
  });
}
