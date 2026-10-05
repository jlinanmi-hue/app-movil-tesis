import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../exceptions/api_exception.dart';
import 'session_service.dart';
import '../../models/user_model.dart';
import '../../models/indicator_model.dart';
import '../../models/token_metrics_model.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  late Dio _dio;

  ApiService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    // Interceptor Global para Tokens, Manejo de 401 y Logs
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Actualizar dinámicamente la URL base configurada
          final currentBase = await ApiConfig.getBaseUrl();
          options.baseUrl = currentBase;

          // Inyectar Bearer token si existe
          final token = SessionService.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          debugPrint('[ApiService Error] ${e.requestOptions.path}: ${e.message} (Status: ${e.response?.statusCode})');

          // Manejo de 401: Token expirado o inválido -> Logout y redirigir
          if (e.response?.statusCode == 401) {
            await SessionService.logout();
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: UnauthorizedException(
                  message: e.response?.data?['message']?.toString() ?? 'Sesión expirada. Por favor ingresa nuevamente.',
                  data: e.response?.data,
                ),
              ),
            );
          }

          // Manejo de 403: Activación diferida de cuenta de empleado
          if (e.response?.statusCode == 403) {
            final data = e.response?.data?['data'];
            final msg = e.response?.data?['message']?.toString() ?? 'Acceso no autorizado o cuenta inactiva.';
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: DeferredActivationException(
                  message: msg,
                  fechaIngreso: data?['fecha_ingreso']?.toString(),
                  diasRestantes: (data?['dias_restantes'] as num?)?.toInt(),
                  data: e.response?.data,
                ),
              ),
            );
          }

          // Manejo de errores de conexión y servidor caído
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError) {
            return handler.reject(
              DioException(
                requestOptions: e.requestOptions,
                error: NetworkException(),
              ),
            );
          }

          return handler.next(e);
        },
      ),
    );
  }

  // ==========================================
  // 1. AUTENTICACIÓN
  // ==========================================

  /// Inicia sesión con usuario y contraseña
  Future<UserModel> login(String username, String password) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
        },
      );

      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        final user = UserModel.fromJson(data['data'] as Map<String, dynamic>);
        await SessionService.saveSession(user);
        return user;
      } else {
        throw ApiException(
          message: data?['message']?.toString() ?? 'Credenciales no válidas.',
          statusCode: response.statusCode,
          data: data,
        );
      }
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error al autenticar con el servidor.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Cierra la sesión activa en el backend y localmente
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {}
    await SessionService.logout();
  }

  // ==========================================
  // 2. DASHBOARD E INDICADORES OFICIALES
  // ==========================================

  /// Obtiene los 4 indicadores principales de Tesis (PODE, PEOR, PRS, TBPP)
  Future<DashboardIndicatorsResponse> getIndicators({
    String? mes,
    String? semana,
    String? periodo,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (mes != null) queryParams['mes'] = mes;
      if (semana != null) queryParams['semana'] = semana;
      if (periodo != null) queryParams['periodo'] = periodo;

      final response = await _dio.get('/dashboard/indicators', queryParameters: queryParams);
      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        return DashboardIndicatorsResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: data?['message']?.toString() ?? 'Error al obtener indicadores.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error de conexión al cargar indicadores.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Obtiene el detalle analítico y subgráficos (A, B, C, D, E) de un indicador específico
  Future<Map<String, dynamic>> getIndicatorDetail(
    int indicatorId, {
    Map<String, dynamic>? filters,
  }) async {
    try {
      final response = await _dio.get(
        '/dashboard/indicator/$indicatorId',
        queryParameters: filters,
      );
      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
      throw ApiException(message: data?['message']?.toString() ?? 'Error al obtener detalle del indicador.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error al consultar subgráficos del indicador.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Obtiene el flujo general de órdenes y etapas operativas (Compatibilidad de Tesis)
  Future<OrderFlowResponse> getOrderFlow({int dias = 7, int? canalId}) async {
    try {
      final queryParams = <String, dynamic>{
        'dias': dias,
        'canal_id': ?canalId,
      };
      final response = await _dio.get('/dashboard/indicadores', queryParameters: queryParams);
      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        return OrderFlowResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: 'Error al obtener flujo de órdenes.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error al cargar flujo de órdenes.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Obtiene métricas y auditoría de tokens consumidos por Gemini
  Future<TokenMetricsResponse> getTokenMetrics({
    int? dias,
    String? fechaDesde,
    String? fechaHasta,
  }) async {
    try {
      final queryParams = <String, dynamic>{};
      if (dias != null) queryParams['dias'] = dias;
      if (fechaDesde != null) queryParams['fecha_desde'] = fechaDesde;
      if (fechaHasta != null) queryParams['fecha_hasta'] = fechaHasta;

      final response = await _dio.get('/dashboard/tokens', queryParameters: queryParams);
      final data = response.data;
      if (data != null && data['success'] == true && data['data'] != null) {
        return TokenMetricsResponse.fromJson(data['data'] as Map<String, dynamic>);
      }
      throw ApiException(message: 'Error al obtener métricas de tokens.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error al cargar consumo de tokens.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  // ==========================================
  // 3. INTELIGENCIA ARTIFICIAL (VALENCIA AI)
  // ==========================================

  /// Envía un mensaje en modo normal (fallback sin streaming)
  Future<Map<String, dynamic>> chatAi(
    String message, {
    String? sessionId,
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      final response = await _dio.post(
        '/ai/chat',
        data: {
          'message': message,
          'prompt': message,
          'session_id': ?sessionId,
          'history': ?history,
        },
      );
      final data = response.data;
      if (data != null && data['success'] == true) {
        return (data['data'] as Map<String, dynamic>?) ?? data;
      }
      throw ApiException(message: data?['message']?.toString() ?? 'Error en respuesta de IA.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      throw ApiException(
        message: e.response?.data?['message']?.toString() ?? 'Error al comunicarse con Valencia AI.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Envía mensaje con streaming progresivo SSE (Server-Sent Events) y fallback automático
  Future<void> chatStream({
    required String prompt,
    String? sessionId,
    List<Map<String, dynamic>>? history,
    Function(String token)? onToken,
    Function(String status)? onStatus,
    Function(Map<String, dynamic> fullData)? onDone,
    Function(dynamic error)? onError,
  }) async {
    try {
      final currentBase = await ApiConfig.getBaseUrl();
      final response = await _dio.post<ResponseBody>(
        '$currentBase/ai/chat-stream',
        data: {
          'prompt': prompt,
          'message': prompt,
          'session_id': ?sessionId,
          'history': ?history,
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw ApiException(message: 'No se pudo abrir el canal stream con la IA.');
      }

      String buffer = '';
      final Map<String, dynamic> accumulatedData = {};

      await for (final chunk in stream) {
        final chunkText = utf8.decode(chunk, allowMalformed: true);
        buffer += chunkText;

        final parts = buffer.split('\n\n');
        buffer = parts.removeLast(); // Guardar el remanente en el buffer

        for (final part in parts) {
          if (part.trim().isEmpty) continue;
          final lines = part.split('\n');
          String eventType = 'message';
          dynamic eventData;

          for (final line in lines) {
            if (line.startsWith('event: ')) {
              eventType = line.substring(7).trim();
            } else if (line.startsWith('data: ')) {
              final rawData = line.substring(6).trim();
              try {
                eventData = jsonDecode(rawData);
              } catch (_) {
                eventData = rawData;
              }
            }
          }

          if (eventData != null) {
            if (eventType == 'status' && onStatus != null) {
              final sMsg = eventData is String ? eventData : (eventData['message'] ?? eventData['status'] ?? '');
              onStatus(sMsg.toString());
            } else if (eventType == 'token' && onToken != null) {
              final tVal = eventData is String ? eventData : (eventData['token'] ?? eventData['chunk'] ?? '');
              onToken(tVal.toString());
            } else if (eventType == 'done') {
              if (eventData is Map<String, dynamic>) {
                accumulatedData.addAll(eventData);
              }
              if (onDone != null) onDone(accumulatedData);
            } else if (eventType == 'error') {
              if (onError != null) onError(eventData);
            } else {
              // Eventos data directos
              if (eventData is Map<String, dynamic>) {
                if (eventData.containsKey('token') && onToken != null) {
                  onToken(eventData['token'].toString());
                }
                if (eventData.containsKey('status') && onStatus != null) {
                  onStatus(eventData['status'].toString());
                }
                accumulatedData.addAll(eventData);
              }
            }
          }
        }
      }

      if (onDone != null) {
        onDone(accumulatedData);
      }
    } catch (err) {
      debugPrint('[ChatStream Error] Fallback a chat normal: $err');
      // Fallback transparente a /api/ai/chat
      try {
        final fallbackRes = await chatAi(prompt, sessionId: sessionId, history: history);
        final reply = fallbackRes['reply']?.toString() ?? fallbackRes['text']?.toString() ?? '';
        if (onToken != null && reply.isNotEmpty) {
          onToken(reply);
        }
        if (onDone != null) {
          onDone(fallbackRes);
        }
      } catch (fallbackErr) {
        if (onError != null) {
          onError(fallbackErr);
        } else {
          rethrow;
        }
      }
    }
  }

  /// Registra feedback Human-in-the-Loop (Like / Dislike) en una operación de la IA
  Future<bool> sendAiFeedback({
    required int logId,
    required String feedback, // 'like' o 'dislike'
    String? motivo,
    String? comentario,
  }) async {
    try {
      final response = await _dio.post(
        '/ai/feedback',
        data: {
          'log_id': logId,
          'feedback': feedback,
          'motivo': ?motivo,
          'comentario': ?comentario,
        },
      );
      final data = response.data;
      return data != null && data['success'] == true;
    } catch (e) {
      debugPrint('Error enviando feedback IA: $e');
      return false;
    }
  }

  /// Obtiene estado del motor Gemini y herramientas activas
  Future<Map<String, dynamic>> getAiStatus() async {
    try {
      final response = await _dio.get('/ai/status');
      return response.data as Map<String, dynamic>? ?? {};
    } catch (_) {
      return {'status': 'offline', 'provider': 'gemini'};
    }
  }

  /// Obtiene la lista de tools operativas registradas en el backend
  Future<List<dynamic>> getAiTools() async {
    try {
      final response = await _dio.get('/ai/tools');
      final data = response.data;
      if (data is Map && data['tools'] is List) {
        return data['tools'] as List<dynamic>;
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Transcribe un archivo de audio grabado en el dispositivo usando el backend de IA (Gemini)
  /// POST /api/ai/transcribe-audio
  Future<Map<String, dynamic>> transcribeAudio({
    required String filePath,
    String? mimeType,
  }) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final ext = fileName.split('.').last.toLowerCase();

    // Mapeo MIME type compatible con el backend Laravel y Gemini
    final detectedMime = mimeType ?? (ext == 'm4a' ? 'audio/mp4' : (ext == 'wav' ? 'audio/wav' : 'audio/webm'));

    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
      'mime_type': detectedMime,
    });

    final response = await _dio.post(
      '/ai/transcribe-audio',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        sendTimeout: const Duration(seconds: 40),
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data['success'] == true && data['data'] != null) {
        return data['data'] as Map<String, dynamic>;
      }
      throw ApiException(
        message: data['message']?.toString() ?? 'Error al transcribir audio.',
        statusCode: response.statusCode,
      );
    }
    throw ApiException(message: 'Respuesta inválida del servidor al procesar el audio.');
  }

  // ==========================================
  // 4. MÓDULO DE PERSONAL Y CUENTA
  // ==========================================

  /// Obtiene la información completa del perfil de un empleado
  /// GET /api/personal/{id}
  Future<EmpleadoModel> getPersonal(String id) async {
    try {
      final response = await _dio.get('/personal/$id');
      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] != null) {
        return EmpleadoModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      final msg = (data is Map) ? data['message']?.toString() : null;
      throw ApiException(message: msg ?? 'No se pudo obtener el perfil.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      final resData = e.response?.data;
      final msg = (resData is Map) ? resData['message']?.toString() : null;
      throw ApiException(
        message: msg ?? 'Error al cargar perfil del empleado.',
        statusCode: e.response?.statusCode,
      );
    }
  }

  /// Actualiza los datos personales del colaborador
  /// PUT /api/personal/{id}
  Future<EmpleadoModel> updatePersonal(String id, Map<String, dynamic> personalData) async {
    try {
      final response = await _dio.put(
        '/personal/$id',
        data: personalData,
      );
      final data = response.data;
      if (data is Map && data['success'] == true && data['data'] != null) {
        return EmpleadoModel.fromJson(data['data'] as Map<String, dynamic>);
      }
      final msg = (data is Map) ? data['message']?.toString() : null;
      throw ApiException(message: msg ?? 'No se pudo actualizar los datos.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      final resData = e.response?.data;
      final errors = (resData is Map) ? resData['errors'] : null;
      String? errorDetails;
      if (errors is Map) {
        errorDetails = errors.values.map((v) => (v is List) ? v.join(', ') : v.toString()).join('\n');
      }
      final msg = (resData is Map) ? resData['message']?.toString() : null;
      throw ApiException(
        message: errorDetails ?? msg ?? 'Error al guardar los datos personales.',
        statusCode: e.response?.statusCode,
        data: resData is Map<String, dynamic> ? resData : null,
      );
    }
  }

  /// Actualiza la contraseña de acceso del colaborador
  /// PATCH /api/personal/{id}/password
  Future<void> updatePersonalPassword(
    String id, {
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await _dio.patch(
        '/personal/$id/password',
        data: {
          'password': password,
          'password_confirmation': passwordConfirmation,
        },
      );
      final data = response.data;
      if (data is Map && data['success'] == true) {
        return;
      }
      final msg = (data is Map) ? data['message']?.toString() : null;
      throw ApiException(message: msg ?? 'No se pudo actualizar la contraseña.');
    } on DioException catch (e) {
      if (e.error is ApiException) throw e.error as ApiException;
      final resData = e.response?.data;
      final errors = (resData is Map) ? resData['errors'] : null;
      String? errorDetails;
      if (errors is Map) {
        errorDetails = errors.values.map((v) => (v is List) ? v.join(', ') : v.toString()).join('\n');
      }
      final msg = (resData is Map) ? resData['message']?.toString() : null;
      throw ApiException(
        message: errorDetails ?? msg ?? 'Error al cambiar la contraseña.',
        statusCode: e.response?.statusCode,
        data: resData is Map<String, dynamic> ? resData : null,
      );
    }
  }
}
