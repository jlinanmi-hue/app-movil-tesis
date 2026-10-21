import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/core/widgets/erp_ui.dart';
import 'package:app_tesis/screens/erp/despacho_tab.dart';

/// Regresión: la bandeja de despacho (pedidos de clientes) debe permitir
/// filtrar por estado igual que Recepción, para no mezclar en una sola
/// lista las órdenes por atender, en preparación y cerradas.
void main() {
  testWidgets('Despacho filtra pedidos por estado (Por atender / En preparación / Cerradas)',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: DespachoTab())),
    );
    // Sin pumpAndSettle: la carga inicial depende de la red y en las pruebas
    // de widgets puede quedar esperando. Los chips se pintan al primer frame.
    await tester.pump();

    ErpFilterPills pildoras() =>
        tester.widget<ErpFilterPills>(find.byType(ErpFilterPills));

    expect(pildoras().options,
        const ['Por atender', 'En preparación', 'Cerradas']);
    // Por defecto solo se muestran las órdenes listas para atender.
    expect(pildoras().selected, 'Por atender');

    await tester.tap(find.text('En preparación'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(pildoras().selected, 'En preparación');

    await tester.tap(find.text('Cerradas'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(pildoras().selected, 'Cerradas');
  });
}
