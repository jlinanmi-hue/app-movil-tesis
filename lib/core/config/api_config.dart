import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyCustomBaseUrl = 'custom_api_base_url';

  // URLs predeterminadas según entorno
  static const String emulatorAndroidUrl = 'http://10.0.2.2:8000/api';
  static const String localhostUrl = 'http://127.0.0.1:8000/api';

  static String _cachedBaseUrl = '';

  /// Obtiene la URL base por defecto según la plataforma
  static String get defaultBaseUrl {
    if (kIsWeb) {
      return localhostUrl;
    }
    try {
      if (Platform.isAndroid) {
        return emulatorAndroidUrl;
      }
    } catch (_) {}
    return localhostUrl;
  }

  /// Obtiene de forma síncrona la URL base actual (o la predeterminada)
  static String get currentBaseUrl => _cachedBaseUrl.isNotEmpty ? _cachedBaseUrl : defaultBaseUrl;

  /// Carga la URL base configurada o la predeterminada
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyCustomBaseUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      _cachedBaseUrl = _normalizeUrl(saved.trim());
      return _cachedBaseUrl;
    }
    _cachedBaseUrl = defaultBaseUrl;
    return _cachedBaseUrl;
  }

  /// Establece una URL base personalizada
  static Future<void> setBaseUrl(String url) async {
    final normalized = _normalizeUrl(url.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCustomBaseUrl, normalized);
    _cachedBaseUrl = normalized;
  }

  /// Restablece la URL a la predeterminada
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomBaseUrl);
    _cachedBaseUrl = defaultBaseUrl;
  }

  static String _normalizeUrl(String url) {
    var result = url;
    if (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    if (!result.endsWith('/api') && !result.contains('/api/')) {
      result = '$result/api';
    }
    return result;
  }
}
