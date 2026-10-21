import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';

/// RECEPCIÓN DE MERCADERÍA (órdenes de compra)
/// Tabla de órdenes de compra (más recientes primero) con buscador y filtro
/// por estado. Al tocar una orden se despliega hacia abajo: cada producto
/// con su check (ingresa stock + Kárdex al instante), su X (rechazo) y la
/// cantidad recibida editable. Cuando se marca el último producto pendiente,
/// la recepción se cierra automáticamente.
class RecepcionTab extends StatefulWidget {
  const RecepcionTab({super.key});

  @override
  State<RecepcionTab> createState() => _RecepcionTabState();
}

class _RecepcionTabState extends State<RecepcionTab> {
  final _svc = ModulesService();
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  bool _cargando = true;
  List<Map<String, dynamic>> _ordenes = [];
  String _filtro = 'Por atender';

  String? _expandido; // Orden_CompraId desplegado
  bool _cargandoDetalle = false;
  Map<String, dynamic> _detalle = {};
  final Map<String, TextEditingController> _cantCtrls = {};
  String? _itemOcupado; // detalleId en proceso
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

  Future<void> _cargar({bool spinner = true}) async {
    if (spinner) setState(() => _cargando = true);
    final q = _searchCtrl.text.trim();
    var data = await _svc.recepcionOrdenes(search: q);

    if (q.isNotEmpty && data.isEmpty) {
      final all = await _svc.recepcionOrdenes(search: '');
      final qLower = q.toLowerCase();
      data = all.where((o) {
        final prov = '${o['proveedor_nombre'] ?? o['proveedor'] ?? ''}'.toLowerCase();
        final id = '${o['id'] ?? o['codigo'] ?? ''}'.toLowerCase();
        final ruc = '${o['proveedor_ruc'] ?? ''}'.toLowerCase();
        return prov.contains(qLower) || id.contains(qLower) || ruc.contains(qLower);
      }).toList();
    }

    if (!mounted) return;
    setState(() {
      _ordenes = data; // ya vienen más recientes primero
      _cargando = false;
    });
  }

  List<Map<String, dynamic>> get _filtradas => _ordenes
      // La orden desplegada se mantiene visible aunque el filtro ya no
      // coincida (al iniciar recepción pasa de "Por atender" a "Parcial").
      .where((o) => _coincideFiltro(o) || '${o['id']}' == _expandido)
      .toList();

