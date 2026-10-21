import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';

/// DESPACHO DE PEDIDOS
/// Tabla de pedidos (más recientes primero) con buscador y filtro de fechas.
/// Al tocar un pedido se despliega hacia abajo: cada producto con su check,
/// su X y la cantidad (la presentación NO se modifica, solo la cantidad).
/// Cuando el último producto se marca, la orden se cierra automáticamente.
class DespachoTab extends StatefulWidget {
  const DespachoTab({super.key});

  @override
  State<DespachoTab> createState() => _DespachoTabState();
}

class _DespachoTabState extends State<DespachoTab> {
  final _svc = ModulesService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  DateTime? _desde;
  DateTime? _hasta;
  String _filtro = 'Por atender';

  bool _cargando = true;
  List<Map<String, dynamic>> _pedidos = [];

  String? _expandido;
  bool _cargandoDetalle = false;
  Map<String, dynamic> _detalle = {};
  final Map<String, TextEditingController> _cantCtrls = {};
  final Map<String, String> _decision = {}; // detalleId -> 'OK' | 'NO'
  bool _cerrando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    for (final c in _cantCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final q = _searchCtrl.text.trim();
    var data = await _svc.despachoPedidos(
      search: q,
      fechaDesde: _desde == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_desde!),
      fechaHasta: _hasta == null
          ? null
          : DateFormat('yyyy-MM-dd').format(_hasta!),
    );

