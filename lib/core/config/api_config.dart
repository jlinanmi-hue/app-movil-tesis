import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _keyCustomBaseUrl = 'custom_api_base_url';
  static const String _keyConfigVersion = 'api_base_url_version';
  static const int _configVersion = 2;

  // Backend oficial desplegado en Render.
  static const String productionUrl = 'https://backend-tesis-xu33.onrender.com/api';

  // URLs locales para desarrollo o pruebas (configurables manualmente).
  static const String emulatorAndroidUrl = 'http://10.0.2.2:8000/api';
  static const String localhostUrl = 'http://127.0.0.1:8000/api';

  static String _cachedBaseUrl = '';

  /// URL base por defecto: backend oficial en Render.
  static String get defaultBaseUrl => productionUrl;

  /// Obtiene de forma síncrona la URL base actual (o la predeterminada)
  static String get currentBaseUrl => _cachedBaseUrl.isNotEmpty ? _cachedBaseUrl : defaultBaseUrl;

  /// Carga la URL base configurada o la predeterminada
  static Future<String> getBaseUrl() async {
    if (_cachedBaseUrl.isNotEmpty) {
      return _cachedBaseUrl;
    }
    final prefs = await SharedPreferences.getInstance();

    // Migración única: el backend cambió de dominio. Se descarta cualquier
    // URL guardada por versiones anteriores para que la app use la nueva.
    final version = prefs.getInt(_keyConfigVersion) ?? 1;
    if (version < _configVersion) {
      await prefs.remove(_keyCustomBaseUrl);
      await prefs.setInt(_keyConfigVersion, _configVersion);
      _cachedBaseUrl = defaultBaseUrl;
      return _cachedBaseUrl;
    }

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
    await prefs.setInt(_keyConfigVersion, _configVersion);
    _cachedBaseUrl = normalized;
  }

  /// Restablece la URL a la predeterminada
  static Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCustomBaseUrl);
    await prefs.setInt(_keyConfigVersion, _configVersion);
    _cachedBaseUrl = defaultBaseUrl;
  }

  /// Solo para pruebas: descarta la URL en memoria para simular un arranque.
  @visibleForTesting
  static void resetCache() => _cachedBaseUrl = '';

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
