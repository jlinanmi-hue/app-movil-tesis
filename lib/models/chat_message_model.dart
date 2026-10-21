class ChatChipModel {
  final String label;
  final String query;
  final String? action;
  final Map<String, dynamic>? params;

  const ChatChipModel({
    required this.label,
    required this.query,
    this.action,
    this.params,
  });

  factory ChatChipModel.fromJson(Map<String, dynamic> json) {
    return ChatChipModel(
      label: json['label']?.toString() ?? json['titulo']?.toString() ?? '',
      query: json['query']?.toString() ?? json['label']?.toString() ?? json['titulo']?.toString() ?? '',
      action: json['action']?.toString(),
      params: json['params'] is Map ? Map<String, dynamic>.from(json['params'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'query': query,
    if (action != null) 'action': action,
    if (params != null) 'params': params,
  };
}

class ChatMessageModel {
  final String id;
  final String sender; // 'user' o 'assistant'
  String text;
  final DateTime timestamp;
  final String? sessionId;
  final int? logId;
  final String? toolUsed;
  final bool? toolSuccess;
  final String? toolStatus;
  UiActionModel? uiAction;
  List<ChatChipModel>? chips;
  String? feedback; // null, 'like', 'dislike'
  String? feedbackReason;
  bool isStreaming;
  final bool isVoiceNote;
  final int? audioDurationSec;
  final String? imageBase64;

  ChatMessageModel({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.sessionId,
    this.logId,
    this.toolUsed,
    this.toolSuccess,
    this.toolStatus,
    this.uiAction,
    this.chips,
    this.feedback,
    this.feedbackReason,
    this.isStreaming = false,
    this.isVoiceNote = false,
    this.audioDurationSec,
    this.imageBase64,
  });

  bool get isUser => sender == 'user';
  bool get isAssistant => sender == 'assistant';
  bool get hasUiAction => uiAction != null;
  bool get hasChips => chips != null && chips!.isNotEmpty;
  bool get canFeedback => logId != null && isAssistant && !isStreaming;
}

class UiActionModel {
  final String type; // 'render_chart', 'render_table', 'open_order_form', 'open_purchase_order_form'
  final String? form; // 'pedido', 'orden_compra', 'cliente', 'proveedor'
  final String? title;
  final Map<String, dynamic>? chartData;
  final Map<String, dynamic>? tableData;
  final Map<String, dynamic>? prefill;
  final Map<String, dynamic>? raw;

  UiActionModel({
    required this.type,
    this.form,
    this.title,
    this.chartData,
    this.tableData,
    this.prefill,
    this.raw,
  });

  factory UiActionModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? '').toString();
    final form = json['form']?.toString();
    final data = json['data'] != null && json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : json;

    Map<String, dynamic>? chart;
    if (type == 'render_chart' || data.containsKey('chart')) {
      final rawChart = data['chart'] ?? data;
      if (rawChart is Map) {
        chart = Map<String, dynamic>.from(rawChart);
      }
    }

    Map<String, dynamic>? table;
    if (type == 'render_table' || data.containsKey('table')) {
      final rawTable = data['table'] ?? data;
      if (rawTable is Map) {
        table = Map<String, dynamic>.from(rawTable);
      }
    }

    Map<String, dynamic>? prefill;
    if (json['prefill'] is Map) {
      prefill = Map<String, dynamic>.from(json['prefill'] as Map);
    } else if (data['prefill'] is Map) {
      prefill = Map<String, dynamic>.from(data['prefill'] as Map);
    }

    return UiActionModel(
      type: type,
      form: form,
      title: chart?['title']?.toString() ??
          table?['title']?.toString() ??
          data['title']?.toString() ??
          json['title']?.toString(),
      chartData: chart,
      tableData: table,
      prefill: prefill,
      raw: json,
    );
  }

  bool get isOpenOrderForm =>
      type == 'open_order_form' ||
      type == 'abrir_formulario_pedido' ||
      (form == 'pedido' && (prefill != null || type.contains('order')));

  bool get isOpenPurchaseOrderForm =>
      type == 'open_purchase_order_form' ||
      type == 'abrir_formulario_orden_compra' ||
      (form == 'orden_compra' && (prefill != null || type.contains('purchase')));

  String? get clienteNombre {
    if (prefill == null) return null;
    final c = prefill!['cliente'];
    if (c is Map) {
      return c['nombre']?.toString() ?? c['ClienteNombre']?.toString();
    }
    return prefill!['cliente_nombre']?.toString();
  }

  String? get proveedorNombre {
    if (prefill == null) return null;
    final p = prefill!['proveedor'];
    if (p is Map) {
      return p['ProveedorRazonSocial']?.toString() ??
          p['nombre']?.toString() ??
          p['razon_social']?.toString();
    }
    return prefill!['proveedor_nombre']?.toString();
  }

  List<Map<String, dynamic>> get productos {
    if (prefill == null) return [];
    final prods = prefill!['productos'] ?? prefill!['detalles'];
    if (prods is List) {
      return prods
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  int get itemsCount => productos.length;

  double? get totalMonto {
    if (prefill == null) return null;
    final totales = prefill!['totales'];
    if (totales is Map && totales['total'] != null) {
      final t = totales['total'];
      if (t is num) return t.toDouble();
      return double.tryParse(t.toString());
    }
    final t = prefill!['total'];
    if (t is num) return t.toDouble();
    if (t != null) return double.tryParse(t.toString());
    return null;
  }
}

