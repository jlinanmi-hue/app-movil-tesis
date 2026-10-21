import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';
import '../erp/erp_list_screen.dart';
import 'erp_form.dart';

// ===================================================================
// ADMINISTRACIÓN (solo 3): Personal, Catálogos, Roles y Seguridad
// Contenedores del web habilitados: guardar / editar / eliminar /
// restaurar + tablas. Celeste+blanco, SafeArea + LayoutBuilder.
// ===================================================================

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating));
}

Map<String, String> _rawInitial(ErpItem e, List<ErpField> fields) {
  final out = <String, String>{};
  for (final f in fields) {
    final v = e.raw[f.key];
    if (v == null) continue;
    if (v is Map || v is List) continue;
    final s = '$v'.trim();
    if (s.isEmpty || s == '—' || s == 'null') continue;
    out[f.key] = s;
  }
  return out;
}

// ---------------- 1. GESTIÓN DE PERSONAL ----------------
class PersonalScreen extends StatefulWidget {
  const PersonalScreen({super.key});
  @override
  State<PersonalScreen> createState() => _PersonalScreenState();
}

class _PersonalScreenState extends State<PersonalScreen> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Gestión de Personal',
      subtitle: 'Directorio y registro',
      tabs: const ['Activos', 'Vacaciones', 'Licencias', 'Eliminados'],
      loader: (s, t) => _svc.personal(search: s, tab: t),
      rowIcon: Icons.person_outline_rounded,
      searchHint: 'Buscar por nombre o DNI...',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar colaborador',
        fields: ErpForms.personal(),
        onSave: (d) => _svc.crear('/personal', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Personal registrado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar colaborador',
        fields: ErpForms.personal(),
        initial: _rawInitial(e, ErpForms.personal()),
        onSave: (d) => _svc.actualizar('/personal', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Personal actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/personal', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Registro eliminado.');
      },
    );
  }
}

// ---------------- 2. GESTIÓN DE CATÁLOGOS ----------------
class CatalogosHubScreen extends StatelessWidget {
  /// Pestaña inicial: 0 Categorías · 1 Canales · 2 Ubicaciones · 3 Unidades.
  final int initialIndex;

