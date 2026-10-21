import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ChatTableWidget extends StatelessWidget {
  final Map<String, dynamic> tableData;

  const ChatTableWidget({super.key, required this.tableData});

  @override
  Widget build(BuildContext context) {
    final title = tableData['title']?.toString() ?? 'Tabla de Datos';
    final headers = (tableData['headers'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final rawRows = (tableData['rows'] as List<dynamic>? ?? []);

    if (headers.isEmpty || rawRows.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fixedBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.fixedTextDark),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.fixedSurfaceMuted),
              headingTextStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.fixedTextDark,
              ),
              dataTextStyle: TextStyle(
                fontSize: 10.5,
                color: AppColors.fixedTextDark,
              ),
              columnSpacing: 16,
              horizontalMargin: 12,
              columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
              rows: rawRows.map((row) {
                List<dynamic> cells = [];
                if (row is List) {
                  cells = row;
                } else if (row is Map) {
                  cells = row.values.toList();
                }

                return DataRow(
                  cells: cells.map((cell) => DataCell(Text(cell.toString()))).toList(),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
