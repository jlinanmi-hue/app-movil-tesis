import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';

/// NUEVO PEDIDO DE CLIENTE (proceso completo)
/// 1. Buscar y seleccionar cliente · o marcar "Cliente de venta rápida".
/// 2. Recién con el cliente elegido aparece el buscador de productos.
/// 3. Al elegir producto: presentación + cantidad + check (agregar) / X.
/// 4. Carrito del pedido con totales.
/// 5. Envío a domicilio (por si lo pide el cliente): zona + mapa.
/// 6. Guardar pedido → animación de confirmación "Se realizó tu pedido".
class NuevoPedidoScreen extends StatefulWidget {
  /// Si se indica, la pantalla abre en modo edición: carga el pedido
  /// existente (cliente, productos y envío) listo para guardar cambios.
  final String? pedidoId;

  /// Si se indica, precarga el cliente, productos y condiciones enviados desde Valencia AI.
  final Map<String, dynamic>? prefillData;

  const NuevoPedidoScreen({
    super.key,
    this.pedidoId,
    this.prefillData,
  });

  @override
  State<NuevoPedidoScreen> createState() => _NuevoPedidoScreenState();
}

class _NuevoPedidoScreenState extends State<NuevoPedidoScreen> {
  final _svc = ModulesService();

  // ---- cliente ----
  bool _ventaRapida = false;
  final _cliCtrl = TextEditingController();
  Timer? _cliDebounce;
  bool _buscandoCli = false;
  List<ErpItem> _cliResultados = [];
  Map<String, dynamic>? _cliente;

  // ---- productos ----
  final _prodCtrl = TextEditingController();
  bool _cargandoCatalogo = true;
  List<Map<String, dynamic>> _catalogo = [];
  List<Map<String, dynamic>> _prodResultados = [];
  Map<String, dynamic>? _prodSel;
  Map<String, dynamic>? _unidadSel;
  final _cantCtrl = TextEditingController(text: '1');
  String? _errorLinea;

  // ---- carrito ----
  final List<_LineaPedido> _carrito = [];

  // ---- edición de pedido existente ----
  bool get _esEdicion => widget.pedidoId != null;
  bool _cargandoEdicion = false;
  List<_LineaPedido> _lineasOriginales = [];
  String? _clienteOriginalId;
  String _zonaInicialId = '';

  // ---- tipo de registro / fecha de entrega ----
  /// 'Pedido' (descuenta stock) o 'Cotización' (no descuenta stock).
  String _tipoRegistro = 'Pedido';
  String _tipoRegistroOriginal = 'Pedido';
  DateTime? _fechaEntrega;
  String _fechaEntregaOriginal = ''; // 'yyyy-MM-dd' o ''

  // ---- envío a domicilio ----
  bool _esDelivery = false;
  List<Map<String, dynamic>> _zonas = [];
  Map<String, dynamic>? _zonaSel;
  final _dirCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  LatLng? _punto;
  List<_ZonaMapa> _poligonos = [];

  bool _guardando = false;