  const CatalogosHubScreen({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex.clamp(0, 3),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        // UNA sola cabecera para todo el hub (pestañas segmentadas).
        body: Column(
          children: [
            ErpHeader(
              title: 'Gestión de Catálogos',
              subtitle: 'Tablas auxiliares del sistema',
              bottom: const ErpSegmentedTabs(
                tabs: [
                  ErpTabSpec('Categorías', icon: Icons.folder_outlined),
                  ErpTabSpec('Canales', icon: Icons.share_outlined),
                  ErpTabSpec('Ubicaciones', icon: Icons.place_outlined),
                  ErpTabSpec('Unidades', icon: Icons.scale_outlined),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _CatalogoTab(
                      title: 'Categorías de Productos',
                      endpoint: '/categorias',
                      icon: Icons.folder_outlined),
                  _CatalogoTab(
                      title: 'Canales de Pedido',
                      endpoint: '/canales-pedido',
                      icon: Icons.share_outlined),
                  _CatalogoTab(
                      title: 'Ubicaciones',
                      endpoint: '/ubicaciones',
                      icon: Icons.place_outlined),
                  _CatalogoTab(
                      title: 'Unidades de Medida',
                      endpoint: '/unidades-medida',
                      icon: Icons.scale_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogoTab extends StatefulWidget {
  final String title;
  final String endpoint;
  final IconData icon;
  const _CatalogoTab(
      {required this.title, required this.endpoint, required this.icon});
  @override
  State<_CatalogoTab> createState() => _CatalogoTabState();
}

class _CatalogoTabState extends State<_CatalogoTab> {
  int _r = 0;
  final _svc = ModulesService();

  Future<List<ErpItem>> _loader(String s, String t) {
    if (widget.endpoint.contains('categor')) {
      return _svc.categorias(search: s, tab: t);
    }
    if (widget.endpoint.contains('canal')) {
      return _svc.canales(search: s);
    }
    if (widget.endpoint.contains('ubicacion')) {
      return _svc.ubicaciones(search: s);
    }
    return _svc.unidades(search: s);
  }

  List<ErpField> _fields() {
    if (widget.endpoint.contains('categor')) return ErpForms.categoria();
    if (widget.endpoint.contains('canal')) return ErpForms.canal();
    if (widget.endpoint.contains('ubicacion')) return ErpForms.ubicacion();
    return ErpForms.unidad();
  }

  Map<String, String> _initial(ErpItem e) {
    final m = e.raw;
    final out = <String, String>{};
    for (final f in _fields()) {
      if (m[f.key] != null) out[f.key] = '${m[f.key]}';
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey('$_r${widget.endpoint}'),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: widget.title,
      subtitle: 'Crear, editar y cambiar estado',
      tabs: const ['Todos'],
      loader: (s, t) => _loader(s, t),
      rowIcon: widget.icon,
      searchHint: 'Buscar en ${widget.title}...',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar en ${widget.title}',
        fields: _fields(),
        onSave: (d) => _svc.crear(widget.endpoint, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Registro guardado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar registro',
        fields: _fields(),
        initial: _initial(e),
        onSave: (d) => _svc.actualizar(widget.endpoint, e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Registro actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar(widget.endpoint, e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Registro eliminado.');
      },
    );
  }
}

// ---------------- 3. ROLES Y SEGURIDAD ----------------
class SeguridadHubScreen extends StatelessWidget {
  /// Pestaña inicial: 0 Roles · 1 Cargos.
  final int initialIndex;

  const SeguridadHubScreen({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex.clamp(0, 1),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        // UNA sola cabecera para todo el hub (pestañas segmentadas).
        body: Column(
          children: [
            ErpHeader(
              title: 'Roles y Seguridad',
              subtitle: 'Roles de usuario y cargos',
              bottom: const ErpSegmentedTabs(
                tabs: [
                  ErpTabSpec('Roles', icon: Icons.key_outlined),
                  ErpTabSpec('Cargos', icon: Icons.badge_outlined),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [_RolesTab(), _CargosTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RolesTab extends StatefulWidget {
  const _RolesTab();
  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: 'Roles de Usuario',
      subtitle: 'Permisos del sistema',
      tabs: const ['Todos'],
      loader: (s, t) => _svc.roles(search: s),
      rowIcon: Icons.key_outlined,
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Crear rol',
        fields: ErpForms.rol(),
        onSave: (d) => _svc.crear('/seguridad/roles', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Rol creado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar rol',
        fields: ErpForms.rol(),
        initial: {
          'Rol_UserRol_Usercol': e.raw['Rol_UserRol_Usercol'] ?? e.titulo,
          'Rol_UserEmpleadocol': '${e.raw['Rol_UserEmpleadocol'] ?? ''}',
        },
        onSave: (d) => _svc.actualizar('/seguridad/roles', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Rol actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/seguridad/roles', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Rol eliminado.');
      },
    );
  }
}

class _CargosTab extends StatefulWidget {
  const _CargosTab();
  @override
  State<_CargosTab> createState() => _CargosTabState();
}

class _CargosTabState extends State<_CargosTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: 'Cargos de Personal',
      subtitle: 'Puestos y funciones',
      tabs: const ['Todos'],
      loader: (s, t) => _svc.cargos(search: s),
      rowIcon: Icons.work_outline_rounded,
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Crear cargo',
        fields: ErpForms.cargo(),
        onSave: (d) => _svc.crear('/seguridad/cargos', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Cargo creado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar cargo',
        fields: ErpForms.cargo(),
        initial: {
          'cargoDescripcion': e.raw['cargoDescripcion'] ?? e.titulo,
          'cargoEstado': '${e.raw['cargoEstado'] ?? 'A'}',
        },
        onSave: (d) => _svc.actualizar('/seguridad/cargos', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Cargo actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/seguridad/cargos', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Cargo eliminado.');
      },
    );
  }
}

class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({super.key});
  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  final _svc = ModulesService();
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _data = await _svc.obtenerEmpresa();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          ErpHeader(
            title: 'Datos de la Empresa',
            subtitle: 'Comercial Valencia • RUC oficial',
            actions: [
              ErpCircleButton(
                icon: Icons.edit_outlined,
                tooltip: 'Editar empresa',
                onTap: _loading
                    ? null
                    : () => ErpFormSheet.show(
                          context,
                          title: 'Editar empresa',
                          fields: [
                            ErpField(
                                key: 'EmpresaRuc',
                                label: 'RUC (11 dígitos)'),
                            ErpField(
                                key: 'EmpresaRazonSocial',
                                label: 'Razón social'),
                            ErpField(
                                key: 'EmpresaNombreComercial',
                                label: 'Nombre comercial'),
                            ErpField(
                                key: 'EmpresaDireccion',
                                label: 'Dirección'),
                            ErpField(
                                key: 'EmpresaTelefono',
                                label: 'Teléfono'),
                            ErpField(
                                key: 'EmpresaEmail',
                                label: 'Email'),
                          ],
                          initial: (_data ?? {}).map((k, v) =>
                              MapEntry(k.toString(), '${v ?? ''}')),
                          onSave: (d) => _svc.actualizarEmpresa(d),
                          onSaved: () {
                            _load();
                            _snack(context, 'Empresa actualizada.');
                          },
                        ),
              ),
            ],
          ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF00B4D8)))
                  : RefreshIndicator(
                      color: const Color(0xFF00B4D8),
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            _row('RUC',
                                '${_data?['EmpresaRuc'] ?? '—'}'),
                            _row('Razón social',
                                '${_data?['EmpresaRazonSocial'] ?? '—'}'),
                            _row('Nombre comercial',
                                '${_data?['EmpresaNombreComercial'] ?? '—'}'),
                            _row('Dirección',
                                '${_data?['EmpresaDireccion'] ?? '—'}'),
                            _row('Ubigeo',
                                '${_data?['EmpresaUbigeo'] ?? '—'}'),
                            _row('Teléfono',
                                '${_data?['EmpresaTelefono'] ?? '—'}'),
                            _row('WhatsApp',
                                '${_data?['EmpresaWhatsapp'] ?? '—'}'),
                            _row('Email',
                                '${_data?['EmpresaEmail'] ?? '—'}'),
                            _row('Ticket',
                                '${_data?['EmpresaMensajeTicket'] ?? '—'}'),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
    );
  }

  Widget _row(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark))),
        ],
      ),
    );
  }
}

class ErpSimpleScreenAlias extends StatelessWidget {
  const ErpSimpleScreenAlias({super.key});
  @override
  Widget build(BuildContext context) {
    return const EmpresaScreen();
  }
}
