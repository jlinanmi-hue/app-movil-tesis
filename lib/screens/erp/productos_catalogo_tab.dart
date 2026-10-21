import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import 'producto_presentaciones.dart';

/// STOCK Y PRODUCTOS (solo consulta)
/// En el móvil NO se registran ni editan productos (eso es solo web).
///  · buscador por nombre, marca o categoría
///  · lista de productos paginada: se cargan 15 y al llegar al final de la
///    lista se piden 15 más (scroll infinito)
///  · al tocar un producto: modal compacto con sus presentaciones, el precio
///    de venta/compra de cada una y las unidades disponibles
class ProductosTab extends StatefulWidget {
  const ProductosTab({super.key});

  @override
  State<ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<ProductosTab> {
  static const int _porPagina = 15;

  final _svc = ModulesService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _debounce;

  bool _cargando = true; // primera página / búsqueda
  bool _cargandoMas = false; // página siguiente
  String? _error;

  List<Map<String, dynamic>> _items = [];
  int _pagina = 1;
  int _ultimaPagina = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _cargar(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final falda = _scrollCtrl.position.maxScrollExtent -
        _scrollCtrl.position.pixels;
    if (falda < 320) _cargarMas();
  }

  Future<void> _cargar({bool reset = false, bool spinner = true}) async {
    if (reset) {
      setState(() {
        if (spinner) _cargando = true;
        _error = null;
        _pagina = 1;
      });
    }
    try {
      final q = _searchCtrl.text.trim();
      var res = await _svc.productosPagina(
        search: q,
        page: 1,
        perPage: _porPagina,
      );
      var items = (res['items'] as List).cast<Map<String, dynamic>>();

      // Fallback si la búsqueda directa no trajo resultados por sensibilidad a mayúsculas
      if (q.isNotEmpty && items.isEmpty) {
        final fullRes = await _svc.productosPagina(
          search: '',
          page: 1,
          perPage: 60,
        );
        final fullItems = (fullRes['items'] as List).cast<Map<String, dynamic>>();
        final qLower = q.toLowerCase();
        items = fullItems.where((p) {
          final nom = '${p['ProductoNombre'] ?? ''}'.toLowerCase();
          final cod = '${p['ProductoCodigo'] ?? p['id'] ?? ''}'.toLowerCase();
          final cat = '${p['categoria_nombre'] ?? ''}'.toLowerCase();
          return nom.contains(qLower) || cod.contains(qLower) || cat.contains(qLower);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _items = items;
        _pagina = (res['currentPage'] as int?) ?? 1;
        _ultimaPagina = (res['lastPage'] as int?) ?? 1;
        _total = items.length;
        _cargando = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = '$e';
      });
    }
  }

  Future<void> _cargarMas() async {
    if (_cargando || _cargandoMas || _pagina >= _ultimaPagina) return;
    setState(() => _cargandoMas = true);
    try {
      final res = await _svc.productosPagina(
        search: _searchCtrl.text.trim(),
        page: _pagina + 1,
        perPage: _porPagina,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll((res['items'] as List).cast<Map<String, dynamic>>());
        _pagina = (res['currentPage'] as int?) ?? (_pagina + 1);
        _ultimaPagina = (res['lastPage'] as int?) ?? _ultimaPagina;
        _total = (res['total'] as int?) ?? _total;
        _cargandoMas = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoMas = false);
    }
  }

  void _onBuscar(String _) {
    _debounce?.cancel();
    _debounce =
        Timer(const Duration(milliseconds: 400), () => _cargar(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ------- buscador -------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: ErpSearchField(
            controller: _searchCtrl,
            hint: 'Buscar producto por nombre, marca o categoría...',
            loading: _cargando,
            onChanged: _onBuscar,
            onClear: () {
              _searchCtrl.clear();
              _cargar(reset: true);
            },
          ),
        ),
        Expanded(
          child: _cargando
              ? Center(
                  child:
                      CircularProgressIndicator(color: AppColors.celesteDark))
              : RefreshIndicator(
                  color: AppColors.celesteDark,
                  onRefresh: () => _cargar(reset: true, spinner: false),
                  child: _error != null && _items.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            ErpEmptyState(
                              icon: Icons.cloud_off_rounded,
                              title: 'No se pudo cargar',
                              message: '$_error\nDesliza hacia abajo para '
                                  'reintentar.',
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scrollCtrl,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 2, 16, 96),
                          itemCount: _items.isEmpty
                              ? 1
                              : _items.length + 1, // +1: pie de lista
                          itemBuilder: (_, i) {
                            if (_items.isEmpty) return _vacio();
                            if (i == _items.length) return _pie();
                            return _tarjetaProducto(_items[i]);
                          },
                        ),
                ),
        ),
      ],
    );
  }

