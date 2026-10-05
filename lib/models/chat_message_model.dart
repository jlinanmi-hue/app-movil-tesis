class ChatChipModel {
  final String label;
  final String query;

  const ChatChipModel({
    required this.label,
    required this.query,
  });

  factory ChatChipModel.fromJson(Map<String, dynamic> json) {
    return ChatChipModel(
      label: json['label']?.toString() ?? json['titulo']?.toString() ?? '',
      query: json['query']?.toString() ?? json['label']?.toString() ?? json['titulo']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'query': query,
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
  final UiActionModel? uiAction;
  final List<ChatChipModel>? chips;
  String? feedback; // null, 'like', 'dislike'
  String? feedbackReason;
  bool isStreaming;
  final bool isVoiceNote;
  final int? audioDurationSec;

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
  });

  bool get isUser => sender == 'user';
  bool get isAssistant => sender == 'assistant';
  bool get hasUiAction => uiAction != null;
  bool get hasChips => chips != null && chips!.isNotEmpty;
  bool get canFeedback => logId != null && isAssistant && !isStreaming;
}

class UiActionModel {
  final String type; // 'render_chart', 'render_table'
  final String? title;
  final Map<String, dynamic>? chartData;
  final Map<String, dynamic>? tableData;

  UiActionModel({
    required this.type,
    this.title,
    this.chartData,
    this.tableData,
  });

  factory UiActionModel.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? json['action'] ?? '').toString();
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

    return UiActionModel(
      type: type,
      title: chart?['title']?.toString() ??
          table?['title']?.toString() ??
          data['title']?.toString() ??
          json['title']?.toString(),
      chartData: chart,
      tableData: table,
    );
  }
}

