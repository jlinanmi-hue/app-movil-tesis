import '../core/utils/format_utils.dart';

/// Modelo para las 6 tarjetas del "Resumen de la Jornada" (métricas de hoy).
/// Mapea directamente el objeto `resumen_hoy` de `/api/dashboard/ejecutivo`.
class ResumenJornadaModel {
  final int pedidosConteo;
  final double montoFacturado;
  final int clientesAtendidos;
  final int tiempoMedioSeg;
  final double porcentajeIa;
  final int alertasActivas;
  final double slaCumplimiento;

  const ResumenJornadaModel({
    required this.pedidosConteo,
    required this.montoFacturado,
    required this.clientesAtendidos,
    required this.tiempoMedioSeg,
    required this.porcentajeIa,
    required this.alertasActivas,
    required this.slaCumplimiento,
  });

  factory ResumenJornadaModel.fromJson(Map<String, dynamic> json) {
    return ResumenJornadaModel(
      pedidosConteo: FormatUtils.parseInt(json['pedidos_conteo'], 14),
      montoFacturado: FormatUtils.parseDouble(json['monto_facturado'], 3420.50),
      clientesAtendidos: FormatUtils.parseInt(json['clientes_atendidos'], 11),
      tiempoMedioSeg: FormatUtils.parseInt(json['tiempo_medio_seg'], 42),
      porcentajeIa: FormatUtils.parseDouble(json['porcentaje_ia'], 68.4),
      alertasActivas: FormatUtils.parseInt(json['alertas_activas'], 2),
      slaCumplimiento: FormatUtils.parseDouble(json['sla_cumplimiento'], 100.0),
    );
  }

  factory ResumenJornadaModel.fallback() {
    return const ResumenJornadaModel(
      pedidosConteo: 14,
      montoFacturado: 3420.50,
      clientesAtendidos: 11,
      tiempoMedioSeg: 42,
      porcentajeIa: 68.4,
      alertasActivas: 2,
      slaCumplimiento: 100.0,
    );
  }
}
