import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/models/erp_models.dart';
import 'package:app_tesis/screens/erp/nuevo_cliente_screen.dart';
import 'package:app_tesis/screens/erp/nuevo_proveedor_screen.dart';

void main() {
  group('SunatConsulta.desdePayload', () {
    test('normaliza RUC SUNAT para cliente (target=cliente)', () {
      final info = SunatConsulta.desdePayload(
        {
          'success': true,
          'ruc': '20601234565',
          'target': 'cliente',
          'direccion': 'AV LOS OLIVOS 123',
          'data': {
            'ClienteRuc': '20601234565',
            'ClienteNombre': 'DISTRIBUIDORA ALIMENTARIA SAC',
            'ClienteDireccion': 'AV LOS OLIVOS 123',
            'ClienteNumero': null,
            'ClienteEstado': 'A',
            'departamento': 'LIMA',
            'provincia': 'LIMA',
            'distrito': 'LOS OLIVOS',
          },
          'raw_data': {'tipo_contribuyente': 'SOCIEDAD ANONIMA CERRADA'},
        },
        '20601234565',
        'cliente',
      );

      expect(info.esDni, isFalse);
      expect(info.nombre, 'DISTRIBUIDORA ALIMENTARIA SAC');
      expect(info.direccion, 'AV LOS OLIVOS 123');
      expect(info.telefono, '');
      expect(info.estado, 'A');
      expect(info.estadoTexto, 'ACTIVO');
      expect(info.tipoContribuyente, 'SOCIEDAD ANONIMA CERRADA');
      expect(info.ubicacion, 'LOS OLIVOS - LIMA - LIMA');
    });

    test('normaliza RUC SUNAT para proveedor (target=proveedor)', () {
      final info = SunatConsulta.desdePayload(
        {
          'success': true,
          'ruc': '20601234565',
          'target': 'proveedor',
          'data': {
            'ProveedorRuc': '20601234565',
            'ProveedorRazonSocial': 'ALIMENTOS DEL NORTE SRL',
            'ProveedorTipoContribuyente': 'SOCIEDAD COMERCIAL DE RESPONSABILIDAD LIMITADA',
            'ProveedorEstado': 'A',
            'ProveedorActividadEconomica':
                'VENTA AL POR MAYOR DE ALIMENTOS Y BEBIDAS',
            'ProveedorTelefono': '013150800',
          },
          'raw_data': {
            'estado': 'ACTIVO',
            'condicion': 'HABIDO',
            'actividad_economica': 'VENTA AL POR MAYOR DE ALIMENTOS Y BEBIDAS',
          },
        },
        '20601234565',
        'proveedor',
      );

      expect(info.esDni, isFalse);
      expect(info.nombre, 'ALIMENTOS DEL NORTE SRL');
      expect(info.estado, 'A');
      expect(info.condicion, 'HABIDO');
      expect(info.telefono, '013150800');
      expect(info.actividadEconomica,
          'VENTA AL POR MAYOR DE ALIMENTOS Y BEBIDAS');
    });

    test('normaliza DNI (RENIEC) para proveedor con actividad "-"', () {
      final info = SunatConsulta.desdePayload(
        {
          'success': true,
          'proveedor': {
            'ProveedorRuc': '45678901',
            'ProveedorRazonSocial': 'JUAN PEREZ GOMEZ',
            'ProveedorTipoContribuyente': 'PERSONA NATURAL CON DNI',
            'ProveedorEstado': 'A',
            'ProveedorActividadEconomica': '-',
            'ProveedorTelefono': '-',
          },
          'raw_data': {'estado': 'ACTIVO', 'condicion': 'HABIDO'},
        },
        '45678901',
        'proveedor',
      );

      expect(info.esDni, isTrue);
      expect(info.nombre, 'JUAN PEREZ GOMEZ');
      expect(info.actividadEconomica, '');
      expect(info.telefono, '');
      expect(info.condicion, 'HABIDO');
      expect(info.estado, 'A');
    });

    test('normaliza respuesta servida desde la caché BD (from_db)', () {
      final info = SunatConsulta.desdePayload(
        {
          'from_db': true,
          'cliente': {
            'ClienteRuc': '10456789012',
            'ClienteNombre': 'BODEGA SAN JUAN',
            'ClienteDireccion': 'JR PUNO 456',
            'ClienteEstado': 'I',
            'departamento': 'LIMA',
            'provincia': 'LIMA',
            'distrito': 'CERCADO',
          },
          'raw_data': {'estado': 'INACTIVO', 'condicion': 'NO HABIDO'},
        },
        '10456789012',
        'cliente',
      );

      expect(info.desdeCache, isTrue);
      expect(info.nombre, 'BODEGA SAN JUAN');
      expect(info.estado, 'I');
      expect(info.estadoTexto, 'INACTIVO');
      expect(info.condicion, 'NO HABIDO');
    });
  });

  group('Pantallas de registro con búsqueda SUNAT', () {
    testWidgets('Nuevo Cliente pide documento antes de consultar SUNAT',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NuevoClienteScreen()));

      expect(find.text('Nuevo Cliente'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(find.text('Ingresa el RUC o DNI para consultar.'), findsOneWidget);
    });

    testWidgets('Nuevo Proveedor pide RUC antes de consultar SUNAT',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NuevoProveedorScreen()));

      expect(find.text('Nuevo Proveedor'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(
          find.text('Ingresa el RUC para consultar ante SUNAT.'), findsOneWidget);
    });

    testWidgets('Nuevo Cliente valida longitud del documento', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NuevoClienteScreen()));

      await tester.enterText(find.byType(TextField).first, '123');
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();

      expect(
        find.text(
            'El documento debe tener 8 dígitos (DNI) u 11 dígitos (RUC SUNAT).'),
        findsOneWidget,
      );
    });

    testWidgets('Nuevo Proveedor exige razón social al guardar', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: NuevoProveedorScreen()));

      await tester.enterText(
          find.byType(TextField).first, '20601234565'); // RUC válido
      final boton = find.text('Registrar proveedor');
      await tester.scrollUntilVisible(boton, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(boton);
      await tester.pump();
      final banner = find.text('La razón social es obligatoria.');
      await tester.scrollUntilVisible(banner, -300,
          scrollable: find.byType(Scrollable).first);
      expect(banner, findsOneWidget);
    });
  });
}
