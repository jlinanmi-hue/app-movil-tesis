import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';

/// REGISTRAR / EDITAR CLIENTE
/// Interfaz propia con contenedores por sección (estilo del web):
/// · Documento de identidad → campo RUC/DNI con botón de búsqueda
///   SUNAT / RENIEC que autocompleta el formulario.
/// · Datos del cliente (nombre, teléfono, dirección).
/// · Estado comercial (Activo / Inactivo).
class NuevoClienteScreen extends StatefulWidget {
  /// Cuando se envía, la pantalla entra en modo edición.
  final ErpItem? cliente;

  const NuevoClienteScreen({super.key, this.cliente});

  @override
  State<NuevoClienteScreen> createState() => _NuevoClienteScreenState();
}

class _NuevoClienteScreenState extends State<NuevoClienteScreen> {
  final _svc = ModulesService();

  late final TextEditingController _ruc;
  late final TextEditingController _nombre;
  late final TextEditingController _telefono;
  late final TextEditingController _direccion;

  String _estado = 'A';
  bool _guardando = false;
  bool _consultando = false;
  String? _error;
  SunatConsulta? _sunat;

  bool get _esEdicion => widget.cliente != null;
  String get _doc => _ruc.text.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void initState() {
    super.initState();
    final raw = widget.cliente?.raw ?? const <String, dynamic>{};
    String v(String k) {
      final x = raw[k];
      if (x == null || x is Map || x is List) return '';
      final s = '$x'.trim();
      return (s == 'null' || s == '—') ? '' : s;
    }

    _ruc = TextEditingController(text: v('ClienteRuc'));
    final nombreRaw = v('ClienteNombre');
    _nombre = TextEditingController(
        text: nombreRaw.isNotEmpty ? nombreRaw : (widget.cliente?.titulo ?? ''));
    _telefono = TextEditingController(text: v('ClienteNumero'));
    _direccion = TextEditingController(text: v('ClienteDireccion'));
    _estado = v('ClienteEstado').toUpperCase() == 'I' ? 'I' : 'A';
  }