  // ---------------- tarjeta de producto ----------------

  Widget _tarjetaProducto(Map<String, dynamic> p) {
    final nombre = '${p['ProductoNombre'] ?? 'Producto'}';
    final marca = '${p['ProductoMarca'] ?? ''}';
    final categoria = '${p['categoria_nombre'] ?? ''}';
    final sub = [
      if (marca.isNotEmpty && marca != 'null') marca,
      if (categoria.isNotEmpty && categoria != 'null') categoria,
    ].join(' · ');

    final stock = _num(p['ProductoStockActual'] ?? p['stock_total_vendible']);
    final alerta = '${p['alerta_stock'] ?? ''}';
    final abrev = '${p['unidad_base_abreviatura'] ?? p['unidad_base'] ?? ''}';
    final precio = _precioVentaBase(p);

    final (chipBg, chipBorde, chipTexto, chipLabel) = switch (alerta) {
      'AGOTADO' => (
          AppColors.errorBg,
          AppColors.errorBorder,
          AppColors.errorDark,
          'Agotado'
        ),
      'STOCK_MINIMO' => (
          AppColors.warningBg,
          AppColors.warningBorder,
          AppColors.warningDark,
          'Bajo'
        ),
      _ => (
          AppColors.celesteTint,
          AppColors.celesteBg,
          AppColors.celesteDeep,
          '${_fmt(stock)}${abrev.isNotEmpty && abrev != 'null' ? ' $abrev' : ''}'
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ErpSoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        onTap: () => _ProductoDetalleDialog.mostrar(context, p),
        child: Row(
          children: [
            const ErpIconTile(
                icon: Icons.inventory_2_rounded, size: 38, radius: 12),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                          height: 1.15)),
                  if (sub.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(precio == null ? '—' : 'S/ ${_fmt(precio)}',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.celesteDeep)),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: chipBorde),
                  ),
                  child: Text(chipLabel,
                      style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: chipTexto)),
                ),
              ],
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.celesteDeep),
          ],
        ),
      ),
    );
  }

  double? _precioVentaBase(Map<String, dynamic> p) {
    final base = p['precio_venta_base'];
    if (base != null && _num(base) > 0) return _num(base);

    final dets = detallesProducto(p);
    double? primero;
    for (final d in dets) {
      final factor = _num(d['Detalle_Producto_medida_factor_conversion'] ??
          d['factor_conversion']);
      final precio = _num(d['Detalle_Producto_medida_precio_venta'] ??
          d['precio_venta']);
      primero ??= precio;
      if (factor == 1) return precio;
    }
    if (primero != null) return primero;

    final unis = p['unidades'];
    if (unis is List) {
      double? primeroUnidad;
      for (final u in unis.whereType<Map>()) {
        final precio = _num(u['precio_venta']);
        primeroUnidad ??= precio;
        if (u['es_base'] == true || u['es_base'] == 1) return precio;
      }
      if (primeroUnidad != null) return primeroUnidad;
    }
    return null;
  }

  // ---------------- pie / vacío ----------------

  Widget _pie() {
    if (_cargandoMas) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.celesteDark)),
        ),
      );
    }
    if (_pagina >= _ultimaPagina && _items.length > _porPagina) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text('No hay más productos ($_total en total).',
              style: TextStyle(
                  fontSize: 10.5, color: AppColors.textMuted)),
        ),
      );
    }
    return const SizedBox(height: 4);
  }

  Widget _vacio() => const ErpEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Sin productos',
        message: 'No hay productos que coincidan con la búsqueda.',
      );
}

// ===================================================================
// MODAL COMPACTO DE PRODUCTO
// Presentaciones con su precio de venta/compra y unidades disponibles.
// ===================================================================

class _ProductoDetalleDialog extends StatelessWidget {
  final Map<String, dynamic> producto;
  const _ProductoDetalleDialog({required this.producto});

