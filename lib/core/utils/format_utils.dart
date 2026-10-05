import 'package:intl/intl.dart';

class FormatUtils {
  static final NumberFormat _penFormat = NumberFormat.currency(
    locale: 'es_PE',
    symbol: 'S/ ',
    decimalDigits: 2,
  );

  static final NumberFormat _usdFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 2,
  );

  static final NumberFormat _integerFormat = NumberFormat.decimalPattern('es_PE');

  /// Formatea en Soles Peruanos: ej. S/ 1,250.50
  static String formatPEN(num? value) {
    if (value == null) return 'S/ 0.00';
    return _penFormat.format(value);
  }

  /// Formatea en Dólares: ej. $12.50
  static String formatUSD(num? value) {
    if (value == null) return '\$0.00';
    return _usdFormat.format(value);
  }

  /// Formatea cantidades enteras con separador de miles: ej. 1,450
  static String formatInteger(num? value) {
    if (value == null) return '0';
    return _integerFormat.format(value);
  }

  /// Formatea porcentajes: ej. 95.0%
  static String formatPercentage(num? value, {int decimals = 1}) {
    if (value == null) return '0%';
    return '${value.toStringAsFixed(decimals)}%';
  }

  /// Formatea números de forma compacta (K, M)
  static String formatCompact(num? value) {
    if (value == null) return '0';
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }

  /// Formatea fecha corta: ej. 15/09/2026
  static String formatDateShort(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Formatea fecha y hora: ej. 15/09/2026 15:30
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  /// Convierte con seguridad cualquier valor dinámico (num, String numérico) a double
  static double parseDouble(dynamic val, [double def = 0.0]) {
    if (val == null) return def;
    if (val is num) return val.toDouble();
    if (val is String) {
      return double.tryParse(val) ?? def;
    }
    return def;
  }

  /// Convierte con seguridad cualquier valor dinámico (num, String numérico) a int
  static int parseInt(dynamic val, [int def = 0]) {
    if (val == null) return def;
    if (val is num) return val.toInt();
    if (val is String) {
      return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? def);
    }
    return def;
  }

  /// Convierte con seguridad cualquier valor dinámico a num
  static num parseNum(dynamic val, [num def = 0]) {
    if (val == null) return def;
    if (val is num) return val;
    if (val is String) {
      return num.tryParse(val) ?? def;
    }
    return def;
  }
}
