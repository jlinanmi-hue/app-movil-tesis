import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/erp_ui.dart';

/// Modal con el detalle completo de un movimiento del Kárdex.
///
/// Se alimenta con la fila ya cargada: la vista de Kárdex devuelve todos los
/// campos enriquecidos (producto, cantidades, costo, documento, usuario), por
/// lo que el detalle abre al instante y sin una petición adicional.
class MovimientoDetalleDialog extends StatelessWidget {
  final Map<String, dynamic> movimiento;

  const MovimientoDetalleDialog({super.key, required this.movimiento});

  static Future<void> mostrar(
      BuildContext context, Map<String, dynamic> movimiento) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => MovimientoDetalleDialog(movimiento: movimiento),
    );
  }

  @override
  Widget build(BuildContext context) {
    final esEntrada = _esEntrada(movimiento);
    final id = _primero([
      movimiento['Movimiento_productoId'],
      movimiento['id'],
      '—',
    ]);

    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: MediaQuery.of(context).size.height * .84,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _cabecera(context, esEntrada: esEntrada, id: id),
            Divider(height: 1, color: AppColors.borderSoft),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
                child: _contenido(esEntrada),
              ),
            ),
            Divider(height: 1, color: AppColors.borderSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ErpPillButton(
                    label: 'Cerrar Detalle',
                    icon: Icons.close_rounded,
                    expand: false,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- cabecera ----------------

  Widget _cabecera(BuildContext context,
      {required bool esEntrada, required String id}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: esEntrada ? AppColors.successBg : AppColors.errorBg,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                  color: esEntrada
                      ? AppColors.successBorder
                      : AppColors.errorBorder),
            ),
            alignment: Alignment.center,
            child: Icon(
              esEntrada
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 20,
              color: esEntrada ? AppColors.successDark : AppColors.errorDark,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detalle del Movimiento',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark,
                        letterSpacing: -0.3)),
                const SizedBox(height: 2),
                Text('ID: $id',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted)),
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

  // ---------------- contenido ----------------

  Widget _contenido(bool esEntrada) {
    final producto = movimiento['producto'] is Map
        ? Map<String, dynamic>.from(movimiento['producto'] as Map)
        : <String, dynamic>{};
    final categoria = producto['categoria'] is Map
        ? Map<String, dynamic>.from(producto['categoria'] as Map)
        : <String, dynamic>{};
    final unidadMedida = movimiento['unidadMedida'] is Map
        ? Map<String, dynamic>.from(movimiento['unidadMedida'] as Map)
        : <String, dynamic>{};

    final nombre = _primero([
      movimiento['producto_nombre'],
      producto['ProductoNombre'],
      movimiento['ProductoNombre'],
      'Producto',
    ]);
    final productoId = _primero([
      movimiento['producto_id'],
      movimiento['Movimiento_producto_ProductoId'],
      producto['ProductoId'],
    ]);
    final marca = _primero([
      movimiento['producto_marca'],
      producto['ProductoMarca'],
      'Genérica',
    ]);
    final categoriaNombre = _primero([
      movimiento['categoria_nombre'],
      categoria['Categoria_ProductoDescripcion_categoria'],
      'General',
    ]);

    final cantPresentacion = _num(movimiento[
            'Movimiento_productoCantidadPresentacion'] ??
        movimiento['cantidad_presentacion'] ??
        movimiento['cantidad']);
    final unidadMovAbrev = _primero([
      movimiento['unidad_movimiento_abreviatura'],
      unidadMedida['unidades_medidaAbreviatura'],
      movimiento['unidad_abreviatura'],
    ]);
    final unidadMovNombre = _primero([
      movimiento['unidad_movimiento_nombre'],
      unidadMedida['unidades_medidaDescripcionUnidades'],
      unidadMovAbrev,
      'Unidad',
    ]);
    final cantidadTexto = _primero([
      movimiento['cantidad_presentacion_texto'],
    ]);
    final cantidadMostrada = cantidadTexto.isNotEmpty
        ? cantidadTexto
        : '${_fmt(cantPresentacion)}'
            '${unidadMovAbrev.isNotEmpty ? ' $unidadMovAbrev' : ''}';

    final saldo = _num(movimiento['Movimiento_productoCantidadSaldo'] ??
        movimiento['saldo_resultante'] ??
        movimiento['saldo']);
    final baseAbrev = _primero([
      movimiento['unidad_base_abreviatura'],
    ]);
    final baseNombre = _primero([
      movimiento['unidad_base_nombre'],
      baseAbrev,
      'Unidad',
    ]);
    final saldoTexto = _primero([
      movimiento['saldo_resultante_texto'],
    ]);
    final saldoMostrado = saldoTexto.isNotEmpty
        ? saldoTexto
        : '${_fmt(saldo)}'
            '${baseAbrev.isNotEmpty ? ' $baseAbrev' : ''}';

    final costoUnitario = _num(
        movimiento['Movimiento_productoCostoPrecioUnitario'] ??
            movimiento['precio_unitario'] ??
            movimiento['costo_unitario']);
    final costoTexto = _primero([
      movimiento['costo_precio_formateado'],
    ]);
    final costoMostrado =
        costoTexto.isNotEmpty ? costoTexto : 'S/ ${_money(costoUnitario)}';

    final totalRaw = movimiento['costo_total_estimado'];
    final total = totalRaw != null
        ? _num(totalRaw)
        : cantPresentacion * costoUnitario;
    final totalTexto = _primero([
      movimiento['costo_total_formateado'],
    ]);
    final totalMostrado =
        totalTexto.isNotEmpty ? totalTexto : 'S/ ${_money(total)}';

    final documento = _primero([
      movimiento['documento_referencia'],
      movimiento['Movimiento_productoDocumentoOperacionId'],
      '—',
    ]);
    final usuario = _primero([
      movimiento['usuario_creacion'],
      movimiento['Movimiento_productoUsuarioCreacion'],
      'Sistema',
    ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filaEstado(esEntrada),
        const SizedBox(height: 10),
        _fichaProducto(
          nombre: nombre,
          productoId: productoId,
          marca: marca,
          categoria: categoriaNombre,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metrica(
                'Cantidad operada',
                cantidadMostrada,
                'Unidad: $unidadMovNombre',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metrica(
                'Saldo stock resultante',
                saldoMostrado,
                'Unidad base: $baseNombre',
                valorColor: saldo <= 0
                    ? AppColors.errorDark
                    : AppColors.successDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _metrica(
                'Costo / precio unitario',
                costoMostrado,
                'Valor por unidad de medida',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metrica(
                'Valor total estimado',
                totalMostrado,
                'Cantidad × costo unitario',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _referencias(documento: documento, usuario: usuario),
      ],
    );
  }

  Widget _filaEstado(bool esEntrada) {
    final tipoOperacion = _tipoOperacion(movimiento, esEntrada);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: esEntrada ? AppColors.successBg : AppColors.errorBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: esEntrada
                      ? AppColors.successBorder
                      : AppColors.errorBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  esEntrada
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 12,
                  color:
                      esEntrada ? AppColors.successDark : AppColors.errorDark,
                ),
                const SizedBox(width: 4),
                Text(
                  esEntrada ? 'ENTRADA DE STOCK' : 'SALIDA / MERMA',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .3,
                      color: esEntrada
                          ? AppColors.successDark
                          : AppColors.errorDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: Text(
                  tipoOperacion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fichaProducto({
    required String nombre,
    required String productoId,
    required String marca,
    required String categoria,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.celesteBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('PRODUCTO INVOLUCRADO',
                    style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .5,
                        color: AppColors.celesteDeep)),
              ),
              if (productoId.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.celesteBg),
                  ),
                  child: Text(productoId,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(nombre,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  height: 1.15,
                  letterSpacing: -0.2)),
          const SizedBox(height: 3),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                    text: 'Marca: ',
                    style: TextStyle(color: AppColors.textMuted)),
                TextSpan(
                    text: marca,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
                TextSpan(
                    text: '  ·  ',
                    style: TextStyle(color: AppColors.textSubtle)),
                TextSpan(
                    text: 'Categoría: ',
                    style: TextStyle(color: AppColors.textMuted)),
                TextSpan(
                    text: categoria,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark)),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _metrica(String label, String valor, String detalle,
      {Color? valorColor}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                  color: AppColors.textSubtle)),
          const SizedBox(height: 4),
          Text(valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  color: valorColor ?? AppColors.textDark,
                  letterSpacing: -0.2)),
          const SizedBox(height: 2),
          Text(detalle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 9.5, color: AppColors.textMuted, height: 1.2)),
        ],
      ),
    );
  }

  Widget _referencias({required String documento, required String usuario}) {
    final fecha = _fechaTexto(movimiento);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        children: [
          _filaReferencia('Documento / Guía / Factura', documento,
              chip: true),
          const SizedBox(height: 8),
          _filaReferencia('Fecha y Hora de Registro', fecha),
          const SizedBox(height: 8),
          _filaReferencia('Registrado por', usuario),
        ],
      ),
    );
  }

  Widget _filaReferencia(String label, String valor, {bool chip = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(label,
              maxLines: 2,
              style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: chip
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: Text(valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                )
              : Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
        ),
      ],
    );
  }
}

