import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/exceptions/api_exception.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';

/// REGISTRAR / EDITAR PROVEEDOR
/// Interfaz propia con contenedores por sección (estilo del web):
/// · Documento tributario → campo RUC con botón de búsqueda SUNAT que
///   autocompleta razón social, tipo, actividad y estado.
/// · Datos tributarios (razón social, tipo contribuyente, actividad
///   económica con sugerencias rápidas).
/// · Contacto y estado comercial.
class NuevoProveedorScreen extends StatefulWidget {
  /// Cuando se envía, la pantalla entra en modo edición.
  final ErpItem? proveedor;

  const NuevoProveedorScreen({super.key, this.proveedor});

  @override
  State<NuevoProveedorScreen> createState() => _NuevoProveedorScreenState();
}

class _NuevoProveedorScreenState extends State<NuevoProveedorScreen> {
  final _svc = ModulesService();

  late final TextEditingController _ruc;
  late final TextEditingController _razon;
  late final TextEditingController _tipo;
  late final TextEditingController _actividad;
  late final TextEditingController _telefono;

  String _estado = 'A';
  bool _guardando = false;
  bool _consultando = false;
  String? _error;
  SunatConsulta? _sunat;

  /// Sugerencias rápidas de actividad económica (mismas del web).
  static const _sugerencias = <List<String>>[
    ['Restaurantes y Comidas', 'RESTAURANTES Y SERVICIOS DE COMIDAS'],
    ['Venta de Alimentos', 'VENTA AL POR MAYOR DE ALIMENTOS Y BEBIDAS'],
    ['Distribución Mayorista', 'VENTA AL POR MAYOR NO ESPECIALIZADA'],
    ['Transporte y Carga', 'TRANSPORTE DE CARGA POR CARRETERA'],
    ['Servicios Generales', 'SERVICIOS DE APOYO A EMPRESAS'],
  ];

  bool get _esEdicion => widget.proveedor != null;
  String get _doc => _ruc.text.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  void initState() {
    super.initState();
    final raw = widget.proveedor?.raw ?? const <String, dynamic>{};
    String v(String k) {
      final x = raw[k];
      if (x == null || x is Map || x is List) return '';
      final s = '$x'.trim();
      return (s == 'null' || s == '—') ? '' : s;
    }

    _ruc = TextEditingController(text: v('ProveedorRuc'));
    final razonRaw = v('ProveedorRazonSocial');
    _razon = TextEditingController(
        text: razonRaw.isNotEmpty
            ? razonRaw
            : (widget.proveedor?.titulo ?? ''));
    _tipo = TextEditingController(text: v('ProveedorTipoContribuyente'));
    _actividad = TextEditingController(text: v('ProveedorActividadEconomica'));
    _telefono = TextEditingController(text: v('ProveedorTelefono'));
    _estado = v('ProveedorEstado').toUpperCase() == 'I' ? 'I' : 'A';
  }

