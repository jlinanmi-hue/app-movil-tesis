import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:syncfusion_flutter_charts/charts.dart' hide CornerStyle;
import '../../../core/constants/app_colors.dart';
import '../../../models/indicator_model.dart';

class IndicatorCardWidget extends StatelessWidget {
  final IndicatorItem indicator;
  final VoidCallback onTap;

  const IndicatorCardWidget({
    super.key,
    required this.indicator,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // ==========================================
              // CABECERA: TÍTULO, SUBTÍTULO E ÍCONO
              // ==========================================
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          indicator.titulo,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          indicator.subtitulo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildIconContainer(),
                ],
              ),
              const SizedBox(height: 10),

              // ==========================================
              // GRÁFICO ESPECÍFICO DEL INDICADOR
              // ==========================================
              SizedBox(
                height: 120,
                width: double.infinity,
                child: _buildChart(),
              ),
              const SizedBox(height: 10),

              // ==========================================
              // PIE: META Y ENLACE A SUBGRÁFICOS
              // ==========================================
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.borderSoft, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Text(
                            _getMetaText(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          _isCumple ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                          size: 14,
                          color: _isCumple ? AppColors.success : AppColors.warning,
                        ),
                      ],
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Subgráficos',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: AppColors.primaryBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconContainer() {
    IconData icon;
    Color iconColor;
    Color bgColor;

