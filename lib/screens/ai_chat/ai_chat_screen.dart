import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/modules_service.dart';
import '../../core/services/voice_recorder_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/notification_bell_widget.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../../models/chat_message_model.dart';
import 'widgets/ai_message_content_widget.dart';
import 'widgets/chat_chart_widget.dart';
import 'widgets/chat_table_widget.dart';
import 'widgets/feedback_bar_widget.dart';
import 'widgets/voice_recording_bar.dart';
import '../erp/nuevo_pedido_screen.dart';
import '../erp/nueva_compra_screen.dart';

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
          child: Theme(
            data: AppTheme.fixedLightTheme,
            child: AiChatScreen(onFeedbackRecorded: onFeedbackRecorded, isModal: true),
          ),
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

  final ImagePicker _imagePicker = ImagePicker();
  bool _isAnalyzingVision = false;

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
        if (_recordingSeconds >= 120) {
          _stopAndSendVoiceRecording();
        }
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

  // =========================================================================
  // VALENCIA VISION (Gemini 1.5 Flash 1-Tile en Chat)
  // =========================================================================

  void _mostrarOpcionesCamaraChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF008F9D).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFF008F9D), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enviar Imagen a Valencia AI',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Interpreta listas manuscritas, órdenes o productos',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F3F7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF008F9D)),
                  ),
                  title: const Text('Tomar foto con la cámara', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Fotografía una lista manuscrita en tiempo real', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarImagenVision(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEDE9FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF6366F1)),
                  ),
                  title: const Text('Subir desde galería o archivos', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Elige una foto existente o captura de pantalla', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  onTap: () {
                    Navigator.pop(ctx);
                    _procesarImagenVision(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _procesarImagenVision(ImageSource source) async {
    ChatMessageModel? botMsg;
    try {
      final xfile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 768,
        maxHeight: 768,
        imageQuality: 80,
      );
      if (xfile == null) return;

      setState(() => _isAnalyzingVision = true);

      final bytes = await xfile.readAsBytes();
      final base64Img = base64Encode(bytes);

      // 1. Mensaje del usuario con la miniatura
      final userMsg = ChatMessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        sender: 'user',
        text: '📷 Lista de pedido escaneada',
        timestamp: DateTime.now(),
        imageBase64: base64Img,
      );

      // 2. Mensaje inicial del bot
      final botMsgId = 'bot_${DateTime.now().millisecondsSinceEpoch}';
      botMsg = ChatMessageModel(
        id: botMsgId,
        sender: 'assistant',
        text: 'Interpretando imagen con Valencia Vision...',
        timestamp: DateTime.now(),
        isStreaming: true,
      );

      setState(() {
        _messages.add(userMsg);
        _messages.add(botMsg!);
      });
      _scrollToBottom();

      // 3. Llamada al servicio Vision de Laravel
      final data = await ModulesService().procesarPedidoVision(
        base64Image: base64Img,
        mimeType: 'image/jpeg',
      );

      final token = data['token_auditoria']?.toString();
      final items = (data['items'] as List?) ?? [];

      if (!mounted) return;

      if (items.isEmpty) {
        setState(() {
          botMsg?.text = 'No logré identificar productos claros en la imagen. Intenta con una foto más nítida o escribe tu consulta en el chat.';
          botMsg?.isStreaming = false;
          _isAnalyzingVision = false;
        });
        _scrollToBottom();
        return;
      }

      final totalProds = items.length;
      String replyText = '📸 **He analizado la lista con Valencia Vision (Gemini 1.5 Flash):**\n\nIdentifiqué **$totalProds producto(s)** en el catálogo:\n';
      for (final it in items) {
        final nombre = it['producto_nombre'] ?? it['nombre_buscado'] ?? 'Producto';
        final cant = it['cantidad_detectada'] ?? 1;
        final pres = it['presentacion_nombre'] ?? 'Unidad';
        final precioNum = it['precio_unitario'];
        final precio = precioNum != null ? ' · S/ ${double.tryParse('$precioNum')?.toStringAsFixed(2) ?? '$precioNum'}' : '';
        final badge = it['match_badge'] == 'verde' ? '✅' : '⚡';
        replyText += '\n$badge **${cant}x $nombre** ($pres$precio)';
      }
      replyText += '\n\n¿Deseas que prepare el borrador de la orden de pedido con estos productos?';

      final prefill = {
        'productos': items.where((i) => i['producto_id'] != null).map((i) => {
          'producto_id': i['producto_id'],
          'producto_nombre': i['producto_nombre'],
          'cantidad': i['cantidad_detectada'] ?? 1,
          'unidad_id': i['presentacion_id'],
          'precio_unitario': i['precio_unitario'] ?? 0,
          'factor_conversion': i['presentacion_factor'] ?? 1,
          'stock_fisico': i['stock_actual'] ?? 0,
          'stock_total': i['stock_actual'] ?? 0,
        }).toList(),
        'token_auditoria': token,
      };

      final uiAction = UiActionModel(
        type: 'open_order_form',
        prefill: prefill,
      );

      final chips = [
        ChatChipModel(
          label: '🛒 Preparar orden de pedido',
          query: 'Preparar orden de pedido',
          action: 'open_order_form',
          params: prefill,
        ),
        ChatChipModel(
          label: '📦 Consultar stock',
          query: '¿Hay stock disponible de estos productos?',
        ),
        ChatChipModel(
          label: '❌ Descartar',
          query: 'Descartar esta lista',
        ),
      ];

      setState(() {
        botMsg?.text = replyText;
        botMsg?.isStreaming = false;
        botMsg?.uiAction = uiAction;
        botMsg?.chips = chips;
        _isAnalyzingVision = false;
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      final errorMsg = e.toString().replaceAll('Exception: ', '').replaceAll('ApiException: ', '');
      setState(() {
        if (botMsg != null) {
          botMsg.text = '⚠️ No se pudo procesar la imagen: $errorMsg';
          botMsg.isStreaming = false;
        }
        _isAnalyzingVision = false;
      });
      _scrollToBottom();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al interpretar imagen: $errorMsg'),
          backgroundColor: AppColors.error,
        ),
      );
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
              final rawChips = fullData['chips'] ??
                  (fullData['tool_data'] is Map ? fullData['tool_data']['chips'] : null) ??
                  (fullData['data'] is Map ? fullData['data']['chips'] : null);
              if (rawChips is List) {
                chips = rawChips
                    .whereType<Map<String, dynamic>>()
                    .map((c) => ChatChipModel.fromJson(c))
                    .toList();
              }

              final toolName = fullData['tool_used']?.toString() ?? fullData['tool']?.toString();
              final toolSuccess = fullData['tool_success'] == null
                  ? true
                  : (fullData['tool_success'] == true || fullData['tool_success'] == 1);
              final toolStatus = fullData['tool_status']?.toString() ??
                  (fullData['tool_data'] is Map ? fullData['tool_data']['status']?.toString() : null) ??
                  (fullData['data'] is Map ? fullData['data']['status']?.toString() : null);

              final lId = fullData['log_id'] != null
                  ? (fullData['log_id'] as num).toInt()
                  : (fullData['tool_log_id'] != null ? (fullData['tool_log_id'] as num).toInt() : null);

              final rawUiAction = fullData['ui_action'] ??
                  (fullData['tool_data'] is Map ? fullData['tool_data']['ui_action'] : null) ??
                  (fullData['data'] is Map ? fullData['data']['ui_action'] : null);

              UiActionModel? uiAction;
              if (rawUiAction != null && rawUiAction is Map) {
                uiAction = UiActionModel.fromJson(Map<String, dynamic>.from(rawUiAction));
              } else if (toolName == 'abrir_formulario_pedido' && fullData['tool_data'] is Map) {
                final td = Map<String, dynamic>.from(fullData['tool_data'] as Map);
                uiAction = UiActionModel(
                  type: 'open_order_form',
                  form: 'pedido',
                  prefill: td['prefill'] is Map ? Map<String, dynamic>.from(td['prefill'] as Map) : td,
                );
              } else if (toolName == 'abrir_formulario_orden_compra' && fullData['tool_data'] is Map) {
                final td = Map<String, dynamic>.from(fullData['tool_data'] as Map);
                uiAction = UiActionModel(
                  type: 'open_purchase_order_form',
                  form: 'orden_compra',
                  prefill: td['prefill'] is Map ? Map<String, dynamic>.from(td['prefill'] as Map) : td,
                );
              }

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

              // Aviso rápido si se preparó una orden o compra
              if (uiAction != null && uiAction.isOpenOrderForm) {
                final cli = uiAction.clienteNombre ?? 'Cliente';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('🛒 Pedido precargado para $cli listo para abrir'),
                        backgroundColor: const Color(0xFF007785),
                        action: SnackBarAction(
                          label: 'ABRIR',
                          textColor: Colors.amberAccent,
                          onPressed: () => _abrirFormularioPedido(uiAction!.prefill),
                        ),
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                });
              } else if (uiAction != null && uiAction.isOpenPurchaseOrderForm) {
                final prov = uiAction.proveedorNombre ?? 'Proveedor';
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('📦 Orden de compra para $prov lista para abrir'),
                        backgroundColor: const Color(0xFF0284C7),
                        action: SnackBarAction(
                          label: 'ABRIR',
                          textColor: Colors.amberAccent,
                          onPressed: () => _abrirFormularioCompra(uiAction!.prefill),
                        ),
                        duration: const Duration(seconds: 6),
                      ),
                    );
                  }
                });
              }
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
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                            Expanded(
                              child: FittedBox(
                                alignment: Alignment.centerLeft,
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
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
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Acceso directo a la bandeja real de notificaciones.
                  NotificationBellWidget(
                    iconColor: const Color(0xFF008F9D),
                    backgroundColor: const Color(0xFFF2FDFD),
                    borderColor: const Color(0xFFD6F3F7),
                    size: 20,
                    buttonSize: 34,
                  ),
                  const SizedBox(width: 2),
                  // Acciones de cabecera
                  IconButton(
                    tooltip: 'Opciones sugeridas',
                    icon: const Icon(Icons.list_alt_rounded, color: Color(0xFF008F9D), size: 22),
                    onPressed: _showOptionsModal,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    tooltip: 'Reiniciar conversación',
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B), size: 22),
                    onPressed: _resetChat,
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                    padding: EdgeInsets.zero,
                  ),
                  if (widget.isModal || Navigator.canPop(context)) ...[
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B), size: 22),
                      onPressed: () => Navigator.of(context).maybePop(),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints.tightFor(width: 34, height: 34),
                      padding: EdgeInsets.zero,
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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: _isTranscribing
                      ? Container(
                          key: const ValueKey('transcribing_bar'),
                          height: 52,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF), // blue-50
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(color: const Color(0xFFBFDBFE)), // blue-200
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF2563EB)),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Transcribiendo nota de voz con IA...',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1D4ED8), // blue-700
                                ),
                              ),
                            ],
                          ),
                        )
                      : _isRecording
                          ? VoiceRecordingBar(
                              key: const ValueKey('recording_bar'),
                              recordingSeconds: _recordingSeconds,
                              onCancel: _cancelVoiceRecording,
                              onSend: _stopAndSendVoiceRecording,
                              amplitudeStream: _recorderService.onAmplitudeChanged,
                            )
                          : Row(
                              key: const ValueKey('input_bar'),
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
                              // Botón de cámara / galería para Valencia Vision
                              GestureDetector(
                                onTap: (_isStreaming || _isTranscribing || _isAnalyzingVision)
                                    ? null
                                    : _mostrarOpcionesCamaraChat,
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
                                  child: _isAnalyzingVision
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFF008F9D),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          color: Color(0xFF008F9D),
                                          size: 20,
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
    final interactiveChips = _resolveInteractiveChips(msg);

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
                      if (msg.isUser && msg.imageBase64 != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            base64Decode(msg.imageBase64!),
                            width: 190,
                            height: 130,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (msg.isUser)
                        _buildFormattedText(
                          msg.text,
                          const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        AiMessageContentWidget(
                          message: msg,
                          isStreaming: msg.isStreaming,
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

          // Botones / Chips de opciones interactivas (backend chips o sugerencias extraídas)
          if (!msg.isUser && interactiveChips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 8),
              child: _buildChips(interactiveChips),
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

          // === Formulario de Pedido Precargado ===
          if (!msg.isUser && msg.uiAction != null && msg.uiAction!.isOpenOrderForm)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 10),
              child: _buildOrderFormActionCard(msg.uiAction!),
            ),

          // === Formulario de Orden de Compra Precargada ===
          if (!msg.isUser && msg.uiAction != null && msg.uiAction!.isOpenPurchaseOrderForm)
            Padding(
              padding: const EdgeInsets.only(left: 36, top: 10),
              child: _buildPurchaseOrderFormActionCard(msg.uiAction!),
            ),
        ],
      ),
    );
  }

  // =========================================================================
  // BOTONES / CHIPS DE OPCIONES INTERACTIVAS
  // =========================================================================
  List<ChatChipModel> _resolveInteractiveChips(ChatMessageModel msg) {
    if (msg.chips != null && msg.chips!.isNotEmpty) {
      return msg.chips!;
    }
    if (msg.isUser || msg.isStreaming || msg.text.trim().isEmpty) {
      return const [];
    }

    final lines = msg.text.split('\n');
    final List<ChatChipModel> extracted = [];

    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      // Detecta viñetas de listas como -, *, •, o enumeraciones como 1., 2)
      final match = RegExp(r'^(?:[-*•]|\d+[\.\)])\s*(.+)$').firstMatch(trimmed);
      if (match != null) {
        var candidate = match.group(1)!.trim();
        // Quitar negritas y cursivas
        candidate = candidate
            .replaceAll('**', '')
            .replaceAll('*', '')
            .replaceAll('__', '')
            .replaceAll('_', '')
            .trim();

        // Descartar líneas explicativas de instrucción o advertencias
        if (RegExp(r'^(o\s+indica|por\s+favor|nota|recuerda|si\s+deseas|ejemplo|puedes|haz\s+clic)\b',
                caseSensitive: false)
            .hasMatch(candidate)) {
          continue;
        }

        // Quitar signos de puntuación final
        candidate = candidate.replaceAll(RegExp(r'[\.,;:]$'), '').trim();

        if (candidate.length >= 2 && candidate.length <= 75) {
          extracted.add(ChatChipModel(
            label: candidate,
            query: candidate,
          ));
        }
      }
    }

    if (extracted.isNotEmpty && extracted.length <= 8) {
      return extracted;
    }

    return const [];
  }

  Widget _buildChips(List<ChatChipModel> chips) {
    if (chips.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.touch_app_rounded, size: 13, color: Color(0xFF008F9D)),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Opciones disponibles para continuar:',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF007A87),
                  ),
                ),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips.map((chip) {
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isStreaming ? null : () => _onChipTap(chip),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF008F9D).withValues(alpha: 0.35),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF008F9D).withValues(alpha: 0.08),
                        blurRadius: 6,
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
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF005E68),
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF008F9D).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 13,
                          color: Color(0xFF008F9D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  void _onChipTap(ChatChipModel chip) {
    if (_isStreaming) return;
    if (chip.action == 'open_purchase_order_form') {
      _abrirFormularioCompra(chip.params);
      return;
    }
    if (chip.action == 'open_order_form') {
      _abrirFormularioPedido(chip.params);
      return;
    }
    _sendMessage(chip.query);
  }

  // =========================================================================
  // TARJETA INTERACTIVA: NUEVO PEDIDO PRECARGADO
  // =========================================================================
  Widget _buildOrderFormActionCard(UiActionModel action) {
    final cliente = action.clienteNombre ?? 'Cliente General';
    final prods = action.productos;
    final total = action.totalMonto;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF99F6E4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF007785).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0FDFA),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF008F9D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pedido de Venta Precargado',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Formulario listo para revisión y guardado',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cliente asignado
                Row(
                  children: [
                    const Icon(Icons.person_pin_rounded, size: 18, color: Color(0xFF007785)),
                    const SizedBox(width: 6),
                    const Text(
                      'Cliente: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        cliente,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lista resumida de productos
                if (prods.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < prods.length && i < 3; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF008F9D),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${prods[i]['cantidad'] ?? 1}x ${prods[i]['producto_nombre'] ?? prods[i]['productoNombre'] ?? prods[i]['nombre'] ?? 'Producto'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (prods[i]['subtotal'] != null || prods[i]['precio_unitario'] != null)
                                Text(
                                  'S/ ${(prods[i]['subtotal'] ?? prods[i]['precio_unitario']).toString()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF007785),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (prods.length > 3) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+ ${prods.length - 3} producto(s) más cargados en la orden',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Resumen de total si existe
                if (total != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimado:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'S/ ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF005B66),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Botón principal de apertura
                ElevatedButton(
                  onPressed: () => _abrirFormularioPedido(action.prefill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF008F9D),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.open_in_new_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Abrir Formulario de Pedido',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TARJETA INTERACTIVA: NUEVA ORDEN DE COMPRA PRECARGADA
  // =========================================================================
  Widget _buildPurchaseOrderFormActionCard(UiActionModel action) {
    final proveedor = action.proveedorNombre ?? 'Proveedor';
    final prods = action.productos;
    final total = action.totalMonto;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera elegante
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF0F9FF),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_shipping_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Orden de Compra Precargada',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Proveedor y productos listos para procesar',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                      SizedBox(width: 4),
                      Text(
                        'Listo',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Proveedor asignado
                Row(
                  children: [
                    const Icon(Icons.store_mall_directory_rounded, size: 18, color: Color(0xFF0284C7)),
                    const SizedBox(width: 6),
                    const Text(
                      'Proveedor: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        proveedor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Lista resumida de productos
                if (prods.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < prods.length && i < 3; i++) ...[
                          if (i > 0) const SizedBox(height: 5),
                          Row(
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0284C7),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${prods[i]['cantidad'] ?? 1}x ${prods[i]['productoNombre'] ?? prods[i]['producto_nombre'] ?? prods[i]['nombre'] ?? 'Producto'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              if (prods[i]['subtotal'] != null || prods[i]['precioUnitario'] != null || prods[i]['precio_unitario'] != null)
                                Text(
                                  'S/ ${(prods[i]['subtotal'] ?? prods[i]['precioUnitario'] ?? prods[i]['precio_unitario']).toString()}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        if (prods.length > 3) ...[
                          const SizedBox(height: 4),
                          Text(
                            '+ ${prods.length - 3} producto(s) más cargados en la orden',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Resumen de total si existe
                if (total != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimado:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      Text(
                        'S/ ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0369A1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Botón principal de apertura
                ElevatedButton(
                  onPressed: () => _abrirFormularioCompra(action.prefill),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.open_in_new_rounded, size: 16),
                      SizedBox(width: 8),
                      Text(
                        'Abrir Formulario de Compra',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirFormularioPedido(Map<String, dynamic>? prefill) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevoPedidoScreen(prefillData: prefill),
      ),
    );

    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Pedido guardado exitosamente en el sistema.'),
          backgroundColor: Color(0xFF007785),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _abrirFormularioCompra(Map<String, dynamic>? prefill) async {
    final res = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaCompraScreen(prefillData: prefill),
      ),
    );

    if (res == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Orden de compra creada exitosamente en el sistema.'),
          backgroundColor: Color(0xFF0284C7),
          duration: Duration(seconds: 4),
        ),
      );
    }
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

    final status = (msg.toolStatus ?? '').toLowerCase().trim();

    // Determinación del estado visual e informativo de la herramienta
    String statusLabel;
    IconData statusIcon;
    Color statusColor;
    Color statusBg;
    Color statusBorder;

    if (status == 'ambiguous_presentation') {
      statusLabel = 'Seleccionar presentación';
      statusIcon = Icons.tune_rounded;
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFF0F9FF);
      statusBorder = const Color(0xFFBAE6FD);
    } else if (status == 'ambiguous_product') {
      statusLabel = 'Seleccionar producto';
      statusIcon = Icons.search_rounded;
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
    } else if (status == 'not_found') {
      statusLabel = 'Por confirmar nombre';
      statusIcon = Icons.manage_search_rounded;
      statusColor = const Color(0xFFD97706);
      statusBg = const Color(0xFFFFFBEB);
      statusBorder = const Color(0xFFFDE68A);
    } else if (status == 'client_not_found') {
      statusLabel = 'Cliente no registrado';
      statusIcon = Icons.person_search_rounded;
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFF0F9FF);
      statusBorder = const Color(0xFFBAE6FD);
    } else if (status == 'missing_fields') {
      statusLabel = 'Datos por completar';
      statusIcon = Icons.info_outline_rounded;
      statusColor = const Color(0xFF0284C7);
      statusBg = const Color(0xFFF0F9FF);
      statusBorder = const Color(0xFFBAE6FD);
    } else if (status == 'ready' ||
        status == 'open_form' ||
        (msg.uiAction?.isOpenOrderForm == true) ||
        (msg.uiAction?.isOpenPurchaseOrderForm == true)) {
      statusLabel = 'Formulario listo';
      statusIcon = Icons.fact_check_rounded;
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
    } else if (msg.toolSuccess == false && (status == 'error' || status.contains('fail'))) {
      statusLabel = 'No disponible';
      statusIcon = Icons.warning_amber_rounded;
      statusColor = const Color(0xFFDC2626);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
    } else if (msg.toolSuccess == false) {
      statusLabel = 'Consulta informativa';
      statusIcon = Icons.help_outline_rounded;
      statusColor = const Color(0xFF64748B);
      statusBg = const Color(0xFFF8FAFC);
      statusBorder = const Color(0xFFE2E8F0);
    } else {
      statusLabel = 'Ejecutado';
      statusIcon = Icons.check_circle_rounded;
      statusColor = const Color(0xFF059669);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: statusBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
            statusIcon,
            size: 13,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 9.5,
              color: statusColor,
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
                children: [
                  const Icon(Icons.list_alt_rounded, size: 22, color: Color(0xFF008F9D)),
                  const SizedBox(width: 8),
                  Text(
                    'Consultas Rápidas Sugeridas',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textDark),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
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
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      opt.subtitle,
                      style: TextStyle(
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