    // Fallback case-insensitive si la API devolvió lista vacía por sensibilidad a mayúsculas
    if (q.isNotEmpty && data.isEmpty) {
      final all = await _svc.despachoPedidos(
        search: '',
        fechaDesde: _desde == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_desde!),
        fechaHasta: _hasta == null
            ? null
            : DateFormat('yyyy-MM-dd').format(_hasta!),
      );
      final qLower = q.toLowerCase();
      data = all.where((p) {
        final cli = '${p['ClienteNombre'] ?? p['cliente'] ?? ''}'.toLowerCase();
        final id = '${p['PedidoId'] ?? p['codigo'] ?? ''}'.toLowerCase();
        final ruc = '${p['ClienteRuc'] ?? p['ClienteDni'] ?? ''}'.toLowerCase();
        return cli.contains(qLower) || id.contains(qLower) || ruc.contains(qLower);
      }).toList();
    }

    if (!mounted) return;
    // Pedidos más recientes primero
    data.sort((a, b) {
      final fa = DateTime.tryParse(
              '${a['PedidoFecha'] ?? a['PedidoFechaCreacion'] ?? ''}') ??
          DateTime(1970);
      final fb = DateTime.tryParse(
              '${b['PedidoFecha'] ?? b['PedidoFechaCreacion'] ?? ''}') ??
          DateTime(1970);
      return fb.compareTo(fa);
    });
    setState(() {
      _pedidos = data;
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _filtrados => _pedidos
      // El pedido desplegado se mantiene visible aunque el filtro ya no
      // coincida (al iniciar el despacho pasa de "Por atender" a
      // "En preparación").
      .where((p) => _coincideFiltro(p) || '${p['PedidoId']}' == _expandido)
      .toList();

  bool _coincideFiltro(Map<String, dynamic> p) {
    final e = '${p['PedidoEstadoDespacho'] ?? ''}'.toUpperCase();
    switch (_filtro) {
      case 'Por atender':
        return e.isEmpty || e == 'PENDIENTE' || e == 'PENDIENTE_DESPACHO';
      case 'En preparación':
        return e == 'EN_PREPARACION';
      case 'Cerradas':
        return _esFinal(e);
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ------- buscador + rango de fechas -------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              ErpSearchField(
                controller: _searchCtrl,
                hint: 'Buscar pedido o cliente...',
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 400), _cargar);
                },
                onClear: () {
                  _searchCtrl.clear();
                  _cargar();
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ErpDateField(
                      label: 'Desde',
                      value: _desde,
                      onPick: (d) {
                        setState(() => _desde = d);
                        _cargar();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ErpDateField(
                      label: 'Hasta',
                      value: _hasta,
                      onPick: (d) {
                        setState(() => _hasta = d);
                        _cargar();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Filtro por estado del despacho (igual que Recepción).
              Align(
                alignment: Alignment.centerLeft,
                child: ErpFilterPills(
                  options: const [
                    'Por atender',
                    'En preparación',
                    'Cerradas'
                  ],
                  selected: _filtro,
                  onSelect: (v) => setState(() => _filtro = v),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _cargando
              ? Center(
                  child:
                      CircularProgressIndicator(color: AppColors.celesteDark))
              : RefreshIndicator(
                  color: AppColors.celesteDark,
                  onRefresh: _cargar,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                    children: [_filtrados.isEmpty ? _vacio() : _tabla()],
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------- tabla ----------------

  Widget _tabla() {
    return ErpTableFrame(
      child: Column(
        children: [
          Container(
            color: AppColors.celesteTint,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(width: 72, child: _txtCabecera('Pedido')),
                Expanded(child: _txtCabecera('Cliente')),
                SizedBox(
                    width: 54,
                    child: _txtCabecera('Fecha', align: Alignment.center)),
                SizedBox(
                    width: 82,
                    child: _txtCabecera('Estado', align: Alignment.center)),
              ],
            ),
          ),
          for (final p in _filtrados) _filaPedido(p),
        ],
      ),
    );
  }

  Widget _txtCabecera(String t, {Alignment align = Alignment.centerLeft}) =>
      Container(
        alignment: align,
        child: Text(t,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: 0.2)),
      );

  Widget _filaPedido(Map<String, dynamic> p) {
    final id = '${p['PedidoId'] ?? ''}';
    final cliente = '${p['ClienteNombre'] ?? 'Cliente'}';
    final telefono = '${p['ClienteTelefono'] ?? ''}';
    final fechaRaw = '${p['PedidoFecha'] ?? p['PedidoFechaCreacion'] ?? ''}';
    final fecha = DateTime.tryParse(fechaRaw.replaceFirst(' ', 'T'));
    final estado = '${p['PedidoEstadoDespacho'] ?? ''}';
    final badge = _badgeEstado(estado);
    final abierto = _expandido == id;

    return Column(
      children: [
        InkWell(
          onTap: () => _toggle(p),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                  top: BorderSide(color: AppColors.borderSoft, width: 1)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Row(
                    children: [
                      Icon(
                          abierto
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 15,
                          color: AppColors.celesteDark),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cliente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (telefono.isNotEmpty && telefono != 'null')
                        Text(telefono,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 9.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 54,
                  child: Column(
                    children: [
                      Text(
                          fecha == null
                              ? '—'
                              : DateFormat('dd/MM').format(fecha),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                      if (fecha != null)
                        Text(DateFormat('HH:mm').format(fecha),
                            style: TextStyle(
                                fontSize: 9, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 82,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: badge.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badge.border),
                      ),
                      child: Text(badge.label,
                          style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: badge.text)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (abierto) _panelPedido(p),
      ],
    );
  }

  ({String label, Color bg, Color border, Color text}) _badgeEstado(
      String estado) {
    final s = estado.toUpperCase();
    if (s.contains('PREPARACION')) {
      return (
        label: 'Preparando',
        bg: AppColors.celesteTint,
        border: AppColors.celesteBg,
        text: AppColors.celesteDeep
      );
    }
    if (s.contains('FALTANTE')) {
      return (
        label: 'Con faltante',
        bg: AppColors.warningBg,
        border: AppColors.warningBorder,
        text: AppColors.warningDark
      );
    }
    if (s.startsWith('ENTREGADO')) {
      return (
        label: 'Entregado',
        bg: AppColors.successBg,
        border: AppColors.successBorder,
        text: AppColors.successDark
      );
    }
    if (s.startsWith('RECHAZADO') || s.contains('ANULADO')) {
      return (
        label: 'Rechazado',
        bg: AppColors.errorBg,
        border: AppColors.errorBorder,
        text: AppColors.errorDark
      );
    }
    return (
      label: 'Pendiente',
      bg: AppColors.warningBg,
      border: AppColors.warningBorder,
      text: AppColors.warningDark
    );
  }

  bool _esFinal(String? e) {
    final s = (e ?? '').toUpperCase();
    return s.startsWith('ENTREGADO') ||
        s.startsWith('RECHAZADO') ||
        s.contains('ANULADO');
  }

  // ---------------- desplegable por pedido ----------------

  Future<void> _toggle(Map<String, dynamic> p) async {
    final id = '${p['PedidoId']}';
    if (_expandido == id) {
      setState(() {
        _expandido = null;
        _cargandoDetalle = false;
      });
      _limpiarExpansion();
      return;
    }
    _limpiarExpansion();
    setState(() {
      _expandido = id;
      _cargandoDetalle = true;
      _detalle = {};
    });
    try {
      final d = await _svc.despachoDetalle(id);
      if (!mounted || _expandido != id) return;
      setState(() {
        _detalle = d;
        _cargandoDetalle = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _expandido = null;
        _cargandoDetalle = false;
      });
      _snack(context, '$e');
    }
  }

  void _limpiarExpansion() {
    _decision.clear();
    final viejos = _cantCtrls.values.toList();
    _cantCtrls.clear();
    _detalle = {};
    // Se liberan tras el frame para que los TextField aún montados
    // no usen un controller ya dispuesto.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in viejos) {
        c.dispose();
      }
    });
  }

  Widget _panelPedido(Map<String, dynamic> p) {
    if (_cargandoDetalle) {
      return Container(
        width: double.infinity,
        color: AppColors.celesteTint.withValues(alpha: .35),
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: Center(
          child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2.2, color: AppColors.celesteDark)),
        ),
      );
    }

    final pedido = _detalle['pedido'] is Map
        ? Map<String, dynamic>.from(_detalle['pedido'] as Map)
        : <String, dynamic>{};
    final items = _detalle['items'] is List
        ? (_detalle['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final estado =
        '${pedido['PedidoEstadoDespacho'] ?? p['PedidoEstadoDespacho'] ?? ''}';
    final finalizado = _esFinal(estado);
    final esDelivery =
        '${pedido['PedidoEsDelivery'] ?? p['PedidoEsDelivery'] ?? 'N'}'
                .toUpperCase() ==
            'S';
    final direccion =
        '${pedido['PedidoDireccionEntrega'] ?? pedido['ClienteDireccion'] ?? ''}';

    return Container(
      width: double.infinity,
      color: AppColors.celesteTint.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (esDelivery && direccion.isNotEmpty && direccion != 'null') ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.delivery_dining_rounded,
                    size: 15, color: AppColors.celesteDeep),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Entrega: $direccion',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.celesteDeep)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (items.isEmpty)
            Text('Sin productos registrados en este pedido.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          for (final it in items) _filaItem(it, finalizado),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Icon(
                    finalizado
                        ? Icons.lock_rounded
                        : Icons.info_outline_rounded,
                    size: 13,
                    color: finalizado
                        ? AppColors.successDark
                        : AppColors.textMuted),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                      finalizado
                          ? 'Pedido cerrado.'
                          : 'Marca check en cada producto; al completar el último, el pedido se cierra solo.',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight:
                              finalizado ? FontWeight.w800 : FontWeight.w500,
                          color: finalizado
                              ? AppColors.successDark
                              : AppColors.textMuted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaItem(Map<String, dynamic> it, bool finalizado) {
    final id = '${it['Detalle_Pedido_ProductosId']}';
    final solicitada = _num(it['cantidad_solicitada']);
    final unidad = '${it['unidad_medida'] ?? ''}';
    final sufijo = unidad.isNotEmpty && unidad != 'null' ? ' $unidad' : '';

    // Pedido cerrado → SOLO lectura: sin caja de cantidad ni check/X,
    // que únicamente tienen sentido mientras el pedido sigue abierto.
    if (finalizado) {
      final despachada = _num(it['cantidad_despachada']);
      final completo = despachada > 0 && despachada >= solicitada;
      final sinDespacho = despachada <= 0;
      final colorBg = completo
          ? AppColors.successBg
          : (sinDespacho ? AppColors.errorBg : AppColors.warningBg);
      final colorBorde = completo
          ? AppColors.successBorder
          : (sinDespacho
              ? AppColors.errorBorder
              : AppColors.warningBorder);
      final colorTexto = completo
          ? AppColors.successDark
          : (sinDespacho ? AppColors.errorDark : AppColors.warningDark);
      final etiqueta = completo
          ? 'Despachado: ${_fmt(despachada)}$sufijo'
          : (sinDespacho
              ? 'No despachado'
              : 'Despachado: ${_fmt(despachada)} de ${_fmt(solicitada)}');

      return Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorBorde),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${it['producto_nombre'] ?? 'Producto'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          height: 1.15)),
                  const SizedBox(height: 2),
                  Text('Solicitado: ${_fmt(solicitada)}$sufijo',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colorBorde),
              ),
              child: Text(etiqueta,
                  style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: colorTexto)),
            ),
          ],
        ),
      );
    }

    // Pedido abierto → edición con caja de cantidad + check/X.
    if (!_cantCtrls.containsKey(id)) {
      final previa = it['cantidad_despachada'];
      final inicial = (previa != null &&
              '$previa' != 'null' &&
              _num(previa) > 0)
          ? _num(previa)
          : _num(it['cantidad_solicitada']);
      _cantCtrls[id] = TextEditingController(text: _fmt(inicial));
    }
    final decision = _decision[id];

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: decision == 'OK'
                ? AppColors.successBorder
                : (decision == 'NO'
                    ? AppColors.errorBorder
                    : AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it['producto_nombre'] ?? 'Producto'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.15)),
                const SizedBox(height: 2),
                Text(
                    'Solicitado: ${_fmt(solicitada)}${unidad.isNotEmpty && unidad != 'null' ? ' $unidad' : ''}',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 58,
            child: TextField(
              controller: _cantCtrls[id],
              enabled: !finalizado && decision != 'NO',
              textAlign: TextAlign.center,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
              ],
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: AppColors.celesteTint.withValues(alpha: .7),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: AppColors.borderSoft)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(
                        color: AppColors.celesteDark, width: 1.3)),
                disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(11),
                    borderSide: BorderSide(color: AppColors.borderSoft)),
              ),
            ),
          ),
          const SizedBox(width: 6),
          _botonAccion(
            icon: Icons.check_rounded,
            activo: decision == 'OK',
            color: AppColors.success,
            onTap: finalizado ? null : () => _decidir(it, 'OK'),
          ),
          const SizedBox(width: 4),
          _botonAccion(
            icon: Icons.close_rounded,
            activo: decision == 'NO',
            color: AppColors.error,
            onTap: finalizado ? null : () => _decidir(it, 'NO'),
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({
    required IconData icon,
    required bool activo,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: activo ? color : AppColors.celesteTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon,
            size: 17,
            color: activo ? Colors.white : AppColors.textMuted),
      ),
    );
  }

  // ---------------- decisiones y cierre ----------------

  void _decidir(Map<String, dynamic> it, String tipo) {
    final id = '${it['Detalle_Pedido_ProductosId']}';
    if (tipo == 'NO') {
      _cantCtrls[id]?.text = '0';
    } else {
      final solicitada = _num(it['cantidad_solicitada']);
      final v = _num(_cantCtrls[id]?.text);
      if (v <= 0) {
        _snack(context, 'Ingresa una cantidad mayor a 0.');
        return;
      }
      if (v > solicitada) {
        _snack(context,
            'La cantidad no puede superar la solicitada (${_fmt(solicitada)}).');
        return;
      }
    }
    setState(() => _decision[id] = tipo);
    _quizasCerrar();
  }

  void _quizasCerrar() {
    final items = _detalle['items'] is List
        ? (_detalle['items'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return;
    for (final it in items) {
      final id = '${it['Detalle_Pedido_ProductosId']}';
      if (_decision[id] == null) return; // aún faltan productos por marcar
    }
    _cerrarDespacho(items);
  }

  Future<void> _cerrarDespacho(List<Map<String, dynamic>> items) async {
    if (_cerrando || _expandido == null) return;
    final pedidoId = _expandido!;
    setState(() => _cerrando = true);
    try {
      final payloadItems = <Map<String, dynamic>>[];
      var completo = true;
      var faltantes = 0;

      for (final it in items) {
        final id = '${it['Detalle_Pedido_ProductosId']}';
        final solicitada = _num(it['cantidad_solicitada']);
        final despachada =
            _decision[id] == 'NO' ? 0.0 : _num(_cantCtrls[id]?.text);
        if (despachada < solicitada) {
          completo = false;
          faltantes++;
        }
        payloadItems.add({
          'detalle_id': id,
          'cantidad_despachada': despachada,
          if (_decision[id] == 'NO') 'observacion': 'Sin stock en almacén',
        });
      }

      if (completo) {
        await _svc.despachoCompletar(pedidoId);
        if (mounted) {
          _snack(context, 'Pedido $pedidoId despachado por completo.');
        }
      } else {
        await _svc.despachoFaltante(
          pedidoId,
          observacion:
              'Despacho con faltante acordado con el cliente. $faltantes ítem(s) con faltante auditado.',
          items: payloadItems,
        );
        if (mounted) {
          _snack(context, 'Pedido $pedidoId despachado con faltante.');
        }
      }

      if (mounted) {
        setState(() => _expandido = null);
        _limpiarExpansion();
        await _cargar();
      }
    } catch (e) {
      if (mounted) {
        _snack(context, '$e');
        if ('$e'.toLowerCase().contains('procesado')) {
          setState(() => _expandido = null);
          _limpiarExpansion();
          _cargar();
        }
      }
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  Widget _vacio() => const ErpEmptyState(
        icon: Icons.delivery_dining_rounded,
        title: 'Sin pedidos',
        message: 'No hay pedidos para los filtros seleccionados.',
      );
}

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating));
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);