    switch (indicator.id) {
      case 1:
        icon = Icons.gps_fixed_rounded;
        iconColor = AppColors.primaryBlue;
        bgColor = const Color(0xFFEFF6FF);
        break;
      case 2:
        icon = Icons.trending_down_rounded;
        iconColor = AppColors.success;
        bgColor = AppColors.successBg;
        break;
      case 3:
        icon = Icons.inventory_2_outlined;
        iconColor = AppColors.purple;
        bgColor = AppColors.purpleBg;
        break;
      case 4:
      default:
        icon = Icons.access_time_rounded;
        iconColor = AppColors.indigo;
        bgColor = AppColors.indigoBg;
        break;
    }

    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: 18),
    );
  }

  bool get _isCumple {
    switch (indicator.id) {
      case 1:
        return indicator.resultado >= indicator.meta;
      case 2:
      case 3:
      case 4:
      default:
        return indicator.resultado <= indicator.meta;
    }
  }

  String _getMetaText() {
    switch (indicator.id) {
      case 1:
        return 'Meta: ≥ ${indicator.meta.toInt()}%';
      case 2:
        return 'Meta: ≤ ${indicator.meta.toInt()}%';
      case 3:
        return 'Meta: ≤ ${indicator.meta.toInt()}%';
      case 4:
      default:
        return 'Meta: ≤ ${indicator.meta.toInt()}s';
    }
  }

  Widget _buildChart() {
    switch (indicator.id) {
      case 1:
        return _buildPodeGauge();
      case 2:
        return _buildPeorTrend();
      case 3:
        return _buildPrsBars();
      case 4:
      default:
        return _buildTbppCurve();
    }
  }

  // ----------------------------------------------------
  // INDICADOR 1: PODE - GAUGE SEMICIRCULAR NATIVO SYNFCUSION
  // ----------------------------------------------------
  Widget _buildPodeGauge() {
    final delta = indicator.anterior?.deltaPct;
    final deltaText = delta != null
        ? '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)}% vs mes ant.'
        : '+3.0% vs mes pasado';

    return Stack(
      alignment: Alignment.center,
      children: [
        SfRadialGauge(
          axes: <RadialAxis>[
            RadialAxis(
              startAngle: 180,
              endAngle: 0,
              canScaleToFit: true,
              showLabels: false,
              showTicks: false,
              radiusFactor: 0.95,
              axisLineStyle: AxisLineStyle(
                thickness: 12,
                color: const Color(0xFFE2E8F0),
                cornerStyle: CornerStyle.bothCurve,
              ),
              pointers: <GaugePointer>[
                RangePointer(
                  value: indicator.resultado.clamp(0, 100),
                  width: 12,
                  color: AppColors.success,
                  cornerStyle: CornerStyle.bothCurve,
                  gradient: const SweepGradient(
                    colors: [AppColors.success, AppColors.primaryBlue],
                    stops: [0.6, 1.0],
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${indicator.resultado.toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                deltaText,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.successDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // INDICADOR 2: PEOR - LÍNEA DE TENDENCIA DESCENDENTE
  // ----------------------------------------------------
  Widget _buildPeorTrend() {
    final dataPoints = [
      _ChartData('Sem 1', 11.5),
      _ChartData('Sem 2', 8.2),
      _ChartData('Sem 3', 6.4),
      _ChartData('Sem 4', 4.1),
      _ChartData('Sem 5', 2.8),
      _ChartData('Sem 6', indicator.resultado),
    ];

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(color: AppColors.borderLight),
        labelStyle: TextStyle(fontSize: 9, color: AppColors.textSubtle),
      ),
      primaryYAxis: const NumericAxis(
        isVisible: false,
      ),
      series: <CartesianSeries<_ChartData, String>>[
        SplineAreaSeries<_ChartData, String>(
          dataSource: dataPoints,
          xValueMapper: (_ChartData d, _) => d.x,
          yValueMapper: (_ChartData d, _) => d.y,
          color: AppColors.success.withValues(alpha: 0.18),
          borderColor: AppColors.success,
          borderWidth: 2.2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 6,
            width: 6,
            color: AppColors.success,
            borderColor: Colors.white,
            borderWidth: 1.5,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // INDICADOR 3: PRS - BARRAS MORADAS DECRECIENTES HACIA CERO
  // ----------------------------------------------------
  Widget _buildPrsBars() {
    final dataPoints = [
      _ChartData('Sem 1', 8.0),
      _ChartData('Sem 2', 5.5),
      _ChartData('Sem 3', 4.2),
      _ChartData('Sem 4', 2.3),
      _ChartData('Sem 5', 1.2),
      _ChartData('Sem 6', indicator.resultado),
    ];

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(color: AppColors.borderLight),
        labelStyle: TextStyle(fontSize: 9, color: AppColors.textSubtle),
      ),
      primaryYAxis: const NumericAxis(
        isVisible: false,
      ),
      series: <CartesianSeries<_ChartData, String>>[
        ColumnSeries<_ChartData, String>(
          dataSource: dataPoints,
          xValueMapper: (_ChartData d, _) => d.x,
          yValueMapper: (_ChartData d, _) => d.y,
          color: AppColors.purple,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          width: 0.55,
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // INDICADOR 4: TBPP - CURVA ÍNDIGO DE OPTIMIZACIÓN CON IA
  // ----------------------------------------------------
  Widget _buildTbppCurve() {
    final dataPoints = [
      _ChartData('Sem 1', 180.0),
      _ChartData('Sem 2', 125.0),
      _ChartData('Sem 3', 75.0),
      _ChartData('Sem 4', 38.0),
      _ChartData('Sem 5', 18.0),
      _ChartData('Sem 6', indicator.resultado * 1.5),
    ];

    return SfCartesianChart(
      margin: EdgeInsets.zero,
      plotAreaBorderWidth: 0,
      primaryXAxis: const CategoryAxis(
        majorGridLines: MajorGridLines(width: 0),
        axisLine: AxisLine(color: AppColors.borderLight),
        labelStyle: TextStyle(fontSize: 9, color: AppColors.textSubtle),
      ),
      primaryYAxis: const NumericAxis(
        isVisible: false,
      ),
      series: <CartesianSeries<_ChartData, String>>[
        SplineAreaSeries<_ChartData, String>(
          dataSource: dataPoints,
          xValueMapper: (_ChartData d, _) => d.x,
          yValueMapper: (_ChartData d, _) => d.y,
          color: AppColors.indigo.withValues(alpha: 0.18),
          borderColor: AppColors.indigo,
          borderWidth: 2.2,
          markerSettings: const MarkerSettings(
            isVisible: true,
            height: 6,
            width: 6,
            color: AppColors.indigo,
            borderColor: Colors.white,
            borderWidth: 1.5,
          ),
        ),
      ],
    );
  }
}

class _ChartData {
  final String x;
  final double y;
  _ChartData(this.x, this.y);
}
