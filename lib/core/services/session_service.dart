import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/user_model.dart';

class SessionService {
  static const String _keyToken = 'auth_token';
  static const String _keyUserData = 'auth_user_data';
  static const String _keyIsLoggedIn = 'auth_is_logged_in';

  static final ValueNotifier<bool> isLoggedInNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<UserModel?> currentUserNotifier = ValueNotifier<UserModel?>(null);
  static UserModel? _currentUser;
  static String? _cachedToken;

  /// Inicializa el estado de la sesión al arrancar la app
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool(_keyIsLoggedIn) ?? false;
    _cachedToken = prefs.getString(_keyToken);

    final rawUser = prefs.getString(_keyUserData);
    if (isLoggedIn && rawUser != null) {
      try {
        final Map<String, dynamic> userMap = jsonDecode(rawUser);
        _currentUser = UserModel.fromJson(userMap, token: _cachedToken);
        currentUserNotifier.value = _currentUser;
        isLoggedInNotifier.value = true;
        return;
      } catch (e) {
        debugPrint('Error al restaurar sesión: $e');
      }
    }
    _currentUser = null;
    currentUserNotifier.value = null;
    isLoggedInNotifier.value = false;
  }

  /// Guarda la sesión activa tras un login exitoso
  static Future<void> saveSession(UserModel user, {String? token}) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = user;
    _cachedToken = token ?? user.token;
    currentUserNotifier.value = user;

    await prefs.setBool(_keyIsLoggedIn, true);
    if (_cachedToken != null) {
      await prefs.setString(_keyToken, _cachedToken!);
    }
    await prefs.setString(_keyUserData, jsonEncode(user.toJson()));

    isLoggedInNotifier.value = true;
  }

  /// Actualiza los datos del usuario en sesión activa y en memoria persistente
  static Future<void> updateUser(UserModel updatedUser) async {
    final prefs = await SharedPreferences.getInstance();
    _currentUser = updatedUser;
    currentUserNotifier.value = updatedUser;
    await prefs.setString(_keyUserData, jsonEncode(updatedUser.toJson()));
  }

  /// Obtiene el usuario autenticado actual
  static UserModel? get currentUser => _currentUser;

  /// Obtiene el token de autenticación
  static String? get token => _cachedToken;

  /// Verifica si hay una sesión activa
  static bool get isLoggedIn => isLoggedInNotifier.value;

  /// Cierra la sesión y limpia el almacenamiento persistente
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyIsLoggedIn);
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserData);

    _currentUser = null;
    _cachedToken = null;
    currentUserNotifier.value = null;
    isLoggedInNotifier.value = false;
  }
}
