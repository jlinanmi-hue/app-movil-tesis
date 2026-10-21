import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app_tesis/models/chat_message_model.dart';
import 'package:app_tesis/screens/erp/nuevo_pedido_screen.dart';
import 'package:app_tesis/screens/erp/nueva_compra_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Valencia AI - UiActionModel Tests', () {
    test('Parsea acción open_order_form con cliente y productos precargados', () {
      final json = {
        'type': 'open_order_form',
        'form': 'pedido',
        'prefill': {
          'cliente': {
            'id': 'CLI-00014',
            'nombre': 'Don Juan Comercial',
            'dni_ruc': '10456789012',
            'direccion': 'Av. Principal 123',
          },
          'productos': [
            {
              'producto_id': 'PROD-00005',
              'producto_nombre': 'Aceite Chef 1L',
              'unidad_id': 'UND-00001',
              'unidad_descripcion': 'Botella 1L',
              'factor_conversion': 1,
              'precio_unitario': 8.50,
              'cantidad': 10,
              'subtotal': 85.00,
            },
          ],
          'acuerdo_comercial': 'Contado Mostrador',
          'totales': {
            'subtotal': 85.00,
            'igv': 15.30,
            'total': 100.30,
          },
        },
      };

      final action = UiActionModel.fromJson(json);

      expect(action.isOpenOrderForm, isTrue);
      expect(action.isOpenPurchaseOrderForm, isFalse);
      expect(action.clienteNombre, 'Don Juan Comercial');
      expect(action.itemsCount, 1);
      expect(action.totalMonto, 100.30);
      expect(action.productos.first['producto_nombre'], 'Aceite Chef 1L');
    });

    test('Parsea acción open_purchase_order_form con proveedor y productos', () {
      final json = {
        'type': 'open_purchase_order_form',
        'form': 'orden_compra',
        'prefill': {
          'proveedor': {
            'ProveedorId': 'PRV-00002',
            'ProveedorRazonSocial': 'ALICORP S.A.A.',
            'ProveedorRuc': '20100055237',
          },
          'productos': [
            {
              'productoId': 'PROD-00001',
              'productoNombre': 'Fideo Don Vittorio 250g',
              'unidadMedidaId': 'UND-00016',
              'unidadNombre': 'Paquete x 20',
              'factor_conversion': 20,
              'cantidad': 5,
              'precioUnitario': 45.00,
              'subtotal': 225.00,
            },
          ],
          'observacion': 'Orden solicitada por Valencia AI',
          'totales': {
            'total': 225.00,
          },
        },
      };

      final action = UiActionModel.fromJson(json);

      expect(action.isOpenPurchaseOrderForm, isTrue);
      expect(action.isOpenOrderForm, isFalse);
      expect(action.proveedorNombre, 'ALICORP S.A.A.');
      expect(action.itemsCount, 1);
      expect(action.totalMonto, 225.00);
      expect(action.productos.first['productoNombre'], 'Fideo Don Vittorio 250g');
    });
  });

  group('Formularios ERP con Prefill', () {
    testWidgets('NuevoPedidoScreen carga correctamente datos precargados', (tester) async {
      final prefill = {
        'cliente': {
          'id': 'CLI-00014',
          'nombre': 'Don Juan Comercial',
          'dni_ruc': '10456789012',
          'direccion': 'Av. Principal 123',
        },
        'productos': [
          {
            'producto_id': 'PROD-00005',
            'producto_nombre': 'Aceite Chef 1L',
            'unidad_id': 'UND-00001',
            'unidad_descripcion': 'Botella 1L',
            'factor_conversion': 1,
            'precio_unitario': 8.50,
            'cantidad': 10,
            'subtotal': 85.00,
          },
        ],
        'acuerdo_comercial': 'Contado Mostrador',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: NuevoPedidoScreen(prefillData: prefill),
        ),
      );
      await tester.pumpAndSettle();

      // Cliente precargado
      expect(find.text('Don Juan Comercial'), findsWidgets);
      // Producto precargado en carrito
      expect(find.text('Aceite Chef 1L'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('NuevaCompraScreen carga correctamente datos precargados', (tester) async {
      final prefill = {
        'proveedor': {
          'ProveedorId': 'PRV-00002',
          'ProveedorRazonSocial': 'ALICORP S.A.A.',
          'ProveedorRuc': '20100055237',
        },
        'productos': [
          {
            'productoId': 'PROD-00001',
            'productoNombre': 'Fideo Don Vittorio 250g',
            'unidadMedidaId': 'UND-00016',
            'unidadNombre': 'Paquete x 20',
            'factor_conversion': 20,
            'cantidad': 5,
          },
        ],
        'observacion': 'Orden generada vía Valencia AI',
      };

      await tester.pumpWidget(
        MaterialApp(
          home: NuevaCompraScreen(prefillData: prefill),
        ),
      );
      await tester.pumpAndSettle();

      // Proveedor precargado
      expect(find.text('ALICORP S.A.A.'), findsWidgets);
      // Producto precargado en carrito
      expect(find.text('Fideo Don Vittorio 250g'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
