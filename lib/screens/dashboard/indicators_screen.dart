import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../../models/indicator_model.dart';
import '../ai_chat/ai_chat_screen.dart';
import 'widgets/indicator_card_widget.dart';
import 'widgets/indicator_detail_sheet.dart';

class IndicatorsScreen extends StatefulWidget {
  const IndicatorsScreen({super.key});

  @override
  State<IndicatorsScreen> createState() => _IndicatorsScreenState();
}

class _IndicatorsScreenState extends State<IndicatorsScreen> {
  DashboardIndicatorsResponse? _indicators;
  bool _loading = true;
  String? _errorMessage;
  int _selectedFilter = 0; // 0: Todos, 1: Cumplen meta, 2: Requieren atención

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService().getIndicators();
      if (mounted) {
        setState(() {
          _indicators = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _loading = false;
        });
      }
    }
  }

  bool _checkCumple(IndicatorItem item) {
    if (item.id == 1) {
      return item.resultado >= item.meta;
    }
    return item.resultado <= item.meta;
  }

  List<IndicatorItem> get _filteredIndicators {
    if (_indicators == null) return [];
    final all = _indicators!.all;
    if (_selectedFilter == 1) {
      return all.where(_checkCumple).toList();
    } else if (_selectedFilter == 2) {
      return all.where((it) => !_checkCumple(it)).toList();
    }
    return all;
  }

  int get _countCumple {
    if (_indicators == null) return 0;
    return _indicators!.all.where(_checkCumple).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A3642),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_rounded, color: Color(0xFF38BDF8), size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'Indicadores de Tesis',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
            tooltip: 'Actualizar Indicadores',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF0096C7),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==========================================
              // HERO BANNER DE METODOLOGÍA & ESTADO
              // ==========================================
              _buildExecutiveHeroCard(),
              const SizedBox(height: 16),

              // ==========================================
              // RESUMEN KPI EN CUADRÍCULA RÁPIDA
              // ==========================================
              if (_indicators != null) ...[
                _buildKpiSummaryGrid(),
                const SizedBox(height: 16),

                // ==========================================
                // FILTROS DE ESTADO (CHIPS)
                // ==========================================
                _buildFilterChips(),
                const SizedBox(height: 14),
              ],

              // ==========================================
              // ERROR BANNER
              // ==========================================
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.errorBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.errorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 12, color: AppColors.errorDark, height: 1.3),
                        ),
                      ),
                      TextButton(
                        onPressed: _loadData,
                        child: const Text('Reintentar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),

              // ==========================================
              // ESTADO DE CARGA O LISTA DE INDICADORES
              // ==========================================
              if (_loading && _indicators == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF0096C7)),
                        SizedBox(height: 12),
                        Text(
                          'Calculando métricas operativas...',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_filteredIndicators.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.filter_list_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                      const SizedBox(height: 10),
                      const Text(
                        'No hay indicadores con este filtro',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Todos los indicadores cumplen con los parámetros esperados.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() => _selectedFilter = 0),
                        child: const Text('Ver todos los indicadores'),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredIndicators.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _filteredIndicators[index];
                    return IndicatorCardWidget(
                      indicator: item,
                      onTap: () {
                        IndicatorDetailSheet.show(
                          context,
                          item,
                          onRefreshParent: _loadData,
                        );
                      },
                    );
                  },
                ),

              const SizedBox(height: 20),

              // ==========================================
              // BANNER CONSULTAR CON VALENCIA AI
              // ==========================================
              _buildAiAssistantConsultBanner(context),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- HERO BANNER ----------------
  Widget _buildExecutiveHeroCard() {
    final cumple = _countCumple;
    final total = _indicators?.all.length ?? 4;
    final pct = total > 0 ? ((cumple / total) * 100).toInt() : 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A3642), Color(0xFF134E5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A3642).withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00B4D8).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00B4D8).withValues(alpha: 0.50)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValenciaBotIcon(size: 14, headColor: Colors.white, eyeColor: Color(0xFF38BDF8)),
                    SizedBox(width: 6),
                    Text(
                      'IA Generativa • En vivo',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE0F2FE),
                      ),
                    ),
                  ],
                ),
              ),
              if (_indicators != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: cumple == total
                        ? const Color(0xFF10B981).withValues(alpha: 0.22)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: cumple == total ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '$cumple/$total en meta ($pct%)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cumple == total ? const Color(0xFF6EE7B7) : const Color(0xFFFCD34D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Métricas Oficiales de Investigación',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Evaluación pre/post implementación del sistema inteligente de comercialización y gestión de pedidos.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF94A3B8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- RESUMEN KPI EN CUADRÍCULA ----------------
  Widget _buildKpiSummaryGrid() {
    final all = _indicators!.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: all.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.65,
      ),
      itemBuilder: (context, index) {
        final item = all[index];
        final isOk = _checkCumple(item);
        final unit = item.id == 1 || item.id == 2 ? '%' : (item.id == 4 ? 's' : '');

        return InkWell(
          onTap: () => IndicatorDetailSheet.show(context, item, onRefreshParent: _loadData),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isOk ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                width: 1.2,
              ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0369A1),
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    Icon(
                      isOk ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 16,
                      color: isOk ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                Text(
                  '${item.resultado.toStringAsFixed(1)}$unit',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  item.id == 1
                      ? 'Meta: ≥ ${item.meta.toInt()}%'
                      : (item.id == 4 ? 'Meta: ≤ ${item.meta.toInt()}s' : 'Meta: ≤ ${item.meta.toInt()}%'),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------- FILTROS DE ESTADO (CHIPS) ----------------
  Widget _buildFilterChips() {
    final cumple = _countCumple;
    final total = _indicators?.all.length ?? 4;
    final alert = total - cumple;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _filterChip(label: 'Todos ($total)', index: 0),
          const SizedBox(width: 8),
          _filterChip(label: 'Cumple Meta ($cumple)', index: 1, icon: Icons.check_rounded, color: const Color(0xFF10B981)),
          const SizedBox(width: 8),
          _filterChip(label: 'Atención ($alert)', index: 2, icon: Icons.warning_amber_rounded, color: const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _filterChip({required String label, required int index, IconData? icon, Color? color}) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0A3642) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0A3642) : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0A3642).withValues(alpha: 0.20),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: isSelected ? Colors.white : (color ?? const Color(0xFF64748B))),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- BANNER ASISTENTE IA ----------------
  Widget _buildAiAssistantConsultBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3DC7BD), Color(0xFF008F9D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const ValenciaBotIcon(
              size: 22,
              headColor: Colors.white,
              eyeColor: Color(0xFF38BDF8),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '¿Deseas profundizar en las métricas?',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF14532D),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pregúntale a Valencia AI sobre PODE, PEOR, PRS o TBPP.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF15803D)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => AiChatScreen.show(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF008F9D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Preguntar', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
