import 'package:flutter/material.dart';
import '../../../core/config/api_config.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class ServerConfigDialog extends StatefulWidget {
  const ServerConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ServerConfigDialog(),
    );
  }

  @override
  State<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends State<ServerConfigDialog> {
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _loadCurrentUrl();
  }

  Future<void> _loadCurrentUrl() async {
    final current = await ApiConfig.getBaseUrl();
    _urlController.text = current;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final inputUrl = _urlController.text.trim();
      await ApiConfig.setBaseUrl(inputUrl);

      final status = await ApiService().getAiStatus();
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = true;
          _testResult = '¡Conexión exitosa con el Backend! (Estado: ${status['status'] ?? 'online'})';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testSuccess = false;
          _testResult = 'No se pudo conectar: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _saveAndClose() async {
    final inputUrl = _urlController.text.trim();
    if (inputUrl.isNotEmpty) {
      await ApiConfig.setBaseUrl(inputUrl);
    }
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Configuración de servidor guardada.'),
          backgroundColor: AppColors.successFill,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Icon(Icons.dns_rounded, color: AppColors.primaryBlue),
          SizedBox(width: 8),
          Text(
            'Servidor Backend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ajusta la URL base del backend Laravel (nube o entorno local):',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 14),

            // Opciones rápidas
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Backend Render'),
                  onPressed: () => _urlController.text = ApiConfig.productionUrl,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                ActionChip(
                  label: const Text('Android Emulador (10.0.2.2)'),
                  onPressed: () => _urlController.text = ApiConfig.emulatorAndroidUrl,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
                ActionChip(
                  label: const Text('Localhost (127.0.0.1)'),
                  onPressed: () => _urlController.text = ApiConfig.localhostUrl,
                  labelStyle: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL API Base',
                hintText: ApiConfig.productionUrl,
                prefixIcon: Icon(Icons.link_rounded),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),

            // Botón de prueba de conexión
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering_rounded, size: 16),
                label: Text(_testing ? 'Comprobando...' : 'Probar Conexión'),
              ),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _testSuccess ? AppColors.successBg : AppColors.errorBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _testSuccess ? AppColors.successBorder : AppColors.errorBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                      size: 16,
                      color: _testSuccess ? AppColors.successDark : AppColors.errorDark,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _testResult!,
                        style: TextStyle(
                          fontSize: 11,
                          color: _testSuccess ? AppColors.successDark : AppColors.errorDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saveAndClose,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
