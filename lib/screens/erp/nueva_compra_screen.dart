import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';

/// NUEVA ORDEN DE COMPRA (hacia proveedores)
/// · Tradicional: proveedor + productos (cantidad y presentación, sin
///   precio) + fecha estimada de llegada + observación opcional.
/// · Compra rápida: productos + cantidades a PYME Vecina (comercio aliado)
///   con ingreso inmediato a stock, sin verificación.
class NuevaCompraScreen extends StatefulWidget {
  /// Si se indica, precarga proveedor, productos y observaciones enviados desde Valencia AI.
  final Map<String, dynamic>? prefillData;

  const NuevaCompraScreen({super.key, this.prefillData});

  @override
  State<NuevaCompraScreen> createState() => _NuevaCompraScreenState();
}

class _NuevaCompraScreenState extends State<NuevaCompraScreen> {
  final _svc = ModulesService();

  // ---- modo ----
  bool _rapida = false;

  // ---- proveedor ----
  final _provCtrl = TextEditingController();
  Timer? _provDebounce;
  bool _buscandoProv = false;
  List<ErpItem> _provResultados = [];
  Map<String, dynamic>? _proveedor;

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
  final List<_LineaCompra> _carrito = [];

  // ---- entrega / observación ----
  DateTime? _fechaLlegada;
  final _obsCtrl = TextEditingController();

  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _fechaLlegada = DateTime.now().add(const Duration(days: 2));
    _cargarCatalogo();
    if (widget.prefillData != null) {
      _aplicarPrefill(widget.prefillData!);
    }
  }

  void _aplicarPrefill(Map<String, dynamic> prefill) {
    // 1. Proveedor
    if (prefill['proveedor'] is Map) {
      final p = Map<String, dynamic>.from(prefill['proveedor'] as Map);
      _proveedor = {
        'id': '${p['ProveedorId'] ?? p['id'] ?? ''}',
        'nombre': '${p['ProveedorRazonSocial'] ?? p['nombre'] ?? p['razon_social'] ?? 'Proveedor'}',
        'ruc': '${p['ProveedorRuc'] ?? p['ruc'] ?? ''}',
      };
    } else if (prefill['proveedor_nombre'] != null) {
      _proveedor = {
        'id': '${prefill['proveedor_id'] ?? ''}',
        'nombre': '${prefill['proveedor_nombre']}',
        'ruc': '',
      };
    }

    // 2. Observación
    final obs = prefill['observacion'] ?? prefill['observaciones'];
    if (obs != null && obs.toString().isNotEmpty) {
      _obsCtrl.text = obs.toString();
    }

    // 3. Productos / Detalles
    final prodsRaw = prefill['productos'] ?? prefill['detalles'];
    if (prodsRaw is List) {
      final lineas = <_LineaCompra>[];
      for (final raw in prodsRaw) {
        if (raw is! Map) continue;
        final it = Map<String, dynamic>.from(raw);
        final factor = _num(it['factor_conversion'] ?? it['factor']);
        final cant = _num(it['cantidad']);
        final desc = it['unidadNombre']?.toString() ??
            it['unidad_nombre']?.toString() ??
            it['unidad_descripcion']?.toString() ??
            it['unidadAbreviatura']?.toString() ??
            it['unidad_abreviatura']?.toString() ??
            'Unidad';

        lineas.add(_LineaCompra(
          productoId: '${it['productoId'] ?? it['producto_id'] ?? ''}',
          nombre: '${it['productoNombre'] ?? it['producto_nombre'] ?? it['nombre'] ?? 'Producto'}',
          unidadId: '${it['unidadMedidaId'] ?? it['unidad_id'] ?? 'UND-00001'}',
          unidadDescripcion: desc,
          factor: factor <= 0 ? 1.0 : factor,
          cantidad: cant <= 0 ? 1.0 : cant,
        ));
      }
      _carrito.clear();
      _carrito.addAll(lineas);
    }
  }

  @override
  void dispose() {
    _provDebounce?.cancel();
    _provCtrl.dispose();
    _prodCtrl.dispose();
    _cantCtrl.dispose();
    _obsCtrl.dispose();
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

  // ================= PROVEEDOR =================

  void _onProvQuery(String q) {
    _provDebounce?.cancel();
    final t = q.trim();
    if (t.isEmpty) {
      setState(() => _provResultados = []);
      return;
    }
    _provDebounce =
        Timer(const Duration(milliseconds: 300), () => _buscarProveedores(t));
  }

  Future<void> _buscarProveedores(String q) async {
    setState(() => _buscandoProv = true);
    final r = await _svc.proveedores(search: q);
    if (!mounted) return;
    setState(() {
      _provResultados = r.take(6).toList();
      _buscandoProv = false;
    });
  }

  void _seleccionarProveedor(ErpItem e) {
    final raw = e.raw;
    final ruc = '${raw['ProveedorRuc'] ?? raw['ruc'] ?? ''}';
    setState(() {
      _proveedor = {
        'id': e.id,
        'nombre': e.titulo,
        'ruc': ruc == 'null' ? '' : ruc,
      };
      _provResultados = [];
      _provCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _limpiarProveedor() {
    setState(() {
      _proveedor = null;
      _provResultados = [];
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
        return '${p['ProductoNombre'] ?? ''}'.toLowerCase().contains(t) ||
            '${p['ProductoMarca'] ?? ''}'.toLowerCase().contains(t) ||
            '${p['categoria_nombre'] ?? ''}'.toLowerCase().contains(t);
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
    base ??=
        unis.isNotEmpty ? Map<String, dynamic>.from(unis.first) : null;
    setState(() {
      _prodSel = p;
      _unidadSel = base;
      _cantCtrl.text = '1';
      _errorLinea = null;
    });
  }

  void _agregarLinea() {
    final p = _prodSel;
    final u = _unidadSel;
    if (p == null || u == null) return;

    final cant = _num(_cantCtrl.text);
    if (cant <= 0) {
      setState(() => _errorLinea = 'Ingresa una cantidad válida.');
      return;
    }

    var factor = _num(u['factor_conversion']);
    if (factor <= 0) factor = 1;
    final pid = '${p['ProductoId']}';
    final uid = '${u['unidades_medidaId']}';

    final idx =
        _carrito.indexWhere((l) => l.productoId == pid && l.unidadId == uid);
    setState(() {
      if (idx >= 0) {
        _carrito[idx].cantidad += cant;
      } else {
        _carrito.add(_LineaCompra(
          productoId: pid,
          nombre: '${p['ProductoNombre'] ?? 'Producto'}',
          unidadId: uid,
          unidadDescripcion: '${u['descripcion'] ?? 'Unidad'}',
          factor: factor,
          cantidad: cant,
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

  // ================= GUARDAR =================

  Future<void> _guardar() async {
    if (!_rapida && _proveedor == null) {
      _snack(context, 'Selecciona al proveedor.');
      return;
    }
    if (_carrito.isEmpty) {
      _snack(context, 'Agrega al menos un producto.');
      return;
    }
    if (!_rapida && _fechaLlegada == null) {
      _snack(context, 'Selecciona la fecha estimada de llegada.');
      return;
    }

    setState(() => _guardando = true);
    try {
      final detalles = _carrito
          .map((l) => {
                'producto_id': l.productoId,
                'unidad_medida_id': l.unidadId,
                'cantidad': l.cantidad,
                'precio_unitario': 0,
              })
          .toList();

      final Map<String, dynamic> res;
      if (_rapida) {
        res = await _svc.compraRapidaProceso({
          if (_obsCtrl.text.trim().isNotEmpty)
            'observaciones': _obsCtrl.text.trim(),
          'detalles': detalles,
        });
      } else {
        res = await _svc.crearOrdenCompraProceso({
          'proveedor_id': _proveedor!['id'],
          if (_fechaLlegada != null)
            'fecha_estimada_llegada': _fechaIso(_fechaLlegada!),
          if (_obsCtrl.text.trim().isNotEmpty)
            'Orden_CompraObservacion': _obsCtrl.text.trim(),
          'detalles': detalles,
        });
      }
      if (!mounted) return;

      final data = res['data'];
      final codigo = data is Map
          ? '${data['id'] ?? data['Orden_CompraId'] ?? ''}'
          : '';

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DialogoCompra(codigo: codigo, rapida: _rapida),
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

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          const ErpHeader(
            title: 'Nueva Orden de Compra',
            subtitle: 'Proveedor · productos · recepción',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                _seccionModo(),
                if (!_rapida) _seccionProveedor(),
                _seccionProductos(),
                _seccionCarrito(),
                if (!_rapida) _seccionEntrega(),
                _seccionObservacion(),
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
                Text(titulo,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.2)),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ---------------- modo ----------------

  Widget _seccionModo() {
    return _seccion(
      titulo: 'Modalidad',
      icono: Icons.swap_horiz_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ErpChoicePill(
                label: 'Tradicional',
                icon: Icons.request_page_outlined,
                selected: !_rapida,
                onTap: () => setState(() => _rapida = false),
              ),
              const SizedBox(width: 8),
              ErpChoicePill(
                label: 'Compra rápida',
                icon: Icons.bolt_rounded,
                selected: _rapida,
                onTap: () => setState(() => _rapida = true),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
              _rapida
                  ? 'PYME Vecina (aliado local): el producto ingresa al stock al guardar, sin verificación.'
                  : 'Proveedor y fecha estimada de llegada; la mercadería se recibe después.',
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ---------------- proveedor ----------------

  Widget _seccionProveedor() {
    return _seccion(
      titulo: 'Proveedor',
      icono: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_proveedor != null)
            _tileProveedor()
          else ...[
            ErpSearchField(
              controller: _provCtrl,
              hint: 'Buscar proveedor por nombre o RUC...',
              onChanged: _onProvQuery,
            ),
            if (_buscandoProv)
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
            for (final e in _provResultados) _filaProveedorResultado(e),
          ],
        ],
      ),
    );
  }

  Widget _tileProveedor() {
    final nombre = '${_proveedor!['nombre']}';
    final ruc = '${_proveedor!['ruc'] ?? ''}';
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_rounded,
              color: AppColors.celesteDark, size: 20),
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
                if (ruc.isNotEmpty)
                  Text('RUC $ruc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          InkWell(
            onTap: _limpiarProveedor,
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

  Widget _filaProveedorResultado(ErpItem e) {
    return InkWell(
      onTap: () => _seleccionarProveedor(e),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            const ErpIconTile(
                icon: Icons.local_shipping_outlined, size: 32, radius: 10),
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
                            fontSize: 10.5, color: AppColors.textMuted)),
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

  // ---------------- productos ----------------

  Widget _seccionProductos() {
    if (!_rapida && _proveedor == null) {
      return _seccion(
        titulo: 'Productos',
        icono: Icons.shopping_bag_outlined,
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 15, color: AppColors.textMuted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                  'Selecciona un proveedor para agregar productos.',
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpSearchField(
            controller: _prodCtrl,
            hint: _cargandoCatalogo
                ? 'Cargando catálogo...'
                : 'Buscar producto a pedir...',
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
                            fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                  color: AppColors.celesteTint,
                  borderRadius: BorderRadius.circular(8)),
              child: Text(
                  'Stock: ${_fmt(stock)}${abrev.isNotEmpty ? ' $abrev' : ''}',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.celesteDeep)),
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
                      'x ${_fmt(_num(u['factor_conversion']))} ${'${p['unidad_base'] ?? 'UND'}'}',
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
          TextField(
            controller: _cantCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            onChanged: (_) => setState(() => _errorLinea = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark),
            decoration: InputDecoration(
              hintText: 'Cantidad a pedir',
              hintStyle:
                  TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
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
            ),
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

  // ---------------- carrito ----------------

  Widget _seccionCarrito() {
    return _seccion(
      titulo: _rapida ? 'Compra rápida' : 'Orden de compra',
      icono: Icons.receipt_long_outlined,
      child: _carrito.isEmpty
          ? Text('Agrega productos para armar la orden.',
              style:
                  TextStyle(fontSize: 12, color: AppColors.textMuted))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in _carrito) _lineaCarrito(l),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                          _rapida
                              ? 'Al guardar, el stock se actualiza automáticamente.'
                              : 'El precio se completa cuando se recibe la mercadería.',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textMuted)),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _lineaCarrito(_LineaCompra l) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.15)),
                Text('${l.unidadDescripcion} × ${_fmt(l.cantidad)}',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
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

  // ---------------- entrega ----------------

  Widget _seccionEntrega() {
    return _seccion(
      titulo: 'Entrega',
      icono: Icons.event_available_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ErpDateField(
            label: 'Fecha estimada de llegada',
            emptyLabel: 'Sin fecha',
            value: _fechaLlegada,
            minima: DateTime.now(),
            onPick: (d) => setState(() => _fechaLlegada = d),
          ),
          const SizedBox(height: 6),
          Text('Tiempo estimado que tarda el proveedor en entregar.',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  // ---------------- observación ----------------

  Widget _seccionObservacion() {
    return _seccion(
      titulo: 'Observación',
      icono: Icons.sticky_note_2_outlined,
      child: TextField(
        controller: _obsCtrl,
        maxLines: 3,
        maxLength: 250,
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark),
        decoration: InputDecoration(
          hintText: 'Observación (opcional)',
          hintStyle:
              TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
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
          counterStyle:
              TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ),
    );
  }

  // ---------------- guardar ----------------

  Widget _botonGuardar() {
    final habilitado = !_guardando &&
        _carrito.isNotEmpty &&
        (_rapida || _proveedor != null);
    return ErpPrimaryButton(
      label: _guardando
          ? 'Guardando...'
          : (_rapida ? 'Registrar compra rápida' : 'Guardar orden de compra'),
      icon: Icons.save_outlined,
      loading: _guardando,
      onTap: habilitado ? _guardar : null,
    );
  }
}

// ==================== diálogo de éxito ====================

class _DialogoCompra extends StatefulWidget {
  final String codigo;
  final bool rapida;
  const _DialogoCompra({required this.codigo, required this.rapida});

  @override
  State<_DialogoCompra> createState() => _DialogoCompraState();
}

class _DialogoCompraState extends State<_DialogoCompra>
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
              scale:
                  CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.celesteDeep,
                ),
                child: Icon(
                    widget.rapida
                        ? Icons.bolt_rounded
                        : Icons.check_rounded,
                    color: Colors.white,
                    size: 48),
              ),
            ),
            const SizedBox(height: 18),
            Text(
                widget.rapida
                    ? 'Compra rápida registrada'
                    : 'Orden de compra registrada',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark)),
            if (widget.codigo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                  widget.rapida
                      ? 'Orden ${widget.codigo} registrada y el stock ya fue actualizado.'
                      : 'Orden ${widget.codigo} registrada. Ya puedes recepcionar la mercadería.',
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

class _LineaCompra {
  final String productoId;
  final String nombre;
  final String unidadId;
  final String unidadDescripcion;
  final double factor;
  double cantidad;

  _LineaCompra({
    required this.productoId,
    required this.nombre,
    required this.unidadId,
    required this.unidadDescripcion,
    required this.factor,
    required this.cantidad,
  });
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
