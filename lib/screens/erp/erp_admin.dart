import 'package:flutter/material.dart';
import '../../core/services/modules_service.dart';
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
      heroLabel: 'Colaboradores',
      heroValue: '24',
      heroCaption: '18 activos • 2 vacaciones',
      heroIcon: Icons.badge_outlined,
      kpis: const [],
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
  const CatalogosHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Color(0xFF0096C7))),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Gestión de Catálogos',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3642))),
                          Text('Tablas auxiliares del sistema',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF4A7C8E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const TabBar(
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF4A7C8E),
                indicator: BoxDecoration(color: Color(0xFF0096C7)),
                tabs: [
                  Tab(text: 'Categorías'),
                  Tab(text: 'Canales'),
                  Tab(text: 'Ubicaciones'),
                  Tab(text: 'Unidades'),
                ],
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
      title: widget.title,
      subtitle: 'Crear, editar y cambiar estado',
      heroLabel: widget.title,
      heroValue: '•',
      heroCaption: 'CRUD completo habilitado',
      heroIcon: widget.icon,
      kpis: const [],
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
  const SeguridadHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (Navigator.canPop(context))
                      IconButton(
                          onPressed: () => Navigator.maybePop(context),
                          icon: const Icon(Icons.arrow_back_rounded,
                              color: Color(0xFF0096C7))),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Roles y Seguridad',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3642))),
                          Text('Roles de usuario y cargos',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF4A7C8E))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Color(0xFF4A7C8E),
                indicator: BoxDecoration(color: Color(0xFF0096C7)),
                tabs: [Tab(text: 'Roles'), Tab(text: 'Cargos')],
              ),
              const Expanded(
                child: TabBarView(
                  children: [_RolesTab(), _CargosTab()],
                ),
              ),
            ],
          ),
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
      title: 'Roles de Usuario',
      subtitle: 'Permisos del sistema',
      heroLabel: 'Roles',
      heroValue: '3',
      heroCaption: 'CRUD inline como en web',
      heroIcon: Icons.key_outlined,
      kpis: const [],
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
      title: 'Cargos de Personal',
      subtitle: 'Puestos y funciones',
      heroLabel: 'Cargos',
      heroValue: '3',
      heroCaption: 'CRUD inline como en web',
      heroIcon: Icons.work_outline_rounded,
      kpis: const [],
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (Navigator.canPop(context))
                    IconButton(
                        onPressed: () => Navigator.maybePop(context),
                        icon: const Icon(Icons.arrow_back_rounded,
                            color: Color(0xFF0096C7))),
                  const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Datos de la Empresa',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3642))),
                          Text('Comercial Valencia • RUC oficial',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF4A7C8E))),
                        ]),
                  ),
                  IconButton(
                    onPressed: _loading
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
                              onSave: (d) =>
                                  _svc.actualizarEmpresa(d),
                              onSaved: () {
                                _load();
                                _snack(context,
                                    'Empresa actualizada.');
                              },
                            ),
                    icon: const Icon(Icons.edit_outlined,
                        color: Color(0xFF0096C7)),
                  ),
                ],
              ),
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
      ),
    );
  }

  Widget _row(String k, String v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCAF0F8)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF4A7C8E))),
          Flexible(
              child: Text(v,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0A3642)))),
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