  @override
  void dispose() {
    _ruc.dispose();
    _nombre.dispose();
    _telefono.dispose();
    _direccion.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ---------------- Consulta SUNAT / RENIEC ----------------

  Future<void> _buscarSunat() async {
    final doc = _doc;
    if (doc.isEmpty) {
      setState(() => _error = 'Ingresa el RUC o DNI para consultar.');
      return;
    }
    if (doc.length != 8 && doc.length != 11) {
      setState(() => _error =
          'El documento debe tener 8 dígitos (DNI) u 11 dígitos (RUC SUNAT).');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _consultando = true;
      _error = null;
    });
    try {
      final info =
          await _svc.consultarDocumentoSunat(doc, target: 'cliente');
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _sunat = info;
        if (info.nombre.isNotEmpty) _nombre.text = info.nombre;
        if (info.direccion.isNotEmpty) _direccion.text = info.direccion;
        if (info.telefono.isNotEmpty) _telefono.text = info.telefono;
        _estado = info.estado;
      });
      _snack(info.esDni
          ? '¡DNI encontrado en RENIEC! Datos autocompletados.'
          : '¡RUC encontrado en SUNAT! Datos autocompletados.');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _sunat = null;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _sunat = null;
        _error = 'No se encontró información para el documento ingresado.';
      });
    }
  }

  // ---------------- Guardar ----------------

  Future<void> _guardar() async {
    final doc = _doc;
    if (doc.length != 8 && doc.length != 11) {
      setState(() =>
          _error = 'El RUC/DNI debe tener 8 u 11 dígitos numéricos.');
      return;
    }
    if (_nombre.text.trim().isEmpty) {
      setState(() => _error = 'El nombre o razón social es obligatorio.');
      return;
    }
    if (_telefono.text.trim().isEmpty) {
      setState(() => _error = 'El teléfono de contacto es obligatorio.');
      return;
    }
    if (_direccion.text.trim().isEmpty) {
      setState(() => _error = 'La dirección fiscal o comercial es obligatoria.');
      return;
    }

    final data = <String, String>{
      'ClienteRuc': doc,
      'ClienteNombre': _nombre.text.trim(),
      'ClienteNumero': _telefono.text.trim(),
      'ClienteDireccion': _direccion.text.trim(),
      'ClienteEstado': _estado,
    };

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _svc.guardarCliente(data,
          id: _esEdicion ? widget.cliente!.id : null);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = 'No se pudo guardar el cliente. Intenta nuevamente.';
      });
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          ErpHeader(
            title: _esEdicion ? 'Editar Cliente' : 'Nuevo Cliente',
            subtitle: 'Directorio comercial · validación SUNAT',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                if (_error != null) _bannerError(),
                _seccionDocumento(),
                _seccionDatos(),
                _seccionEstado(),
                const SizedBox(height: 2),
                ErpPrimaryButton(
                  label: _esEdicion ? 'Guardar cambios' : 'Registrar cliente',
                  icon: Icons.check_rounded,
                  loading: _guardando,
                  onTap: _guardando ? null : _guardar,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.errorBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.errorBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded,
              size: 16, color: AppColors.errorDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.errorDark)),
          ),
        ],
      ),
    );
  }

  Widget _seccion({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ErpSoftCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ErpIconTile(icon: icono, size: 32, radius: 11),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(titulo,
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textDark,
                          letterSpacing: -0.2)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ---------------- Documento + SUNAT ----------------

  Widget _seccionDocumento() {
    return _seccion(
      titulo: 'Documento de identidad',
      icono: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta('RUC / DNI',
              obligatorio: true, extra: 'Consulta SUNAT / RENIEC'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ruc,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _buscarSunat(),
                  onChanged: (_) => setState(() => _error = null),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: AppColors.textDark),
                  decoration: _deco(
                      'Ej: 20601234565 (11 dígitos) o 45678901 (8 DNI)'),
                ),
              ),
              const SizedBox(width: 8),
              _botonBuscar(),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.shield_outlined,
                  size: 13, color: AppColors.textSubtle),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                    'Validación algorítmica SUNAT Módulo 11 automática.',
                    style: TextStyle(
                        fontSize: 10.5, color: AppColors.textSubtle)),
              ),
            ],
          ),
          if (_sunat != null) _panelSunat(_sunat!),
        ],
      ),
    );
  }

  Widget _botonBuscar() {
    return GestureDetector(
      onTap: _consultando ? null : _buscarSunat,
      child: Tooltip(
        message: 'Buscar datos oficiales en SUNAT / RENIEC',
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppColors.celesteDeep,
            borderRadius: BorderRadius.circular(10),
          ),
          child: _consultando
              ? const Padding(
                  padding: EdgeInsets.all(15),
                  child: CircularProgressIndicator(
                      strokeWidth: 2.2, color: Colors.white),
                )
              : const Icon(Icons.search_rounded,
                  color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _panelSunat(SunatConsulta info) {
    Widget chip(String texto) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: AppColors.celesteSoft),
          ),
          child: Text(texto,
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.celesteDeep)),
        );

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.celesteSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_rounded,
                  size: 15, color: AppColors.celesteDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                    'Datos oficiales ${info.esDni ? 'RENIEC' : 'SUNAT'}',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textDark)),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              chip(info.estadoTexto),
              if (info.condicion.isNotEmpty) chip(info.condicion),
              if (info.desdeCache) chip('Caché BD'),
            ],
          ),
          if (info.tipoContribuyente.isNotEmpty ||
              info.nombreComercial.isNotEmpty ||
              info.ubicacion.isNotEmpty ||
              info.actividadEconomica.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (info.tipoContribuyente.isNotEmpty)
              _dato('Tipo', info.tipoContribuyente),
            if (info.nombreComercial.isNotEmpty)
              _dato('Comercial', info.nombreComercial),
            if (info.ubicacion.isNotEmpty)
              _dato(
                  'Ubigeo',
                  info.ubicacion +
                      (info.ubigeo.isNotEmpty ? ' (${info.ubigeo})' : '')),
            if (info.actividadEconomica.isNotEmpty)
              _dato('Actividad', info.actividadEconomica),
          ],
        ],
      ),
    );
  }

  Widget _dato(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text.rich(
        TextSpan(children: [
          TextSpan(
              text: '$label: ',
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMuted)),
          TextSpan(
              text: valor,
              style:
                  TextStyle(fontSize: 10.5, color: AppColors.textDark)),
        ]),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ---------------- Datos ----------------

  Widget _seccionDatos() {
    return _seccion(
      titulo: 'Datos del cliente',
      icono: Icons.person_outline_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta('Nombre o razón social', obligatorio: true),
          TextField(
            controller: _nombre,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration:
                _deco('Ej: Bodega Los Amigos S.A.C.', maxLength: 100),
          ),
          const SizedBox(height: 10),
          _etiqueta('Teléfono / celular', obligatorio: true),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            maxLength: 45,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration:
                _deco('Ej: +51 987123456', icon: Icons.call_outlined, maxLength: 45),
          ),
          const SizedBox(height: 10),
          _etiqueta('Dirección fiscal o comercial', obligatorio: true),
          TextField(
            controller: _direccion,
            maxLength: 200,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration: _deco(
                'Ej: Av. Las Flores 123, Urb. San Felipe',
                icon: Icons.place_outlined,
                maxLength: 200),
          ),
        ],
      ),
    );
  }

  // ---------------- Estado ----------------

  Widget _seccionEstado() {
    return _seccion(
      titulo: 'Estado comercial',
      icono: Icons.toggle_on_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ErpChoicePill(
                label: 'Activo',
                icon: Icons.check_circle_outline_rounded,
                selected: _estado == 'A',
                onTap: () => setState(() => _estado = 'A'),
              ),
              const SizedBox(width: 8),
              ErpChoicePill(
                label: 'Inactivo',
                icon: Icons.pause_circle_outline_rounded,
                selected: _estado == 'I',
                onTap: () => setState(() => _estado = 'I'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _estado == 'A'
                ? 'Habilitado para pedidos y ventas.'
                : 'Suspendido comercialmente (no aparece en pedidos).',
            style:
                TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---------------- helpers de campos ----------------

  Widget _etiqueta(String texto, {bool obligatorio = false, String? extra}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(texto.toUpperCase(),
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textMuted,
                  letterSpacing: .4)),
          if (obligatorio)
            Text(' *',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.errorDark)),
          const Spacer(),
          if (extra != null)
            Text(extra,
                style: TextStyle(
                    fontSize: 10, color: AppColors.textSubtle)),
        ],
      ),
    );
  }

  InputDecoration _deco(String hint, {IconData? icon, int? maxLength}) {
    OutlineInputBorder borde(Color color, [double width = 1]) =>
        OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textSubtle),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18, color: AppColors.textMuted),
      counterText: maxLength == null ? null : '',
      isDense: true,
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: borde(AppColors.hairline),
      enabledBorder: borde(AppColors.hairline),
      focusedBorder: borde(AppColors.celesteDark, 1.4),
    );
  }
}
