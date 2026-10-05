import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Campo configurable para formularios móviles (crear/editar).
class ErpField {
  final String key;
  final String label;
  final String? hint;
  final TextInputType keyboard;
  final bool required;
  final int maxLines;
  final List<String>? options; // si no null -> dropdown
  final String? initial;

  ErpField({
    required this.key,
    required this.label,
    this.hint,
    this.keyboard = TextInputType.text,
    this.required = false,
    this.maxLines = 1,
    this.options,
    this.initial,
  });
}

/// BottomSheet CRUD responsive: SafeArea + scroll + validación.
class ErpFormSheet extends StatefulWidget {
  final String title;
  final List<ErpField> fields;
  final Map<String, String> initial;
  final Future<void> Function(Map<String, String>) onSave;

  const ErpFormSheet({
    super.key,
    required this.title,
    required this.fields,
    required this.initial,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<ErpField> fields,
    Map<String, String> initial = const {},
    required Future<void> Function(Map<String, String>) onSave,
    VoidCallback? onSaved,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ErpFormSheet(
            title: title, fields: fields, initial: initial, onSave: onSave),
      ),
    );
    if (saved == true) onSaved?.call();
  }

  @override
  State<ErpFormSheet> createState() => _ErpFormSheetState();
}

class _ErpFormSheetState extends State<ErpFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _ctrl;
  late Map<String, String?> _drop;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = {};
    _drop = {};
    for (final f in widget.fields) {
      final v = widget.initial[f.key] ?? f.initial ?? '';
      if (f.options != null) {
        _drop[f.key] = v.isEmpty ? null : v;
      } else {
        _ctrl[f.key] = TextEditingController(text: v);
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, c) {
          final isTablet = c.maxWidth >= 600;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: isTablet ? 560 : double.infinity),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.celesteBg,
                                borderRadius: BorderRadius.circular(2)))),
                    const SizedBox(height: 14),
                    Text(widget.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark)),
                    const SizedBox(height: 4),
                    const Text('Completa los campos para guardar el registro.',
                        style: TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                    const SizedBox(height: 14),
                    if (isTablet)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 4,
                          childAspectRatio: 2.4,
                        ),
                        itemCount: widget.fields.length,
                        itemBuilder: (_, i) =>
                            _field(widget.fields[i]),
                      )
                    else
                      ...widget.fields.map(_field),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.celeste,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar registro',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _field(ErpField f) {
    if (f.options != null) {
      // A prueba de crashes: si el valor inicial no está en la lista
      // (ej. Estado=V cuando opciones son A/I, o un Map serializado),
      // se usa null en lugar de romper el Dropdown.
      // Se deduplican opciones por seguridad.
      final opts = f.options!.toSet().toList();
      String? raw = _drop[f.key]?.trim();
      if (raw != null && raw.isEmpty) raw = null;
      String? safe;
      if (raw != null) {
        if (opts.contains(raw)) {
          safe = raw;
        } else {
          final match = opts.where(
              (o) => o.trim().toLowerCase() == raw!.trim().toLowerCase());
          safe = match.isEmpty ? null : match.first;
        }
      }
      // Sincroniza sin setState durante build (evita valor inválido retenido)
      if (safe != _drop[f.key]) {
        _drop[f.key] = safe;
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: DropdownButtonFormField<String>(
          key: ValueKey('${f.key}_$safe'),
          initialValue: safe,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint ?? (raw != null ? 'Actual: $raw' : null),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.celesteBg)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.celesteBg)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: opts
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _drop[f.key] = v),
          validator: (v) {
            if (f.required && (v == null || v.isEmpty)) {
              return 'Requerido';
            }
            return null;
          },
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: _ctrl[f.key],
        keyboardType: f.keyboard,
        maxLines: f.maxLines,
        decoration: InputDecoration(
          labelText: f.label + (f.required ? ' *' : ''),
          hintText: f.hint,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.celesteBg)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.celesteBg)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        validator: (v) {
          if (f.required && (v == null || v.trim().isEmpty)) {
            return 'Campo requerido';
          }
          return null;
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final data = <String, String>{};
    for (final f in widget.fields) {
      if (f.options != null) {
        data[f.key] = _drop[f.key] ?? '';
      } else {
        data[f.key] = _ctrl[f.key]!.text.trim();
      }
    }
    setState(() => _saving = true);
    try {
      await widget.onSave(data);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

/// Tabla historial responsive con scroll horizontal (SafeArea aware).
class ErpHistoryTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final String title;

  const ErpHistoryTable({
    super.key,
    required this.title,
    required this.columns,
    required this.rows,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => ErpHistoryTable(
            title: title, columns: columns, rows: rows),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.celesteBg,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.celesteTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${rows.length} filas',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.celesteDark)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(
                      child: Text('Sin historial por ahora.',
                          style: TextStyle(color: AppColors.textMuted)))
                  : LayoutBuilder(
                      builder: (context, c) => SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                                minWidth: c.maxWidth),
                            child: DataTable(
                              headingRowColor:
                                  WidgetStateProperty.all(
                                      AppColors.celesteTint),
                              headingTextStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.celesteDark),
                              dataTextStyle: const TextStyle(
                                  fontSize: 11.5,
                                  color: AppColors.textDark),
                              columns: columns
                                  .map((h) => DataColumn(label: Text(h)))
                                  .toList(),
                              rows: rows
                                  .map((r) => DataRow(
                                      cells: r
                                          .map((v) => DataCell(Text(v)))
                                          .toList()))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Configs de formularios por módulo (campos del frontend-tesis).
class ErpForms {
  static List<ErpField> cliente() => [
        ErpField(key: 'ClienteNombre', label: 'Nombre / Razón social', required: true, hint: 'Ej: Bodega San Juan'),
        ErpField(key: 'ClienteRuc', label: 'RUC / DNI', keyboard: TextInputType.number, hint: '11 dígitos RUC u 8 DNI'),
        ErpField(key: 'ClienteNumero', label: 'Teléfono', keyboard: TextInputType.phone),
        ErpField(key: 'ClienteDireccion', label: 'Dirección', maxLines: 2),
        ErpField(key: 'ClienteEstado', label: 'Estado', options: const ['A', 'I']),
      ];

  static List<ErpField> proveedor() => [
        ErpField(key: 'ProveedorRuc', label: 'RUC', required: true, keyboard: TextInputType.number, hint: '11 dígitos'),
        ErpField(key: 'ProveedorRazonSocial', label: 'Razón social', required: true),
        ErpField(key: 'ProveedorTipoContribuyente', label: 'Tipo contribuyente'),
        ErpField(key: 'ProveedorActividadEconomica', label: 'Actividad económica'),
        ErpField(key: 'ProveedorTelefono', label: 'Teléfono', keyboard: TextInputType.phone),
        ErpField(key: 'ProveedorEstado', label: 'Estado', options: const ['A', 'I']),
      ];

  static List<ErpField> producto() => [
        ErpField(key: 'ProductoNombre', label: 'Nombre producto', required: true),
        ErpField(key: 'ProductoMarca', label: 'Marca'),
        ErpField(key: 'Producto_Categoria_ProductoId', label: 'Categoría ID', hint: 'Ej: CAT-00001'),
        ErpField(key: 'Producto_producto_ubi_id', label: 'Ubicación ID', hint: 'Ej: UBI-00001'),
        ErpField(key: 'ProductoStockMinimo', label: 'Stock mínimo', keyboard: TextInputType.number),
        ErpField(key: 'ProductoStockMaximo', label: 'Stock máximo', keyboard: TextInputType.number),
        ErpField(key: 'stockInicial', label: 'Stock inicial', keyboard: TextInputType.number),
        ErpField(key: 'precio_compra', label: 'Precio compra', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ErpField(key: 'precio_venta', label: 'Precio venta', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ErpField(key: 'ProductoEstado', label: 'Estado', options: const ['A', 'I']),
      ];

  static List<ErpField> personal() => [
        ErpField(key: 'EmpleadoNombres', label: 'Nombres', required: true),
        ErpField(key: 'EmpleadoApellidos', label: 'Apellidos', required: true),
        ErpField(key: 'EmpleadoDni', label: 'DNI (8 dígitos)', required: true, keyboard: TextInputType.number),
        ErpField(key: 'EmpleadoTelefono', label: 'Teléfono', keyboard: TextInputType.phone),
        ErpField(key: 'EmpleadoCorreo', label: 'Correo', keyboard: TextInputType.emailAddress),
        ErpField(key: 'EmpleadoSexo', label: 'Sexo', options: const ['M', 'F']),
        ErpField(key: 'Empleado_cargoId', label: 'Cargo ID'),
        ErpField(key: 'EmpleadoFechaIngreso', label: 'Fecha ingreso (YYYY-MM-DD)'),
        // Backend admite A|V|L|I|S (activo, vacaciones, licencia, inactivo)
        ErpField(key: 'EmpleadoEstado', label: 'Estado', options: const ['A', 'V', 'L', 'I']),
      ];

  static List<ErpField> categoria() => [
        ErpField(
            key: 'Categoria_ProductoDescripcion_categoria',
            label: 'Descripción',
            required: true,
            hint: 'Ej: Abarrotes'),
        ErpField(
            key: 'Categoria_ProductoEstado',
            label: 'Estado',
            options: const ['A', 'I']),
      ];

  static List<ErpField> canal() => [
        ErpField(
            key: 'Canal_pedidoDescripcion',
            label: 'Descripción',
            required: true,
            hint: 'Ej: WhatsApp'),
        ErpField(
            key: 'Canal_pedidoEstado',
            label: 'Estado',
            options: const ['A', 'I']),
      ];

  static List<ErpField> ubicacion() => [
        ErpField(
            key: 'producto_ubi_descripcion',
            label: 'Descripción',
            required: true,
            hint: 'Ej: Estante A-01'),
        ErpField(key: 'producto_ubi_observacion', label: 'Observación'),
        ErpField(
            key: 'producto_ubi_estado',
            label: 'Estado',
            options: const ['A', 'I']),
      ];

  static List<ErpField> unidad() => [
        ErpField(
            key: 'unidades_medidaDescripcionUnidades',
            label: 'Descripción',
            required: true,
            hint: 'Ej: Caja'),
        ErpField(key: 'unidades_medidaAbreviatura', label: 'Abreviatura', hint: 'Ej: CJA'),
        ErpField(
            key: 'unidades_medidaEstadoUnidades',
            label: 'Estado',
            options: const ['A', 'I']),
      ];

  static List<ErpField> rol() => [
        ErpField(
            key: 'Rol_UserRol_Usercol',
            label: 'Nombre rol',
            required: true,
            hint: 'Ej: Vendedor'),
        ErpField(key: 'Rol_UserEmpleadocol', label: 'Código', hint: 'Ej: VENDEDOR'),
      ];

  static List<ErpField> cargo() => [
        ErpField(
            key: 'cargoDescripcion',
            label: 'Descripción cargo',
            required: true,
            hint: 'Ej: Cajero'),
        ErpField(
            key: 'cargoEstado', label: 'Estado', options: const ['A', 'I']),
      ];

  static List<ErpField> pedidoCliente() => [
        ErpField(key: 'cliente', label: 'Cliente (nombre o ID)', required: true),
        ErpField(key: 'canal', label: 'Canal', options: const ['Mostrador', 'WhatsApp', 'Teléfono', 'Valencia AI']),
        ErpField(key: 'acuerdo', label: 'Acuerdo', options: const ['Contado Mostrador', 'Crédito 7 días', 'Crédito 15 días']),
        ErpField(key: 'producto', label: 'Producto (nombre o código)', required: true),
        ErpField(key: 'cantidad', label: 'Cantidad', required: true, keyboard: TextInputType.number),
        ErpField(key: 'precio', label: 'Precio unit.', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ErpField(key: 'observacion', label: 'Observación', maxLines: 2),
      ];

  static List<ErpField> ordenCompra() => [
        ErpField(key: 'proveedor', label: 'Proveedor (nombre o RUC)', required: true),
        ErpField(key: 'producto', label: 'Producto (nombre o código)', required: true),
        ErpField(key: 'cantidad', label: 'Cantidad', required: true, keyboard: TextInputType.number),
        ErpField(key: 'precio', label: 'Precio unit.', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        ErpField(key: 'fecha_entrega', label: 'Entrega estimada (YYYY-MM-DD)'),
        ErpField(key: 'observacion', label: 'Observación', maxLines: 2),
      ];

  static List<ErpField> recepcion() => [
        ErpField(key: 'orden_id', label: 'Orden compra ID', required: true),
        ErpField(key: 'cantidad_recibida', label: 'Cantidad recibida', required: true, keyboard: TextInputType.number),
        ErpField(key: 'conformidad', label: 'Conformidad', options: const ['Conforme', 'Parcial', 'Faltante', 'Rechazado']),
        ErpField(key: 'motivo', label: 'Motivo / nota', maxLines: 2),
      ];
}
