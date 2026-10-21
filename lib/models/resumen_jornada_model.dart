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
      pedidosConteo: FormatUtils.parseInt(json['pedidos_conteo'], 0),
      montoFacturado: FormatUtils.parseDouble(json['monto_facturado'], 0.0),
      clientesAtendidos: FormatUtils.parseInt(json['clientes_atendidos'], 0),
      tiempoMedioSeg: FormatUtils.parseInt(json['tiempo_medio_seg'], 0),
      porcentajeIa: FormatUtils.parseDouble(json['porcentaje_ia'], 0.0),
      alertasActivas: FormatUtils.parseInt(json['alertas_activas'], 0),
      slaCumplimiento: FormatUtils.parseDouble(json['sla_cumplimiento'], 100.0),
    );
  }

  factory ResumenJornadaModel.fallback() {
    return const ResumenJornadaModel(
      pedidosConteo: 0,
      montoFacturado: 0.0,
      clientesAtendidos: 0,
      tiempoMedioSeg: 0,
      porcentajeIa: 0.0,
      alertasActivas: 0,
      slaCumplimiento: 100.0,
    );
  }
}
