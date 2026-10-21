import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/format_utils.dart';

class ChatChartWidget extends StatelessWidget {
  final Map<String, dynamic> chartData;

  const ChatChartWidget({super.key, required this.chartData});

  @override
  Widget build(BuildContext context) {
    final title = chartData['title']?.toString() ?? 'Gráfico Generado por IA';
    final type = (chartData['chart_type'] ?? chartData['type'] ?? 'bar').toString().toLowerCase();

    // Soporte robusto para labels (en backend Laravel se envía 'labels', 'categories' o 'x')
    final rawLabels = (chartData['labels'] ?? chartData['categories'] ?? chartData['x']) as List<dynamic>? ?? [];
    final labels = rawLabels.map((e) => e.toString()).toList();

    // Total acumulado y formato monetario
    final total = chartData['total']?.toString();
    final formato = chartData['formato']?.toString() ?? chartData['metadata']?['formato']?.toString() ?? '';
    final unidad = chartData['unidad']?.toString() ?? chartData['metadata']?['unidad']?.toString() ?? '';
    final isMoneda = formato == 'moneda' ||
        unidad == 'soles' ||
        (total != null && total.trim().startsWith('S/')) ||
        title.toLowerCase().contains('ventas') ||
        title.toLowerCase().contains('facturación');

    final rawSeries = chartData['series'] as List<dynamic>? ?? [];

    List<_ChatSeriesPoint> points = [];

    if (rawSeries.isNotEmpty && rawSeries.first is Map) {
      final firstSeries = rawSeries.first as Map<String, dynamic>;
      final dataVals = (firstSeries['data'] as List<dynamic>? ?? []);
      for (int i = 0; i < labels.length && i < dataVals.length; i++) {
        points.add(_ChatSeriesPoint(
          labels[i],
          FormatUtils.parseDouble(dataVals[i]),
        ));
      }
    } else {
      // rawSeries es una lista de números o cadenas numéricas (ej. [24, 1] o ["24", "1"])
      for (int i = 0; i < labels.length && i < rawSeries.length; i++) {
        points.add(_ChatSeriesPoint(
          labels[i],
          FormatUtils.parseDouble(rawSeries[i]),
        ));
      }
    }

    if (points.isEmpty) {
      return const SizedBox.shrink();
    }

    final isPieDonut = type == 'pie' || type == 'donut';
    final isHorizontal = type == 'horizontal_bar' ||
        (!isPieDonut && (type == 'bar' || type == '') && (title.toLowerCase().contains('producto') || title.toLowerCase().contains('cliente')));
    final isArea = type == 'area';
    final isLine = type == 'line';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fixedBorderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la tarjeta con título
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              children: [
                Icon(Icons.bar_chart_rounded, size: 16, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fixedTextDark,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'IA',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Gráfico
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
            child: SizedBox(
              height: 200,
              child: isPieDonut
                  ? SfCircularChart(
                      margin: EdgeInsets.zero,
                      palette: const [
                        Color(0xFF3B82F6),
                        Color(0xFFEF4444),
                        Color(0xFFF59E0B),
                        Color(0xFF10B981),
                        Color(0xFF8B5CF6),
                      ],
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        textStyle: TextStyle(fontSize: 10, color: AppColors.fixedTextDark),
                      ),
                      series: <CircularSeries>[
                        DoughnutSeries<_ChatSeriesPoint, String>(
                          dataSource: points,
                          xValueMapper: (_ChatSeriesPoint p, _) => p.x,
                          yValueMapper: (_ChatSeriesPoint p, _) => p.y,
                          dataLabelSettings: const DataLabelSettings(
                            isVisible: true,
                            textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    )
                  : isHorizontal
                      ? SfCartesianChart(
                          margin: EdgeInsets.zero,
                          primaryXAxis: CategoryAxis(
                            labelStyle: TextStyle(fontSize: 9.5, color: AppColors.fixedTextSubtle),
                          ),
                          primaryYAxis: NumericAxis(
                            labelFormat: isMoneda ? 'S/{value}' : '{value}',
                            labelStyle: TextStyle(fontSize: 9, color: AppColors.fixedTextSubtle),
                          ),
                          series: <CartesianSeries>[
                            BarSeries<_ChatSeriesPoint, String>(
                              dataSource: points,
                              xValueMapper: (_ChatSeriesPoint p, _) => p.x,
                              yValueMapper: (_ChatSeriesPoint p, _) => p.y,
                              color: AppColors.primaryBlue,
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                              dataLabelSettings: const DataLabelSettings(
                                isVisible: true,
                                textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        )
                      : isArea
                          ? SfCartesianChart(
                              margin: EdgeInsets.zero,
                              primaryXAxis: CategoryAxis(
                                labelStyle: TextStyle(fontSize: 9.5, color: AppColors.fixedTextSubtle),
                              ),
                              primaryYAxis: NumericAxis(
                                labelFormat: isMoneda ? 'S/{value}' : '{value}',
                                labelStyle: TextStyle(fontSize: 9, color: AppColors.fixedTextSubtle),
                              ),
                              series: <CartesianSeries>[
                                AreaSeries<_ChatSeriesPoint, String>(
                                  dataSource: points,
                                  xValueMapper: (_ChatSeriesPoint p, _) => p.x,
                                  yValueMapper: (_ChatSeriesPoint p, _) => p.y,
                                  color: AppColors.primaryBlue.withValues(alpha: 0.2),
                                  borderColor: AppColors.primaryBlue,
                                  borderWidth: 2,
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            )
                          : isLine
                              ? SfCartesianChart(
                                  margin: EdgeInsets.zero,
                                  primaryXAxis: CategoryAxis(
                                    labelStyle: TextStyle(fontSize: 9.5, color: AppColors.fixedTextSubtle),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    labelFormat: isMoneda ? 'S/{value}' : '{value}',
                                    labelStyle: TextStyle(fontSize: 9, color: AppColors.fixedTextSubtle),
                                  ),
                                  series: <CartesianSeries>[
                                    LineSeries<_ChatSeriesPoint, String>(
                                      dataSource: points,
                                      xValueMapper: (_ChatSeriesPoint p, _) => p.x,
                                      yValueMapper: (_ChatSeriesPoint p, _) => p.y,
                                      color: AppColors.primaryBlue,
                                      width: 2.5,
                                      markerSettings: const MarkerSettings(isVisible: true, height: 4, width: 4),
                                    ),
                                  ],
                                )
                              : SfCartesianChart(
                                  margin: EdgeInsets.zero,
                                  primaryXAxis: CategoryAxis(
                                    labelStyle: TextStyle(fontSize: 9.5, color: AppColors.fixedTextSubtle),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    labelFormat: isMoneda ? 'S/{value}' : '{value}',
                                    labelStyle: TextStyle(fontSize: 9, color: AppColors.fixedTextSubtle),
                                  ),
                                  series: <CartesianSeries>[
                                    ColumnSeries<_ChatSeriesPoint, String>(
                                      dataSource: points,
                                      xValueMapper: (_ChatSeriesPoint p, _) => p.x,
                                      yValueMapper: (_ChatSeriesPoint p, _) => p.y,
                                      color: AppColors.primaryBlue,
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                      dataLabelSettings: const DataLabelSettings(
                                        isVisible: true,
                                        textStyle: TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
            ),
          ),

          // Pie de la tarjeta con total acumulado (Idéntico a web)
          if (total != null && total.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Text(
                    'Total acumulado: ',
                    style: TextStyle(fontSize: 11, color: AppColors.fixedTextSubtle),
                  ),
                  Text(
                    total,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.fixedTextDark,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ChatSeriesPoint {
  final String x;
  final double y;
  _ChatSeriesPoint(this.x, this.y);
}

