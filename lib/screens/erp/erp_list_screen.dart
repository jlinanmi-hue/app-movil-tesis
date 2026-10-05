import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/campus_card.dart';
import '../../core/widgets/responsive.dart';
import '../../models/erp_models.dart';

/// Pantalla genérica ERP estilo Campus Cash (CELESTE + BLANCO).
/// Hero + KPIs + buscador + tabs + lista responsive.
/// Soporta CRUD completo: crear / editar / eliminar / historial.
class ErpListScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final String heroLabel;
  final String heroValue;
  final String heroCaption;
  final IconData heroIcon;
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

  const ErpListScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.heroLabel,
    required this.heroValue,
    required this.heroCaption,
    required this.heroIcon,
    required this.kpis,
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
    setState(() {
      _isSearching = true;
    });
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await widget.loader(_search.text.trim(), _tab);
      if (mounted) {
        setState(() {
          _items = res;
          _loading = false;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      actions: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
                colors: [AppColors.celeste, AppColors.celesteDark]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              if (widget.onCreate != null) {
                widget.onCreate!();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Usa Valencia AI para crear registros por voz o texto.'),
                      behavior: SnackBarBehavior.floating),
                );
              }
            },
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            tooltip: 'Nuevo registro',
          ),
        ),
      ],
      body: LayoutBuilder(
        builder: (context, c) {
          final isTablet = c.maxWidth >= 600;
          return RefreshIndicator(
            color: AppColors.celeste,
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CampusHeroCard(
                    label: widget.heroLabel,
                    value: widget.heroValue,
                    caption: widget.heroCaption,
                    icon: widget.heroIcon,
                  ),
                  const SizedBox(height: 12),
                  CampusKpiRow(kpis: widget.kpis),
                  const SizedBox(height: 12),

                  // Buscador en Vivo con Debounce y Feedback Instantáneo
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _search.text.isNotEmpty
                            ? AppColors.celeste
                            : AppColors.celesteBg,
                        width: _search.text.isNotEmpty ? 1.4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.celesteDark.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) {
                        _debounceTimer?.cancel();
                        _load();
                      },
                      decoration: InputDecoration(
                        hintText: widget.searchHint,
                        hintStyle: const TextStyle(
                          color: AppColors.textSubtle,
                          fontSize: 13,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.celesteDark,
                          size: 20,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isSearching || (_loading && _search.text.isNotEmpty))
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.celesteDark,
                                  ),
                                ),
                              ),
                            if (_search.text.isNotEmpty)
                              IconButton(
                                onPressed: () {
                                  _debounceTimer?.cancel();
                                  _search.clear();
                                  _load();
                                },
                                icon: const Icon(
                                  Icons.clear_rounded,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                                tooltip: 'Limpiar búsqueda',
                              ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  // Chip indicador de búsqueda activa en vivo
                  if (_search.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.celesteTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.celesteBg),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.manage_search_rounded,
                              size: 16, color: AppColors.celesteDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Filtrando por "${_search.text.trim()}" • ${_items.length} ${_items.length == 1 ? "registro" : "registros"}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textDark,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _debounceTimer?.cancel();
                              _search.clear();
                              _load();
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text(
                                'Quitar',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.celesteDark,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tabs tipo Campus
                  if (widget.tabs.length > 1) ...[
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: widget.tabs.map((t) {
                          final sel = t == _tab;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(t),
                              selected: sel,
                              onSelected: (_) {
                                setState(() => _tab = t);
                                _load();
                              },
                              selectedColor: AppColors.celesteDark,
                              backgroundColor: Colors.white,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textMuted,
                              ),
                              side: BorderSide(
                                  color: sel
                                      ? AppColors.celesteDark
                                      : AppColors.celesteBg),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  CampusCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    child: _loading
                        ? const Padding(
                            padding: EdgeInsets.all(28),
                            child: Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.celeste)),
                          )
                        : _items.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  children: [
                                    const Icon(
                                        Icons.inbox_outlined,
                                        size: 36,
                                        color: AppColors.celesteBg),
                                    const SizedBox(height: 8),
                                    Text(
                                        _search.text.isNotEmpty
                                            ? 'No se encontraron registros para "${_search.text}".'
                                            : widget.emptyText,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            color:
                                                AppColors.textMuted)),
                                    const SizedBox(height: 4),
                                    TextButton(
                                        onPressed: () {
                                          if (_search.text.isNotEmpty) {
                                            _search.clear();
                                          }
                                          _load();
                                        },
                                        child: Text(_search.text.isNotEmpty
                                            ? 'Limpiar búsqueda'
                                            : 'Reintentar')),
                                  ],
                                ),
                              )
                            : isTablet
                                ? GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 2.6,
                                      crossAxisSpacing: 12,
                                    ),
                                    itemCount: _items.length,
                                    itemBuilder: (_, i) => _row(_items[i], divider: false),
                                  )
                                : Column(
                                    children: _items
                                        .map((e) => _row(e))
                                        .toList(),
                                  ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _row(ErpItem e, {bool divider = true}) {
    return Column(
      children: [
        CampusListRow(
          icon: widget.rowIcon,
          title: e.titulo,
          subtitle: e.subtitulo,
          trailing: e.monto,
          badge: e.estado,
          progress: e.progreso,
          onTap: () => _showDetail(e),
        ),
        if (divider && e != _items.last)
          const Divider(height: 1, color: Color(0xFFE6F7FC)),
      ],
    );
  }

  void _showDetail(ErpItem e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                  child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.celesteBg,
                          borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                        color: AppColors.celesteTint,
                        borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Icon(widget.rowIcon,
                        color: AppColors.celesteDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e.titulo,
                              style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textDark)),
                          Text('ID: ${e.id} • ${e.estado}',
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textMuted)),
                        ]),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _kv('Detalle', e.subtitulo),
              _kv('Monto / Dato', e.monto.isEmpty ? '—' : e.monto),
              _kv('Estado', e.estado),
              const SizedBox(height: 8),
              CampusProgress(value: e.progreso),
              const SizedBox(height: 14),
              // Acciones CRUD: editar / historial / eliminar
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 420;
                  final btns = <Widget>[];
                  if (widget.onEdit != null) {
                    btns.add(_actionBtn(
                      icon: Icons.edit_outlined,
                      label: 'Editar',
                      primary: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onEdit!(e);
                      },
                    ));
                  }
                  if (widget.onHistory != null) {
                    btns.add(_actionBtn(
                      icon: Icons.history_rounded,
                      label: widget.historyLabel,
                      primary: false,
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onHistory!(e);
                      },
                    ));
                  }
                  if (widget.onDelete != null) {
                    btns.add(_actionBtn(
                      icon: Icons.delete_outline_rounded,
                      label: 'Eliminar',
                      primary: false,
                      danger: true,
                      onTap: () {
                        Navigator.pop(ctx);
                        widget.onDelete!(e);
                      },
                    ));
                  }
                  if (btns.isEmpty) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.celeste,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cerrar'),
                      ),
                    );
                  }
                  if (wide) {
                    return Row(
                      children: [
                        for (int i = 0; i < btns.length; i++) ...[
                          Expanded(child: btns[i]),
                          if (i != btns.length - 1)
                            const SizedBox(width: 8),
                        ],
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (int i = 0; i < btns.length; i++) ...[
                        btns[i],
                        if (i != btns.length - 1)
                          const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cerrar')),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
    bool danger = false,
  }) {
    final bg = primary
        ? AppColors.celeste
        : danger
            ? const Color(0xFFFEF2F2)
            : AppColors.celesteTint;
    final fg = primary
        ? Colors.white
        : danger
            ? const Color(0xFFB91C1C)
            : AppColors.celesteDark;
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label,
          style: const TextStyle(
              fontSize: 12.5, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: primary
                    ? AppColors.celeste
                    : danger
                        ? const Color(0xFFFECACA)
                        : AppColors.celesteBg)),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark))),
        ],
      ),
    );
  }
}

/// Helper para pantallas simples sin servicio (usa ModulesService.generico)
class ErpSimpleScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final String endpoint;
  final IconData icon;
  final List<String> tabs;
  const ErpSimpleScreen(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.endpoint,
      required this.icon,
      this.tabs = const ['Todos']});

  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    return ErpListScreen(
      title: title,
      subtitle: subtitle,
      heroLabel: title,
      heroValue: '${tabs.length > 1 ? tabs.length : '—'}',
      heroCaption: subtitle,
      heroIcon: icon,
      kpis: [
        CampusKpi(icon: icon, value: '•', label: 'Registros'),
        CampusKpi(
            icon: Icons.check_circle_outline_rounded,
            value: '•',
            label: 'Activos'),
        CampusKpi(
            icon: Icons.timelapse_rounded, value: '•', label: 'Hoy'),
        CampusKpi(
            icon: Icons.insights_rounded, value: 'IA', label: 'Asistido'),
      ],
      tabs: tabs,
      loader: (s, t) => svc.generico(endpoint, search: s),
      rowIcon: icon,
      searchHint: 'Buscar en $title...',
    );
  }
}