  // ---- Valencia Vision (IA 1-Tile) ----
  final _picker = ImagePicker();
  bool _procesandoVision = false;
  String? _tokenAuditoria;
  bool _origenIa = false;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
    _cargarZonas();
    if (_esEdicion) {
      _cargarPedidoEdicion();
    } else if (widget.prefillData != null) {
      _aplicarPrefill(widget.prefillData!);
    }
  }

  void _aplicarPrefill(Map<String, dynamic> prefill) {
    // 1. Cliente
    if (prefill['cliente'] is Map) {
      final cli = Map<String, dynamic>.from(prefill['cliente'] as Map);
      final cliId = '${cli['id'] ?? cli['ClienteId'] ?? 'CLI-00011'}';
      final dir = '${cli['direccion'] ?? cli['ClienteDireccion'] ?? ''}';
      _cliente = {
        'id': cliId,
        'nombre': '${cli['nombre'] ?? cli['ClienteNombre'] ?? 'Cliente General'}',
        'doc': '${cli['dni_ruc'] ?? cli['ClienteRuc'] ?? ''}',
        'direccion': dir == 'null' ? '' : dir,
      };
      _ventaRapida = cliId == 'CLI-00011';
      if (dir.isNotEmpty && dir != 'null') {
        _dirCtrl.text = dir;
      }
    } else if (prefill['cliente_nombre'] != null) {
      final cliId = '${prefill['cliente_id'] ?? 'CLI-00011'}';
      _cliente = {
        'id': cliId,
        'nombre': '${prefill['cliente_nombre']}',
        'doc': '',
        'direccion': '',
      };
      _ventaRapida = cliId == 'CLI-00011';
    }

    // 2. Tipo de registro / acuerdo comercial
    final acuerdo = prefill['acuerdo_comercial']?.toString();
    if (acuerdo != null && acuerdo.toLowerCase().contains('cotizaci')) {
      _tipoRegistro = 'Cotización';
    } else {
      _tipoRegistro = 'Pedido';
    }

    // 3. Productos / detalles
    final prodsRaw = prefill['productos'] ?? prefill['detalles'];
    if (prodsRaw is List) {
      final lineas = <_LineaPedido>[];
      for (final raw in prodsRaw) {
        if (raw is! Map) continue;
        final it = Map<String, dynamic>.from(raw);
        final factor = _num(it['factor_conversion'] ?? it['factor']);
        final cant = _num(it['cantidad']);
        final precio = _num(it['precio_unitario'] ?? it['precio']);
        final desc = it['unidad_descripcion']?.toString() ??
            it['unidad_nombre']?.toString() ??
            it['unidad_abreviatura']?.toString() ??
            it['unidadAbreviatura']?.toString() ??
            'Unidad';

        lineas.add(_LineaPedido(
          productoId: '${it['producto_id'] ?? it['productoId'] ?? ''}',
          nombre: '${it['producto_nombre'] ?? it['productoNombre'] ?? it['nombre'] ?? 'Producto'}',
          unidadId: '${it['unidad_id'] ?? it['unidadMedidaId'] ?? 'UND-00001'}',
          unidadDescripcion: desc,
          factor: factor <= 0 ? 1.0 : factor,
          cantidad: cant <= 0 ? 1.0 : cant,
          precio: precio,
        ));
      }
      _carrito.clear();
      _carrito.addAll(lineas);
    }
  }

  @override
  void dispose() {
    _cliDebounce?.cancel();
    _cliCtrl.dispose();
    _prodCtrl.dispose();
    _cantCtrl.dispose();
    _dirCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    final data = await _svc.productosCatalogo();
    if (!mounted) return;
    setState(() {
      _catalogo = data;
      _cargandoCatalogo = false;
    });
  }

  Future<void> _cargarZonas() async {
    final zs = await _svc.zonasDeliveryActivas();
    final polys = <_ZonaMapa>[];
    for (final z in zs) {
      final anillos = _parseGeoJson(
          z['Zona_DeliveryPoligonoGeoJSON'] ?? z['poligono']);
      if (anillos.isNotEmpty) {
        polys.add(_ZonaMapa(
            id: '${z['Zona_DeliveryId']}', anillos: anillos));
      }
    }
    if (!mounted) return;
    setState(() {
      _zonas = zs;
      _poligonos = polys;
      // En edición, resolvemos la zona del pedido cuando llegan las zonas.
      if (_esEdicion && _zonaInicialId.isNotEmpty && _zonaSel == null) {
        _zonaSel = _buscarZona(_zonaInicialId);
      }
    });
  }

  Map<String, dynamic>? _buscarZona(String id) {
    if (id.isEmpty || id == 'null') return null;
    for (final z in _zonas) {
      if ('${z['Zona_DeliveryId']}' == id) return z;
    }
    return null;
  }

  /// Modo edición: carga el pedido existente y llena cliente, carrito,
  /// delivery y punto del mapa tal como quedaría listo para guardar.
  Future<void> _cargarPedidoEdicion() async {
    setState(() => _cargandoEdicion = true);
    try {
      final d = await _svc.pedidoDetalle(widget.pedidoId!);
      if (!mounted) return;

      final cli = d['cliente'] is Map
          ? Map<String, dynamic>.from(d['cliente'] as Map)
          : <String, dynamic>{};
      final detalles = d['detalles'] is List
          ? (d['detalles'] as List)
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
          : <Map<String, dynamic>>[];

      final lineas = <_LineaPedido>[];
      for (final it in detalles) {
        final factor = _num(it['factor_conversion']);
        lineas.add(_LineaPedido(
          productoId: '${it['producto_id']}',
          nombre: '${it['producto_nombre'] ?? 'Producto'}',
          unidadId: '${it['unidad_id']}',
          unidadDescripcion: '${it['unidad_nombre'] ?? 'Unidad'}',
          factor: factor <= 0 ? 1 : factor,
          cantidad: _num(it['cantidad']),
          precio: _num(it['precio_unitario']),
        ));
      }

      final cliId = '${cli['id'] ?? d['cliente_id'] ?? ''}';
      final cliDir = '${cli['direccion'] ?? ''}';
      final esDel = d['es_delivery'] == true ||
          '${d['es_delivery'] ?? ''}'.toUpperCase() == 'S';
      final dirEntrega = '${d['direccion_entrega'] ?? ''}';
      final refEntrega = '${d['referencia_entrega'] ?? ''}';
      final lat = d['latitud_entrega'];
      final lng = d['longitud_entrega'];
      final zonaId = '${d['zona_delivery_id'] ?? ''}';

      // Tipo de registro (Pedido / Cotización) y fecha de entrega.
      final tipoRaw = '${d['tipo_registro'] ?? 'Pedido'}';
      final tipo = tipoRaw == 'Cotización' ? 'Cotización' : 'Pedido';
      final fechaRaw = '${d['fecha_entrega'] ?? ''}';
      final fechaIso =
          (fechaRaw.isEmpty || fechaRaw == 'null') ? '' : fechaRaw;

      setState(() {
        if (cliId.isNotEmpty && cliId != 'null') {
          _cliente = {
            'id': cliId,
            'nombre': '${cli['nombre'] ?? 'Cliente'}',
            'doc': '${cli['dni_ruc'] ?? ''}',
            'direccion': cliDir == 'null' ? '' : cliDir,
          };
          _ventaRapida = cliId == 'CLI-00011';
        }
        _clienteOriginalId = cliId.isEmpty || cliId == 'null' ? null : cliId;

        _carrito
          ..clear()
          ..addAll(lineas);
        _lineasOriginales = lineas
            .map((l) => _LineaPedido(
                  productoId: l.productoId,
                  nombre: l.nombre,
                  unidadId: l.unidadId,
                  unidadDescripcion: l.unidadDescripcion,
                  factor: l.factor,
                  cantidad: l.cantidad,
                  precio: l.precio,
                ))
            .toList();

        _esDelivery = esDel;
        _dirCtrl.text = dirEntrega == 'null' ? '' : dirEntrega;
        _refCtrl.text = refEntrega == 'null' ? '' : refEntrega;
        if (lat is num && lng is num) {
          _punto = LatLng(lat.toDouble(), lng.toDouble());
        }
        _zonaInicialId = zonaId == 'null' ? '' : zonaId;
        _zonaSel = _buscarZona(_zonaInicialId) ?? _zonaSel;

        _tipoRegistro = tipo;
        _tipoRegistroOriginal = tipo;
        _fechaEntregaOriginal = fechaIso;
        _fechaEntrega = DateTime.tryParse(fechaIso);

        _cargandoEdicion = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargandoEdicion = false);
      _snack(context, '$e');
      Navigator.of(context).maybePop();
    }
  }

  // ================= CLIENTE =================

  void _onCliQuery(String q) {
    _cliDebounce?.cancel();
    final t = q.trim();
    if (t.isEmpty) {
      setState(() => _cliResultados = []);
      return;
    }
    _cliDebounce =
        Timer(const Duration(milliseconds: 300), () => _buscarClientes(t));
  }

  Future<void> _buscarClientes(String q) async {
    setState(() => _buscandoCli = true);
    final r = await _svc.clientes(search: q);
    if (!mounted) return;
    setState(() {
      _cliResultados = r.take(6).toList();
      _buscandoCli = false;
    });
  }

  void _seleccionarCliente(ErpItem e) {
    final raw = e.raw;
    final dir = '${raw['ClienteDireccion'] ?? ''}';
    setState(() {
      _cliente = {
        'id': e.id,
        'nombre': e.titulo,
        'doc': '${raw['ClienteRuc'] ?? raw['ClienteNumero'] ?? ''}',
        'direccion': dir == 'null' ? '' : dir,
      };
      _ventaRapida = false;
      _cliResultados = [];
      _cliCtrl.clear();
    });
    if (_dirCtrl.text.trim().isEmpty && dir.isNotEmpty && dir != 'null') {
      _dirCtrl.text = dir;
    }
    FocusScope.of(context).unfocus();
  }

  void _toggleVentaRapida(bool v) {
    setState(() {
      _ventaRapida = v;
      if (v) {
        _cliente = {
          'id': 'CLI-00011',
          'nombre': 'Cliente de venta rápida',
          'doc': '',
          'direccion': '',
        };
        _cliResultados = [];
        _cliCtrl.clear();
      } else {
        _cliente = null;
      }
    });
  }

  void _limpiarCliente() {
    setState(() {
      _cliente = null;
      _ventaRapida = false;
      _cliResultados = [];
    });
  }

  // ================= PRODUCTOS =================

  void _onProdQuery(String q) {
    final t = q.trim().toLowerCase();
    setState(() {
      _prodSel = null;
      _unidadSel = null;
      _errorLinea = null;
      if (t.isEmpty) {
        _prodResultados = [];
        return;
      }
      _prodResultados = _catalogo.where((p) {
        final nom = '${p['ProductoNombre'] ?? ''}'.toLowerCase();
        final marca = '${p['ProductoMarca'] ?? ''}'.toLowerCase();
        final cat = '${p['categoria_nombre'] ?? ''}'.toLowerCase();
        final cod = '${p['ProductoCodigo'] ?? p['id'] ?? ''}'.toLowerCase();
        return nom.contains(t) || marca.contains(t) || cat.contains(t) || cod.contains(t);
      }).take(8).toList();
    });
  }

  void _seleccionarProducto(Map<String, dynamic> p) {
    final unis = (p['unidades'] is List)
        ? (p['unidades'] as List).whereType<Map>().toList()
        : <Map>[];
    Map<String, dynamic>? base;
    for (final u in unis) {
      if (u['es_base'] == true || u['es_base'] == 1) {
        base = Map<String, dynamic>.from(u);
        break;
      }
    }
    base ??= unis.isNotEmpty ? Map<String, dynamic>.from(unis.first) : null;
    setState(() {
      _prodSel = p;
      _unidadSel = base;
      _cantCtrl.text = '1';
      _errorLinea = null;
    });
  }

  double _disponibleDe(Map<String, dynamic> p, Map<String, dynamic>? u) {
    final stock = _num(p['ProductoStockActual']);
    final factor = u == null ? 1.0 : _num(u['factor_conversion']);
    var disp = factor <= 1 ? stock : (stock / factor).floorToDouble();
    // En edición, si el pedido ya reservó stock al crearse (tipo Pedido), al
    // recalcular sus líneas esa reserva vuelve a estar disponible (el backend
    // primero devuelve el stock de las líneas eliminadas y luego descuenta
    // las nuevas). En Cotización no hubo reserva.
    if (_esEdicion && _tipoRegistroOriginal == 'Pedido') {
      final pid = '${p['ProductoId']}';
      var reservaBase = 0.0;
      for (final o in _lineasOriginales) {
        if (o.productoId == pid) reservaBase += o.cantidad * o.factor;
      }
      if (reservaBase > 0) {
        disp += factor <= 1
            ? reservaBase
            : (reservaBase / factor).floorToDouble();
      }
    }
    return disp;
  }

  void _agregarLinea() {
    final p = _prodSel;
    final u = _unidadSel;
    if (p == null || u == null) return;

    final pid = '${p['ProductoId']}';
    final uid = '${u['unidades_medidaId']}';
    final abrev = '${u['abreviatura'] ?? ''}';
    final cant = _num(_cantCtrl.text);
    var factor = _num(u['factor_conversion']);
    if (factor <= 0) factor = 1;
    final disponible = _disponibleDe(p, u);

    if (cant <= 0) {
      setState(() => _errorLinea = 'Ingresa una cantidad válida.');
      return;
    }

    final idx =
        _carrito.indexWhere((l) => l.productoId == pid && l.unidadId == uid);
    final enCarrito = idx >= 0 ? _carrito[idx].cantidad : 0.0;
    // La cotización NO descuenta stock: se puede cotizar más de lo disponible.
    if (_tipoRegistro != 'Cotización' && cant + enCarrito > disponible) {
      setState(() => _errorLinea =
          'Supera el stock disponible (${_fmt(disponible)}${abrev.isNotEmpty ? ' $abrev' : ''}).');
      return;
    }

    setState(() {
      if (idx >= 0) {
        _carrito[idx].cantidad += cant;
      } else {
        _carrito.add(_LineaPedido(
          productoId: pid,
          nombre: '${p['ProductoNombre'] ?? 'Producto'}',
          unidadId: uid,
          unidadDescripcion: '${u['descripcion'] ?? 'Unidad'}',
          factor: factor,
          cantidad: cant,
          precio: _num(u['precio_venta']),
        ));
      }
      _prodSel = null;
      _unidadSel = null;
      _errorLinea = null;
      _cantCtrl.text = '1';
      _prodCtrl.clear();
      _prodResultados = [];
    });
  }

  // ================= TOTALES =================

  double get _subtotal =>
      _carrito.fold(0.0, (a, l) => a + l.subtotal);
  double get _igv => _subtotal * 0.18;
  double get _envio => _esDelivery && _zonaSel != null
      ? _num(_zonaSel!['Zona_DeliveryTarifa'])
      : 0;
  double get _total => _subtotal + _igv + _envio;

  // ================= GUARDAR =================

  Future<void> _guardar() async {
    if (_cliente == null) {
      _snack(context, 'Selecciona al cliente.');
      return;
    }
    if (_carrito.isEmpty) {
      _snack(context, 'Agrega al menos un producto.');
      return;
    }
    if (_esDelivery) {
      if (_subtotal < 100) {
        _snack(context,
            'El envío a domicilio requiere un mínimo de S/ 100.00 en productos.');
        return;
      }
      if (_zonaSel == null) {
        _snack(context, 'Selecciona la zona de entrega.');
        return;
      }
      if (_dirCtrl.text.trim().isEmpty) {
        _snack(context, 'Ingresa la dirección de entrega.');
        return;
      }
    }

    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        await _guardarEdicion();
        return;
      }

      final payload = <String, dynamic>{
        'cliente_id': _cliente!['id'],
        'canal_id': 'CNL-00001',
        'acuerdo_comercial': _tipoRegistro,
        'origen_ia': _origenIa ? 'S' : 'N',
        if (_tokenAuditoria != null) 'token_auditoria': _tokenAuditoria,
        if (_fechaEntrega != null) 'fecha_entrega': _fechaIso(_fechaEntrega!),
        'es_delivery': _esDelivery ? 'S' : 'N',
        if (_esDelivery) 'zona_delivery_id': _zonaSel!['Zona_DeliveryId'],
        if (_esDelivery) 'direccion_entrega': _dirCtrl.text.trim(),
        if (_esDelivery && _refCtrl.text.trim().isNotEmpty)
          'referencia_entrega': _refCtrl.text.trim(),
        if (_esDelivery && _punto != null) 'latitud': _punto!.latitude,
        if (_esDelivery && _punto != null) 'longitud': _punto!.longitude,
        'detalles': _carrito
            .map((l) => {
                  'producto_id': l.productoId,
                  'cantidad': l.cantidad,
                  'precio_unitario': l.precio,
                  'unidad_id': l.unidadId,
                  'factor_conversion': l.factor,
                })
            .toList(),
      };

      final res = await _svc.crearPedidoProceso(payload);
      if (!mounted) return;

      final data = res['data'];
      final pedidoId = data is Map
          ? '${data['PedidoId'] ?? data['id'] ?? ''}'
          : '';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoExito(pedidoId: pedidoId),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _snack(context, '$e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Guarda los cambios del pedido en edición: envía al backend solo las
  /// diferencias (acciones agregar/eliminar) más cliente, tipo de registro,
  /// fecha de entrega y datos de envío.
  Future<void> _guardarEdicion() async {
    final acciones = _accionesEdicion();
    final fechaActual = _fechaEntrega == null ? '' : _fechaIso(_fechaEntrega!);
    final payload = <String, dynamic>{
      if ('${_cliente!['id']}' != (_clienteOriginalId ?? ''))
        'cliente_id': '${_cliente!['id']}',
      if (_tipoRegistro != _tipoRegistroOriginal)
        'acuerdo_comercial': _tipoRegistro,
      if (fechaActual != _fechaEntregaOriginal)
        'fecha_entrega': _fechaEntrega == null ? null : fechaActual,
      'es_delivery': _esDelivery ? 'S' : 'N',
      if (_esDelivery) 'zona_delivery_id': _zonaSel!['Zona_DeliveryId'],
      if (_esDelivery) 'direccion_entrega': _dirCtrl.text.trim(),
      if (_esDelivery && _refCtrl.text.trim().isNotEmpty)
        'referencia_entrega': _refCtrl.text.trim(),
      if (_esDelivery && _punto != null) 'latitud': _punto!.latitude,
      if (_esDelivery && _punto != null) 'longitud': _punto!.longitude,
      if (acciones.isNotEmpty) 'acciones': acciones,
      'motivo_correccion': 'Edición de pedido desde la app móvil',
    };

    final res = await _svc.actualizarPedidoProceso(widget.pedidoId!, payload);
    if (!mounted) return;

    final data = res['data'];
    final id = data is Map
        ? '${data['id'] ?? data['PedidoId'] ?? widget.pedidoId}'
        : widget.pedidoId!;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoExito(pedidoId: id, edicion: true),
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  /// Diferencias entre las líneas originales y el carrito actual: por
  /// producto, si cambió algo se elimina y se vuelve a agregar con las
  /// líneas nuevas (el backend devuelve stock al eliminar y lo vuelve a
  /// descontar al agregar).
  List<Map<String, dynamic>> _accionesEdicion() {
    bool mismo(double a, double b) => (a - b).abs() < 0.0001;

    Map<String, List<_LineaPedido>> agrupar(Iterable<_LineaPedido> ls) {
      final m = <String, List<_LineaPedido>>{};
      for (final l in ls) {
        m.putIfAbsent(l.productoId, () => []).add(l);
      }
      return m;
    }

    final originales = agrupar(_lineasOriginales);
    final nuevos = agrupar(_carrito);
    final acciones = <Map<String, dynamic>>[];

    for (final pid in originales.keys) {
      final orig = originales[pid]!;
      final act = nuevos[pid];
      if (act == null || act.isEmpty) {
        acciones.add({'tipo': 'eliminar', 'producto_id': pid});
        continue;
      }
      final sinCambios = orig.length == act.length &&
          orig.every((o) => act.any((n) =>
              n.unidadId == o.unidadId && mismo(n.cantidad, o.cantidad)));
      if (sinCambios) continue;
      acciones.add({'tipo': 'eliminar', 'producto_id': pid});
      for (final n in act) {
        acciones.add(_accionAgregar(n));
      }
    }

    for (final pid in nuevos.keys) {
      if (originales.containsKey(pid)) continue;
      for (final n in nuevos[pid]!) {
        acciones.add(_accionAgregar(n));
      }
    }
    return acciones;
  }

  Map<String, dynamic> _accionAgregar(_LineaPedido l) => {
        'tipo': 'agregar',
        'producto_id': l.productoId,
        'cantidad': l.cantidad,
        'unidad_id': l.unidadId,
        'factor_conversion': l.factor,
        'precio_unitario': l.precio,
      };

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // ÚNICA cabecera de la pantalla (estilo del hub).
          ErpHeader(
            title: _esEdicion ? 'Editar Pedido' : 'Nuevo Pedido',
            subtitle: _esEdicion
                ? '${widget.pedidoId} · ajusta y guarda'
                : 'Cliente · productos · envío',
          ),
          Expanded(
            child: _cargandoEdicion
                ? Center(
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: AppColors.celesteDark)),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                    children: [
                      _seccionCliente(),
                      _seccionProductos(),
                      _seccionPedido(),
                      _seccionEnvio(),
                      const SizedBox(height: 2),
                      _botonGuardar(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required Widget child,
    Widget? accion,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ErpSoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ErpIconTile(icon: icono, size: 32, radius: 11),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.2)),
                ),
                ?accion,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint, {Widget? prefix, Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
        prefixIcon: prefix,
        suffixIcon: suffix,
        isDense: true,
        filled: true,
        fillColor: AppColors.celesteTint.withValues(alpha: .55),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderSoft)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: AppColors.borderSoft)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide:
                BorderSide(color: AppColors.celeste, width: 1.4)),
      );

  // ---------------- 1. cliente ----------------

  Widget _seccionCliente() {
    return _seccion(
      titulo: 'Cliente',
      icono: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ErpCheck(
                value: _ventaRapida,
                onChanged: () => _toggleVentaRapida(!_ventaRapida),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Cliente de venta rápida',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_cliente != null)
            _tileCliente()
          else ...[
            ErpSearchField(
              controller: _cliCtrl,
              hint: 'Buscar cliente por nombre, RUC o DNI...',
              onChanged: _onCliQuery,
            ),
            if (_buscandoCli)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.celesteDark)),
                ),
              ),
            for (final e in _cliResultados) _filaClienteResultado(e),
          ],
        ],
      ),
    );
  }

  Widget _tileCliente() {
    final nombre = '${_cliente!['nombre']}';
    final doc = '${_cliente!['doc'] ?? ''}';
    final dir = '${_cliente!['direccion'] ?? ''}';
    var sub = [
      if (doc.isNotEmpty && doc != 'null') doc,
      if (dir.isNotEmpty && dir != 'null') dir,
    ].join(' · ');
    if (sub.isEmpty) {
      sub = _ventaRapida ? 'Venta directa en mostrador' : '';
    }
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(
              _ventaRapida
                  ? Icons.bolt_rounded
                  : Icons.person_rounded,
              color: AppColors.celesteDark,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                if (sub.isNotEmpty)
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          InkWell(
            onTap: _limpiarCliente,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.celesteBg)),
              child: Icon(Icons.close_rounded,
                  size: 16, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaClienteResultado(ErpItem e) {
    return InkWell(
      onTap: () => _seleccionarCliente(e),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const ErpIconTile(
                icon: Icons.person_outline_rounded, size: 32, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  if (e.subtitulo.isNotEmpty)
                    Text(e.subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.celesteDark),
          ],
        ),
      ),
    );
  }

  // ---------------- 2. productos ----------------

  Widget _seccionProductos() {
    if (_cliente == null) {
      return _seccion(
        titulo: 'Productos',
        icono: Icons.shopping_bag_outlined,
        accion: _botonEscanearLista(deshabilitado: true),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 15, color: AppColors.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Selecciona un cliente para buscar productos o escanear lista con IA.',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    }

    return _seccion(
      titulo: 'Productos',
      icono: Icons.shopping_bag_outlined,
      accion: _botonEscanearLista(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSearchField(
            controller: _prodCtrl,
            hint: _cargandoCatalogo
                ? 'Cargando catálogo...'
                : 'Buscar producto...',
            onChanged: _onProdQuery,
          ),
          if (_prodSel != null) ...[
            const SizedBox(height: 10),
            _editorLinea(),
          ] else ...[
            for (final p in _prodResultados) _filaProductoResultado(p),
            if (!_cargandoCatalogo &&
                _catalogo.isEmpty &&
                _prodCtrl.text.trim().isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                    'No se pudo cargar el catálogo. Revisa la conexión.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ),
            if (_prodCtrl.text.trim().isNotEmpty &&
                _prodResultados.isEmpty &&
                !_cargandoCatalogo)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Sin resultados para tu búsqueda.',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ),
          ],
        ],
      ),
    );
  }

  // =========================================================================
  // VALENCIA VISION (Gemini 1.5 Flash 1-Tile)
  // =========================================================================

  Widget _botonEscanearLista({bool deshabilitado = false}) {
    if (_procesandoVision) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
            ),
            SizedBox(width: 6),
            Text(
              'Leyendo...',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: deshabilitado
          ? () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Por favor, selecciona un cliente primero antes de escanear la lista.'),
                  duration: Duration(seconds: 2),
                ),
              );
            }
          : _mostrarOpcionesCapturaVision,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: deshabilitado
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : [const Color(0xFF2563EB), const Color(0xFF4F46E5)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: deshabilitado
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_rounded, size: 13, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'Escanear IA',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpcionesCapturaVision() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF2563EB), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Escanear Lista de Pedido',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Gemini 1.5 Flash Vision (1-Tile)',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF2563EB)),
                  ),
                  title: const Text('Tomar foto con la cámara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Fotografía una lista manuscrita o impresa', style: TextStyle(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _tomarFotoLista(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF4F46E5)),
                  ),
                  title: const Text('Seleccionar de la galería', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Sube una captura o imagen existente', style: TextStyle(fontSize: 11.5)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _tomarFotoLista(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _tomarFotoLista(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 80,
      );
      if (xfile == null) return;

      setState(() => _procesandoVision = true);

      final bytes = await xfile.readAsBytes();
      final base64Img = base64Encode(bytes);

      final data = await _svc.procesarPedidoVision(
        base64Image: base64Img,
        mimeType: 'image/jpeg',
      );

      if (!mounted) return;
      setState(() => _procesandoVision = false);

      final token = data['token_auditoria']?.toString();
      final items = (data['items'] as List?) ?? [];

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se detectaron productos en la imagen.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      _mostrarDialogoConfirmacionVision(items, token);
    } catch (e) {
      if (!mounted) return;
      setState(() => _procesandoVision = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _mostrarDialogoConfirmacionVision(List<dynamic> items, String? token) {
    final list = List<Map<String, dynamic>>.from(
      items.map((e) => Map<String, dynamic>.from(e as Map)),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final validos = list.where((it) => it['producto_id'] != null).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.document_scanner_rounded, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Productos Detectados por IA',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${validos.length} emparejados con tu catálogo',
                              style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (_, idx) {
                        final it = list[idx];
                        final matched = it['producto_id'] != null;
                        final cant = _num(it['cantidad_detectada']) <= 0 ? 1.0 : _num(it['cantidad_detectada']);
                        final badge = '${it['match_badge'] ?? 'verde'}';
                        final badgeColor = badge == 'verde'
                            ? const Color(0xFF16A34A)
                            : (badge == 'ambar' ? const Color(0xFFD97706) : Colors.grey);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${it['producto_nombre'] ?? it['nombre_buscado'] ?? 'Producto'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: matched ? AppColors.textDark : Colors.grey,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                        ),
                                        child: Text(
                                          badge == 'verde' ? 'Exacto' : 'Sugerido',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: badgeColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${it['presentacion_nombre'] ?? 'Unidad'} · S/ ${_fmt(_num(it['precio_unitario']))} c/u',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Stepper de cantidad
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  InkWell(
                                    onTap: () {
                                      if (cant > 1) {
                                        setModalState(() {
                                          it['cantidad_detectada'] = cant - 1;
                                        });
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.remove, size: 14, color: Colors.black87),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                    child: Text(
                                      _fmt(cant),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () {
                                      setModalState(() {
                                        it['cantidad_detectada'] = cant + 1;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.all(6),
                                      child: Icon(Icons.add, size: 14, color: Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                              onPressed: () {
                                setModalState(() {
                                  list.removeAt(idx);
                                });
                              },
                              tooltip: 'Descartar ítem',
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: validos.isEmpty
                          ? null
                          : () {
                              for (final it in validos) {
                                final pid = '${it['producto_id']}';
                                final nombre = '${it['producto_nombre'] ?? 'Producto'}';
                                final uid = '${it['presentacion_id'] ?? 'UND-00001'}';
                                final udesc = '${it['presentacion_nombre'] ?? 'Unidad'}';
                                final factor = _num(it['presentacion_factor']) <= 0 ? 1.0 : _num(it['presentacion_factor']);
                                final cant = _num(it['cantidad_detectada']) <= 0 ? 1.0 : _num(it['cantidad_detectada']);
                                final precio = _num(it['precio_unitario']);

                                final idx = _carrito.indexWhere((l) => l.productoId == pid && l.unidadId == uid);
                                if (idx >= 0) {
                                  _carrito[idx].cantidad = cant;
                                } else {
                                  _carrito.add(_LineaPedido(
                                    productoId: pid,
                                    nombre: nombre,
                                    unidadId: uid,
                                    unidadDescripcion: udesc,
                                    factor: factor,
                                    cantidad: cant,
                                    precio: precio,
                                    sugeridoIa: true,
                                  ));
                                }
                              }
                              setState(() {
                                _tokenAuditoria = token;
                                _origenIa = true;
                              });
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Se precargaron ${validos.length} productos detectados por IA.'),
                                  backgroundColor: const Color(0xFF16A34A),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: Text(
                        'Precargar en Pedido (${validos.length} productos)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _filaProductoResultado(Map<String, dynamic> p) {
    final nombre = '${p['ProductoNombre'] ?? 'Producto'}';
    final marca = '${p['ProductoMarca'] ?? ''}';
    final categoria = '${p['categoria_nombre'] ?? ''}';
    final sub = [
      if (marca.isNotEmpty && marca != 'null') marca,
      if (categoria.isNotEmpty && categoria != 'null') categoria,
    ].join(' · ');
    final stock = _num(p['ProductoStockActual']);
    final abrev = '${p['unidad_base'] ?? ''}';

    return InkWell(
      onTap: () => _seleccionarProducto(p),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const ErpIconTile(
                icon: Icons.inventory_2_outlined, size: 32, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark)),
                  if (sub.isNotEmpty)
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: stock <= 0
                      ? AppColors.errorBg
                      : AppColors.celesteTint,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  stock <= 0
                      ? 'Agotado'
                      : '${_fmt(stock)}${abrev.isNotEmpty ? ' $abrev' : ''}',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: stock <= 0
                          ? AppColors.errorDark
                          : AppColors.celesteDeep)),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.celesteDark),
          ],
        ),
      ),
    );
  }

  Widget _editorLinea() {
    final p = _prodSel!;
    final unis = (p['unidades'] is List)
        ? (p['unidades'] as List).whereType<Map>().toList()
        : <Map>[];
    final unidadId = '${_unidadSel?['unidades_medidaId'] ?? ''}';
    final abrev = '${_unidadSel?['abreviatura'] ?? ''}';
    final disponible = _disponibleDe(p, _unidadSel);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.celesteTint.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.celeste),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${p['ProductoNombre'] ?? 'Producto'}',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          const SizedBox(height: 8),
          ErpDropdownField<String>(
            label: 'Presentación',
            hint: 'Elegir presentación',
            icon: Icons.straighten_rounded,
            value: unidadId.isEmpty ? null : unidadId,
            options: [
              for (final u in unis)
                ErpDropdownOption(
                  value: '${u['unidades_medidaId']}',
                  label: '${u['descripcion']}',
                  subtitle:
                      '${u['precio_venta_formateado'] ?? 'S/ ${_fmt(_num(u['precio_venta']))}'}',
                ),
            ],
            onChanged: (v) {
              Map<String, dynamic>? nueva;
              for (final u in unis) {
                if ('${u['unidades_medidaId']}' == v) {
                  nueva = Map<String, dynamic>.from(u);
                  break;
                }
              }
              setState(() {
                _unidadSel = nueva ?? _unidadSel;
                _errorLinea = null;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cantCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  onChanged: (_) =>
                      setState(() => _errorLinea = null),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark),
                  decoration: _deco('Cantidad'),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Disponible',
                      style: TextStyle(
                          fontSize: 9.5, color: AppColors.textMuted)),
                  Text(
                      '${_fmt(disponible)}${abrev.isNotEmpty ? ' $abrev' : ''}',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: disponible <= 0
                              ? AppColors.errorDark
                              : AppColors.celesteDeep)),
                ],
              ),
            ],
          ),
          if (_errorLinea != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 13, color: AppColors.errorDark),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(_errorLinea!,
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.errorDark)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ErpPrimaryButton(
                  label: 'Agregar',
                  icon: Icons.check_rounded,
                  onTap: _agregarLinea,
                ),
              ),
              const SizedBox(width: 8),
              ErpCircleButton(
                icon: Icons.close_rounded,
                size: 50,
                tooltip: 'Descartar',
                onTap: () => setState(() {
                  _prodSel = null;
                  _unidadSel = null;
                  _errorLinea = null;
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------- 3. pedido (carrito) ----------------

  Widget _seccionPedido() {
    return _seccion(
      titulo: 'Pedido',
      icono: Icons.receipt_long_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ErpChoicePill(
                label: 'Pedido',
                icon: Icons.shopping_cart_outlined,
                selected: _tipoRegistro == 'Pedido',
                onTap: () => setState(() => _tipoRegistro = 'Pedido'),
              ),
              const SizedBox(width: 8),
              ErpChoicePill(
                label: 'Cotización',
                icon: Icons.description_outlined,
                selected: _tipoRegistro == 'Cotización',
                onTap: () => setState(() => _tipoRegistro = 'Cotización'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              _tipoRegistro == 'Cotización'
                  ? 'Cotización: no descuenta stock.'
                  : 'Pedido: descuenta stock al guardar.',
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          ErpDateField(
            label: 'Fecha de entrega',
            emptyLabel: 'Sin fecha',
            value: _fechaEntrega,
            minima: DateTime.now(),
            onPick: (d) => setState(() => _fechaEntrega = d),
          ),
          const SizedBox(height: 12),
          if (_carrito.isEmpty)
            Text(
                _tipoRegistro == 'Cotización'
                    ? 'Agrega productos para armar la cotización.'
                    : 'Agrega productos para armar el pedido.',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textMuted))
          else ...[
            for (final l in _carrito) _lineaCarrito(l),
            Divider(height: 22, color: AppColors.celesteBg),
            _filaTotal('Subtotal', _subtotal),
            _filaTotal('IGV (18%)', _igv),
            if (_esDelivery) _filaTotal('Envío', _envio),
            const SizedBox(height: 4),
            _filaTotal('Total', _total, fuerte: true),
          ],
        ],
      ),
    );
  }

  Widget _lineaCarrito(_LineaPedido l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(l.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                              height: 1.15)),
                    ),
                    if (l.sugeridoIa) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 9, color: Color(0xFF2563EB)),
                            SizedBox(width: 2),
                            Text('IA', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                    '${l.unidadDescripcion} × ${_fmt(l.cantidad)} · S/ ${_fmt(l.precio)} c/u',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text('S/ ${_fmt(l.subtotal)}',
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.celesteDeep)),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => setState(() => _carrito.remove(l)),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.celesteBg)),
              child: Icon(Icons.close_rounded,
                  size: 14, color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaTotal(String label, double monto, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: fuerte ? 13.5 : 12,
                    fontWeight:
                        fuerte ? FontWeight.w800 : FontWeight.w600,
                    color: fuerte
                        ? AppColors.textDark
                        : AppColors.textMuted)),
          ),
          Text('S/ ${_fmt(monto)}',
              style: TextStyle(
                  fontSize: fuerte ? 15 : 12.5,
                  fontWeight: FontWeight.w800,
                  color: fuerte
                      ? AppColors.celesteDeep
                      : AppColors.textDark)),
        ],
      ),
    );
  }

  // ---------------- 4. envío a domicilio ----------------

  Widget _seccionEnvio() {
    return _seccion(
      titulo: 'Envío',
      icono: Icons.delivery_dining_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ErpCheck(
                value: _esDelivery,
                onChanged: () =>
                    setState(() => _esDelivery = !_esDelivery),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Envío a domicilio',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ),
            ],
          ),
          if (_esDelivery) ...[
            const SizedBox(height: 10),
            if (_subtotal < 100)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                    color: AppColors.warningBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warningBorder)),
                child: Text(
                    'El delivery requiere un mínimo de S/ 100.00 en productos.',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.warningDark)),
              ),
            const SizedBox(height: 10),
            ErpDropdownField<String>(
              label: 'Zona de entrega',
              hint: 'Seleccionar zona',
              icon: Icons.map_outlined,
              value: _zonaSel == null
                  ? null
                  : '${_zonaSel!['Zona_DeliveryId']}',
              options: [
                for (final z in _zonas)
                  ErpDropdownOption(
                    value: '${z['Zona_DeliveryId']}',
                    label: '${z['Zona_DeliveryNombre']}',
                    subtitle:
                        'Envío: S/ ${_fmt(_num(z['Zona_DeliveryTarifa']))}',
                  ),
              ],
              onChanged: (v) {
                Map<String, dynamic>? nueva;
                for (final z in _zonas) {
                  if ('${z['Zona_DeliveryId']}' == v) {
                    nueva = z;
                    break;
                  }
                }
                setState(() => _zonaSel = nueva);
              },
            ),
            if (_zonas.isEmpty)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Zonas de entrega no disponibles.',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted)),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _dirCtrl,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              decoration: _deco('Dirección de entrega',
                  prefix: Icon(Icons.location_on_outlined,
                      size: 19, color: AppColors.celesteDark)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _refCtrl,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark),
              decoration: _deco('Referencia (opcional)'),
            ),
            const SizedBox(height: 10),
            _mapa(),
          ],
        ],
      ),
    );
  }

  Widget _mapa() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 220,
            decoration: BoxDecoration(
                border: Border.all(color: AppColors.borderSoft),
                borderRadius: BorderRadius.circular(16)),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _punto ?? const LatLng(-8.1116, -79.0287),
                initialZoom: 12.6,
                onTap: (_, p) => setState(() => _punto = p),
                interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName:
                      'pe.comercialvalencia.app_tesis',
                ),
                PolygonLayer(
                  polygons: [
                    for (final z in _poligonos)
                      for (final anillo in z.anillos)
                        Polygon(
                          points: anillo,
                          color: (_zonaSel != null &&
                                  '${_zonaSel!['Zona_DeliveryId']}' == z.id)
                              ? AppColors.celeste
                                  .withValues(alpha: .16)
                              : AppColors.celesteSoft
                                  .withValues(alpha: .08),
                          borderColor: (_zonaSel != null &&
                                  '${_zonaSel!['Zona_DeliveryId']}' == z.id)
                              ? AppColors.celesteDark
                              : AppColors.celesteLight,
                          borderStrokeWidth: (_zonaSel != null &&
                                  '${_zonaSel!['Zona_DeliveryId']}' == z.id)
                              ? 2.2
                              : 1.1,
                        ),
                  ],
                ),
                if (_punto != null)
                  MarkerLayer(markers: [
                    Marker(
                      point: _punto!,
                      width: 40,
                      height: 40,
                      child: const Icon(Icons.location_on_rounded,
                          color: Color(0xFFE53935), size: 38),
                    ),
                  ]),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution('OpenStreetMap contributors'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
                _punto == null
                    ? Icons.touch_app_outlined
                    : Icons.check_circle_rounded,
                size: 14,
                color: _punto == null
                    ? AppColors.textMuted
                    : AppColors.successDark),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  _punto == null
                      ? 'Toca el mapa para fijar el punto de entrega.'
                      : 'Ubicación de entrega fijada.',
                  style: TextStyle(
                      fontSize: 10.5,
                      color: _punto == null
                          ? AppColors.textMuted
                          : AppColors.successDark)),
            ),
            if (_punto != null)
              GestureDetector(
                onTap: () => setState(() => _punto = null),
                child: Text('Quitar',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.celesteDark)),
              ),
          ],
        ),
      ],
    );
  }

  // ---------------- guardar ----------------

  Widget _botonGuardar() {
    final habilitado =
        !_guardando && _cliente != null && _carrito.isNotEmpty;
    return ErpPrimaryButton(
      label: _guardando
          ? 'Guardando...'
          : (_esEdicion ? 'Guardar cambios' : 'Guardar pedido'),
      icon: _esEdicion ? Icons.check_rounded : Icons.save_outlined,
      loading: _guardando,
      onTap: habilitado ? _guardar : null,
    );
  }
}

