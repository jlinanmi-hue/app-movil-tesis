import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/core/widgets/erp_ui.dart';
import 'package:app_tesis/models/erp_models.dart';
import 'package:app_tesis/screens/erp/erp_list_screen.dart';

void main() {
  testWidgets(
      'El detalle de una fila se abre como modal flotante (no hoja inferior)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErpListScreen(
          title: 'Gestión de Clientes',
          tabs: const ['Activos'],
          rowIcon: Icons.person_outline_rounded,
          loader: (s, t) async => [
            ErpItem(
              id: 'CLI-00017',
              titulo: 'Raúl Jiménez',
              subtitulo: '11100000 • Calle Los Pinos 123',
              monto: '0 compras',
              estado: 'activo',
            ),
          ],
          onEdit: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Raúl Jiménez'));
    await tester.pumpAndSettle();

    // Modal flotante centrado (Dialog), sin drag handle de hoja inferior.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ErpDragHandle), findsNothing);
    expect(find.text('ID: CLI-00017 • activo'), findsOneWidget);
    expect(find.text('Editar'), findsOneWidget);
    expect(find.text('Cerrar'), findsOneWidget);
    // Solo la acción de editar: una píldora rellena (primary).
    expect(find.byType(ErpPillButton), findsOneWidget);

    // La X cierra el modal sin ejecutar acciones.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Cerrar del modal flotante también lo descarta', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErpListScreen(
          title: 'Gestión de Proveedores',
          tabs: const ['Activos'],
          rowIcon: Icons.business_outlined,
          loader: (s, t) async => [
            ErpItem(
              id: 'PRV-00003',
              titulo: 'Distribuidora Alimentaria S.A.C.',
              subtitulo: 'RUC 20601234565 • 987654321',
              monto: 'VENTA AL POR MAYOR',
              estado: 'activo',
            ),
          ],
          onEdit: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Distribuidora Alimentaria S.A.C.'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(find.text('Eliminar'), findsOneWidget);
    // Editar (rellena) + Eliminar (outline rojo): dos píldoras.
    expect(find.byType(ErpPillButton), findsNWidgets(2));

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('Modal compacto en pantalla angosta: píldoras centradas con wrap',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ErpListScreen(
          title: 'Gestión de Proveedores',
          tabs: const ['Activos'],
          rowIcon: Icons.business_outlined,
          loader: (s, t) async => [
            ErpItem(
              id: 'PRV-00003',
              titulo: 'Distribuidora Alimentaria S.A.C.',
              subtitulo: 'RUC 20601234565 • 987654321',
              monto: 'VENTA AL POR MAYOR',
              estado: 'activo',
            ),
          ],
          onEdit: (_) {},
          onHistory: (_) {},
          onDelete: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Distribuidora Alimentaria S.A.C.'));
    await tester.pumpAndSettle();

    // Editar (rellena) + Historial (outline) + Eliminar (rojo): sin
    // desbordes aunque no quepan en una sola línea.
    expect(find.byType(Dialog), findsOneWidget);
    expect(find.byType(ErpPillButton), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
}
