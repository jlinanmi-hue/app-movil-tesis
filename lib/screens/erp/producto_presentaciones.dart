import 'dart:convert';

/// Presentación/unidad de medida de un producto.
class PresentacionProducto {
  final String descripcion;
  final String abreviatura;
  final bool esBase;
  final double factor;
  final double precioCompra;
  final double precioVenta;

  const PresentacionProducto({
    required this.descripcion,
    required this.abreviatura,
    required this.esBase,
    required this.factor,
    required this.precioCompra,
    required this.precioVenta,
  });
}

/// Extrae la lista cruda de detalles sin importar cómo la nombre o serialice
/// el API: `detalleProductoMedidas` (relación Eloquent) o
/// `detalle_producto_medidas` (vista de stock, puede llegar como texto JSON).
List<Map> detallesProducto(Map<String, dynamic> p) {
  final raw = p['detalleProductoMedidas'] ?? p['detalle_producto_medidas'];
  if (raw is List) return raw.whereType<Map>().toList();
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.whereType<Map>().toList();
    } catch (_) {
      // Si no es JSON válido, se ignora y se usa la lista vacía.
    }
  }
  return const [];
}

/// Presentaciones del producto listas para mostrar. Soporta el formato de la
/// vista de stock (`unidad_medida`, claves `Detalle_Producto_medida_*`) y el
/// de la relación Eloquent (`unidadMedida`), además del fallback `unidades`
/// que devuelve /inventario/productos-select.
List<PresentacionProducto> presentacionesDeProducto(Map<String, dynamic> p) {
  final out = <PresentacionProducto>[];

  for (final d in detallesProducto(p)) {
    final eliminado =
        '${d['Detalle_Producto_medidaEliminado'] ?? 'N'}'.toUpperCase();
    if (eliminado == 'S') continue;

    final rawUm = d['unidadMedida'] ?? d['unidad_medida'];
    final um = rawUm is Map
        ? Map<String, dynamic>.from(rawUm)
        : <String, dynamic>{};
    var factor = _num(
        d['Detalle_Producto_medida_factor_conversion'] ?? d['factor_conversion']);
    if (factor <= 0) factor = 1;

    out.add(PresentacionProducto(
      descripcion: '${um['unidades_medidaDescripcionUnidades'] ??
          d['descripcion'] ?? 'Unidad'}',
      abreviatura:
          '${um['unidades_medidaAbreviatura'] ?? d['abreviatura'] ?? ''}',
      esBase: _num(um['unidades_medidaEsBase']) == 1 || factor == 1,
      factor: factor,
      precioCompra: _num(
          d['Detalle_Producto_medida_precio_compra'] ?? d['precio_compra']),
      precioVenta: _num(
          d['Detalle_Producto_medida_precio_venta'] ?? d['precio_venta']),
    ));
  }

  if (out.isEmpty) {
    final unis = p['unidades'];
    if (unis is List) {
      for (final u in unis.whereType<Map>()) {
        var factor = _num(u['factor_conversion']);
        if (factor <= 0) factor = 1;
        out.add(PresentacionProducto(
          descripcion: '${u['descripcion'] ?? 'Unidad'}',
          abreviatura: '${u['abreviatura'] ?? ''}',
          esBase: u['es_base'] == true || u['es_base'] == 1,
          factor: factor,
          precioCompra: _num(u['precio_compra']),
          precioVenta: _num(u['precio_venta']),
        ));
      }
    }
  }

  out.sort((a, b) => a.factor.compareTo(b.factor));
  return out;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}