  bool _coincideFiltro(Map<String, dynamic> o) {
    final e = '${o['estado'] ?? ''}'.toUpperCase();
    switch (_filtro) {
      case 'Por atender':
        return e == 'EMITIDA';
      case 'Parciales':
        return e == 'RECEPCION_PARCIAL';
      case 'Cerradas':
        return e.startsWith('CERRADA') || e == 'ANULADA' || e == 'RECHAZADA';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ------- buscador + filtro por estado -------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              ErpSearchField(
                controller: _searchCtrl,
                hint: 'Buscar OC o proveedor...',
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
              Align(
                alignment: Alignment.centerLeft,
                child: ErpFilterPills(
                  options: const ['Por atender', 'Parciales', 'Cerradas'],
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
                  onRefresh: () => _cargar(spinner: false),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                    children: [
                      if (_filtradas.isEmpty) _vacio() else _tabla(),
                    ],
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
                SizedBox(width: 76, child: _txtCabecera('OC')),
                Expanded(child: _txtCabecera('Proveedor')),
                SizedBox(
                    width: 54,
                    child: _txtCabecera('Fecha', align: Alignment.center)),
                SizedBox(
                    width: 84,
                    child: _txtCabecera('Estado', align: Alignment.center)),
              ],
            ),
          ),
          for (final o in _filtradas) _filaOrden(o),
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

  Widget _filaOrden(Map<String, dynamic> o) {
    final id = '${o['id'] ?? ''}';
    final prov = o['proveedor'] is Map
        ? '${(o['proveedor'] as Map)['razon_social'] ?? 'Proveedor'}'
        : '${o['proveedor_nombre'] ?? 'Proveedor'}';
    final fechaRaw = '${o['fecha'] ?? ''}';
    final fecha = DateTime.tryParse(fechaRaw.replaceFirst(' ', 'T'));
    final badge = _badgeEstado('${o['estado'] ?? ''}');
    final abierto = _expandido == id;
    final estado = '${o['estado'] ?? ''}'.toUpperCase();

    return Column(
      children: [
        InkWell(
          onTap: () => _toggle(o),
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
                  width: 76,
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
                                fontSize: 10,
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
                      Text(prov,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      if (estado.startsWith('CERRADA'))
                        Text('Mercadería verificada',
                            style: TextStyle(
                                fontSize: 9.5, color: AppColors.textMuted))
                      else if (estado.contains('ANULADA') || estado.contains('RECHAZADA'))
                        Text(estado.contains('RECHAZADA') ? 'Orden rechazada' : 'Orden anulada',
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
                  width: 84,
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
        if (abierto) _panelOrden(o),
      ],
    );
  }

  ({String label, Color bg, Color border, Color text}) _badgeEstado(
      String estado) {
    final s = estado.toUpperCase();
    if (s == 'RECEPCION_PARCIAL') {
      return (
        label: 'Parcial',
        bg: AppColors.warningBg,
        border: AppColors.warningBorder,
        text: AppColors.warningDark
      );
    }
    if (s == 'CERRADA_CON_FALTANTE') {
      return (
        label: 'Con faltante',
        bg: AppColors.warningBg,
        border: AppColors.warningBorder,
        text: AppColors.warningDark
      );
    }
    if (s.startsWith('CERRADA')) {
      return (
        label: 'Cerrada',
        bg: AppColors.successBg,
        border: AppColors.successBorder,
        text: AppColors.successDark
      );
    }
    if (s.contains('ANULADA') || s.contains('RECHAZADA')) {
      return (
        label: s.contains('RECHAZADA') ? 'Rechazada' : 'Anulada',
        bg: AppColors.errorBg,
        border: AppColors.errorBorder,
        text: AppColors.errorDark
      );
    }
    return (
      label: 'Por atender',
      bg: AppColors.celesteTint,
      border: AppColors.celesteBg,
      text: AppColors.celesteDeep
    );
  }

  bool _esFinal(String estado) =>
      estado.startsWith('CERRADA') || estado.contains('ANULADA') || estado.contains('RECHAZADA');

  // ---------------- desplegable por orden ----------------

  Future<void> _toggle(Map<String, dynamic> o) async {
    final id = '${o['id']}';
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

    // La primera recepción mueve la orden a "En Recepción Parcial".
    final estado = '${o['estado'] ?? ''}'.toUpperCase();
    if (estado == 'EMITIDA') {
      try {
        await _svc.iniciarRecepcion(id);
      } catch (_) {
        // Si falla, recepcionar-item igualmente auto-transiciona.
      }
    }

    try {
      final d = await _svc.ordenCompraDetalle(id);
      if (!mounted || _expandido != id) return;
      setState(() {
        _detalle = d;
        _cargandoDetalle = false;
      });
      _cargar(spinner: false); // refresca estado en la tabla
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

  List<Map<String, dynamic>> get _items {
    if (_detalle['detalles'] is List) {
      return (_detalle['detalles'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  Widget _panelOrden(Map<String, dynamic> o) {
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

    final estado = '${_detalle['estado'] ?? o['estado'] ?? ''}'.toUpperCase();
    final finalizado = _esFinal(estado);
    final prov = _detalle['proveedor'] is Map
        ? '${(_detalle['proveedor'] as Map)['razon_social'] ?? ''}'
        : '';
    final fechaEst = [
      '${_detalle['fecha_entrega_estimada'] ?? ''}',
      '${_detalle['fecha_estimada_llegada_formateada'] ?? ''}',
      '${o['fecha_estimada_llegada_formateada'] ?? ''}',
      '${o['fecha_entrega_estimada'] ?? ''}',
    ].firstWhere((f) => f.isNotEmpty && f != 'null', orElse: () => '');
    final observacion = '${_detalle['observacion'] ?? ''}';

    return Container(
      width: double.infinity,
      color: AppColors.celesteTint.withValues(alpha: .35),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.local_shipping_rounded,
                  size: 15, color: AppColors.celesteDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    prov.isEmpty || prov == 'null' ? 'Proveedor' : prov,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.celesteDeep)),
              ),
              if (fechaEst.isNotEmpty)
                Text('Llegada: $fechaEst',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          if (observacion.isNotEmpty && observacion != 'null') ...[
            const SizedBox(height: 4),
            Text('Obs.: $observacion',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, color: AppColors.textMuted)),
          ],
          const SizedBox(height: 8),
          if (_items.isEmpty)
            Text('Sin productos registrados en esta orden.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          for (final it in _items) _filaItem(it, finalizado),
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
                          ? 'Recepción cerrada.'
                          : 'Marca check en cada producto; al completar el último, la recepción se cierra sola.',
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
    final id = '${it['id'] ?? ''}';
    final solicitada = _num(it['cantidad']);
    final recibida = _num(it['cantidad_recibida']);
    final pendiente = it['cantidad_pendiente'] != null
        ? _num(it['cantidad_pendiente'])
        : (solicitada - recibida) < 0
            ? 0.0
            : (solicitada - recibida);
    final abrev = '${it['unidad_medida_abreviatura'] ?? it['unidad_nombre'] ?? ''}';
    final sufijo = abrev.isNotEmpty && abrev != 'null' ? ' $abrev' : '';
    final factor = _num(it['factor_conversion']);
    final rechazado = it['rechazado'] == true ||
        '${it['estado_recepcion'] ?? ''}'.toUpperCase() == 'RECHAZADO';

    // Orden cerrada o ítem ya decidido (recibido completo / rechazado)
    // → SOLO lectura: pill con lo recibido, sin caja ni check/X.
    final decidido = rechazado || (pendiente <= 0 && recibida > 0);
    if (finalizado || decidido) {
      final completo = !rechazado && pendiente <= 0 && recibida > 0;
      final colorBg = rechazado
          ? AppColors.errorBg
          : (completo ? AppColors.successBg : AppColors.warningBg);
      final colorBorde = rechazado
          ? AppColors.errorBorder
          : (completo ? AppColors.successBorder : AppColors.warningBorder);
      final colorTexto = rechazado
          ? AppColors.errorDark
          : (completo ? AppColors.successDark : AppColors.warningDark);
      final etiqueta = rechazado
          ? 'Rechazado'
          : (recibida <= 0
              ? 'No recibido'
              : (completo
                  ? 'Recibido: ${_fmt(recibida)}$sufijo'
                  : 'Recibido: ${_fmt(recibida)} de ${_fmt(solicitada)}'));

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

    // Orden abierta → caja de cantidad + check (recepcionar) + X (rechazar).
    if (!_cantCtrls.containsKey(id)) {
      final inicial = pendiente > 0 ? pendiente : solicitada;
      _cantCtrls[id] = TextEditingController(text: _fmt(inicial));
    }
    final enProceso = _itemOcupado == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
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
                    'Solicitado: ${_fmt(solicitada)}$sufijo'
                    '${recibida > 0 ? ' · Recibido: ${_fmt(recibida)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                if (factor > 1)
                  Text('${_fmt(factor)} unidades físicas por $abrev',
                      style: TextStyle(
                          fontSize: 9.5, color: AppColors.celesteDeep)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 58,
            child: TextField(
              controller: _cantCtrls[id],
              enabled: !enProceso,
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
            color: AppColors.success,
            ocupado: enProceso,
            onTap: enProceso ? null : () => _recepcionar(it),
          ),
          const SizedBox(width: 4),
          _botonAccion(
            icon: Icons.close_rounded,
            color: AppColors.error,
            ocupado: false,
            onTap: enProceso ? null : () => _rechazar(it),
          ),
        ],
      ),
    );
  }

  Widget _botonAccion({
    required IconData icon,
    required Color color,
    required bool ocupado,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onTap == null ? AppColors.celesteTint : color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: ocupado
            ? const Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon,
                size: 17,
                color: onTap == null ? AppColors.textMuted : Colors.white),
      ),
    );
  }

  // ---------------- recepcionar / rechazar / cerrar ----------------

  Future<void> _recepcionar(Map<String, dynamic> it) async {
    final ordenId = _expandido;
    if (ordenId == null || _itemOcupado != null) return;
    final id = '${it['id'] ?? ''}';
    final solicitada = _num(it['cantidad']);
    final recibida = _num(it['cantidad_recibida']);
    final pendiente = it['cantidad_pendiente'] != null
        ? _num(it['cantidad_pendiente'])
        : (solicitada - recibida) < 0
            ? 0.0
            : (solicitada - recibida);
    final cant = _num(_cantCtrls[id]?.text);

    if (cant <= 0) {
      _snack(context, 'Ingresa una cantidad mayor a 0 a recepcionar.');
      return;
    }
    if (cant > pendiente) {
      _snack(context,
          'La cantidad no puede superar lo pendiente (${_fmt(pendiente)}).');
      return;
    }

    setState(() => _itemOcupado = id);
    try {
      await _svc.recepcionarItem(ordenId, detalleId: id, cantidad: cant);
      if (!mounted) return;
      final factor = _num(it['factor_conversion']);
      final abrev =
          '${it['unidad_medida_abreviatura'] ?? it['unidad_nombre'] ?? ''}';
      final unidadesFisicas = factor > 1 ? ' (+${_fmt(cant * factor)} físicas)' : '';
      _snack(context, 'Ingresado: ${_fmt(cant)} $abrev$unidadesFisicas al stock.');
      await _recargarDetalle(ordenId);
      _quizasCerrar(ordenId);
    } catch (e) {
      if (mounted) _snack(context, '$e');
    } finally {
      if (mounted) setState(() => _itemOcupado = null);
    }
  }

  Future<void> _rechazar(Map<String, dynamic> it) async {
    final ordenId = _expandido;
    if (ordenId == null || _itemOcupado != null) return;
    final id = '${it['id'] ?? ''}';
    final nombre = '${it['producto_nombre'] ?? 'el producto'}';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rechazar producto',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
            '¿Rechazar "$nombre"? El ítem no ingresará al almacén ni afectará el stock.',
            style: const TextStyle(fontSize: 12.5)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar',
                style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Rechazar',
                style: TextStyle(
                    color: AppColors.errorDark,
                    fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _itemOcupado = id);
    try {
      await _svc.rechazarItemRecepcion(ordenId, detalleId: id);
      if (!mounted) return;
      _snack(context, '"$nombre" marcado como rechazado.');
      await _recargarDetalle(ordenId);
      _quizasCerrar(ordenId);
    } catch (e) {
      if (mounted) _snack(context, '$e');
    } finally {
      if (mounted) setState(() => _itemOcupado = null);
    }
  }

  Future<void> _recargarDetalle(String ordenId) async {
    try {
      final d = await _svc.ordenCompraDetalle(ordenId);
      if (!mounted || _expandido != ordenId) return;
      // Conserva las cantidades escritas que sigan haciendo falta.
      final items = (d['detalles'] is List)
          ? (d['detalles'] as List).whereType<Map>().toList()
          : const [];
      for (final it in items) {
        final id = '${it['id'] ?? ''}';
        final pend = _num(it['cantidad_pendiente']);
        if (_cantCtrls.containsKey(id) && pend > 0) {
          _cantCtrls[id]!.text = _fmt(pend);
        }
      }
      setState(() => _detalle = d);
      _cargar(spinner: false);
    } catch (_) {
      // Si falla la recarga, se mantiene la vista actual.
    }
  }

  void _quizasCerrar(String ordenId) {
    final items = _items;
    if (items.isEmpty) return;
    for (final it in items) {
      final rechazado = it['rechazado'] == true ||
          '${it['estado_recepcion'] ?? ''}'.toUpperCase() == 'RECHAZADO';
      final pendiente = it['cantidad_pendiente'] != null
          ? _num(it['cantidad_pendiente'])
          : (_num(it['cantidad']) - _num(it['cantidad_recibida']));
      if (!rechazado && pendiente > 0) return; // aún faltan productos
    }
    _cerrarRecepcion(ordenId);
  }

  Future<void> _cerrarRecepcion(String ordenId) async {
    if (_cerrando || _expandido != ordenId) return;
    setState(() => _cerrando = true);
    try {
      final res = await _svc.cerrarRecepcion(ordenId);
      if (!mounted) return;
      final data = res['data'];
      final estadoTexto =
          data is Map ? '${data['estado_texto'] ?? ''}' : '';
      _snack(
          context,
          'Recepción de $ordenId cerrada'
          '${estadoTexto.isNotEmpty ? ': $estadoTexto' : '.'}');
      setState(() => _expandido = null);
      _limpiarExpansion();
      await _cargar(spinner: false);
    } catch (e) {
      if (!mounted) return;
      _snack(context, '$e');
      // Si ya no está en recepción, refrescar la tabla igualmente.
      if ('$e'.toLowerCase().contains('estado') || '$e'.contains('proceso')) {
        setState(() => _expandido = null);
        _limpiarExpansion();
        _cargar(spinner: false);
      }
    } finally {
      if (mounted) setState(() => _cerrando = false);
    }
  }

  Widget _vacio() => const ErpEmptyState(
        icon: Icons.unarchive_outlined,
        title: 'Sin órdenes',
        message: 'No hay órdenes de compra para este filtro.',
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
