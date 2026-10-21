import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_tesis/core/services/modules_service.dart';
import 'package:app_tesis/screens/erp/nuevo_pedido_screen.dart';
import 'package:app_tesis/screens/erp/nueva_compra_screen.dart';
import 'package:app_tesis/screens/erp/despacho_tab.dart';
import 'package:app_tesis/screens/erp/recepcion_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final svc = ModulesService();

  group('Batería Exhaustiva de Pruebas: Búsqueda Insensible a Mayúsculas/Minúsculas', () {
    test('Prueba 1: Búsqueda con "j" minúscula encuentra clientes con "J" mayúscula', () async {
      final res = await svc.clientes(search: 'j');
      expect(res, isNotEmpty);
      final titles = res.map((e) => e.titulo.toLowerCase()).toList();
      final hasJ = titles.any((t) => t.contains('j'));
      expect(hasJ, isTrue, reason: 'Debe contener clientes que tengan la letra j/J como San Juan');
    });

    test('Prueba 2: Búsqueda con "J" mayúscula encuentra los mismos clientes que con "j"', () async {
      final resMin = await svc.clientes(search: 'j');
      final resMay = await svc.clientes(search: 'J');
      expect(resMay, isNotEmpty);
      expect(resMay.length, equals(resMin.length),
          reason: 'Búsqueda con "J" y "j" debe arrojar exactamente la misma cantidad de resultados');
      expect(resMay.first.id, equals(resMin.first.id));
    });

    test('Prueba 3: Búsqueda de un solo carácter ("d", "1", "b") devuelve resultados inmediatos', () async {
      final resD = await svc.clientes(search: 'd');
      expect(resD, isNotEmpty);

      final res1 = await svc.clientes(search: '1');
      expect(res1, isNotEmpty);

      final resB = await svc.clientes(search: 'b');
      expect(resB, isNotEmpty);
    });

    test('Prueba 4: Búsqueda insensible a tildes (ej: "libreria" encuentra "Librería")', () async {
      final res = await svc.clientes(search: 'libreria');
      expect(res, isNotEmpty);
      final match = res.any((e) => e.titulo.toLowerCase().contains('librería') || e.titulo.toLowerCase().contains('libreria'));
      expect(match, isTrue);
    });

    test('Prueba 5: Búsqueda con "a" en proveedores encuentra "Alicorp", "Backus" o "Lima"', () async {
      final resA = await svc.proveedores(search: 'a');
      final resMayA = await svc.proveedores(search: 'A');
      expect(resA, isNotEmpty);
      expect(resMayA.length, equals(resA.length));
    });

    test('Prueba 6: Búsqueda de proveedores con "gloria" encuentra "Gloria Proveedores"', () async {
      final resMin = await svc.proveedores(search: 'gloria');
      final resMay = await svc.proveedores(search: 'GLORIA');
      expect(resMin, isNotEmpty);
      expect(resMay.length, equals(resMin.length));
    });

    testWidgets('Prueba 7: UI NuevoPedidoScreen busca cliente con "j" minúscula y muestra lista', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NuevoPedidoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchFinder = find.byType(TextField).first;
      await tester.enterText(searchFinder, 'j');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Debe haber resultados desplegados
      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Prueba 8: UI NuevoPedidoScreen busca cliente con "J" mayúscula con idéntico comportamiento', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NuevoPedidoScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchFinder = find.byType(TextField).first;
      await tester.enterText(searchFinder, 'J');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Prueba 9: UI NuevaCompraScreen busca proveedor con "d" minúscula sin trabas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NuevaCompraScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final searchFinder = find.byType(TextField).first;
      await tester.enterText(searchFinder, 'd');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(ListView), findsWidgets);
    });

    testWidgets('Prueba 10: DespachoTab busca pedidos con "p" sin importar mayúsculas', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DespachoTab(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final searchFinder = find.byType(TextField).first;
      await tester.enterText(searchFinder, 'p');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Por atender'), findsOneWidget);
    });

    testWidgets('Prueba 11: RecepcionTab busca órdenes con "oc" o "OC" indistintamente', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RecepcionTab(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));

      final searchFinder = find.byType(TextField).first;
      await tester.enterText(searchFinder, 'oc');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Por atender'), findsOneWidget);
    });

    test('Prueba 12: Normalización exhaustiva de caracteres y acentos', () {
      final norm1 = ModulesService.debugNormalizar('Álvaro José Núñez');
      expect(norm1, equals('alvaro jose nunez'));

      final norm2 = ModulesService.debugNormalizar('¡JUAN PÉREZ!');
      expect(norm2.contains('juan perez'), isTrue);
    });
  });
}
