import 'dart:async';
import 'dart:io' show Platform;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../../models/notification_model.dart';
import 'device_notification_service.dart';
import 'session_service.dart';

/// Servicio centralizado de Notificaciones en tiempo real para Comercial Valencia
class NotificationService {
  static const String _keyLastSeenNotifId = 'valencia_last_seen_notif_id';
  static final NotificationService instance = NotificationService._internal();
  factory NotificationService() => instance;

  late Dio _dio;
  Timer? _pollingTimer;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<AppNotificationModel>> notificationsNotifier =
      ValueNotifier<List<AppNotificationModel>>([]);
  final ValueNotifier<bool> isLoadingNotifier = ValueNotifier<bool>(false);

  final StreamController<AppNotificationModel> _newNotificationController =
      StreamController<AppNotificationModel>.broadcast();
  Stream<AppNotificationModel> get onNewNotification =>
      _newNotificationController.stream;

  final Set<String> _knownNotificationIds = {};
  bool _isFirstFetch = true;

  NotificationService._internal() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          options.baseUrl = await ApiConfig.getBaseUrl();
          final token = SessionService.token;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );

    // Iniciar polling ligero si no estamos en entorno de pruebas unitarias
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      startPolling();
    }
  }

  void startPolling({Duration interval = const Duration(seconds: 10)}) {
    _pollingTimer?.cancel();
    // Primera carga inmediata
    fetchNotifications();

    _pollingTimer = Timer.periodic(interval, (_) {
      fetchNotifications(isBackgroundPoll: true);
    });
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Carga el listado de notificaciones y actualiza el contador no leídas
  Future<void> fetchNotifications({
    bool soloNoLeidas = false,
    int perPage = 35,
    String? search,
    String? categoria,
    bool isBackgroundPoll = false,
  }) async {
    try {
      if (!isBackgroundPoll) {
        isLoadingNotifier.value = true;
      }
      final queryParams = <String, dynamic>{
        'per_page': perPage,
      };
      if (soloNoLeidas) queryParams['solo_no_leidas'] = 1;
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (categoria != null && categoria.isNotEmpty && categoria != 'TODAS') {
        queryParams['categoria'] = categoria;
      }

      final response = await _dio.get(
        '/notificaciones',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data != null) {
        final dataWrapper = response.data['data'];
        List<dynamic> itemsList = [];

        if (dataWrapper is Map && dataWrapper['data'] is List) {
          // Paginación Laravel estándar { data: { current_page, data: [...] } }
          itemsList = dataWrapper['data'] as List;
        } else if (dataWrapper is List) {
          itemsList = dataWrapper;
        }

        final list = itemsList
            .whereType<Map>()
            .map((e) => AppNotificationModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        // Detección de notificaciones nuevas (persistente con SharedPreferences)
        SharedPreferences? prefs;
        try {
          prefs = await SharedPreferences.getInstance();
        } catch (_) {}

        final savedLastId = prefs?.getString(_keyLastSeenNotifId);

        if (_isFirstFetch) {
          _isFirstFetch = false;
          for (final n in list) {
            _knownNotificationIds.add(n.id);
          }
          // Si ya teníamos un ID guardado y el primer elemento es distinto, alertar sobre las nuevas
          if (savedLastId != null && list.isNotEmpty && list.first.id != savedLastId) {
            for (final n in list) {
              if (n.id == savedLastId) break;
              if (!n.leida) {
                emitNewNotification(n);
              }
            }
          }
        } else {
          // Identificar si llegó una notificación no vista previamente
          for (final n in list) {
            if (!_knownNotificationIds.contains(n.id)) {
              _knownNotificationIds.add(n.id);
              if (!n.leida) {
                emitNewNotification(n);
              }
            }
          }
        }

        if (list.isNotEmpty) {
          prefs?.setString(_keyLastSeenNotifId, list.first.id);
        }

        notificationsNotifier.value = list;

        // Actualizar total no leídas desde backend
        if (response.data['total_no_leidas'] != null) {
          final count = (response.data['total_no_leidas'] as num).toInt();
          unreadCountNotifier.value = count;
        } else {
          // Fallback contando en la lista
          final localUnread = list.where((n) => !n.leida).length;
          unreadCountNotifier.value = localUnread;
        }
      }
    } catch (e) {
      debugPrint('[NotificationService] Error al obtener notificaciones: $e');
    } finally {
      if (!isBackgroundPoll) {
        isLoadingNotifier.value = false;
      }
    }
  }

  /// Emite una notificación inteligente:
  /// - Siempre la registra en el panel de notificaciones del teléfono móvil (Android/iOS).
  /// - Si la aplicación está en primer plano, también muestra el Pop emergente interactivo desde la campana.
  void emitNewNotification(AppNotificationModel notif) {
    // 1. Siempre emitir al panel de notificaciones del dispositivo móvil
    DeviceNotificationService.instance.showNativeNotification(notif);

    // 2. Si la app está abierta, emitir también al controlador del Pop in-app
    if (!_newNotificationController.isClosed) {
      _newNotificationController.add(notif);
    }
  }

  /// Dispara una notificación de prueba en pantalla para visualizar el pop
  void triggerTestNotification({bool asNativeSystem = false}) {
    final list = notificationsNotifier.value;
    final sample = list.isNotEmpty
        ? list.first
        : AppNotificationModel(
            id: 'TEST-${DateTime.now().millisecondsSinceEpoch}',
            titulo: 'Apertura de tienda',
            mensaje: 'Se programó la apertura de tienda a las 7:30.',
            tipo: 'info',
            categoria: 'GENERAL',
            referenciaId: 'USR-00007',
            leida: false,
            fecha: DateTime.now(),
          );

    if (asNativeSystem) {
      DeviceNotificationService.instance.showNativeNotification(sample);
    } else {
      if (!_newNotificationController.isClosed) {
        _newNotificationController.add(sample);
      }
    }
  }

  /// Consulta rápida solo para refrescar el conteo de no leídas
  Future<int> fetchUnreadCount() async {
    try {
      final response = await _dio.get(
        '/notificaciones',
        queryParameters: {'per_page': 1},
      );
      if (response.statusCode == 200 && response.data != null) {
        if (response.data['total_no_leidas'] != null) {
          final count = (response.data['total_no_leidas'] as num).toInt();
          unreadCountNotifier.value = count;
          return count;
        }
      }
    } catch (_) {}
    return unreadCountNotifier.value;
  }

  /// Marcar una notificación individual como leída
  Future<bool> markAsRead(String id) async {
    try {
      // Actualización optimista local
      final currentList = notificationsNotifier.value;
      final index = currentList.indexWhere((n) => n.id == id);
      if (index != -1 && !currentList[index].leida) {
        final updatedList = List<AppNotificationModel>.from(currentList);
        updatedList[index] = currentList[index].copyWith(leida: true);
        notificationsNotifier.value = updatedList;
        if (unreadCountNotifier.value > 0) {
          unreadCountNotifier.value -= 1;
        }
      }

      final response = await _dio.patch('/notificaciones/$id/leer');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationService] Error al marcar como leída $id: $e');
      return false;
    }
  }

  /// Marcar todas las notificaciones como leídas
  Future<bool> markAllAsRead() async {
    try {
      // Actualización optimista local
      final updatedList = notificationsNotifier.value
          .map((n) => n.copyWith(leida: true))
          .toList();
      notificationsNotifier.value = updatedList;
      unreadCountNotifier.value = 0;

      final response = await _dio.post('/notificaciones/marcar-todas');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationService] Error al marcar todas como leídas: $e');
      return false;
    }
  }

  /// Eliminar una notificación
  Future<bool> deleteNotification(String id) async {
    try {
      final currentList = notificationsNotifier.value;
      final item = currentList.firstWhere(
        (n) => n.id == id,
        orElse: () => AppNotificationModel(
          id: id,
          titulo: '',
          mensaje: '',
          tipo: 'info',
          categoria: 'GENERAL',
          leida: true,
        ),
      );

      final updatedList = currentList.where((n) => n.id != id).toList();
      notificationsNotifier.value = updatedList;
      if (!item.leida && unreadCountNotifier.value > 0) {
        unreadCountNotifier.value -= 1;
      }

      final response = await _dio.delete('/notificaciones/$id');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[NotificationService] Error al eliminar $id: $e');
      return false;
    }
  }
}
