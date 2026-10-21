import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/core/widgets/campus_card.dart';

void main() {
  testWidgets(
      'CampusListRow recorta datos largos sin desbordar (giro del proveedor)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CampusListRow(
              icon: Icons.business_outlined,
              title: 'COMERCIAL AL POR MENOR DE ABARROTES Y BEBIDAS',
              subtitle: 'RUC 20487654321 • 987654321 • ventas@empresa.com',
              trailing: 'VENTA AL POR MAYOR NO ESPECIALIZADA Y AL POR MENOR',
              badge: 'activo',
              onTap: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    // Antes desbordaba ~9.7 px (franjas amarillas en la vista Proveedores).
    expect(tester.takeException(), isNull);
    expect(find.text('activo'), findsOneWidget);
    expect(find.text('VENTA AL POR MAYOR NO ESPECIALIZADA Y AL POR MENOR'),
        findsOneWidget);
  });

  testWidgets('CampusListRow mantiene el texto corto sin recortar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: CampusListRow(
              icon: Icons.business_outlined,
              title: 'Cassinelli S.A.',
              subtitle: 'RUC 20100100127 • 999888777',
              trailing: 'Distribución de bebidas',
              badge: 'activo',
              onTap: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Cassinelli S.A.'), findsOneWidget);
    expect(find.text('Distribución de bebidas'), findsOneWidget);
  });
}
