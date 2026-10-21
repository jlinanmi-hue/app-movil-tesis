import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:app_tesis/screens/erp/producto_presentaciones.dart';

/// Regresión: la vista `vista_stock_productos` devuelve las presentaciones en
/// `detalle_producto_medidas` (snake_case) y con el objeto `unidad_medida`.
/// Antes la app solo leía `detalleProductoMedidas`, por eso el modal mostraba
/// "Sin presentaciones registradas" aunque la web sí las mostraba.
void main() {
  Map<String, dynamic> productoVista() => {
        'ProductoNombre': 'Avena Grano de Oro Sachet',
        'detalle_producto_medidas': [
          {
            'Detalle_Producto_medida_ProductoId': 'PROD-00159',
            'Detalle_Producto_medida_unidades_medidaId': 'UND',
            'Detalle_Producto_medida_factor_conversion': 1,
            'Detalle_Producto_medida_precio_compra': 0.8,
            'Detalle_Producto_medida_precio_venta': 1.0,
            'unidad_medida': {
              'unidades_medidaId': 'UND',
              'unidades_medidaDescripcionUnidades': 'Unidad (UND)',
              'unidades_medidaAbreviatura': 'UND',
            },
          },
          {
            'Detalle_Producto_medida_ProductoId': 'PROD-00159',
            'Detalle_Producto_medida_unidades_medidaId': 'CAJ',
            'Detalle_Producto_medida_factor_conversion': 24,
            'Detalle_Producto_medida_precio_compra': 19.2,
            'Detalle_Producto_medida_precio_venta': 24.0,
            'unidad_medida': {
              'unidades_medidaId': 'CAJ',
              'unidades_medidaDescripcionUnidades': 'CAJA*24',
              'unidades_medidaAbreviatura': 'CAJ',
            },
          },
        ],
      };

  test('lee detalle_producto_medidas de la vista de stock', () {
    final presentaciones = presentacionesDeProducto(productoVista());

    expect(presentaciones, hasLength(2));
    expect(presentaciones[0].descripcion, 'Unidad (UND)');
    expect(presentaciones[0].esBase, isTrue);
    expect(presentaciones[0].factor, 1);
    expect(presentaciones[0].precioVenta, 1);
    expect(presentaciones[1].descripcion, 'CAJA*24');
    expect(presentaciones[1].esBase, isFalse);
    expect(presentaciones[1].factor, 24);
    expect(presentaciones[1].precioCompra, 19.2);
    expect(presentaciones[1].precioVenta, 24);
  });

  test('acepta detalle_producto_medidas serializado como texto JSON', () {
    final producto = productoVista();
    producto['detalle_producto_medidas'] =
        jsonEncode(producto['detalle_producto_medidas']);

    final presentaciones = presentacionesDeProducto(producto);

    expect(presentaciones, hasLength(2));
    expect(presentaciones[1].descripcion, 'CAJA*24');
  });

  test('mantiene compatibilidad con detalleProductoMedidas (Eloquent)', () {
    final producto = {
      'detalleProductoMedidas': [
        {
          'Detalle_Producto_medida_factor_conversion': 12,
          'Detalle_Producto_medida_precio_compra': 9,
          'Detalle_Producto_medida_precio_venta': 12,
          'unidadMedida': {
            'unidades_medidaDescripcionUnidades': 'DOCENA',
            'unidades_medidaAbreviatura': 'DOC',
          },
        },
        {
          'Detalle_Producto_medida_factor_conversion': 1,
          'Detalle_Producto_medida_precio_compra': 1,
          'Detalle_Producto_medida_precio_venta': 1.5,
          'unidadMedida': {
            'unidades_medidaDescripcionUnidades': 'UNIDAD',
            'unidades_medidaAbreviatura': 'UND',
          },
        },
      ],
    };

    final presentaciones = presentacionesDeProducto(producto);

    expect(presentaciones, hasLength(2));
    expect(presentaciones.first.descripcion, 'UNIDAD');
    expect(presentaciones.first.esBase, isTrue);
    expect(presentaciones.last.descripcion, 'DOCENA');
  });

  test('usa unidades de productos-select cuando no hay detalles', () {
    final producto = {
      'unidades': [
        {
          'descripcion': 'UNIDAD',
          'abreviatura': 'UND',
          'es_base': true,
          'factor_conversion': 1,
          'precio_compra': 1,
          'precio_venta': 2,
        },
        {
          'descripcion': 'CAJA*12',
          'abreviatura': 'CAJ',
          'es_base': false,
          'factor_conversion': 12,
          'precio_compra': 10,
          'precio_venta': 20,
        },
      ],
    };

    final presentaciones = presentacionesDeProducto(producto);

    expect(presentaciones, hasLength(2));
    expect(presentaciones.first.esBase, isTrue);
    expect(presentaciones.last.factor, 12);
  });

  test('ignora presentaciones eliminadas y sin datos devuelve lista vacía', () {
    final conEliminada = {
      'detalle_producto_medidas': [
        {
          'Detalle_Producto_medidaEliminado': 'S',
          'Detalle_Producto_medida_factor_conversion': 1,
          'unidad_medida': {
            'unidades_medidaDescripcionUnidades': 'UNIDAD',
          },
        },
      ],
    };

    expect(presentacionesDeProducto(conEliminada), isEmpty);
    expect(presentacionesDeProducto({'ProductoNombre': 'X'}), isEmpty);
    expect(
      presentacionesDeProducto({'detalle_producto_medidas': 'no-json'}),
      isEmpty,
    );
  });
}
