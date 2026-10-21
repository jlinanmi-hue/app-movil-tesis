import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/campus_card.dart';
import '../../core/widgets/erp_ui.dart';
import '../../core/widgets/responsive.dart';
import '../../models/erp_models.dart';

/// Subinterfaz genérica ERP (CELESTE + BLANCO) para listas y CRUD.
///
/// REGLAS DE DISEÑO DE ESTA VERSIÓN:
/// 1) SIN dashboards: `mostrarKpis` está APAGADO por defecto → la pantalla
///    solo renderiza buscador + tabs + lista, con todo el alto para los ítems.
/// 2) UNA sola cabecera: dentro de hubs con AppBar propio se usa
///    `incrustado: true` → no pinta título ni flecha duplicados y el botón
///    de crear sale como FAB.
/// 3) Filas compactas: nombre, dato y estado (sin barras de progreso).
class ErpListScreen extends StatefulWidget {
  final String title;
  final String subtitle;

  /// Dashboard opcional (hero + KPIs). Por defecto APAGADO.
  final bool mostrarKpis;

  /// true → incrustada dentro de un hub que ya tiene cabecera + tabs.
  final bool incrustado;

  final String heroLabel;
  final String heroValue;
  final String heroCaption;
  final IconData? heroIcon;
  final List<CampusKpi> kpis;
  final List<String> tabs;
  final Future<List<ErpItem>> Function(String search, String tab) loader;
  final IconData rowIcon;
  final String searchHint;
  final String emptyText;
  final VoidCallback? onCreate;
  final void Function(ErpItem item)? onEdit;
  final void Function(ErpItem item)? onDelete;
  final void Function(ErpItem item)? onHistory;
  final String historyLabel;

  /// Cuando se define, reemplaza la hoja de detalle genérica al tocar una
  /// fila (p. ej. el modal compacto de pedidos).
  final void Function(ErpItem item)? onRowTap;

  const ErpListScreen({
    super.key,
    required this.title,
    this.subtitle = '',
    this.mostrarKpis = false,
    this.incrustado = false,
    this.heroLabel = '',
    this.heroValue = '',
    this.heroCaption = '',
    this.heroIcon,
    this.kpis = const [],
    required this.tabs,
    required this.loader,
    required this.rowIcon,
    this.searchHint = 'Buscar...',
    this.emptyText = 'Sin registros por ahora.',
    this.onCreate,
    this.onEdit,
    this.onDelete,
    this.onHistory,
    this.historyLabel = 'Historial',
    this.onRowTap,
  });

  @override
  State<ErpListScreen> createState() => _ErpListScreenState();
}

class _ErpListScreenState extends State<ErpListScreen> {
  final _search = TextEditingController();
  String _tab = '';
  List<ErpItem> _items = [];
  bool _loading = true;
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _tab = widget.tabs.isNotEmpty ? widget.tabs.first : '';
    _load();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    setState(() => _isSearching = true);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final q = _search.text.trim();
      var res = await widget.loader(q, _tab);

      // Fallback case-insensitive en memoria si la API es sensible a mayúsculas
      if (q.isNotEmpty && res.isEmpty) {
        final all = await widget.loader('', _tab);
        final qLower = q.toLowerCase();
        res = all.where((e) {
          final t = e.titulo.toLowerCase();
          final s = e.subtitulo.toLowerCase();
          final id = e.id.toLowerCase();
          final raw = e.raw.values.map((v) => '$v'.toLowerCase()).join(' ');
          return t.contains(qLower) || s.contains(qLower) || id.contains(qLower) || raw.contains(qLower);
        }).toList();
      }