  static Future<void> mostrar(
      BuildContext context, Map<String, dynamic> producto) {
    return showDialog<void>(
      context: context,
      barrierColor: AppColors.scrim,
      builder: (_) => _ProductoDetalleDialog(producto: producto),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final nombre = '${producto['ProductoNombre'] ?? 'Producto'}';
    final marca = '${producto['ProductoMarca'] ?? ''}';
    final categoria = '${producto['categoria_nombre'] ?? ''}';
    final sub = [
      if (marca.isNotEmpty && marca != 'null') marca,
      if (categoria.isNotEmpty && categoria != 'null') categoria,
    ].join(' · ');
    final descripcion = '${producto['producto_descripcion'] ?? ''}'.trim();
    final mostrarDescripcion = descripcion.isNotEmpty &&
        descripcion != 'null' &&
        !descripcion.toLowerCase().startsWith('no se ingres');
    final stock = _num(
        producto['ProductoStockActual'] ?? producto['stock_total_vendible']);
    final abrev =
        '${producto['unidad_base_abreviatura'] ?? producto['unidad_base'] ?? ''}';
    final stockTexto = '${producto['stock_actual_formateado'] ?? ''}';
    final presentaciones = presentacionesDeProducto(producto);

    return Dialog(
      backgroundColor: AppColors.surfaceLight,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 430,
          maxHeight: media.size.height * .74,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ------- cabecera -------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ErpIconTile(
                      icon: Icons.inventory_2_rounded, size: 42, radius: 13),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(nombre,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textDark,
                                letterSpacing: -0.3)),
                        if (sub.isNotEmpty)
                          Text(sub,
                              style: TextStyle(
                                  fontSize: 11.5, color: AppColors.textMuted)),
                        if (mostrarDescripcion) ...[
                          const SizedBox(height: 3),
                          Text(descripcion,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.celesteTint,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.celesteBg),
                      ),
                      child: Icon(Icons.close_rounded,
                          size: 16, color: AppColors.celesteDeep),
                    ),
                  ),
                ],
              ),
            ),
            // ------- stock disponible -------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: stock <= 0
                          ? AppColors.errorBg
                          : AppColors.celesteTint,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: stock <= 0
                              ? AppColors.errorBorder
                              : AppColors.celesteBg),
                    ),
                    child: Text(
                        stockTexto.isNotEmpty && stockTexto != 'null'
                            ? 'Stock: $stockTexto'
                            : 'Stock: ${_fmt(stock)}'
                                '${abrev.isNotEmpty && abrev != 'null' ? ' $abrev' : ''}',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: stock <= 0
                                ? AppColors.errorDark
                                : AppColors.celesteDeep)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.borderSoft),
            // ------- presentaciones -------
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Presentaciones',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    if (presentaciones.isEmpty)
                      Text('Sin presentaciones registradas.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textMuted)),
                    for (final pr in presentaciones) _filaPresentacion(pr),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaPresentacion(PresentacionProducto pr) {
    final stock = _num(
        producto['ProductoStockActual'] ?? producto['stock_total_vendible']);
    final abrevBase =
        '${producto['unidad_base_abreviatura'] ?? producto['unidad_base'] ?? ''}';
    final abrev = pr.abreviatura.isNotEmpty && pr.abreviatura != 'null'
        ? pr.abreviatura
        : abrevBase;
    final disponible = pr.esBase || pr.factor <= 1
        ? stock
        : (stock / pr.factor).floorToDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                Row(
                  children: [
                    Flexible(
                      child: Text(pr.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark)),
                    ),
                    if (pr.esBase) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.celesteTint,
                            borderRadius: BorderRadius.circular(6)),
                        child: Text('Base',
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.celesteDeep)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                    pr.esBase
                        ? 'Unidad base'
                        : 'Contiene ${_fmt(pr.factor)}'
                            '${abrevBase.isNotEmpty && abrevBase != 'null' ? ' $abrevBase' : ''}',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('S/ ${_fmt(pr.precioVenta)}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.celesteDeep)),
              if (pr.precioCompra > 0)
                Text('Compra: S/ ${_fmt(pr.precioCompra)}',
                    style: TextStyle(
                        fontSize: 9.5, color: AppColors.textMuted)),
              const SizedBox(height: 1),
              Text(
                  disponible <= 0
                      ? 'Sin stock'
                      : 'Disponible: ${_fmt(disponible)}'
                          '${abrev.isNotEmpty && abrev != 'null' ? ' $abrev' : ''}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: disponible <= 0
                          ? AppColors.errorDark
                          : AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== helpers ====================

double _num(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

String _fmt(double d) =>
    d % 1 == 0 ? d.toInt().toString() : d.toStringAsFixed(2);
