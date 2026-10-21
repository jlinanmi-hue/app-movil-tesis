import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/screens/erp/movimiento_detalle_dialog.dart';

/// Regresión: cada fila del Kárdex debe abrir un modal con el detalle del
/// movimiento, usando los campos enriquecidos que ya devuelve la vista.
void main() {
  Map<String, dynamic> movimientoEntrada() => {
        'Movimiento_productoId': 'MOV-27128',
        'producto_id': 'PROD-00023',
        'producto_nombre': 'Agua Cielo 2500 ml',
        'producto_marca': 'Cielo',
        'categoria_nombre': 'Bebidas y Refrescos',
        'tipo_movimiento_badge': 'ENTRADA',
        'tipo_operacion_texto': 'Recepción de Orden de Compra',
        'Movimiento_productoTipoMovimiento': 'E',
        'Movimiento_productoSubtipo': 'RECEPCION_OC',
        'Movimiento_productoCantidadPresentacion': 40,
        'Movimiento_productoCantidadSaldo': 242,
        'Movimiento_productoCostoPrecioUnitario': 9,
        'cantidad_presentacion_texto': '40 PAQ6',
        'unidad_movimiento_nombre': 'PAQUETE *6',
        'unidad_movimiento_abreviatura': 'PAQ6',
        'saldo_resultante_texto': '242 UND',
        'unidad_base_nombre': 'Unidad (UND)',
        'unidad_base_abreviatura': 'UND',
        'costo_precio_formateado': 'S/ 9.00',
        'costo_total_estimado': 360,
        'costo_total_formateado': 'S/ 360.00',
        'documento_referencia': 'OC-00184',
        'fecha_movimiento_formateada': '2026-10-19 18:13',
        'usuario_creacion': 'ADMIN',
      };

  testWidgets('abre el modal con todos los datos del movimiento de entrada',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => MovimientoDetalleDialog.mostrar(
                    context, movimientoEntrada()),
                child: const Text('Abrir detalle'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir detalle'));
    await tester.pumpAndSettle();

    expect(find.text('Detalle del Movimiento'), findsOneWidget);
    expect(find.text('ID: MOV-27128'), findsOneWidget);
    expect(find.text('ENTRADA DE STOCK'), findsOneWidget);
    expect(find.text('Recepción de Orden de Compra'), findsOneWidget);
    expect(find.text('PRODUCTO INVOLUCRADO'), findsOneWidget);
    expect(find.text('PROD-00023'), findsOneWidget);
    expect(find.text('Agua Cielo 2500 ml'), findsOneWidget);
    expect(find.text('40 PAQ6'), findsOneWidget);
    expect(find.text('Unidad: PAQUETE *6'), findsOneWidget);
    expect(find.text('242 UND'), findsOneWidget);
    expect(find.text('Unidad base: Unidad (UND)'), findsOneWidget);
    expect(find.text('S/ 9.00'), findsOneWidget);
    expect(find.text('S/ 360.00'), findsOneWidget);
    expect(find.text('OC-00184'), findsOneWidget);
    expect(find.text('2026-10-19 18:13'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);

    await tester.tap(find.text('Cerrar Detalle'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del Movimiento'), findsNothing);
  });

  testWidgets('muestra salida / merma y calcula los campos faltantes',
      (tester) async {
    final movimiento = {
      'Movimiento_productoId': 'MOV-27129',
      'Movimiento_productoTipoMovimiento': 'S',
      'Movimiento_productoSubtipo': 'AJUSTE_MANUAL',
      'producto_nombre': 'Aceite Cocinero 900 ml',
      'producto_marca': 'Cocinero',
      'categoria_nombre': 'Aceites',
      'Movimiento_productoCantidadPresentacion': 1,
      'Movimiento_productoCantidadSaldo': 79,
      'Movimiento_productoCostoPrecioUnitario': 7.5,
      'unidad_movimiento_abreviatura': 'UND',
      'unidad_movimiento_nombre': 'Unidad',
      'unidad_base_nombre': 'Unidad',
      'unidad_base_abreviatura': 'UND',
      'Movimiento_productoDocumentoOperacionId': 'AJU-00044',
      'Movimiento_productoFecha_Movimiento': '2026-10-19T16:17:00.000000Z',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    MovimientoDetalleDialog.mostrar(context, movimiento),
                child: const Text('Abrir salida'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir salida'));
    await tester.pumpAndSettle();

    expect(find.text('SALIDA / MERMA'), findsOneWidget);
    expect(find.text('Ajuste Manual de Kárdex'), findsOneWidget);
    expect(find.text('1 UND'), findsOneWidget);
    expect(find.text('79 UND'), findsOneWidget);
    expect(find.text('S/ 7.50'), findsNWidgets(2));
    expect(find.text('AJU-00044'), findsOneWidget);
    expect(find.text('2026-10-19 16:17'), findsOneWidget);
    expect(find.text('Sistema'), findsOneWidget);
  });
}
