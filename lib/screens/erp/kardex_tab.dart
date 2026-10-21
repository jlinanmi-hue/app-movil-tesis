import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import 'movimiento_detalle_dialog.dart';

/// KARDEX · Una sola tabla responsiva para móvil (con marcos y todo):
///   · filtro de fechas (desde / hasta)
///   · combo de tipo de movimiento: Todos · Entradas · Salidas
/// La tabla se actualiza sola al cambiar cualquier filtro.
class KardexTab extends StatefulWidget {
  const KardexTab({super.key});

  @override
  State<KardexTab> createState() => _KardexTabState();
}

class _KardexTabState extends State<KardexTab> {
  final _svc = ModulesService();
  String? _tipo; // null = todos · 'E' entradas · 'S' salidas
  DateTime? _desde;
  DateTime? _hasta;
  bool _cargando = true;
  List<Map<String, dynamic>> _filas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final data = await _svc.kardexMovimientos(
      tipo: _tipo,
      fechaDesde:
          _desde == null ? null : DateFormat('yyyy-MM-dd').format(_desde!),
      fechaHasta:
          _hasta == null ? null : DateFormat('yyyy-MM-dd').format(_hasta!),
    );
    if (!mounted) return;
    setState(() {
      _filas = data;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ------- filtros: tipo de movimiento + rango de fechas -------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              ErpDropdownField<String?>(
                label: 'Tipo de movimiento',
                hint: 'Todos',
                icon: Icons.swap_vert_rounded,
                value: _tipo,
                options: const [
                  ErpDropdownOption(
                      value: null,
                      label: 'Todos',
                      subtitle: 'Entradas y salidas'),
                  ErpDropdownOption(value: 'E', label: 'Entradas'),
                  ErpDropdownOption(value: 'S', label: 'Salidas'),
                ],
                onChanged: (v) {
                  setState(() => _tipo = v);
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
                    children: [_filas.isEmpty ? _vacio() : _tabla()],
                  ),
                ),
        ),
      ],
    );
  }

  // ---------------- tabla ----------------

  Widget _tabla() {
    return ErpTableFrame(
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(56),
          1: FlexColumnWidth(2.4),
          2: FixedColumnWidth(70),
          3: FixedColumnWidth(46),
        },
        border: TableBorder.symmetric(
            inside: BorderSide(color: AppColors.borderSoft, width: 1)),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            _celda(_txtCabecera('Fecha'), header: true),
            _celda(_txtCabecera('Producto'), header: true),
            _celda(_txtCabecera('Tipo'), header: true),
            _celda(_txtCabecera('Cant.'), header: true),
          ]),
          ..._filas.map(_filaDato),
        ],
      ),
    );
  }

  Widget _txtCabecera(String t) => Text(t,
      style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          letterSpacing: 0.2));

  Widget _celda(Widget child,
          {bool header = false,
          Alignment align = Alignment.centerLeft,
          VoidCallback? onTap}) {
    final content = Container(
      alignment: align,
      color: header ? AppColors.celesteTint : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: child,
    );
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }

  TableRow _filaDato(Map<String, dynamic> j) {
    final tipo = '${j['Movimiento_productoTipoMovimiento'] ?? ''}'.toUpperCase();
    final esEntrada = tipo == 'E';
    final esSalida = tipo == 'S';
    void abrirDetalle() {
      HapticFeedback.selectionClick();
      MovimientoDetalleDialog.mostrar(context, j);
    }

    final prod = j['producto'];
    final nombre = prod is Map
        ? '${prod['ProductoNombre'] ?? 'Producto'}'
        : '${j['producto_nombre'] ?? j['ProductoNombre'] ?? 'Producto'}';

    final doc = '${j['Movimiento_productoDocumentoOperacionId'] ?? ''}';
    final motivo =
        '${j['Movimiento_productoSubtipo'] ?? j['Movimiento_productoMotivo'] ?? ''}';
    var detalle = (doc.isNotEmpty && doc != 'null') ? doc : motivo;
    if (detalle == 'null') detalle = '';

    final fecha = _fechaDe(j);
    final hora = _horaDe(j);
    final cant = _cantidadDe(j);

    return TableRow(children: [
      _celda(Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fecha,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark)),
          if (hora.isNotEmpty)
            Text(hora,
                style: TextStyle(
                    fontSize: 9.5, color: AppColors.textMuted)),
        ],
      ), onTap: abrirDetalle),
      _celda(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.15)),
                if (detalle.isNotEmpty)
                  Text(detalle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded,
              size: 15, color: AppColors.celesteDeep),
        ],
      ), onTap: abrirDetalle),
      _celda(
        esEntrada || esSalida
            ? Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      esEntrada ? AppColors.successBg : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: esEntrada
                          ? AppColors.successBorder
                          : AppColors.errorBorder),
                ),
                child: Text(esEntrada ? 'Entrada' : 'Salida',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: esEntrada
                            ? AppColors.successDark
                            : AppColors.errorDark)),
              )
            : Text('—',
                style:
                    TextStyle(fontSize: 11, color: AppColors.textMuted)),
        align: Alignment.center,
        onTap: abrirDetalle,
      ),
      _celda(
        Text(cant.texto,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: cant.color)),
        align: Alignment.center,
        onTap: abrirDetalle,
      ),
    ]);
  }

  ({String texto, Color color}) _cantidadDe(Map<String, dynamic> j) {
    final tipo = '${j['Movimiento_productoTipoMovimiento'] ?? ''}'.toUpperCase();
    final raw = j['Movimiento_productoCantidadPresentacion'] ??
        j['cantidad_presentacion'] ??
        j['Movimiento_productoCantidadEntrada'] ??
        j['Movimiento_productoCantidadSalida'] ??
        j['cantidad'];
    final esSalida = tipo == 'S';
    return (
      texto: '${esSalida ? '-' : '+'}${_fmt(_num(raw))}',
      color: esSalida ? AppColors.errorDark : AppColors.successDark,
    );
  }

  String _fechaDe(Map<String, dynamic> j) {
    final raw = '${j['fecha_solo'] ?? j['Movimiento_productoFecha_Movimiento'] ?? j['fecha_movimiento_formateada'] ?? ''}';
    if (raw.isEmpty || raw == 'null') return '—';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
    return DateFormat('dd/MM').format(d);
  }

  String _horaDe(Map<String, dynamic> j) {
    final h = j['hora_solo'];
    if (h != null && '$h'.isNotEmpty && '$h' != 'null') return '$h';
    final raw = '${j['Movimiento_productoFecha_Movimiento'] ?? ''}';
    final d = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
    if (d == null) return '';
    return DateFormat('HH:mm').format(d);
  }

  Widget _vacio() => const ErpEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Sin movimientos',
        message: 'No hay registros para los filtros seleccionados.',
        padding: EdgeInsets.only(top: 70),
      );
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);