// ==================== diálogo de éxito (check animado) ====================

class _DialogoExito extends StatefulWidget {
  final String pedidoId;
  final bool edicion;
  const _DialogoExito({required this.pedidoId, this.edicion = false});

  @override
  State<_DialogoExito> createState() => _DialogoExitoState();
}

class _DialogoExitoState extends State<_DialogoExito>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                  parent: _ctrl, curve: Curves.elasticOut),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.celesteDeep,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 48),
              ),
            ),
            const SizedBox(height: 18),
            Text(widget.edicion ? 'Pedido actualizado' : 'Se realizó tu pedido',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            if (widget.pedidoId.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                  widget.edicion
                      ? 'Pedido ${widget.pedidoId} actualizado correctamente.'
                      : 'Pedido ${widget.pedidoId} registrado correctamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ErpPrimaryButton(
                label: 'Aceptar',
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== modelos auxiliares ====================

class _LineaPedido {
  final String productoId;
  final String nombre;
  final String unidadId;
  final String unidadDescripcion;
  final double factor;
  double cantidad;
  final double precio;
  final bool sugeridoIa;

  _LineaPedido({
    required this.productoId,
    required this.nombre,
    required this.unidadId,
    required this.unidadDescripcion,
    required this.factor,
    required this.cantidad,
    required this.precio,
    this.sugeridoIa = false,
  });

  double get subtotal => cantidad * precio;
}

class _ZonaMapa {
  final String id;
  final List<List<LatLng>> anillos;
  const _ZonaMapa({required this.id, required this.anillos});
}

// ==================== helpers ====================

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating));
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fechaIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);

