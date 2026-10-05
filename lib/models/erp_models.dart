// Modelos ERP con NOMBRES REALES del backend-tesis (routes/api.php + modelos).
// Si el backend cambia un campo, cae al fallback sin mostrar "Registro".

class ErpItem {
  final String id;
  final String titulo;
  final String subtitulo;
  final String monto;
  final String estado;
  final double progreso;
  final Map<String, dynamic> raw;

  ErpItem({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.monto,
    required this.estado,
    this.progreso = 0.5,
    this.raw = const {},
  });

  static String _s(dynamic v, [String fb = '—']) {
    if (v == null) return fb;
    if (v is bool) return v ? 'Sí' : 'No';
    final s = v.toString().trim();
    return s.isEmpty ? fb : s;
  }

  static String _estado(String? e) {
    switch (e) {
      case 'A':
        return 'activo';
      case 'I':
        return 'inactivo';
      case 'E':
        return 'emitida';
      case 'P':
        return 'pendiente';
      case 'C':
        return 'completado';
      default:
        return (e == null || e.isEmpty) ? 'activo' : e.toLowerCase();
    }
  }

  // ---------- CATEGORÍAS ----------
  factory ErpItem.fromCategoria(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['Categoria_ProductoId'] ?? j['id'], '0'),
      titulo: _s(j['Categoria_ProductoDescripcion_categoria'],
          'Sin descripción'),
      subtitulo:
          'ID: ${_s(j['Categoria_ProductoId'], '')} • ${_s(j['productos'] is List ? '${(j['productos'] as List).length} productos' : 'Catálogo')}',
      monto: '',
      estado:
          _estado(j['Categoria_ProductoEstado']?.toString()),
      progreso: 0.7,
      raw: j,
    );
  }

  // ---------- CANALES ----------
  factory ErpItem.fromCanal(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['Canal_pedidoId'] ?? j['id'], '0'),
      titulo: _s(j['Canal_pedidoDescripcion'], 'Sin descripción'),
      subtitulo: 'ID: ${_s(j['Canal_pedidoId'], '')} • Canal de pedido',
      monto: '',
      estado: _estado(j['Canal_pedidoEstado']?.toString()),
      progreso: 0.7,
      raw: j,
    );
  }

  // ---------- UBICACIONES ----------
  factory ErpItem.fromUbicacion(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['producto_ubi_id'] ?? j['id'], '0'),
      titulo: _s(j['producto_ubi_descripcion'], 'Sin ubicación'),
      subtitulo: _s(j['producto_ubi_observacion'], 'Zona almacén'),
      monto: '',
      estado: _estado(j['producto_ubi_estado']?.toString()),
      progreso: 0.6,
      raw: j,
    );
  }

  // ---------- UNIDADES ----------
  factory ErpItem.fromUnidad(Map<String, dynamic> j) {
    final abrev = _s(j['unidades_medidaAbreviatura'], '');
    return ErpItem(
      id: _s(j['unidades_medidaId'] ?? j['id'], '0'),
      titulo:
          '${_s(j['unidades_medidaDescripcionUnidades'], 'Unidad')}${abrev != '—' && abrev.isNotEmpty ? ' ($abrev)' : ''}',
      subtitulo: (j['unidades_medidaEsBase'] == true ||
              j['unidades_medidaEsBase'] == 1)
          ? 'Unidad base'
          : 'Presentación',
      monto: abrev == '—' ? '' : abrev,
      estado:
          _estado(j['unidades_medidaEstadoUnidades']?.toString()),
      progreso: 0.6,
      raw: j,
    );
  }

  // ---------- CLIENTES ----------
  factory ErpItem.fromCliente(Map<String, dynamic> j) {
    final compras = j['ClienteComprasCount'];
    final total = j['ClienteTotalMonto'];
    return ErpItem(
      id: _s(j['ClienteId'] ?? j['id'], '0'),
      titulo: _s(j['ClienteNombre'], 'Cliente sin nombre'),
      subtitulo:
          '${_s(j['ClienteRuc'], 'Sin doc.')} • ${_s(j['ClienteDireccion'], 'Sin dirección')}',
      monto: compras != null
          ? '$compras compras${total != null ? ' • S/ $total' : ''}'
          : _s(j['ClienteNumero'], ''),
      estado: _estado(j['ClienteEstado']?.toString()),
      progreso: 0.65,
      raw: j,
    );
  }

  // ---------- PROVEEDORES ----------
  factory ErpItem.fromProveedor(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['ProveedorId'] ?? j['id'], '0'),
      titulo: _s(j['ProveedorRazonSocial'], 'Proveedor sin nombre'),
      subtitulo:
          'RUC ${_s(j['ProveedorRuc'], '—')} • ${_s(j['ProveedorTelefono'], 'Sin tel.')}',
      monto: _s(j['ProveedorActividadEconomica'] ??
          j['ProveedorTipoContribuyente'], ''),
      estado: _estado(j['ProveedorEstado']?.toString()),
      progreso: 0.7,
      raw: j,
    );
  }

  // ---------- PRODUCTOS ----------
  factory ErpItem.fromProducto(Map<String, dynamic> j) {
    final stock = double.tryParse(
            '${j['ProductoStockActual'] ?? j['stock_total_vendible'] ?? 0}') ??
        0;
    final minimo = double.tryParse(
            '${j['ProductoStockMinimo'] ?? 10}') ??
        10;
    final alerta = j['alerta_stock']?.toString() ?? '';
    final precio = j['precio_venta_base_formateado'] ??
        j['precio_venta_base'] ??
        j['Detalle_Producto_medida_precio_venta'];
    final cat = j['categoria_nombre'] ??
        (j['categoria'] is Map
            ? (j['categoria']
                    as Map)['Categoria_ProductoDescripcion_categoria']
            : null) ??
        'General';
    String estado;
    if (alerta == 'AGOTADO' || stock <= 0) {
      estado = 'agotado';
    } else if (alerta == 'STOCK_MINIMO' || stock <= minimo) {
      estado = 'bajo';
    } else {
      estado = _estado(j['ProductoEstado']?.toString());
    }
    final prog =
        minimo <= 0 ? 1.0 : (stock / (minimo * 2)).clamp(0.0, 1.0);
    return ErpItem(
      id: _s(j['ProductoId'] ?? j['id'], '0'),
      titulo: _s(j['ProductoNombre'], 'Producto sin nombre'),
      subtitulo:
          'Stock: ${stock.toStringAsFixed(stock % 1 == 0 ? 0 : 2)} • $cat${j['ProductoMarca'] != null && '${j['ProductoMarca']}'.isNotEmpty ? ' • ${j['ProductoMarca']}' : ''}',
      monto: precio != null ? 'S/ $precio'.replaceAll('S/ S/ ', 'S/ ') : '',
      estado: estado,
      progreso: prog,
      raw: j,
    );
  }

  // ---------- PEDIDOS (PedidoResource) ----------
  factory ErpItem.fromPedido(Map<String, dynamic> j) {
    // Resource usa id/fecha_formateada/total/estado/cliente/canal
    final cli = j['cliente'] is Map
        ? _s((j['cliente'] as Map)['nombre'], '')
        : _s(j['cliente_nombre'], '');
    final fecha = _s(
        j['fecha_formateada'] ?? j['PedidoFecha_pedido'], '');
    return ErpItem(
      id: _s(j['id'] ?? j['PedidoId'], '0'),
      titulo: _s(j['id'] ?? j['codigo'], 'Pedido'),
      subtitulo:
          '${cli.isNotEmpty && cli != '—' ? '$cli • ' : ''}$fecha${j['total_items'] != null ? ' • ${j['total_items']} ítems' : ''}',
      monto: j['total'] != null ? 'S/ ${j['total']}' : '',
      estado: _s(
          j['estado_texto'] ?? j['estado'] ?? j['PedidoEstado_pedido'],
          'pendiente'),
      progreso: 0.5,
      raw: j,
    );
  }

  // ---------- ÓRDENES COMPRA (OrdenCompraResource) ----------
  factory ErpItem.fromOrdenCompra(Map<String, dynamic> j) {
    final prov = j['proveedor'] is Map
        ? _s((j['proveedor'] as Map)['razon_social'], '')
        : _s(j['proveedor_nombre'], '');
    return ErpItem(
      id: _s(j['id'] ?? j['Orden_CompraId'], '0'),
      titulo: _s(j['id'] ?? j['codigo'], 'Orden'),
      subtitulo:
          '${prov.isNotEmpty && prov != '—' ? '$prov • ' : ''}${_s(j['fecha_formateada'] ?? j['fecha'], '')}${j['total_items'] != null ? ' • ${j['total_items']} ítems' : ''}',
      monto: j['total'] != null ? 'S/ ${j['total']}' : '',
      estado: _s(j['estado_texto'] ?? j['estado'], 'pendiente'),
      progreso: 0.5,
      raw: j,
    );
  }

  // ---------- PERSONAL ----------
  factory ErpItem.fromPersonal(Map<String, dynamic> j) {
    final cargo = j['cargo'] is Map
        ? _s((j['cargo'] as Map)['cargoDescripcion'], '')
        : _s(j['cargoNombre'], '');
    return ErpItem(
      id: _s(j['EmpleadoId'] ?? j['id'], '0'),
      titulo:
          '${_s(j['EmpleadoNombres'], '')} ${_s(j['EmpleadoApellidos'], '')}'
              .trim()
              .replaceAll(RegExp(r'\s+—$'), ''),
      subtitulo:
          '${cargo.isNotEmpty && cargo != '—' ? '$cargo • ' : ''}DNI ${_s(j['EmpleadoDni'], '—')}',
      monto: _s(j['EmpleadoCorreo'], ''),
      estado: _estado(j['EmpleadoEstado']?.toString()),
      progreso: 0.6,
      raw: j,
    );
  }

  // ---------- ROLES ----------
  factory ErpItem.fromRol(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['Rol_UserId'] ?? j['id'], '0'),
      titulo: _s(j['Rol_UserRol_Usercol'], 'Rol sin nombre'),
      subtitulo: _s(j['Rol_UserEmpleadocol'],
          '${j['usuarios_count'] ?? ''} usuarios'),
      monto: j['usuarios_count'] != null
          ? '${j['usuarios_count']} usuarios'
          : '',
      estado: 'activo',
      progreso: 0.6,
      raw: j,
    );
  }

  // ---------- CARGOS ----------
  factory ErpItem.fromCargo(Map<String, dynamic> j) {
    return ErpItem(
      id: _s(j['cargoId'] ?? j['id'], '0'),
      titulo: _s(j['cargoDescripcion'], 'Cargo sin nombre'),
      subtitulo: j['empleados_count'] != null
          ? '${j['empleados_count']} empleados'
          : 'Puesto de personal',
      monto: '',
      estado: _estado(j['cargoEstado']?.toString()),
      progreso: 0.6,
      raw: j,
    );
  }

  // ---------- MOVIMIENTOS ----------
  factory ErpItem.fromMovimiento(Map<String, dynamic> j) {
    final tipo = _s(
        j['Movimiento_productoTipoMovimiento'], '');
    final prod = j['producto'] is Map
        ? _s((j['producto'] as Map)['ProductoNombre'], '')
        : _s(j['producto_nombre'], 'Movimiento');
    final cant = _s(
        j['Movimiento_productoCantidadPresentacion'] ??
            j['Movimiento_productoCantidadEntrada'] ??
            j['Movimiento_productoCantidadSalida'],
        '');
    return ErpItem(
      id: _s(j['Movimiento_productoId'] ?? j['id'], '0'),
      titulo:
          '${tipo == 'E' ? 'Entrada' : tipo == 'S' ? 'Salida' : 'Movimiento'} • $prod',
      subtitulo:
          '${_s(j['Movimiento_productoDocumentoOperacionId'], '')} • ${_s(j['Movimiento_productoSubtipo'] ?? j['Movimiento_productoMotivo'], '')}',
      monto: cant.isNotEmpty && cant != '—'
          ? '${tipo == 'S' ? '-' : '+'}$cant'
          : '',
      estado: tipo == 'E' ? 'entrada' : 'salida',
      progreso: 0.5,
      raw: j,
    );
  }

  // ---------- AJUSTES ----------
  factory ErpItem.fromAjuste(Map<String, dynamic> j) {
    final prod = j['producto'] is Map
        ? _s((j['producto'] as Map)['ProductoNombre'], '')
        : '';
    return ErpItem(
      id: _s(j['Ajuste_inventario_id'] ?? j['id'], '0'),
      titulo:
          '${_s(j['Ajuste_inventario_tipo'], 'Ajuste')}${prod.isNotEmpty && prod != '—' ? ' • $prod' : ''}',
      subtitulo:
          '${_s(j['Ajuste_inventario_motivo'], '')} • ${_s(j['Ajuste_inventario_fecha'], '')}',
      monto: j['Ajuste_inventario_cantidad'] != null
          ? '-${j['Ajuste_inventario_cantidad']}'
          : '',
      estado: _s(j['Ajuste_inventario_tipo'], 'ajuste').toLowerCase(),
      progreso: 0.4,
      raw: j,
    );
  }
}
