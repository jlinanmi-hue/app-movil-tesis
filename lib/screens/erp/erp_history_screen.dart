import 'package:flutter/material.dart';

/// Pantalla Completa y Vista Dedicada para Historiales de Operaciones
/// Provee una tabla estructurada de alto nivel con bordes definidos,
/// zebra striping, badges semánticos, buscador en vivo, filtros por estado
/// y vista alternativa en tarjetas móviles.
class ErpHistoryScreen extends StatefulWidget {
  final String title;
  final String? subtitle;
  final List<String> columns;
  final List<List<String>>? initialRows;
  final Future<List<List<String>>> Function()? loader;
  final bool incrustado;

  const ErpHistoryScreen({
    super.key,
    required this.title,
    this.subtitle,
    required this.columns,
    this.initialRows,
    this.loader,
    this.incrustado = false,
  });

  @override
  State<ErpHistoryScreen> createState() => _ErpHistoryScreenState();
}

class _ErpHistoryScreenState extends State<ErpHistoryScreen> {
  List<List<String>> _allRows = [];
  bool _loading = false;
  String _searchQuery = '';
  String _selectedStatusFilter = 'TODOS';
  bool _isTableView = true; // true: Tabla Grid, false: Tarjetas Móviles
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialRows != null) {
      _allRows = List.from(widget.initialRows!);
    } else if (widget.loader != null) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (widget.loader == null) return;
    setState(() => _loading = true);
    try {
      final rows = await widget.loader!();
      if (mounted) {
        setState(() {
          _allRows = rows;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _availableStatuses {
    final statusSet = <String>{};
    for (final r in _allRows) {
      for (final cell in r) {
        final clean = cell.toLowerCase().trim();
        if (_isStatusValue(clean)) {
          statusSet.add(clean);
        }
      }
    }
    return statusSet.toList();
  }

  bool _isStatusValue(String s) {
    return s == 'completado' ||
        s == 'entregado' ||
        s == 'pendiente' ||
        s == 'cancelado' ||
        s == 'anulado' ||
        s == 'emitida' ||
        s == 'cerrada' ||
        s == 'recepción' ||
        s == 'recepcion' ||
        s == 'conforme' ||
        s == 'faltante' ||
        s == 'activo' ||
        s == 'inactivo' ||
        s == 'merma' ||
        s == 'daño' ||
        s == 'dano' ||
        s == 'conteo' ||
        s == 'ajuste';
  }

  List<List<String>> get _filteredRows {
    return _allRows.where((row) {
      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        final match = row.any((cell) =>
            cell.toLowerCase().contains(_searchQuery.toLowerCase()));
        if (!match) return false;
      }
      // Filtro de estado
      if (_selectedStatusFilter != 'TODOS') {
        final matchStatus = row.any((cell) =>
            cell.toLowerCase().trim() == _selectedStatusFilter.toLowerCase());
        if (!matchStatus) return false;
      }
      return true;
    }).toList();
  }

  double get _totalMontoSum {
    double sum = 0.0;
    for (final row in _filteredRows) {
      for (final cell in row) {
        if (cell.contains('S/') || cell.contains('s/')) {
          final clean = cell.replaceAll(RegExp(r'[^\d.]'), '');
          final val = double.tryParse(clean);
          if (val != null) sum += val;
        }
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final content = Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: widget.incrustado
          ? null
          : AppBar(
              backgroundColor: const Color(0xFF0A3642),
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                IconButton(
                  tooltip: _isTableView ? 'Ver en tarjetas' : 'Ver en tabla',
                  icon: Icon(
                    _isTableView
                        ? Icons.view_agenda_outlined
                        : Icons.table_chart_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _isTableView = !_isTableView),
                ),
                if (widget.loader != null)
                  IconButton(
                    tooltip: 'Recargar historial',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                    onPressed: _loadData,
                  ),
                const SizedBox(width: 4),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: widget.loader != null ? _loadData : () async {},
        color: const Color(0xFF0096C7),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Barra superior integrada si es incrustado
              if (widget.incrustado) ...[
                _buildIncrustadoHeader(),
                const SizedBox(height: 12),
              ],

              // 1. Métricas de Resumen Superior (KPI Bar)
              _buildSummaryKpiBar(),
              const SizedBox(height: 14),

              // 2. Buscador en Vivo y Filtros de Estado
              _buildSearchAndFilters(),
              const SizedBox(height: 14),

              // 3. Vista Principal: Tabla con Bordes o Tarjetas
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF0096C7)),
                  ),
                )
              else if (_filteredRows.isEmpty)
                _buildEmptyState()
              else if (_isTableView)
                _buildStructuredTableCard()
              else
                _buildCardsListView(),
            ],
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildIncrustadoHeader() {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF00B4D8).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.history_rounded, color: Color(0xFF0077B6), size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.2,
                ),
              ),
              if (widget.subtitle != null)
                Text(
                  widget.subtitle!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: _isTableView ? 'Ver en tarjetas' : 'Ver en tabla',
          icon: Icon(
            _isTableView ? Icons.view_agenda_outlined : Icons.table_chart_rounded,
            color: const Color(0xFF0077B6),
            size: 20,
          ),
          onPressed: () => setState(() => _isTableView = !_isTableView),
        ),
        if (widget.loader != null)
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 20),
            onPressed: _loadData,
          ),
      ],
    );
  }

  Widget _buildSummaryKpiBar() {
    final count = _filteredRows.length;
    final totalSum = _totalMontoSum;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Total Registros
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.table_rows_rounded, color: Color(0xFF0284C7), size: 18),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Registros', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    Text(
                      '$count filas',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Total Soles si hay valores monetarios
          if (totalSum > 0) ...[
            Container(width: 1, height: 26, color: const Color(0xFFE2E8F0)),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.payments_rounded, color: Color(0xFF16A34A), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Monto', style: TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      Text(
                        'S/ ${totalSum.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF15803D)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    final statuses = _availableStatuses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de búsqueda en vivo
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (val) => setState(() => _searchQuery = val.trim()),
            decoration: InputDecoration(
              hintText: 'Filtrar por código, nombre, fecha o monto...',
              hintStyle: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              isDense: true,
            ),
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
          ),
        ),

        // Filtros rápidos por estado si hay estados detectados
        if (statuses.isNotEmpty) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChip('TODOS'),
                for (final st in statuses) ...[
                  const SizedBox(width: 6),
                  _buildStatusChip(st.toUpperCase()),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusChip(String label) {
    final isSelected = _selectedStatusFilter == label;
    return InkWell(
      onTap: () => setState(() => _selectedStatusFilter = label),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A3642) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A3642) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  /// =========================================================================
  /// TABLA ESTRUCTURADA PREMIUM (BORDES, ZEBRA STRIPING, CELDAS INTELIGENTES)
  /// =========================================================================
  Widget _buildStructuredTableCard() {
    final rows = _filteredRows;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Scroll horizontal y vertical para grilla completa
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 360),
              child: DataTable(
                headingRowHeight: 42,
                dataRowMinHeight: 46,
                dataRowMaxHeight: 52,
                columnSpacing: 18,
                horizontalMargin: 16,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFF0A3642), // Azul marino institucional Valencia
                ),
                columns: [
                  for (final col in widget.columns)
                    DataColumn(
                      label: Text(
                        col.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                ],
                rows: [
                  for (int i = 0; i < rows.length; i++)
                    DataRow(
                      color: WidgetStateProperty.all(
                        i.isEven ? Colors.white : const Color(0xFFF8FAFC), // Zebra striping
                      ),
                      cells: [
                        for (int j = 0; j < rows[i].length; j++)
                          DataCell(
                            _buildSmartCell(rows[i][j]),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),

          // Pie informativo dentro de la tabla
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mostrando ${rows.length} de ${_allRows.length} registros',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                ),
                const Row(
                  children: [
                    Icon(Icons.swipe_rounded, size: 13, color: Color(0xFF94A3B8)),
                    SizedBox(width: 4),
                    Text(
                      'Desliza para ver más',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Celda Inteligente: Formatea badges para Códigos, Montos y Estados
  Widget _buildSmartCell(String val) {
    final clean = val.trim();
    final lower = clean.toLowerCase();

    // 1. Estado conocido (Semáforo)
    if (_isStatusValue(lower)) {
      return _buildStatusBadge(clean);
    }

    // 2. Código de entidad (PED-XXXX, OC-XXXX, etc.)
    if (RegExp(r'^(?:PED|OC|AJU|NOT|PROD|CLI|PRV)-').hasMatch(clean)) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          clean,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: Color(0xFF0F172A),
          ),
        ),
      );
    }

    // 3. Monto en Soles (S/ 450.00)
    if (clean.contains('S/') || clean.contains('s/')) {
      return Text(
        clean,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFF15803D), // Verde esmeralda
        ),
      );
    }

    // 4. Texto general
    return Text(
      clean,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF1E293B),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final lower = status.toLowerCase();
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);
    Color dotColor = const Color(0xFF64748B);

    if (lower == 'completado' || lower == 'entregado' || lower == 'conforme' || lower == 'cerrada' || lower == 'activo') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      dotColor = const Color(0xFF22C55E);
    } else if (lower == 'pendiente' || lower == 'emitida' || lower == 'recepción' || lower == 'recepcion') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      dotColor = const Color(0xFFF59E0B);
    } else if (lower == 'cancelado' || lower == 'anulado' || lower == 'faltante' || lower == 'inactivo') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
      dotColor = const Color(0xFFEF4444);
    } else if (lower == 'merma' || lower == 'daño' || lower == 'dano') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      dotColor = const Color(0xFFEF4444);
    } else if (lower == 'conteo' || lower == 'ajuste') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      dotColor = const Color(0xFF0EA5E9);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// =========================================================================
  /// VISTA ALTERNATIVA EN TARJETAS MÓVILES (CARDS VIEW)
  /// =========================================================================
  Widget _buildCardsListView() {
    final rows = _filteredRows;

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: rows.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final row = rows[index];
        final code = row.isNotEmpty ? row[0] : '';
        final second = row.length > 1 ? row[1] : '';
        final third = row.length > 2 ? row[2] : '';
        final fourth = row.length > 3 ? row[3] : '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Código y Estado
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSmartCell(code),
                  if (fourth.isNotEmpty) _buildSmartCell(fourth),
                ],
              ),
              const SizedBox(height: 8),

              // Contenido medio
              if (second.isNotEmpty)
                Text(
                  second,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              const SizedBox(height: 4),

              // Contenido inferior: Fecha o Monto
              if (third.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.columns.length > 2 ? widget.columns[2] : '',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    _buildSmartCell(third),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_off_rounded, size: 28, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 12),
          const Text(
            'No se encontraron registros en el historial',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Intenta cambiar los términos de búsqueda o limpiar el filtro de estado.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
                _selectedStatusFilter = 'TODOS';
              });
            },
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }
}
