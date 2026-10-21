import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/screens/dashboard/dashboard_screen.dart';

void main() {
  testWidgets(
      'Inicio organizado: bienvenida, módulos y administración sin duplicados',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    // Bienvenida + buscador global
    expect(find.text('Bienvenido'), findsOneWidget);
    expect(find.text('Buscar órdenes, inventario, clientes...'), findsOneWidget);

    // Módulos: exactamente los 4 accesos directos
    expect(find.text('Módulos'), findsOneWidget);
    expect(find.text('Pedidos'), findsOneWidget);
    expect(find.text('Compras'), findsOneWidget);
    expect(find.text('Stock y Productos'), findsOneWidget);
    expect(find.text('Clientes'), findsOneWidget);

    // Administración agrupada en una sola tarjeta
    expect(find.text('Administración'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Catálogos'), findsOneWidget);
    expect(find.text('Seguridad'), findsOneWidget);

    // Sin el acumulamiento anterior: banner IA, KPIs duplicados y secciones
    // sueltas que repetían el hub de Operaciones.
    expect(find.text('Optimiza tu día con IA'), findsNothing);
    expect(find.text('Métricas de Tesis'), findsNothing);
    expect(find.text('Objetivos de Investigación de Tesis'), findsNothing);
    expect(find.text('Órdenes'), findsNothing);
    expect(find.text('Inventario'), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
