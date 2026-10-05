import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/api_service.dart';

class FeedbackDialog extends StatefulWidget {
  final int logId;
  final VoidCallback? onFeedbackSent;

  const FeedbackDialog({
    super.key,
    required this.logId,
    this.onFeedbackSent,
  });

  static Future<void> show(BuildContext context, {required int logId, VoidCallback? onFeedbackSent}) {
    return showDialog(
      context: context,
      builder: (context) => FeedbackDialog(logId: logId, onFeedbackSent: onFeedbackSent),
    );
  }

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final List<String> _motivos = [
    'Cantidad incorrecta',
    'Producto incorrecto',
    'Cliente o Proveedor erróneo',
    'Precio o Descuento erróneo',
    'Error de interpretación',
    'Otro motivo',
  ];

  String _selectedMotivo = 'Error de interpretación';
  final TextEditingController _comentarioController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final success = await ApiService().sendAiFeedback(
        logId: widget.logId,
        feedback: 'dislike',
        motivo: _selectedMotivo,
        comentario: _comentarioController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        if (success) {
          widget.onFeedbackSent?.call();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gracias por tu retroalimentación para calibrar la IA.'),
              backgroundColor: AppColors.primaryBlue,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: const [
          Icon(Icons.thumb_down_rounded, color: AppColors.error, size: 20),
          SizedBox(width: 8),
          Text(
            'Reportar Inconsistencia IA',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Cuál fue la causa de la respuesta o cálculo insatisfactorio?',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedMotivo,
              decoration: const InputDecoration(
                labelText: 'Motivo del problema',
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: _motivos
                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12))))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedMotivo = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comentarioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Detalles adicionales (opcional)',
                hintText: 'Describe brevemente qué se esperaba...',
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
          child: _submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Enviar Reporte'),
        ),
      ],
    );
  }
}
