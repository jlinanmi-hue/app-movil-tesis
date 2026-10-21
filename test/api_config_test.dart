import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_tesis/core/config/api_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConfig.resetCache();
    await ApiConfig.resetToDefault();
  });

  tearDown(() {
    ApiConfig.resetCache();
  });

  test('la URL por defecto apunta al backend en Render', () {
    expect(
      ApiConfig.defaultBaseUrl,
      'https://backend-tesis-xu33.onrender.com/api',
    );
  });

  test('descarta la URL guardada por versiones anteriores', () async {
    SharedPreferences.setMockInitialValues({
      'custom_api_base_url': 'https://backend-anterior.example.com/api',
      'api_base_url_version': 1,
    });
    ApiConfig.resetCache();

    final url = await ApiConfig.getBaseUrl();

    expect(url, ApiConfig.productionUrl);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('custom_api_base_url'), isNull);
    expect(prefs.getInt('api_base_url_version'), 2);
  });

  test('conserva una URL personalizada guardada con la versión actual',
      () async {
    await ApiConfig.setBaseUrl('https://mi-servidor.com');

    ApiConfig.resetCache();
    final url = await ApiConfig.getBaseUrl();

    expect(url, 'https://mi-servidor.com/api');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('api_base_url_version'), 2);
  });

  test('resetToDefault vuelve al backend oficial', () async {
    await ApiConfig.setBaseUrl('http://10.0.2.2:8000/api');
    await ApiConfig.resetToDefault();
    ApiConfig.resetCache();

    expect(await ApiConfig.getBaseUrl(), ApiConfig.productionUrl);
  });
}