// ==================== helpers ====================

bool _esEntrada(Map<String, dynamic> m) {
  final badge = _txt(m['tipo_movimiento_badge']).toUpperCase();
  if (badge == 'ENTRADA') return true;
  if (badge == 'SALIDA') return false;
  return _txt(m['Movimiento_productoTipoMovimiento']).toUpperCase() == 'E';
}

String _tipoOperacion(Map<String, dynamic> m, bool esEntrada) {
  final explicito = _txt(m['tipo_operacion_texto']);
  if (explicito.isNotEmpty) return explicito;

  final subtipo =
      _txt(m['Movimiento_productoSubtipo'] ?? m['subtipo']).toUpperCase();
  final doc = _txt(m['Movimiento_productoDocumentoOperacionId'] ??
          m['documento_referencia'])
      .toUpperCase();

  switch (subtipo) {
    case 'RECEPCION_OC':
      return 'Recepción de Orden de Compra';
    case 'ANULACION_RECEPCION':
      return 'Contra-Movimiento (Anulación OC)';
    case 'COMPRA_RAPIDA':
      return 'Compra Rápida a PYME Vecina';
    case 'AJUSTE_MANUAL':
      return 'Ajuste Manual de Kárdex';
    case 'DEVOLUCION_CLIENTE':
      return 'Devolución de Pedido Cliente';
    case 'INVENTARIO_INICIAL':
      return 'Inventario Inicial';
  }
  if (doc.startsWith('AJU-')) return 'Ajuste / Merma de Inventario';
  if (doc.startsWith('REV-')) return 'Reversión de Ajuste';
  if (doc.startsWith('INV-')) return 'Inventario Inicial';
  if (doc.startsWith('PED-')) return 'Salida por Pedido de Venta';
  if (doc.startsWith('F') || doc.startsWith('B') || doc.startsWith('DOC-')) {
    return esEntrada ? 'Recepción / Compra' : 'Salida de Mercadería';
  }
  return esEntrada ? 'Recepción / Compra' : 'Salida de Mercadería';
}

String _fechaTexto(Map<String, dynamic> m) {
  final raw = _primero([
    m['fecha_movimiento_formateada'],
    m['Movimiento_productoFecha_Movimiento'],
  ]);
  if (raw.isEmpty) {
    final solo = _txt(m['fecha_solo']);
    final hora = _txt(m['hora_solo']);
    final unido = [solo, hora].where((e) => e.isNotEmpty).join(' ');
    return unido.isEmpty ? '—' : unido;
  }
  final normal = raw.replaceFirst('T', ' ');
  return normal.length > 16 ? normal.substring(0, 16) : normal;
}

String _primero(List<dynamic> valores) {
  for (final v in valores) {
    final s = _txt(v);
    if (s.isNotEmpty) return s;
  }
  return '';
}

String _txt(dynamic v) {
  final s = '${v ?? ''}'.trim();
  return (s == 'null' || s == 'undefined') ? '' : s;
}

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);

String _money(double d) => d.toStringAsFixed(2);
