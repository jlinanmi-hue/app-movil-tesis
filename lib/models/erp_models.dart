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

  /// Limpia y humaniza marcas temporales ISO crudas (evitando .000000Z, T, etc.)
  /// Formato resultante: "19/10/2026 • 15:30" o la fecha limpia correspondiente.
  static String formatDate(dynamic v) {
    if (v == null) return '';
    final s = '$v'.trim();
    if (s.isEmpty || s == '—' || s == 'null') return '';
    try {
      final dt = DateTime.tryParse(s);
      if (dt == null) {
        return s.replaceAll(RegExp(r'\.?0+Z$'), '').replaceAll('T', ' ');
      }
      final local = dt.toLocal();
      final d = local.day.toString().padLeft(2, '0');
      final m = local.month.toString().padLeft(2, '0');
      final y = local.year.toString();
      final h = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '$d/$m/$y • $h:$min';
    } catch (_) {
      return s;
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
    final doc = _s(j['ClienteRuc'] ?? j['ClienteDni'] ?? j['documento'] ?? j['ruc'], '');
    final tel = _s(j['ClienteTelefono'] ?? j['ClienteNumero'] ?? j['telefono'] ?? j['celular'], '');
    final dir = _s(j['ClienteDireccion'] ?? j['direccion'], '');

    final datos = <String>[];
    if (doc.isNotEmpty && doc != '—') datos.add(doc);
    if (tel.isNotEmpty && tel != '—') datos.add('Tel: $tel');
    if (dir.isNotEmpty && dir != '—') datos.add(dir);

    return ErpItem(
      id: _s(j['ClienteId'] ?? j['id'], '0'),
      titulo: _s(j['ClienteNombre'] ?? j['nombre'], 'Cliente sin nombre'),
      subtitulo: datos.isNotEmpty ? datos.join(' • ') : 'Sin datos de contacto',
      monto: '', // Solicitud: nada de compras y soles
      estado: _estado(j['ClienteEstado']?.toString() ?? j['estado']?.toString()),
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
    final fechaRaw = j['fecha_formateada'] ?? j['PedidoFecha_pedido'] ?? j['fecha'] ?? j['created_at'];
    final fecha = formatDate(fechaRaw);
    return ErpItem(
      id: _s(j['id'] ?? j['PedidoId'], '0'),
      titulo: _s(j['id'] ?? j['codigo'], 'Pedido'),
      subtitulo:
          '${cli.isNotEmpty && cli != '—' ? '$cli • ' : ''}$fecha${j['total_items'] != null ? ' • ${j['total_items']} ítems' : ''}',
      monto: j['total'] != null ? 'S/ ${j['total']}'.replaceAll('S/ S/ ', 'S/ ') : '',
      estado: _s(
          j['estado_texto'] ?? j['estado'] ?? j['PedidoEstado_pedido'],
          'pendiente'),
      progreso: 0.5,
      raw: j,
    );
  }

  // ---------- ÓRDENES COMPRA (OrdenCompraResource) ----------
  factory ErpItem.fromOrdenCompra(Map<String, dynamic> j) {
    final provRaw = j['proveedor'];
    String prov = '';
    if (provRaw is Map) {
      prov = _s(provRaw['razon_social'] ?? provRaw['nombre'] ?? provRaw['ProveedorRazonSocial'], '');
    } else if (provRaw != null) {
      prov = _s(provRaw, '');
    }
    if (prov.isEmpty || prov == '—') {
      prov = _s(j['proveedor_nombre'], '');
    }
    final fechaRaw = j['fecha_formateada'] ?? j['fecha'] ?? j['created_at'];
    final fecha = formatDate(fechaRaw);
    return ErpItem(
      id: _s(j['id'] ?? j['Orden_CompraId'], '0'),
      titulo: _s(j['id'] ?? j['codigo'], 'Orden'),
      subtitulo:
          '${prov.isNotEmpty && prov != '—' ? '$prov • ' : ''}$fecha${j['total_items'] != null ? ' • ${j['total_items']} ítems' : ''}',
      monto: j['total'] != null ? 'S/ ${j['total']}'.replaceAll('S/ S/ ', 'S/ ') : '',
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
        : _s(j['producto_nombre'] ?? j['producto'], '');

    String prodNombre = (prod.isEmpty || prod == '—') ? '' : prod;
    if (prodNombre.isEmpty && j['detalles'] is List && (j['detalles'] as List).isNotEmpty) {
      final primerDetalle = (j['detalles'] as List).first;
      if (primerDetalle is Map) {
        prodNombre = _s(primerDetalle['producto_nombre'] ??
            (primerDetalle['producto'] is Map
                ? primerDetalle['producto']['ProductoNombre']
                : null), '');
        if (prodNombre == '—') prodNombre = '';
      }
    }

    final tipoRaw = _s(j['Ajuste_inventario_tipo'] ?? j['tipo'], 'Ajuste');
    final motivo = _s(j['Ajuste_inventario_motivo'] ?? j['motivo'] ?? j['observacion'], '');
    final fechaRaw = j['Ajuste_inventario_fecha'] ?? j['fecha'] ?? j['created_at'];
    final fechaFormateada = formatDate(fechaRaw);
    final cant = j['Ajuste_inventario_cantidad'] ?? j['cantidad'];

    final titulo = prodNombre.isNotEmpty
        ? '$tipoRaw • $prodNombre'
        : tipoRaw;

    final subtituloPartes = <String>[];
    if (motivo.isNotEmpty && motivo != '—') {
      subtituloPartes.add(motivo);
    }
    if (fechaFormateada.isNotEmpty) {
      subtituloPartes.add(fechaFormateada);
    }
    final subtitulo = subtituloPartes.isNotEmpty
        ? subtituloPartes.join(' • ')
        : (fechaFormateada.isNotEmpty ? fechaFormateada : 'Ajuste registrado');

    final monto = cant != null
        ? '${cant.toString().startsWith('-') ? '' : '-'}$cant uds.'
        : '';

    String estado = tipoRaw.toLowerCase();
    if (estado.contains('merma')) {
      estado = 'merma';
    } else if (estado.contains('daño') || estado.contains('dano')) {
      estado = 'daño';
    } else if (estado.contains('físico') || estado.contains('fisico') || estado.contains('anual')) {
      estado = 'conteo';
    } else {
      estado = 'ajuste';
    }

    return ErpItem(
      id: _s(j['Ajuste_inventario_id'] ?? j['id'], '0'),
      titulo: titulo,
      subtitulo: subtitulo,
      monto: monto,
      estado: estado,
      progreso: 0.4,
      raw: j,
    );
  }
}

/// Datos oficiales de SUNAT / RENIEC devueltos por el backend, normalizados
/// para autocompletar los formularios de cliente y proveedor.
class SunatConsulta {
  final String documento;
  final bool esDni;
  final bool desdeCache;
  final String nombre;
  final String direccion;
  final String telefono;
  final String estado; // 'A' activo · 'I' inactivo
  final String estadoTexto; // ACTIVO / INACTIVO
  final String condicion; // HABIDO / NO HABIDO...
  final String tipoContribuyente;
  final String nombreComercial;
  final String actividadEconomica;
  final String departamento;
  final String provincia;
  final String distrito;
  final String ubigeo;

  const SunatConsulta({
    required this.documento,
    required this.esDni,
    required this.desdeCache,
    required this.nombre,
    required this.direccion,
    required this.telefono,
    required this.estado,
    required this.estadoTexto,
    required this.condicion,
    required this.tipoContribuyente,
    required this.nombreComercial,
    required this.actividadEconomica,
    required this.departamento,
    required this.provincia,
    required this.distrito,
    required this.ubigeo,
  });

  bool get activo => estado == 'A';

  /// Ubigeo en formato "Distrito - Provincia - Departamento".
  String get ubicacion => [distrito, provincia, departamento]
      .where((s) => s.isNotEmpty)
      .join(' - ');

  static String _txt(dynamic v) {
    final s = v == null ? '' : '$v'.trim();
    return (s == 'null' || s == 'undefined') ? '' : s;
  }

  static String _pick(List<dynamic> vals) {
    for (final v in vals) {
      final s = _txt(v);
      if (s.isNotEmpty && s != '-' && s != '--') return s;
    }
    return '';
  }

  /// Normaliza el payload interno del endpoint `GET /sunat/ruc/{doc}`.
  /// Soporta las variantes cliente / proveedor / all / DNI-RENIEC y la
  /// ruta servida desde la caché BD del backend.
  factory SunatConsulta.desdePayload(
    Map<String, dynamic> payload,
    String documento,
    String target,
  ) {
    final raw = payload['raw_data'] is Map
        ? Map<String, dynamic>.from(payload['raw_data'] as Map)
        : <String, dynamic>{};
    final inner = target == 'proveedor'
        ? (payload['proveedor'] ?? payload['data'])
        : (payload['cliente'] ?? payload['data']);
    final obj =
        inner is Map ? Map<String, dynamic>.from(inner) : <String, dynamic>{};

    final nombre = _pick([
      obj['ClienteNombre'], obj['ProveedorRazonSocial'],
      payload['razon_social'], raw['razon_social'], raw['nombre'],
      obj['nombre'], //
    ]);
    final direccion = _pick([
      obj['ClienteDireccion'], obj['ProveedorDireccion'], obj['direccion'],
      payload['direccion'], payload['direccion_completa'],
      raw['direccion_fiscal'], raw['direccion'], //
    ]);
    final telefono = _pick([
      obj['ClienteNumero'], obj['ProveedorTelefono'],
      payload['telefono'], raw['telefono'], //
    ]);
    final estadoRaw = _pick([
      obj['ClienteEstado'], obj['ProveedorEstado'],
      payload['estado'], raw['estado'], //
    ]).toUpperCase();
    final estado = (estadoRaw == 'A' || estadoRaw == 'ACTIVO') ? 'A' : 'I';

    String estadoTexto;
    if (estadoRaw == 'ACTIVO' || estadoRaw == 'A') {
      estadoTexto = 'ACTIVO';
    } else if (estadoRaw == 'INACTIVO' || estadoRaw == 'I') {
      estadoTexto = 'INACTIVO';
    } else {
      estadoTexto = estado == 'A' ? 'ACTIVO' : 'INACTIVO';
    }

    return SunatConsulta(
      documento: documento.trim(),
      esDni: documento.trim().length == 8,
      desdeCache: payload['from_db'] == true,
      nombre: nombre,
      direccion: direccion,
      telefono: telefono,
      estado: estado,
      estadoTexto: estadoTexto,
      condicion: _pick([payload['condicion'], raw['condicion']]).toUpperCase(),
      tipoContribuyente: _pick([
        obj['ProveedorTipoContribuyente'], payload['tipo_contribuyente'],
        raw['tipo_contribuyente'], //
      ]),
      nombreComercial: _pick([
        obj['nombre_comercial'], payload['nombre_comercial'],
        raw['nombre_comercial'], //
      ]),
      actividadEconomica: _pick([
        obj['ProveedorActividadEconomica'], payload['actividad_economica'],
        raw['actividad_economica'], //
      ]),
      departamento:
          _pick([obj['departamento'], payload['departamento'], raw['departamento']]),
      provincia: _pick([obj['provincia'], payload['provincia'], raw['provincia']]),
      distrito: _pick([obj['distrito'], payload['distrito'], raw['distrito']]),
      ubigeo: _pick([payload['ubigeo'], raw['ubigeo']]),
    );
  }
}
