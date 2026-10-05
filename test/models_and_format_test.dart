import 'package:flutter_test/flutter_test.dart';
import 'package:app_tesis/models/user_model.dart';
import 'package:app_tesis/models/indicator_model.dart';
import 'package:app_tesis/models/token_metrics_model.dart';
import 'package:app_tesis/models/chat_message_model.dart';
import 'package:app_tesis/core/utils/format_utils.dart';

void main() {
  group('Modelos y Serialización', () {
    test('UserModel parsea correctamente respuesta de AuthController', () {
      final json = {
        'usuario': {
          'UsuarioId': 'usr-001',
          'UsuarioUserName': 'admin',
          'rol': 'Administrador General',
        },
        'empleado': {
          'EmpleadoId': 'emp-101',
          'EmpleadoNombres': 'Carlos',
          'EmpleadoApellidos': 'Valencia',
          'EmpleadoCorreo': 'carlos@valencia.com',
          'cargo': 'Gerente General',
          'estado': 'A',
        },
        'token': 'mock-jwt-token',
      };

      final user = UserModel.fromJson(json);

      expect(user.usuarioId, 'usr-001');
      expect(user.userName, 'admin');
      expect(user.nombreCompleto, 'Carlos Valencia');
      expect(user.cargo, 'Gerente General');
      expect(user.token, 'mock-jwt-token');
    });

    test('DashboardIndicatorsResponse parsea los 4 indicadores de Tesis', () {
      final json = {
        'pode': {
          'resultado': 95.5,
          'meta': 95,
          'periodo': '2026-09',
          'formula': '(OD / TR) * 100',
          'frecuencia': 'Mensual',
          'anterior': {'valor': 92.0, 'delta_pct': 3.5},
        },
        'peor': {
          'resultado': 2.2,
          'meta': 3,
          'periodo': '2026-09',
          'formula': '(OE / TR) * 100',
          'frecuencia': 'Mensual',
          'anterior': {'valor': 2.8, 'delta_pct': -21.4},
        },
        'prs': {
          'resultado': 4.1,
          'meta': 5,
          'periodo': '2026-W37',
          'formula': '(RS / TS) * 100',
          'frecuencia': 'Semanal',
          'anterior': {'valor': 4.6, 'delta_pct': -10.8},
        },
        'tbpp': {
          'resultado': 8.2,
          'meta': 10,
          'periodo': '2026-09',
          'formula': 'Promedio(TB)',
          'frecuencia': 'Mensual',
          'anterior': {'valor': 13.5, 'delta_pct': -39.2},
        },
      };

      final res = DashboardIndicatorsResponse.fromJson(json);

      expect(res.pode.resultado, 95.5);
      expect(res.pode.meta, 95.0);
      expect(res.pode.anterior?.deltaPct, 3.5);

      expect(res.peor.resultado, 2.2);
      expect(res.peor.meta, 3.0);

      expect(res.prs.resultado, 4.1);
      expect(res.tbpp.resultado, 8.2);
      expect(res.all.length, 4);
    });

    test('OrderFlowResponse parsea el flujo de órdenes operativas', () {
      final json = {
        'resumen_general': {
          'total_pedidos': 24,
          'total_pedidos_formateado': '24',
        },
        'flujo_ordenes': {
          'recepcion_ia': {'badge': 'Registrados: 24', 'count': 24},
          'validacion': {'badge': 'Pendientes: 5', 'count': 5},
          'preparacion': {'badge': 'En Proceso: 12', 'count': 12},
          'despachado': {'badge': 'Completados: 7', 'count': 7},
        },
      };

      final flow = OrderFlowResponse.fromJson(json);

      expect(flow.totalPedidos, 24);
      expect(flow.totalPedidosFormateado, '24');
      expect(flow.recepcionIa.count, 24);
      expect(flow.validacion.count, 5);
      expect(flow.preparacion.count, 12);
      expect(flow.despachado.count, 7);
    });

    test('TokenMetricsResponse parsea KPIs y series de Gemini Flash', () {
      final json = {
        'kpis': {
          'total_tokens': 1250000,
          'total_tokens_formato': '1.25M',
          'delta_pct': 14.2,
          'promedio_diario_fmt': '41,667',
          'total_peticiones': 180,
          'total_costo_usd': 0.35,
          'total_costo_pen': 1.31,
          'herramienta_mas_usada': {
            'nombre': 'consultar_stock',
            'llamadas': 68,
            'porcentaje': 37.8,
          },
          'alerta_consumo': {
            'activo': false,
            'mensaje': '',
          },
        },
        'rango': {
          'dias': 30,
          'label': 'Últimos 30 días',
        },
        'serie_diaria': [
          {
            'fecha': '2026-09-01',
            'fecha_corta': '01/09',
            'total_tokens': 45000,
            'total_tokens_prev': 38000,
            'prompt_tokens': 32000,
            'candidates_tokens': 13000,
            'total_peticiones': 10,
            'costo_usd': 0.015,
          },
        ],
      };

      final tokens = TokenMetricsResponse.fromJson(json);

      expect(tokens.kpis.totalTokensFormato, '1.25M');
      expect(tokens.kpis.totalPeticiones, 180);
      expect(tokens.kpis.totalCostoUsd, 0.35);
      expect(tokens.kpis.herramientaMasUsada?.nombre, 'consultar_stock');
      expect(tokens.serieDiaria.length, 1);
      expect(tokens.serieDiaria.first.totalTokens, 45000);
    });

    test('ChatMessageModel maneja chips interactivos y badges de tools de IA', () {
      final chipJson = {
        'label': '📈 Evolución Diaria de Ventas',
        'query': 'Muestra el gráfico de ventas de los últimos 7 días',
      };
      final chip = ChatChipModel.fromJson(chipJson);
      expect(chip.label, '📈 Evolución Diaria de Ventas');
      expect(chip.query, 'Muestra el gráfico de ventas de los últimos 7 días');

      final msg = ChatMessageModel(
        id: 'msg-1',
        sender: 'assistant',
        text: 'Centro de Estadísticas',
        timestamp: DateTime.now(),
        toolUsed: 'listar_graficos_disponibles',
        toolSuccess: true,
        chips: [chip],
        logId: 101,
      );

      expect(msg.isAssistant, isTrue);
      expect(msg.hasChips, isTrue);
      expect(msg.chips!.length, 1);
      expect(msg.toolUsed, 'listar_graficos_disponibles');
      expect(msg.canFeedback, isTrue);
    });

    test('UiActionModel parsea render_chart de generar_grafico_dashboard del backend', () {
      final json = {
        'type': 'render_chart',
        'chart': {
          'type': 'bar',
          'title': 'Evolución Diaria de Ventas',
          'labels': ['10/09', '11/09', '12/09'],
          'series': [150.5, 200.0, 317.38],
          'total': 'S/ 667.88',
        },
      };

      final uiAction = UiActionModel.fromJson(json);

      expect(uiAction.type, 'render_chart');
      expect(uiAction.title, 'Evolución Diaria de Ventas');
      expect(uiAction.chartData, isNotNull);
      expect(uiAction.chartData!['labels'], ['10/09', '11/09', '12/09']);
      expect(uiAction.chartData!['total'], 'S/ 667.88');
    });
  });

  group('FormatUtils Formateo Monetario y Numérico', () {
    test('Formatea correctamente moneda peruana (PEN)', () {
      final pen = FormatUtils.formatPEN(1250.50);
      expect(pen.contains('S/'), isTrue);
      expect(pen.contains('1,250.50') || pen.contains('1.250,50') || pen.contains('1250.50'), isTrue);
    });

    test('Formatea correctamente números compactos', () {
      expect(FormatUtils.formatCompact(1500000), '1.5M');
      expect(FormatUtils.formatCompact(45000), '45.0k');
      expect(FormatUtils.formatCompact(350), '350');
    });

    test('Formatea porcentajes adecuadamente', () {
      expect(FormatUtils.formatPercentage(95.4), '95.4%');
      expect(FormatUtils.formatPercentage(100.0, decimals: 0), '100%');
    });
  });
}
