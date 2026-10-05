import '../core/utils/format_utils.dart';

class TokenMetricsResponse {
  final TokenKpis kpis;
  final TokenRange? rango;
  final List<TokenDailyPoint> serieDiaria;

  TokenMetricsResponse({
    required this.kpis,
    this.rango,
    required this.serieDiaria,
  });

  factory TokenMetricsResponse.fromJson(Map<String, dynamic> json) {
    return TokenMetricsResponse(
      kpis: TokenKpis.fromJson(json['kpis'] as Map<String, dynamic>? ?? {}),
      rango: json['rango'] is Map<String, dynamic>
          ? TokenRange.fromJson(json['rango'] as Map<String, dynamic>)
          : null,
      serieDiaria: (json['serie_diaria'] as List<dynamic>? ?? [])
          .map((item) => TokenDailyPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TokenKpis {
  final num totalTokens;
  final String totalTokensFormato;
  final num deltaPct;
  final String promedioDiarioFmt;
  final int totalPeticiones;
  final num totalCostoUsd;
  final num totalCostoPen;
  final TopToolItem? herramientaMasUsada;
  final TokenAlert? alertaConsumo;

  TokenKpis({
    required this.totalTokens,
    required this.totalTokensFormato,
    required this.deltaPct,
    required this.promedioDiarioFmt,
    required this.totalPeticiones,
    required this.totalCostoUsd,
    required this.totalCostoPen,
    this.herramientaMasUsada,
    this.alertaConsumo,
  });

  factory TokenKpis.fromJson(Map<String, dynamic> json) {
    return TokenKpis(
      totalTokens: FormatUtils.parseNum(json['total_tokens'], 0),
      totalTokensFormato: (json['total_tokens_formato'] ?? '0').toString(),
      deltaPct: FormatUtils.parseNum(json['delta_pct'], 0),
      promedioDiarioFmt: (json['promedio_diario_fmt'] ?? '0').toString(),
      totalPeticiones: FormatUtils.parseInt(json['total_peticiones'], 0),
      totalCostoUsd: FormatUtils.parseNum(json['total_costo_usd'], 0.0),
      totalCostoPen: FormatUtils.parseNum(json['total_costo_pen'], 0.0),
      herramientaMasUsada: json['herramienta_mas_usada'] is Map<String, dynamic>
          ? TopToolItem.fromJson(json['herramienta_mas_usada'] as Map<String, dynamic>)
          : null,
      alertaConsumo: json['alerta_consumo'] is Map<String, dynamic>
          ? TokenAlert.fromJson(json['alerta_consumo'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TopToolItem {
  final String nombre;
  final int llamadas;
  final num porcentaje;

  TopToolItem({
    required this.nombre,
    required this.llamadas,
    required this.porcentaje,
  });

  factory TopToolItem.fromJson(Map<String, dynamic> json) {
    return TopToolItem(
      nombre: (json['nombre'] ?? 'Ninguna').toString(),
      llamadas: (json['llamadas'] is num) ? (json['llamadas'] as num).toInt() : 0,
      porcentaje: (json['porcentaje'] is num) ? (json['porcentaje'] as num) : 0,
    );
  }
}

class TokenAlert {
  final bool activo;
  final String mensaje;

  TokenAlert({required this.activo, required this.mensaje});

  factory TokenAlert.fromJson(Map<String, dynamic> json) {
    return TokenAlert(
      activo: json['activo'] == true,
      mensaje: (json['mensaje'] ?? '').toString(),
    );
  }
}

class TokenRange {
  final int dias;
  final String? label;
  final String? fechaDesde;
  final String? fechaHasta;

  TokenRange({
    required this.dias,
    this.label,
    this.fechaDesde,
    this.fechaHasta,
  });

  factory TokenRange.fromJson(Map<String, dynamic> json) {
    return TokenRange(
      dias: FormatUtils.parseInt(json['dias'], 30),
      label: json['label']?.toString(),
      fechaDesde: json['fecha_desde']?.toString(),
      fechaHasta: json['fecha_hasta']?.toString(),
    );
  }
}

class TokenDailyPoint {
  final String fecha;
  final String fechaCorta;
  final num totalTokens;
  final num totalTokensPrev;
  final num promptTokens;
  final num candidatesTokens;
  final int totalPeticiones;
  final num costoUsd;

  TokenDailyPoint({
    required this.fecha,
    required this.fechaCorta,
    required this.totalTokens,
    required this.totalTokensPrev,
    required this.promptTokens,
    required this.candidatesTokens,
    required this.totalPeticiones,
    required this.costoUsd,
  });

  factory TokenDailyPoint.fromJson(Map<String, dynamic> json) {
    return TokenDailyPoint(
      fecha: (json['fecha'] ?? '').toString(),
      fechaCorta: (json['fecha_corta'] ?? json['fecha'] ?? '').toString(),
      totalTokens: FormatUtils.parseNum(json['total_tokens'], 0),
      totalTokensPrev: FormatUtils.parseNum(json['total_tokens_prev'], 0),
      promptTokens: FormatUtils.parseNum(json['prompt_tokens'], 0),
      candidatesTokens: FormatUtils.parseNum(json['candidates_tokens'], 0),
      totalPeticiones: FormatUtils.parseInt(json['total_peticiones'], 0),
      costoUsd: FormatUtils.parseNum(json['costo_usd'], 0.0),
    );
  }
}
