import 'dart:convert';

/// Modelo de datos para Notificaciones en Comercial Valencia
class AppNotificationModel {
  final String id;
  final String titulo;
  final String mensaje;
  final String tipo; // success, warning, danger, error, merma, manual, info
  final String categoria; // INVENTARIO, COMPRAS, VENTAS, GENERAL
  final String? referenciaId;
  final Map<String, dynamic>? datos;
  final bool leida;
  final bool silenciosa;
  final DateTime? fecha;
  final String? usuarioId;

  AppNotificationModel({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.categoria,
    this.referenciaId,
    this.datos,
    required this.leida,
    this.silenciosa = false,
    this.fecha,
    this.usuarioId,
  });

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedDatos;
    final rawDatos = json['NotificacionDatos'] ?? json['datos'];
    if (rawDatos is Map<String, dynamic>) {
      parsedDatos = rawDatos;
    } else if (rawDatos is Map) {
      parsedDatos = Map<String, dynamic>.from(rawDatos);
    } else if (rawDatos is String && rawDatos.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDatos);
        if (decoded is Map) {
          parsedDatos = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    DateTime? fechaParsed;
    final rawFecha = (json['NotificacionFecha'] ?? json['fecha'] ?? json['created_at'])?.toString();
    if (rawFecha != null && rawFecha.isNotEmpty) {
      try {
        fechaParsed = DateTime.parse(rawFecha).toLocal();
      } catch (_) {}
    }

    final leidaStr = (json['NotificacionLeida'] ?? json['leida'] ?? 'N').toString().toUpperCase();
    final silenciosaStr = (json['NotificacionSilenciosa'] ?? json['silenciosa'] ?? 'N').toString().toUpperCase();

    return AppNotificationModel(
      id: json['NotificacionId']?.toString() ?? json['id']?.toString() ?? '',
      titulo: json['NotificacionTitulo']?.toString() ?? json['titulo']?.toString() ?? 'Notificación',
      mensaje: json['NotificacionMensaje']?.toString() ?? json['mensaje']?.toString() ?? '',
      tipo: (json['NotificacionTipo']?.toString() ?? json['tipo']?.toString() ?? 'info').toLowerCase(),
      categoria: (json['NotificacionCategoria']?.toString() ?? json['categoria']?.toString() ?? 'GENERAL').toUpperCase(),
      referenciaId: json['NotificacionReferenciaId']?.toString() ?? json['referencia_id']?.toString(),
      datos: parsedDatos,
      leida: leidaStr == 'S' || leidaStr == '1' || leidaStr == 'TRUE',
      silenciosa: silenciosaStr == 'S' || silenciosaStr == '1' || silenciosaStr == 'TRUE',
      fecha: fechaParsed,
      usuarioId: json['NotificacionUsuarioId']?.toString() ?? json['usuario_id']?.toString(),
    );
  }

  /// Retorna una copia con campos modificados
  AppNotificationModel copyWith({
    bool? leida,
  }) {
    return AppNotificationModel(
      id: id,
      titulo: titulo,
      mensaje: mensaje,
      tipo: tipo,
      categoria: categoria,
      referenciaId: referenciaId,
      datos: datos,
      leida: leida ?? this.leida,
      silenciosa: silenciosa,
      fecha: fecha,
      usuarioId: usuarioId,
    );
  }

  /// Helper para tiempo relativo amigable (ej: "Hace 5 min", "Hoy, 14:30")
  String get tiempoRelativo {
    if (fecha == null) return 'Reciente';
    final now = DateTime.now();
    final diff = now.difference(fecha!);

    if (diff.inSeconds < 60) {
      return 'Hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'Hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      final hour = fecha!.hour.toString().padLeft(2, '0');
      final minute = fecha!.minute.toString().padLeft(2, '0');
      return 'Hoy, $hour:$minute';
    } else if (diff.inDays == 1) {
      final hour = fecha!.hour.toString().padLeft(2, '0');
      final minute = fecha!.minute.toString().padLeft(2, '0');
      return 'Ayer, $hour:$minute';
    } else {
      final day = fecha!.day.toString().padLeft(2, '0');
      final month = fecha!.month.toString().padLeft(2, '0');
      return '$day/$month/${fecha!.year}';
    }
  }

  /// Obtiene impacto financiero formateado si existe (ej: "S/ 150.00")
  String? get impactoFinancieroTexto {
    if (datos == null) return null;
    final impacto = datos!['impacto_financiero'];
    if (impacto is Map<String, dynamic>) {
      final costo = impacto['costo_total_perdido'];
      if (costo != null) {
        return 'Pérdida: S/ ${costo.toString()}';
      }
    }
    return null;
  }
}
