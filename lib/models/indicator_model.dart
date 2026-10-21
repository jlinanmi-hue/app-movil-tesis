import '../core/utils/format_utils.dart';

class DashboardIndicatorsResponse {
  final IndicatorItem pode;
  final IndicatorItem peor;
  final IndicatorItem prs;
  final IndicatorItem tbpp;

  DashboardIndicatorsResponse({
    required this.pode,
    required this.peor,
    required this.prs,
    required this.tbpp,
  });

  factory DashboardIndicatorsResponse.fromJson(Map<String, dynamic> json) {
    return DashboardIndicatorsResponse(
      pode: IndicatorItem.fromJson(1, 'pode', json['pode'] as Map<String, dynamic>? ?? {}),
      peor: IndicatorItem.fromJson(2, 'peor', json['peor'] as Map<String, dynamic>? ?? {}),
      prs: IndicatorItem.fromJson(3, 'prs', json['prs'] as Map<String, dynamic>? ?? {}),
      tbpp: IndicatorItem.fromJson(4, 'tbpp', json['tbpp'] as Map<String, dynamic>? ?? {}),
    );
  }

  /// Retorna todos los indicadores del payload (para compatibilidad de serialización)
  List<IndicatorItem> get all => [pode, peor, prs, tbpp];

  /// Únicamente los 3 indicadores oficiales que maneja la web: POD, PRS e ITBPP
  List<IndicatorItem> get oficiales => [pode, prs, tbpp];
}

class IndicatorItem {
  final int id;
  final String key;
  final String titulo;
  final String subtitulo;
  final double resultado;
  final double meta;
  final String? periodo;
  final String? formula;
  final String? frecuencia;
  final IndicatorAnterior? anterior;

  IndicatorItem({
    required this.id,
    required this.key,
    required this.titulo,
    required this.subtitulo,
    required this.resultado,
    required this.meta,
    this.periodo,
    this.formula,
    this.frecuencia,
    this.anterior,
  });

  /// Sigla oficial de tesis: POD, PRS o ITBPP
  String get sigla {
    switch (key.toLowerCase()) {
      case 'pode':
        return 'POD';
      case 'prs':
        return 'PRS';
      case 'tbpp':
        return 'ITBPP';
      default:
        return key.toUpperCase();
    }
  }

  factory IndicatorItem.fromJson(int id, String key, Map<String, dynamic> json) {
    final titles = {
      'pode': 'Órdenes Despachadas con Éxito (POD)',
      'peor': 'Tasa de Error en Procesamiento (PEOR)',
      'prs': 'Quiebres de Stock Semanales (PRS)',
      'tbpp': 'Tiempo de Registro por Pedido (ITBPP)',
    };

    final subtitles = {
      'pode': 'Cumplimiento general de entrega',
      'peor': 'Precisión y captura sin fallos',
      'prs': 'Incidencias por falta de inventario',
      'tbpp': 'Agilidad de atención con asistencia IA',
    };

    final defaultMetas = {
      'pode': 95.0,
      'peor': 2.0,
      'prs': 3.0,
      'tbpp': 180.0,
    };

    return IndicatorItem(
      id: id,
      key: key,
      titulo: json['titulo']?.toString() ?? titles[key] ?? key.toUpperCase(),
      subtitulo: json['subtitulo']?.toString() ?? subtitles[key] ?? '',
      resultado: FormatUtils.parseDouble(json['resultado'], defaultMetas[key] ?? 0.0),
      meta: FormatUtils.parseDouble(json['meta'], defaultMetas[key] ?? 0.0),
      periodo: json['periodo']?.toString(),
      formula: json['formula']?.toString(),
      frecuencia: json['frecuencia']?.toString(),
      anterior: json['anterior'] is Map<String, dynamic>
          ? IndicatorAnterior.fromJson(json['anterior'] as Map<String, dynamic>)
          : null,
    );
  }
}

class IndicatorAnterior {
  final double? valor;
  final double? deltaPct;

  IndicatorAnterior({this.valor, this.deltaPct});

  factory IndicatorAnterior.fromJson(Map<String, dynamic> json) {
    return IndicatorAnterior(
      valor: json['valor'] != null ? FormatUtils.parseDouble(json['valor']) : null,
      deltaPct: json['delta_pct'] != null ? FormatUtils.parseDouble(json['delta_pct']) : null,
    );
  }
}

/// Flujo de Órdenes y Etapas Operativas (Legacy / Operacional)
class OrderFlowResponse {
  final int totalPedidos;
  final String totalPedidosFormateado;
  final StageItem recepcionIa;
  final StageItem validacion;
  final StageItem preparacion;
  final StageItem despachado;

  OrderFlowResponse({
    required this.totalPedidos,
    required this.totalPedidosFormateado,
    required this.recepcionIa,
    required this.validacion,
    required this.preparacion,
    required this.despachado,
  });

  factory OrderFlowResponse.fromJson(Map<String, dynamic> json) {
    final resumen = json['resumen_general'] as Map<String, dynamic>? ?? {};
    final flujo = json['flujo_ordenes'] as Map<String, dynamic>? ?? {};

    return OrderFlowResponse(
      totalPedidos: FormatUtils.parseInt(resumen['total_pedidos'], 21),
      totalPedidosFormateado: (resumen['total_pedidos_formateado'] ?? '21').toString(),
      recepcionIa: StageItem.fromJson(flujo['recepcion_ia'], 'Recepción por IA', 'Entrada multicanal', 'Registrados: 21'),
      validacion: StageItem.fromJson(flujo['validacion'], 'Validación de Pedido', 'Filtro de stock y precios', 'Pendientes: 6'),
      preparacion: StageItem.fromJson(flujo['preparacion'], 'Preparación en Almacén', 'Picking y empaquetado', 'En Proceso: 11'),
      despachado: StageItem.fromJson(flujo['despachado'], 'Pedido Despachado', 'Salida con transportista', 'Completados: 5'),
    );
  }
}

class StageItem {
  final String titulo;
  final String subtitulo;
  final String badge;
  final int count;

  StageItem({
    required this.titulo,
    required this.subtitulo,
    required this.badge,
    required this.count,
  });

  factory StageItem.fromJson(dynamic json, String defaultTitle, String defaultSubtitle, String defaultBadge) {
    if (json is Map<String, dynamic>) {
      return StageItem(
        titulo: json['titulo']?.toString() ?? defaultTitle,
        subtitulo: json['subtitulo']?.toString() ?? defaultSubtitle,
        badge: json['badge']?.toString() ?? defaultBadge,
        count: FormatUtils.parseInt(json['count'], 0),
      );
    }
    return StageItem(
      titulo: defaultTitle,
      subtitulo: defaultSubtitle,
      badge: defaultBadge,
      count: 0,
    );
  }
}