List<LatLng> _anillo(dynamic ring) {
  final pts = <LatLng>[];
  if (ring is! List) return pts;
  for (final pt in ring) {
    if (pt is List && pt.length >= 2) {
      final lng = pt[0];
      final lat = pt[1];
      if (lng is num && lat is num) {
        pts.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    } else if (pt is Map) {
      final lat = pt['lat'] ?? pt['latitude'];
      final lng = pt['lng'] ?? pt['lon'] ?? pt['longitude'];
      if (lat is num && lng is num) {
        pts.add(LatLng(lat.toDouble(), lng.toDouble()));
      }
    }
  }
  return pts;
}

List<List<LatLng>> _parseGeoJson(dynamic geoRaw) {
  dynamic geo = geoRaw;
  if (geo is String) {
    final s = geo.trim();
    if (s.isEmpty || s == 'null') return [];
    try {
      geo = jsonDecode(s);
    } catch (_) {
      return [];
    }
  }

  final anillos = <List<LatLng>>[];

  void procesar(dynamic g) {
    if (g is! Map) return;
    final tipo = '${g['type'] ?? ''}';
    if (tipo == 'FeatureCollection') {
      final fs = g['features'];
      if (fs is List) {
        for (final f in fs) {
          procesar(f);
        }
      }
      return;
    }
    if (tipo == 'Feature' || g['geometry'] is Map) {
      procesar(g['geometry']);
      return;
    }
    if (tipo == 'Polygon' && g['coordinates'] is List) {
      for (final ring in g['coordinates'] as List) {
        final pts = _anillo(ring);
        if (pts.length >= 3) anillos.add(pts);
      }
      return;
    }
    if (tipo == 'MultiPolygon' && g['coordinates'] is List) {
      for (final poly in g['coordinates'] as List) {
        procesar({'type': 'Polygon', 'coordinates': poly});
      }
      return;
    }
    if (g['coordinates'] is List) {
      procesar({'type': 'Polygon', 'coordinates': g['coordinates']});
    }
  }

  procesar(geo);

  if (anillos.isEmpty && geo is List && geo.isNotEmpty) {
    final pts = _anillo(geo);
    if (pts.length >= 3) anillos.add(pts);
  }
  return anillos;
}
