import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../models/token_metrics_model.dart';

class AiTokenMetricsWidget extends StatefulWidget {
  const AiTokenMetricsWidget({super.key});

  @override
  State<AiTokenMetricsWidget> createState() => _AiTokenMetricsWidgetState();
}

class _AiTokenMetricsWidgetState extends State<AiTokenMetricsWidget> {
  TokenMetricsResponse? _data;
  bool _loading = true;
  int _activePreset = 30; // 15, 30, 90
  bool _alertDismissed = false;

  @override
  void initState() {
    super.initState();
    _fetchTokens(dias: _activePreset);
  }

  Future<void> _fetchTokens({int? dias}) async {
    setState(() => _loading = true);
    try {
      final res = await ApiService().getTokenMetrics(dias: dias ?? _activePreset);
      if (mounted) {
        setState(() {
          _data = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onPresetChanged(int dias) {
    setState(() => _activePreset = dias);
    _fetchTokens(dias: dias);
  }

  @override
  Widget build(BuildContext context) {
    final kpis = _data?.kpis;
    final serie = _data?.serieDiaria ?? [];
    final alerta = kpis?.alertaConsumo;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // 1. CABECERA Y PRESETS
            // ==========================================
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryBlue, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Consumo y Auditoría de Tokens IA',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Text(
                              'Motor IA',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlue,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rango: ${_data?.rango?.label ?? 'Últimos $_activePreset días'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSubtle),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _fetchTokens(),
                  icon: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.textMuted),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Píldoras de Presets Rápidos
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPresetChip(15, '15 días (Quincenal)'),
                  const SizedBox(width: 6),
                  _buildPresetChip(30, '30 días (Mensual)'),
                  const SizedBox(width: 6),
                  _buildPresetChip(90, '90 días (Trimestral)'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Alerta de Consumo Inusual si aplica
            if (alerta != null && alerta.activo && !_alertDismissed) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warningBorder),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warningDark),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pico de consumo inusual detectado',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warningDark,
                            ),
                          ),
                          Text(
                            alerta.mensaje,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 14, color: AppColors.warningDark),
                      onPressed: () => setState(() => _alertDismissed = true),
                    ),
                  ],
                ),
              ),
            ],

            // ==========================================
            // 2. TARJETAS DE 5 KPIS
            // ==========================================
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = (constraints.maxWidth - 8) / 2;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // KPI 1: Total Tokens
                    _buildKpiCard(
                      title: 'Total Tokens',
                      value: kpis?.totalTokensFormato ?? '0',
                      subtext: '${kpis?.deltaPct != null && kpis!.deltaPct > 0 ? '+' : ''}${kpis?.deltaPct ?? 0}% vs per. ant.',
                      icon: Icons.bolt_rounded,
                      iconColor: AppColors.primaryBlue,
                      width: itemWidth,
                    ),
                    // KPI 2: Promedio Diario
                    _buildKpiCard(
                      title: 'Promedio Diario',
                      value: kpis?.promedioDiarioFmt ?? '0',
                      subtext: 'tokens / día',
                      icon: Icons.trending_up_rounded,
                      iconColor: AppColors.success,
                      width: itemWidth,
                    ),
                    // KPI 3: Llamadas IA
                    _buildKpiCard(
                      title: 'Llamadas a la IA',
                      value: '${kpis?.totalPeticiones ?? 0}',
                      subtext: 'peticiones procesadas',
                      icon: Icons.memory_rounded,
                      iconColor: AppColors.purple,
                      width: itemWidth,
                    ),
                    // KPI 4: Costo Estimado
                    _buildKpiCard(
                      title: 'Costo Estimado',
                      value: '\$${(kpis?.totalCostoUsd ?? 0.0).toStringAsFixed(2)} USD',
                      subtext: '≈ ${FormatUtils.formatPEN(kpis?.totalCostoPen)}',
                      icon: Icons.attach_money_rounded,
                      iconColor: AppColors.warning,
                      width: itemWidth,
                    ),
                    // KPI 5: Herramienta Top
                    _buildKpiCard(
                      title: 'Herramienta Top',
                      value: kpis?.herramientaMasUsada?.nombre ?? 'Ninguna',
                      subtext: '${kpis?.herramientaMasUsada?.llamadas ?? 0} llamadas (${kpis?.herramientaMasUsada?.porcentaje ?? 0}%)',
                      icon: Icons.build_outlined,
                      iconColor: AppColors.indigo,
                      width: constraints.maxWidth,
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),

            // ==========================================
            // 3. GRÁFICO DE EVOLUCIÓN TEMPORAL DE TOKENS
            // ==========================================
            const Text(
              'EVOLUCIÓN DIARIA DE TOKENS',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 180,
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : serie.isEmpty
                      ? const Center(
                          child: Text(
                            'No se registraron interacciones en este período.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSubtle),
                          ),
                        )
                      : SfCartesianChart(
                          margin: EdgeInsets.zero,
                          plotAreaBorderWidth: 0,
                          primaryXAxis: const CategoryAxis(
                            majorGridLines: MajorGridLines(width: 0),
                            labelStyle: TextStyle(fontSize: 9, color: AppColors.textSubtle),
                            labelRotation: -30,
                          ),
                          primaryYAxis: NumericAxis(
                            axisLine: const AxisLine(width: 0),
                            majorGridLines: const MajorGridLines(
                              color: AppColors.borderSoft,
                              dashArray: <double>[3, 3],
                            ),
                            labelStyle: const TextStyle(fontSize: 9, color: AppColors.textSubtle),
                            numberFormat: null,
                          ),
                          series: <CartesianSeries<TokenDailyPoint, String>>[
                            SplineAreaSeries<TokenDailyPoint, String>(
                              dataSource: serie,
                              xValueMapper: (TokenDailyPoint d, _) => d.fechaCorta,
                              yValueMapper: (TokenDailyPoint d, _) => d.totalTokens,
                              color: AppColors.primaryBlue.withValues(alpha: 0.2),
                              borderColor: AppColors.primaryBlue,
                              borderWidth: 2,
                              name: 'Período Actual',
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(int dias, String label) {
    final isSelected = _activePreset == dias;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => _onPresetChanged(dias),
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected ? AppColors.primaryBlue : AppColors.textMuted,
      ),
      selectedColor: const Color(0xFFEFF6FF),
      backgroundColor: AppColors.surfaceMuted,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isSelected ? const Color(0xFFBFDBFE) : AppColors.borderLight,
        ),
      ),
      showCheckmark: false,
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color iconColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: const TextStyle(fontSize: 9.5, color: AppColors.textSubtle),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
