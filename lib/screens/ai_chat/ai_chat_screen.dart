import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/voice_recorder_service.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../../models/chat_message_model.dart';
import 'widgets/chat_chart_widget.dart';
import 'widgets/chat_table_widget.dart';
import 'widgets/feedback_bar_widget.dart';

class AiChatScreen extends StatefulWidget {
  final VoidCallback? onFeedbackRecorded;
  final bool isModal;

  const AiChatScreen({
    super.key,
    this.onFeedbackRecorded,
    this.isModal = false,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onFeedbackRecorded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(ctx).size.height * 0.90,
          child: AiChatScreen(onFeedbackRecorded: onFeedbackRecorded, isModal: true),
        ),
      ),
    );
  }

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final List<ChatMessageModel> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final VoiceRecorderService _recorderService = VoiceRecorderService();
  bool _isRecording = false;
  bool _isTranscribing = false;
  int _recordingSeconds = 0;
  Timer? _recordingTimer;

  bool _isStreaming = false;
  String? _currentStatus;
  final String _sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';

  final List<_ChatPromptOption> _promptOptions = const [
    _ChatPromptOption(
      title: '¿Cómo va el indicador PODE?',
      subtitle: 'Órdenes despachadas exitosamente (Meta ≥ 95%)',
      prompt: '¿Cómo va el indicador PODE?',
      icon: Icons.verified_rounded,
    ),
    _ChatPromptOption(
      title: '¿Cuáles son los productos con stock bajo?',
      subtitle: 'Alerta de roturas y productos en quiebre (PRS)',
      prompt: '¿Cuáles son los productos con stock bajo?',
      icon: Icons.inventory_2_rounded,
    ),
    _ChatPromptOption(
      title: 'Resumen de pedidos registrados hoy',
      subtitle: 'Flujo operativo, validación y despacho en vivo',
      prompt: 'Resumen de pedidos registrados hoy',
      icon: Icons.local_shipping_rounded,
    ),
    _ChatPromptOption(
      title: '¿Cuál es la tasa de error actual?',
      subtitle: 'Inconsistencias en procesamiento (PEOR, Meta ≤ 3%)',
      prompt: '¿Cuál es la tasa de error actual?',
      icon: Icons.error_outline_rounded,
    ),
    _ChatPromptOption(
      title: '¿Cómo está el tiempo de búsqueda (TBPP)?',
      subtitle: 'Picking y búsqueda asistida por IA (Meta ≤ 10s)',
      prompt: '¿Cómo está el tiempo de búsqueda (TBPP)?',
      icon: Icons.timer_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _resetToWelcome();
  }

  void _resetToWelcome() {
    _messages.clear();
    _messages.add(
      ChatMessageModel(
        id: 'msg_welcome',
        sender: 'assistant',
        text: '¡Hola! 👋 Soy Valencia AI, el asistente inteligente de Comercial Valencia.\n\nConectado a la base de datos en tiempo real. Puedo consultar stock, pedidos, clientes, proveedores, reportes y mucho más. ¿Qué deseas hacer?',
        timestamp: DateTime.now(),
        chips: const [
          ChatChipModel(label: '📦 Stock de productos bajo mínimo', query: '¿Qué productos tienen stock bajo o agotado?'),
          ChatChipModel(label: '🛒 Pedidos de hoy', query: '¿Cuántos pedidos hay hoy?'),
          ChatChipModel(label: '📈 Estadísticas generales', query: '¿Qué estadísticas y gráficos puedes mostrarme?'),
          ChatChipModel(label: '🔔 Alertas del sistema', query: '¿Hay alertas o notificaciones pendientes?'),
        ],
      ),
    );
  }

  void _resetChat() {
    setState(() {
      _resetToWelcome();
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _recorderService.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatRecordingTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startVoiceRecording() async {
    if (_isStreaming || _isTranscribing) return;

    final started = await _recorderService.startRecording();
    if (!started) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('No se pudo acceder al micrófono. Verifica los permisos.')),
              ],
            ),
            backgroundColor: Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _recordingSeconds = 0;
    });

    _recordingTimer?.cancel();
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _recordingSeconds++;
        });
      }
    });
  }

  Future<void> _cancelVoiceRecording() async {
    _recordingTimer?.cancel();
    await _recorderService.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordingSeconds = 0;
      });
    }
  }

  Future<void> _stopAndSendVoiceRecording() async {
    _recordingTimer?.cancel();
    final duration = _recordingSeconds;

    setState(() {
      _isRecording = false;
      _recordingSeconds = 0;
    });

    if (duration < 1) {
      await _recorderService.cancelRecording();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La grabación es muy corta. Habla durante al menos 1 segundo.'),
            backgroundColor: Color(0xFFD97706),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    final path = await _recorderService.stopRecording();
    if (path == null) return;

    setState(() {
      _isTranscribing = true;
    });

    try {
      final res = await ApiService().transcribeAudio(filePath: path);
      final transcribedText = res['text']?.toString().trim() ?? '';

      if (transcribedText.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se detectaron palabras en el audio grabado. Intenta hablar más claro.'),
              backgroundColor: Color(0xFFD97706),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Enviar automáticamente el texto transcrito
      _sendMessage(transcribedText, isVoiceNote: true, audioDurationSec: duration);
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().toLowerCase();
        String userMsg = 'Error al transcribir el audio.';
        if (errorMsg.contains('429') || errorMsg.contains('quota') || errorMsg.contains('503') || errorMsg.contains('saturad')) {
          userMsg = 'El servicio de voz con IA está saturado temporalmente. Intenta nuevamente en breve.';
        } else if (errorMsg.contains('demasiado corto')) {
          userMsg = 'El audio fue demasiado corto o con volumen muy bajo.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mic_off_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(userMsg)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTranscribing = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text, {bool isVoiceNote = false, int? audioDurationSec}) async {
    var clean = text.trim();
    if (clean.isEmpty || _isStreaming) return;

    // Mapeo inteligente si el usuario escribe solo un número (ej. "1", "2") o "opción 1"
    final numberMatch = RegExp(r'^(?:opci[oó]n\s*)?(\d+)$', caseSensitive: false).firstMatch(clean);
    if (numberMatch != null && _messages.isNotEmpty) {
      final chipIndex = int.tryParse(numberMatch.group(1)!);
      for (int i = _messages.length - 1; i >= 0; i--) {
        final m = _messages[i];
        if (m.isAssistant && m.chips != null && m.chips!.isNotEmpty) {
          if (chipIndex != null && chipIndex >= 1 && chipIndex <= m.chips!.length) {
            clean = m.chips![chipIndex - 1].query;
          }
          break;
        }
      }
    }

    _inputController.clear();

    final userMsg = ChatMessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      sender: 'user',
      text: clean,
      timestamp: DateTime.now(),
      isVoiceNote: isVoiceNote,
      audioDurationSec: audioDurationSec,
    );

    final botMsgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
    final botMsg = ChatMessageModel(
      id: botMsgId,
      sender: 'assistant',
      text: '',
      timestamp: DateTime.now(),
      isStreaming: true,
      sessionId: _sessionId,
    );

    setState(() {
      _messages.add(userMsg);
      _messages.add(botMsg);
      _isStreaming = true;
      _currentStatus = 'Conectando con Valencia AI...';
    });

    _scrollToBottom();

    // Historial para contexto
    final history = _messages
        .where((m) => m.id != botMsgId && m.text.isNotEmpty)
        .map((m) => {
              'role': m.isUser ? 'user' : 'model',
              'parts': [{'text': m.text}],
            })
        .toList();

    try {
      await ApiService().chatStream(
        prompt: clean,
        sessionId: _sessionId,
        history: history,
        onToken: (token) {
          if (mounted) {
            setState(() {
              botMsg.text += token;
              _currentStatus = null;
            });
            _scrollToBottom();
          }
        },
        onStatus: (status) {
          if (mounted) {
            setState(() {
              _currentStatus = status;
            });
            _scrollToBottom();
          }
        },
        onDone: (fullData) {
          if (mounted) {
            setState(() {
              botMsg.isStreaming = false;
              _isStreaming = false;
              _currentStatus = null;

              if (fullData.containsKey('reply') && botMsg.text.isEmpty) {
                botMsg.text = fullData['reply'].toString();
              } else if (fullData.containsKey('response') && botMsg.text.isEmpty) {
                botMsg.text = fullData['response'].toString();
              }

              // Extraer chips dinámicos del backend
              List<ChatChipModel>? chips;
              if (fullData['chips'] is List) {
                chips = (fullData['chips'] as List)
                    .whereType<Map<String, dynamic>>()
                    .map((c) => ChatChipModel.fromJson(c))
                    .toList();
              }

              final toolName = fullData['tool_used']?.toString() ?? fullData['tool']?.toString();
              final toolSuccess = fullData['tool_success'] == null
                  ? true
                  : (fullData['tool_success'] == true || fullData['tool_success'] == 1);
              final toolStatus = fullData['tool_status']?.toString();

              final lId = fullData['log_id'] != null
                  ? (fullData['log_id'] as num).toInt()
                  : (fullData['tool_log_id'] != null ? (fullData['tool_log_id'] as num).toInt() : null);

              final uiAction = fullData['ui_action'] != null
                  ? UiActionModel.fromJson(fullData['ui_action'] as Map<String, dynamic>)
                  : null;

              final updatedMsg = ChatMessageModel(
                id: botMsg.id,
                sender: botMsg.sender,
                text: botMsg.text,
                timestamp: botMsg.timestamp,
                sessionId: _sessionId,
                logId: lId,
                toolUsed: toolName,
                toolSuccess: toolSuccess,
                toolStatus: toolStatus,
                uiAction: uiAction,
                chips: chips,
              );
              _messages[_messages.length - 1] = updatedMsg;
            });
            _scrollToBottom();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              botMsg.text = 'Ocurrió un error al procesar la solicitud: $err';
              botMsg.isStreaming = false;
              _isStreaming = false;
              _currentStatus = null;
            });
            _scrollToBottom();
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          botMsg.text = 'No se pudo conectar con el motor de IA. Revisa tu conexión con el backend.';
          botMsg.isStreaming = false;
          _isStreaming = false;
          _currentStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF009CA5), // Tono superior teal de la Imagen 1
            Color(0xFF008F9D), // Tono medio exacto de la Imagen 1 (#008F9D)
            Color(0xFF007E8C),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: widget.isModal
            ? const BorderRadius.vertical(top: Radius.circular(28))
            : BorderRadius.zero,
      ),
      child: SafeArea(
        top: !widget.isModal,
        bottom: false,
        child: Column(
          children: [
            // Manija superior cuando se abre en BottomSheet Modal
            if (widget.isModal) ...[
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            // ===============================================================
            // 1. CABECERA BLANCA ESTILO TARJETA (REFERENCIA IMAGEN 1)
            // ===============================================================
            Container(
              margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Avatar circular con ValenciaBotIcon oficial
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF3DC7BD), Color(0xFF008F9D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF3DC7BD).withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const ValenciaBotIcon(
                      size: 26,
                      headColor: Colors.white,
                      visorColor: Color(0xFF0F172A),
                      eyeColor: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Título y estado en vivo
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Valencia AI',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'En línea • IA generativa',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Acciones de cabecera
                  IconButton(
                    tooltip: 'Opciones sugeridas',
                    icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF008F9D), size: 22),
                    onPressed: _showOptionsModal,
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    tooltip: 'Reiniciar conversación',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: _resetChat,
                    visualDensity: VisualDensity.compact,
                  ),
                  if (widget.isModal || Navigator.canPop(context)) ...[
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      onPressed: () => Navigator.of(context).maybePop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ],
              ),
            ),

            // ===============================================================
            // 2. LISTA DE MENSAJES (CANVAS GRADIENTE TEAL)
            // ===============================================================
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
                itemCount: _messages.length + 1,
                itemBuilder: (context, index) {
                  // Indicador superior de sesión activa
                  if (index == 0) {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 14),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline_rounded, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                            const SizedBox(width: 5),
                            Text(
                              'Hoy • Sesión Segura en Vivo',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final msg = _messages[index - 1];
                  return _buildMessageItem(msg);
                },
              ),
            ),

            // Estado transitorio en vivo (Streaming / Thinking)
            if (_currentStatus != null) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF008F9D)),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        _currentStatus!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF008F9D),
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ===============================================================
            // 3. BARRA DE ENTRADA INFERIOR (TEXTO Y AUDIO CON VALENCIA AI)
            // ===============================================================
            Container(
              padding: EdgeInsets.fromLTRB(14, 8, 14, widget.isModal ? 14 : 92),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: widget.isModal,
                child: _isTranscribing
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDFD),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFCCFBF1)),
                        ),
                        child: Row(
                          children: const [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF008F9D)),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Transcribiendo audio con IA...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF007A87),
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _isRecording
                        ? Row(
                            children: [
                              // Botón descartar grabación
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 24),
                                tooltip: 'Descartar grabación',
                                onPressed: _cancelVoiceRecording,
                              ),
                              // Estado de grabación en vivo con contador
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFFFECACA)),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Grabando audio...',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatRecordingTime(_recordingSeconds),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          color: Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Botón finalizar y transcribir
                              GestureDetector(
                                onTap: _stopAndSendVoiceRecording,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              // Botón de opciones sugeridas
                              IconButton(
                                icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF008F9D), size: 24),
                                tooltip: 'Ver opciones sugeridas',
                                onPressed: _showOptionsModal,
                              ),
                              // Campo de texto estilo píldora
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDFD),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(color: const Color(0xFFCCFBF1)),
                                  ),
                                  child: TextField(
                                    controller: _inputController,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (val) => _sendMessage(val),
                                    decoration: const InputDecoration(
                                      hintText: 'Pregúntale a Valencia AI...',
                                      hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Botón de enviar audio / micrófono
                              GestureDetector(
                                onTap: (_isStreaming || _isTranscribing) ? null : _startVoiceRecording,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F3F7),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFB2EBF2)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.04),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.mic_rounded,
                                    color: Color(0xFF008F9D),
                                    size: 22,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // Botón enviar texto circular turquesa vibrante (#3DC7BD)
                              GestureDetector(
                                onTap: _isStreaming ? null : () => _sendMessage(_inputController.text),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _isStreaming ? const Color(0xFF94A3B8) : const Color(0xFF3DC7BD),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF3DC7BD).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.near_me_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // ÍTEM DE MENSAJE (BOT O USUARIO)
  // =========================================================================
  Widget _buildMessageItem(ChatMessageModel msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Bot si es el asistente
              if (!msg.isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, top: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3DC7BD),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const ValenciaBotIcon(
                    size: 19,
                    headColor: Colors.white,
                    visorColor: Color(0xFF0F172A),
                    eyeColor: Color(0xFF38BDF8),
                  ),
                ),
              ],

              // Burbuja de mensaje
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    // Bot: #E0F3F7 (Pastel cyan/white) | Usuario: #3DC7BD (Vibrant turquoise)
                    color: msg.isUser ? const Color(0xFF3DC7BD) : const Color(0xFFE0F3F7),
                    borderRadius: BorderRadius.circular(20).copyWith(
                      bottomRight: msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
                      bottomLeft: !msg.isUser ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: msg.isUser ? 0.14 : 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.isUser && msg.isVoiceNote) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.mic_rounded, size: 13, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              'Nota de voz (${msg.audioDurationSec ?? 1}s)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      _buildFormattedText(
                        msg.text.isEmpty && msg.isStreaming ? 'Valencia AI está respondiendo...' : msg.text,
                        TextStyle(
                          fontSize: 13,
                          color: msg.isUser ? Colors.white : const Color(0xFF0F172A),
                          height: 1.45,
                          fontWeight: msg.isUser ? FontWeight.w500 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Avatar Usuario si es el usuario
              if (msg.isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(left: 8, top: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
                ),
              ],
            ],
          ),

          // Tarjeta de Tool ejecutada
          if (!msg.isUser && msg.toolUsed != null && msg.toolUsed!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: _buildToolCard(msg),
            ),

          // Barra interactiva de Feedback (Like / Dislike)
          if (msg.canFeedback)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 6),
              child: FeedbackBarWidget(
                logId: msg.logId!,
                currentFeedback: msg.feedback,
                onFeedbackChanged: (fb) {
                  setState(() => msg.feedback = fb);
                  widget.onFeedbackRecorded?.call();
                },
              ),
            ),

          // Botones / Chips de opciones interactivas
          if (!msg.isUser && msg.chips != null && msg.chips!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: _buildChips(msg),
            ),

          // === BI: Gráfico dinámico inline ===
          if (!msg.isUser && msg.uiAction != null && msg.uiAction!.chartData != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: ChatChartWidget(chartData: msg.uiAction!.chartData!),
            ),

          // === BI: Tabla dinámica inline ===
          if (!msg.isUser && msg.uiAction != null && msg.uiAction!.tableData != null)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: ChatTableWidget(tableData: msg.uiAction!.tableData!),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // BOTONES / CHIPS DE OPCIONES INTERACTIVAS (ESTILO PÍLDORA BLANCA)
  // =========================================================================
  Widget _buildChips(ChatMessageModel msg) {
    if (msg.chips == null || msg.chips!.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: msg.chips!.map((chip) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: _isStreaming ? null : () => _sendMessage(chip.query),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFB2EBF2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      chip.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF007A87),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    size: 13,
                    color: Color(0xFF3DC7BD),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // =========================================================================
  // TARJETA DE TOOL EJECUTADA (CATEGORÍA + NOMBRE + STATUS)
  // =========================================================================
  Widget _buildToolCard(ChatMessageModel msg) {
    if (msg.toolUsed == null || msg.toolUsed!.isEmpty) return const SizedBox.shrink();

    final tool = msg.toolUsed!.toLowerCase();
    String category = 'Sistema';
    String iconEmoji = '🛠️';

    if (tool.contains('grafico') || tool.contains('kpi') || tool.contains('tabla') || tool.contains('comparar') || tool.contains('bi')) {
      category = 'BI & Gráficos';
      iconEmoji = '📊';
    } else if (tool.contains('pedido')) {
      category = 'Pedidos';
      iconEmoji = '🛒';
    } else if (tool.contains('cliente')) {
      category = 'Clientes';
      iconEmoji = '👥';
    } else if (tool.contains('producto') || tool.contains('stock')) {
      category = 'Productos';
      iconEmoji = '📦';
    } else if (tool.contains('proveedor')) {
      category = 'Proveedores';
      iconEmoji = '🏢';
    } else if (tool.contains('orden') || tool.contains('compra')) {
      category = 'Órdenes Compra';
      iconEmoji = '📋';
    } else if (tool.contains('alerta') || tool.contains('notif')) {
      category = 'Alertas';
      iconEmoji = '🔔';
    }

    final isSuccess = msg.toolSuccess != false;

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(iconEmoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Text(
            category,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Color(0xFF334155),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('•', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
          ),
          Flexible(
            child: Text(
              msg.toolUsed!,
              style: const TextStyle(
                fontSize: 9.5,
                fontFamily: 'monospace',
                color: Color(0xFF475569),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 12,
            color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
          const SizedBox(width: 3),
          Text(
            isSuccess ? 'Ejecutado' : 'Error',
            style: TextStyle(
              fontSize: 9.5,
              color: isSuccess ? const Color(0xFF059669) : const Color(0xFFDC2626),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // PARSEO Y FORMATEO DE MARKDOWN (**bold**, *italic*)
  // =========================================================================
  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    if (!text.contains('**') && !text.contains('*')) {
      return SelectableText(text, style: baseStyle);
    }

    final spans = <TextSpan>[];
    final regex = RegExp(r'(\*\*([^*]+)\*\*|\*([^*]+)\*)');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastIndex) {
        spans.add(TextSpan(text: text.substring(lastIndex, match.start), style: baseStyle));
      }
      if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: baseStyle.copyWith(fontWeight: FontWeight.bold),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: baseStyle.copyWith(fontStyle: FontStyle.italic),
        ));
      }
      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  // =========================================================================
  // DIÁLOGO / MODAL BOTTOM SHEET DE OPCIONES
  // =========================================================================
  void _showOptionsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.list_alt_rounded, size: 22, color: Color(0xFF008F9D)),
                  SizedBox(width: 8),
                  Text(
                    'Consultas Rápidas Sugeridas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Elige una opción para consultar al asistente Valencia AI:',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSubtle),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _promptOptions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final opt = _promptOptions[i];
                    return _buildPromptOptionTile(
                      opt,
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _sendMessage(opt.prompt);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // ITEM CARD DE OPCIÓN SELECCIONABLE
  // =========================================================================
  Widget _buildPromptOptionTile(_ChatPromptOption opt, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: _isStreaming ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F3F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(opt.icon, size: 19, color: const Color(0xFF008F9D)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opt.title,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt.subtitle,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSubtle,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F3F7),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Color(0xFF008F9D),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPromptOption {
  final String title;
  final String subtitle;
  final String prompt;
  final IconData icon;

  const _ChatPromptOption({
    required this.title,
    required this.subtitle,
    required this.prompt,
    required this.icon,
  });
}