  @override
  void dispose() {
    _ruc.dispose();
    _razon.dispose();
    _tipo.dispose();
    _actividad.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg), behavior: SnackBarBehavior.floating));
  }

  // ---------------- Consulta SUNAT ----------------

  Future<void> _buscarSunat() async {
    final doc = _doc;
    if (doc.isEmpty) {
      setState(() => _error = 'Ingresa el RUC para consultar ante SUNAT.');
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
          await _svc.consultarDocumentoSunat(doc, target: 'proveedor');
      if (!mounted) return;
      setState(() {
        _consultando = false;
        _sunat = info;
        if (info.nombre.isNotEmpty) _razon.text = info.nombre;
        if (info.tipoContribuyente.isNotEmpty) {
          _tipo.text = info.tipoContribuyente;
        }
        if (info.actividadEconomica.isNotEmpty) {
          _actividad.text = info.actividadEconomica;
        }
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
        _error = 'No se encontró información para el RUC ingresado.';
      });
    }
  }

  // ---------------- Guardar ----------------

  Future<void> _guardar() async {
    final doc = _doc;
    if (doc.length != 8 && doc.length != 11) {
      setState(() =>
          _error = 'El RUC debe tener 11 dígitos (u 8 si es DNI).');
      return;
    }
    if (_razon.text.trim().isEmpty) {
      setState(() => _error = 'La razón social es obligatoria.');
      return;
    }
    final tel = _telefono.text.trim();
    if (tel.isNotEmpty && !RegExp(r'^[0-9+\s\-()]+$').hasMatch(tel)) {
      setState(() => _error = 'El teléfono solo debe contener números.');
      return;
    }
    if (_razon.text.trim().length > 45 ||
        _tipo.text.trim().length > 45 ||
        _actividad.text.trim().length > 45) {
      setState(() => _error = 'Los campos tributarios admiten máximo 45 caracteres.');
      return;
    }

    final data = <String, String>{
      'ProveedorRuc': doc,
      'ProveedorRazonSocial': _razon.text.trim(),
      if (_tipo.text.trim().isNotEmpty)
        'ProveedorTipoContribuyente': _tipo.text.trim(),
      if (_actividad.text.trim().isNotEmpty)
        'ProveedorActividadEconomica': _actividad.text.trim(),
      if (tel.isNotEmpty) 'ProveedorTelefono': tel,
      'ProveedorEstado': _estado,
    };

    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await _svc.guardarProveedor(data,
          id: _esEdicion ? widget.proveedor!.id : null);
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
        _error = 'No se pudo guardar el proveedor. Intenta nuevamente.';
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
            title: _esEdicion ? 'Editar Proveedor' : 'Nuevo Proveedor',
            subtitle: 'Abastecimiento · validación SUNAT',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                if (_error != null) _bannerError(),
                _seccionRuc(),
                _seccionTributaria(),
                _seccionContacto(),
                _seccionEstado(),
                const SizedBox(height: 2),
                ErpPrimaryButton(
                  label: _esEdicion ? 'Guardar cambios' : 'Registrar proveedor',
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

  // ---------------- RUC + SUNAT ----------------

  Widget _seccionRuc() {
    return _seccion(
      titulo: 'Documento tributario',
      icono: Icons.badge_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta('Número de RUC',
              obligatorio: true, extra: 'Consulta SUNAT'),
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
                  decoration: _deco('Ej: 20601234565 (11 dígitos)'),
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
        message: 'Buscar datos oficiales en SUNAT y autocompletar',
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
              info.actividadEconomica.isNotEmpty ||
              info.direccion.isNotEmpty) ...[
            const SizedBox(height: 8),
            if (info.tipoContribuyente.isNotEmpty)
              _dato('Tipo', info.tipoContribuyente),
            if (info.nombreComercial.isNotEmpty)
              _dato('Comercial', info.nombreComercial),
            if (info.direccion.isNotEmpty) _dato('Dirección', info.direccion),
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

  // ---------------- Datos tributarios ----------------

  Widget _seccionTributaria() {
    return _seccion(
      titulo: 'Datos tributarios',
      icono: Icons.business_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta('Razón social',
              obligatorio: true,
              extra: '${_razon.text.length} / 45',
              extraLimite: 45,
              largo: _razon.text.length),
          TextField(
            controller: _razon,
            maxLength: 45,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration: _deco('Ej: Distribuidora Alimentaria S.A.C.',
                maxLength: 45),
          ),
          const SizedBox(height: 10),
          _etiqueta('Tipo de contribuyente',
              extra: '${_tipo.text.length} / 45',
              extraLimite: 45,
              largo: _tipo.text.length),
          TextField(
            controller: _tipo,
            maxLength: 45,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration:
                _deco('Ej: SOCIEDAD ANONIMA CERRADA', maxLength: 45),
          ),
          const SizedBox(height: 10),
          _etiqueta('Actividad económica',
              extra: '${_actividad.text.length} / 45',
              extraLimite: 45,
              largo: _actividad.text.length),
          TextField(
            controller: _actividad,
            maxLength: 45,
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration: _deco('Ej: RESTAURANTES Y SERVICIOS DE COMIDAS',
                maxLength: 45),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 24,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _sugerencias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final s = _sugerencias[i];
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _actividad.text = s[1].length > 45
                          ? s[1].substring(0, 45)
                          : s[1];
                    });
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.celesteTint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.borderSoft),
                    ),
                    child: Center(
                      child: Text(s[0],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.celesteDeep)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- Contacto ----------------

  Widget _seccionContacto() {
    return _seccion(
      titulo: 'Contacto',
      icono: Icons.call_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta('Teléfono de contacto',
              extra: '${_telefono.text.length} / 45',
              extraLimite: 45,
              largo: _telefono.text.length),
          TextField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            maxLength: 45,
            onChanged: (_) => setState(() => _error = null),
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark),
            decoration: _deco('Ej: 013150800 o 987654321', maxLength: 45),
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
                ? 'Habilitado para compras y recepciones.'
                : 'Suspendido comercialmente.',
            style:
                TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ---------------- helpers de campos ----------------

  Widget _etiqueta(
    String texto, {
    bool obligatorio = false,
    String? extra,
    int? extraLimite,
    int? largo,
  }) {
    final excedido = extraLimite != null && largo != null && largo > extraLimite;
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
                    fontSize: 10,
                    fontWeight: excedido ? FontWeight.w800 : FontWeight.w400,
                    color: excedido
                        ? AppColors.errorDark
                        : AppColors.textSubtle)),
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