      if (!mounted) return;
      setState(() {
        _items = res;
        _loading = false;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _isSearching = false;
      });
    }
  }

  void _createPressed() {
    HapticFeedback.mediumImpact();
    widget.onCreate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final content = LayoutBuilder(
      builder: (context, c) {
        // Dentro de un hub el contenedor no aplica padding lateral: va aquí.
        final hpad = widget.incrustado ? Responsive.hPad(context, c) : 0.0;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hpad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dashboard OPCIONAL: apagado por defecto (sin KPIs en subinterfaces).
              if (widget.mostrarKpis) ...[
                if (widget.heroLabel.isNotEmpty)
                  CampusHeroCard(
                    label: widget.heroLabel,
                    value: widget.heroValue,
                    caption: widget.heroCaption,
                    icon: widget.heroIcon ?? widget.rowIcon,
                  ),
                if (widget.kpis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  CampusKpiRow(kpis: widget.kpis),
                ],
                const SizedBox(height: 12),
              ],
              if (widget.incrustado) const SizedBox(height: 12),
              _searchField(),
              if (widget.tabs.length > 1) ...[
                const SizedBox(height: 10),
                _tabsRow(),
              ],
              const SizedBox(height: 10),
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.celeste,
                  onRefresh: _load,
                  child: _list(),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (widget.incrustado) {
      // El hub ya aporta la ÚNICA cabecera; aquí solo contenido + FAB de crear.
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        floatingActionButton: widget.onCreate == null
            ? null
            : Padding(
                // Deja libre la barra flotante inferior de la app.
                padding: const EdgeInsets.only(bottom: 74),
                child: _fab(),
              ),
        body: content,
      );
    }
    return ResponsiveScaffold(
      title: widget.title,
      subtitle: widget.subtitle.isEmpty ? null : widget.subtitle,
      actions: [if (widget.onCreate != null) _headerAdd()],
      body: content,
    );
  }

  Widget _searchField() {
    return ErpSearchField(
      controller: _search,
      hint: widget.searchHint,
      loading: _isSearching || (_loading && _search.text.isNotEmpty),
      onChanged: _onSearchChanged,
      onSubmitted: () {
        _debounceTimer?.cancel();
        _load();
      },
    );
  }

  Widget _tabsRow() {
    return ErpFilterPills(
      options: widget.tabs,
      selected: _tab,
      onSelect: (t) {
        if (_tab == t) return;
        setState(() => _tab = t);
        _load();
      },
    );
  }

  Widget _list() {
    // Espacio inferior: deja aire para el FAB y para la barra de la app.
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final bottom = (widget.incrustado ? 96.0 : 16.0) + safeBottom;

    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(top: 60, bottom: bottom),
        children: [
          Center(
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: AppColors.celeste),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: bottom),
        children: [
          ErpEmptyState(
            icon: Icons.inbox_outlined,
            title: _search.text.isNotEmpty ? 'Sin resultados' : 'Sin registros',
            message: _search.text.isNotEmpty
                ? 'No se encontraron registros para "${_search.text.trim()}".'
                : widget.emptyText,
          ),
          const SizedBox(height: 2),
          Center(
            child: ErpSoftButton(
              expand: false,
              icon: _search.text.isNotEmpty
                  ? Icons.close_rounded
                  : Icons.refresh_rounded,
              label:
                  _search.text.isNotEmpty ? 'Limpiar búsqueda' : 'Reintentar',
              onTap: () {
                if (_search.text.isNotEmpty) _search.clear();
                _load();
              },
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: 2, bottom: bottom),
      itemCount: _items.length,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: CampusListRow(
          icon: widget.rowIcon,
          title: _items[i].titulo,
          subtitle: _items[i].subtitulo,
          trailing: _items[i].monto,
          badge: _items[i].estado,
          onTap: () => _rowTapped(_items[i]),
        ),
      ),
    );
  }

  Widget _fab() {
    return SizedBox(
      width: 58,
      height: 58,
      child: FloatingActionButton(
        heroTag: 'erp_fab_${widget.title}',
        onPressed: _createPressed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        highlightElevation: 0,
        splashColor: Colors.white.withValues(alpha: .18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.celesteDeep,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
        ),
      ),
    );
  }

  Widget _headerAdd() {
    return ErpCircleButton(
      icon: Icons.add_rounded,
      tooltip: 'Nuevo registro',
      onTap: _createPressed,
    );
  }

  /// Modal flotante de detalle + acciones CRUD.
  void _rowTapped(ErpItem e) {
    final custom = widget.onRowTap;
    if (custom != null) {
      custom(e);
      return;
    }
    _showDetail(e);
  }

  /// Modal flotante centrado (estilo tarjeta, igual que el detalle de
  /// pedidos): cabecera con icono + X, datos clave y acciones CRUD.
  void _showDetail(ErpItem e) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .38),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * .78;
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: AppColors.surfaceLight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 420, maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Cabecera: icono + título + ID/estado + cerrar (X)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: [
                      ErpIconTile(icon: widget.rowIcon, size: 44, radius: 14),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textDark,
                                    letterSpacing: -0.2)),
                            const SizedBox(height: 3),
                            Text('ID: ${e.id} • ${e.estado}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      ErpCircleButton(
                        icon: Icons.close_rounded,
                        size: 34,
                        tooltip: 'Cerrar',
                        onTap: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.borderSoft),
                // Datos clave del registro
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _kv('Detalle', e.subtitulo),
                        _kv('Monto / Dato', e.monto.isEmpty ? '—' : e.monto),
                        _kv('Estado', e.estado),
                      ],
                    ),
                  ),
                ),
                // Acciones CRUD: editar / historial / eliminar (píldoras
                // compactas centradas; hacen wrap en pantallas angostas).
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 9,
                        runSpacing: 9,
                        children: [
                          if (widget.onEdit != null)
                            ErpPillButton(
                              label: 'Editar',
                              icon: Icons.edit_outlined,
                              primary: true,
                              expand: false,
                              onTap: () {
                                Navigator.pop(ctx);
                                widget.onEdit!(e);
                              },
                            ),
                          if (widget.onHistory != null)
                            ErpPillButton(
                              label: widget.historyLabel,
                              icon: Icons.history_rounded,
                              expand: false,
                              onTap: () {
                                Navigator.pop(ctx);
                                widget.onHistory!(e);
                              },
                            ),
                          if (widget.onDelete != null)
                            ErpPillButton(
                              label: 'Eliminar',
                              icon: Icons.delete_outline_rounded,
                              danger: true,
                              expand: false,
                              onTap: () {
                                Navigator.pop(ctx);
                                widget.onDelete!(e);
                              },
                            ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cerrar',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.celesteDeep),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style:
                  TextStyle(fontSize: 12, color: AppColors.textMuted)),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark))),
        ],
      ),
    );
  }
}

/// Helper para pantallas simples sin servicio (usa ModulesService.generico).
class ErpSimpleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String endpoint;
  final IconData icon;
  final List<String> tabs;
  const ErpSimpleScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.endpoint,
    required this.icon,
    this.tabs = const ['Todos'],
  });

  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    return ErpListScreen(
      title: title,
      subtitle: subtitle,
      tabs: tabs,
      loader: (s, t) => svc.generico(endpoint, search: s),
      rowIcon: icon,
      searchHint: 'Buscar en $title...',
    );
  }
}
