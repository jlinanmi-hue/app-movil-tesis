import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';

/// Modal compacto (no hoja de pantalla completa) con el detalle del pedido:
/// cabecera con código + estado, información clave, listado breve de
/// productos (con imagen cuando existe) y acciones Editar / Eliminar.
/// Se cierra con la X o tocando fuera.
class PedidoDetalleDialog extends StatefulWidget {
  final String pedidoId;
  final Map<String, dynamic> resumen;
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const PedidoDetalleDialog({
    super.key,
    required this.pedidoId,
    this.resumen = const {},
    this.onEditar,
    this.onEliminar,
  });

  static Future<void> mostrar(
    BuildContext context, {
    required String pedidoId,
    Map<String, dynamic> resumen = const {},
    VoidCallback? onEditar,
    VoidCallback? onEliminar,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .38),
      builder: (_) => PedidoDetalleDialog(
        pedidoId: pedidoId,
        resumen: resumen,
        onEditar: onEditar,
        onEliminar: onEliminar,
      ),
    );
  }

  @override
  State<PedidoDetalleDialog> createState() => _PedidoDetalleDialogState();
}

class _PedidoDetalleDialogState extends State<PedidoDetalleDialog> {
  final _svc = ModulesService();
  bool _cargando = true;
  String? _error;
  Map<String, dynamic> _d = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _svc.pedidoDetalle(widget.pedidoId);
      if (!mounted) return;
      setState(() {
        _d = d;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  bool get _esPendiente {
    final e =
        '${_d['estado'] ?? widget.resumen['estado'] ?? ''}'.toUpperCase();
    if (e.isEmpty) return false;
    return e == 'P' || e.startsWith('PENDIENTE');
  }

  // ---------------- cabecera ----------------

  Widget _cabecera() {
    final badge = _badge(
        '${_d['estado_texto'] ?? widget.resumen['estado'] ?? ''}'.trim());
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
      child: Row(
        children: [
          const ErpIconTile(
              icon: Icons.receipt_long_rounded, size: 42, radius: 14),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.pedidoId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.2)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badge.bg,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: badge.border),
                  ),
                  child: Text(badge.label,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: badge.text,
                          letterSpacing: .3)),
                ),
              ],
            ),
          ),
          ErpCircleButton(
            icon: Icons.close_rounded,
            size: 34,
            tooltip: 'Cerrar',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  ({String label, Color bg, Color border, Color text}) _badge(String raw) {
    final s = raw.toUpperCase();
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
    if (s.startsWith('COMPLET')) {
      return (
        label: 'Completada',
        bg: AppColors.successBg,
        border: AppColors.successBorder,
        text: AppColors.successDark
      );
    }
    if (s.startsWith('CANCEL') || s.contains('ANULAD')) {
      return (
        label: 'Cancelada',
        bg: AppColors.errorBg,
        border: AppColors.errorBorder,
        text: AppColors.errorDark
      );
    }
    return (
      label: s.isEmpty ? 'Sin estado' : raw,
      bg: AppColors.celesteTint,
      border: AppColors.celesteBg,
      text: AppColors.celesteDeep
    );
  }

  // ---------------- contenido ----------------

  Widget _cargandoWidget() {
    return SizedBox(
      height: 180,
      child: Center(
        child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.4, color: AppColors.celesteDark)),
      ),
    );
  }

  Widget _errorWidget() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded,
              size: 34, color: AppColors.textSubtle),
          const SizedBox(height: 8),
          Text(_error ?? 'No se pudo cargar el detalle.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          ErpSoftButton(
            expand: false,
            icon: Icons.refresh_rounded,
            label: 'Reintentar',
            onTap: _cargar,
          ),
        ],
      ),
    );
  }

  Widget _contenido() {
    final cli = _d['cliente'] is Map
        ? Map<String, dynamic>.from(_d['cliente'] as Map)
        : <String, dynamic>{};
    final zona = _d['zona_delivery'] is Map
        ? Map<String, dynamic>.from(_d['zona_delivery'] as Map)
        : <String, dynamic>{};
    final detalles = _d['detalles'] is List
        ? (_d['detalles'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final esDelivery = _d['es_delivery'] == true;
    final direccion = '${_d['direccion_entrega'] ?? ''}';
    final total = _num(_d['total']);
    final esCotizacion = _d['tipo_registro'] == 'Cotización';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _info('Cliente', '${cli['nombre'] ?? '—'}'),
          if ('${cli['dni_ruc'] ?? ''}'.trim().isNotEmpty)
            _info('Doc.', '${cli['dni_ruc']}'),
          _info('Fecha', '${_d['fecha_formateada'] ?? '—'}'),
          if (esCotizacion) _info('Tipo', 'Cotización'),
          if (_fechaEntregaTexto().isNotEmpty)
            _info('Entrega', _fechaEntregaTexto()),
          _info(
              'Productos',
              '${_d['total_items'] ?? detalles.length} ítem(s) · '
                  '${_fmt(_num(_d['total_unidades']))} unidad(es)'),
          if (esDelivery && direccion.isNotEmpty && direccion != 'null')
            _info('Delivery',
                '${zona['nombre'] != null ? '${zona['nombre']} · ' : ''}$direccion'),
          _info('Total', 'S/ ${_fmt(total)}', fuerte: true),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 14, color: AppColors.celesteDark),
              const SizedBox(width: 6),
              Text('Listado de productos',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textDark)),
              const Spacer(),
              Text('${detalles.length} línea(s)',
                  style: TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 2),
          if (detalles.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 10),
              child: Text('Sin productos registrados en este pedido.',
                  style:
                      TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            )
          else
            for (final it in detalles) _filaProducto(it),
        ],
      ),
    );
  }

  String _fechaEntregaTexto() {
    final f = '${_d['fecha_entrega_formateada'] ?? ''}'.trim();
    return (f.isEmpty || f == 'null') ? '' : f;
  }

  Widget _info(String label, String valor, {bool fuerte = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(valor,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight:
                        fuerte ? FontWeight.w900 : FontWeight.w700,
                    color: fuerte
                        ? AppColors.celesteDeep
                        : AppColors.textDark)),
          ),
        ],
      ),
    );
  }

  Widget _filaProducto(Map<String, dynamic> it) {
    final nombre = '${it['producto_nombre'] ?? 'Producto'}';
    final abrev = '${it['unidad_abreviatura'] ?? ''}';
    final cant = _num(it['cantidad']);
    final subtotal = _num(it['subtotal']);
    final img = _urlImagen(it['producto_imagen']);

    return Container(
      margin: const EdgeInsets.only(top: 7),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.celesteTint.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          _miniatura(img),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                        height: 1.15)),
                const SizedBox(height: 2),
                Text(
                    '× ${_fmt(cant)}${abrev.isNotEmpty && abrev != 'null' ? ' $abrev' : ''}',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('S/ ${_fmt(subtotal)}',
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.celesteDeep)),
        ],
      ),
    );
  }

  Widget _miniatura(String? url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 36,
        height: 36,
        color: AppColors.celesteTint,
        child: url == null
            ? const _FolioProducto()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const _FolioProducto(),
              ),
      ),
    );
  }

  // ---------------- acciones ----------------

  Widget _acciones() {
    final puedeEditar = _esPendiente && widget.onEditar != null;
    final puedeEliminar = _esPendiente && widget.onEliminar != null;
    if (!puedeEditar && !puedeEliminar) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 9,
        children: [
          if (puedeEditar)
            ErpPillButton(
              label: 'Editar pedido',
              icon: Icons.edit_outlined,
              primary: true,
              expand: false,
              onTap: () {
                Navigator.of(context).pop();
                widget.onEditar!.call();
              },
            ),
          if (puedeEliminar)
            ErpPillButton(
              label: 'Eliminar',
              icon: Icons.delete_outline_rounded,
              danger: true,
              expand: false,
              onTap: () {
                Navigator.of(context).pop();
                widget.onEliminar!.call();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * .78;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: AppColors.surfaceLight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cabecera(),
            Divider(height: 1, color: AppColors.borderSoft),
            Flexible(
              child: _cargando
                  ? _cargandoWidget()
                  : (_error != null ? _errorWidget() : _contenido()),
            ),
            if (!_cargando && _error == null) _acciones(),
          ],
        ),
      ),
    );
  }
}

class _FolioProducto extends StatelessWidget {
  const _FolioProducto();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(Icons.inventory_2_outlined,
          size: 17, color: AppColors.celesteDark),
    );
  }
}

String? _urlImagen(dynamic ruta) {
  final p = '${ruta ?? ''}'.trim();
  if (p.isEmpty || p == 'null' || p.startsWith('Sin imagenes')) return null;
  if (p.startsWith('http')) return p;
  final base = ApiConfig.currentBaseUrl;
  final server =
      base.endsWith('/api') ? base.substring(0, base.length - 4) : base;
  return '$server$p';
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);
