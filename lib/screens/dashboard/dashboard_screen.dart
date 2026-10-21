import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/api_service.dart';
import '../../core/services/session_service.dart';
import '../../core/widgets/erp_ui.dart';
import '../../core/widgets/notification_bell_widget.dart';
import '../../models/resumen_jornada_model.dart';
import '../erp/erp_operaciones.dart';
import '../erp/erp_admin.dart';
import 'widgets/resumen_jornada_widget.dart';

/// HOME - Comercial Valencia (solo CELESTE + BLANCO)
/// Bienvenida + buscador global y accesos organizados en tarjetas:
/// "Módulos" (operaciones) y "Administración", sin duplicar el hub.
class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  ResumenJornadaModel _resumen = ResumenJornadaModel.fallback();

  @override
  void initState() {
    super.initState();
    _loadResumen();
  }

  Future<void> _loadResumen() async {
    try {
      final res = await ApiService().getResumenJornada();
      if (mounted) {
        setState(() => _resumen = res);
      }
    } catch (_) {}
  }

  String get _currentDateText {
    final now = DateTime.now();
    const meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Set', 'Oct', 'Nov', 'Dic'
    ];
    return '${now.day} ${meses[now.month - 1]}';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _go(int index) {
    HapticFeedback.selectionClick();
    widget.onNavigate?.call(index);
  }

  void _push(Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SessionService.currentUserNotifier,
      builder: (context, userObj, child) {
        final user = SessionService.currentUser;
        final nombre = user?.nombreCompleto ?? 'Colaborador Valencia';
        final cargo = user?.cargo ?? 'Personal Autorizado';
        final inicial =
            nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : 'C';

        return Scaffold(
          backgroundColor: AppColors.backgroundLight,
          body: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hPad = constraints.maxWidth >= 600 ? 24.0 : 16.0;
                final wide = constraints.maxWidth >= 600;
                return RefreshIndicator(
                  color: AppColors.celeste,
                  onRefresh: () async {
                    await Future.wait([
                      _loadResumen(),
                      Future.delayed(const Duration(milliseconds: 500)),
                    ]);
                    if (mounted) setState(() {});
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(context, nombre, cargo, inicial, hPad),
                        Padding(
                          padding: EdgeInsets.fromLTRB(hPad, 16, hPad, 110),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_searchQuery.isNotEmpty) ...[
                                _buildLiveSearchResults(context),
                                const SizedBox(height: 18),
                              ],
                              ResumenJornadaWidget(
                                data: _resumen,
                                wide: wide,
                                onRefresh: _loadResumen,
                              ),
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                title: 'Módulos',
                                subtitle: 'Accesos directos a tus operaciones',
                              ),
                              const SizedBox(height: 10),
                              _buildModulesGrid(wide),
                              const SizedBox(height: 20),
                              _buildSectionTitle(
                                title: 'Administración',
                                subtitle: 'Personal, catálogos y seguridad',
                              ),
                              const SizedBox(height: 10),
                              _buildAdminCard(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ---------------- HEADER CELESTE ----------------
  Widget _buildHeader(BuildContext context, String nombre, String cargo,
      String inicial, double hPad) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        hPad,
        MediaQuery.of(context).padding.top + 14,
        hPad,
        18,
      ),
      decoration: BoxDecoration(
        color: AppColors.headerSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.celesteDeep, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: TextStyle(
                    color: AppColors.celesteDark,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Bienvenido',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 3.5,
                          height: 3.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentDateText,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      cargo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const NotificationBellWidget(),
            ],
          ),
          const SizedBox(height: 14),
          // Buscador Global en Vivo
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
              decoration: InputDecoration(
                hintText: 'Buscar órdenes, inventario, clientes...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSubtle,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.celesteDark,
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- RESULTADOS DE BÚSQUEDA EN VIVO ----------------
  Widget _buildLiveSearchResults(BuildContext context) {
    void push(Widget s) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    }

    final query = _searchQuery.toLowerCase();
    final shortcuts = <Map<String, dynamic>>[];

    if ('órdenes pedidos venta compras'.contains(query) || query.isNotEmpty) {
      shortcuts.add({
        'title': 'Buscar "$_searchQuery" en Pedidos',
        'sub': 'Ir al módulo de Órdenes y Pedidos',
        'icon': Icons.receipt_long_rounded,
        'action': () => _go(1),
      });
    }
    if ('inventario stock kardex productos almacén'.contains(query) || query.isNotEmpty) {
      shortcuts.add({
        'title': 'Buscar "$_searchQuery" en Inventario',
        'sub': 'Stock de productos, Kárdex y ajustes',
        'icon': Icons.inventory_2_rounded,
        'action': () => push(const InventarioHubScreen()),
      });
    }
    if ('clientes directorio ventas compradores'.contains(query) || query.isNotEmpty) {
      shortcuts.add({
        'title': 'Buscar "$_searchQuery" en Clientes',
        'sub': 'Directorio comercial y compradores',
        'icon': Icons.groups_rounded,
        'action': () => push(const ClientesScreen()),
      });
    }
    if ('proveedores abastecimiento compras'.contains(query) || query.isNotEmpty) {
      shortcuts.add({
        'title': 'Buscar "$_searchQuery" en Proveedores',
        'sub': 'Abastecimiento y órdenes de compra',
        'icon': Icons.local_shipping_rounded,
        'action': () => push(const ProveedoresScreen()),
      });
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.celesteTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.celesteBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: AppColors.celesteDark, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Atajos directos para "$_searchQuery"',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...shortcuts.take(3).map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: item['action'] as VoidCallback,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.celesteBg),
                  ),
                  child: Row(
                    children: [
                      Icon(item['icon'] as IconData, size: 18, color: AppColors.celesteDark),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              item['sub'] as String,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.celesteDark),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------- MÓDULOS: tarjetas directas ----------------
  Widget _buildModulesGrid(bool wide) {
    final modulos = <_HomeModule>[
      _HomeModule(
        icon: Icons.receipt_long_outlined,
        label: 'Pedidos',
        subtitle: 'Pedidos y despacho',
        onTap: () => _push(const PedidosHubScreen(initialIndex: 0)),
      ),
      _HomeModule(
        icon: Icons.shopping_bag_outlined,
        label: 'Compras',
        subtitle: 'Órdenes de compra',
        onTap: () => _push(const ComprasHubScreen(initialIndex: 0)),
      ),
      _HomeModule(
        icon: Icons.inventory_2_outlined,
        label: 'Stock y Productos',
        subtitle: 'Catálogo y existencias',
        onTap: () => _push(const InventarioHubScreen(initialIndex: 0)),
      ),
      _HomeModule(
        icon: Icons.groups_outlined,
        label: 'Clientes',
        subtitle: 'Directorio comercial',
        onTap: () => _push(const ClientesScreen()),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 116,
      ),
      itemCount: modulos.length,
      itemBuilder: (_, i) => _moduleCard(modulos[i]),
    );
  }

  Widget _moduleCard(_HomeModule m) {
    return InkWell(
      onTap: m.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ErpIconTile(icon: m.icon, size: 40, radius: 13),
                const Spacer(),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textSubtle),
              ],
            ),
            const Spacer(),
            Text(
              m.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              m.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- ADMINISTRACIÓN: una sola tarjeta con filas ----------------
  Widget _buildAdminCard() {
    return ErpSoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _adminTile(
            icon: Icons.badge_outlined,
            title: 'Personal',
            subtitle: 'Colaboradores y accesos',
            onTap: () => _push(const PersonalScreen()),
          ),
          Divider(
              height: 1, thickness: 1, indent: 64, color: AppColors.hairline),
          _adminTile(
            icon: Icons.folder_outlined,
            title: 'Catálogos',
            subtitle: 'Categorías, canales, ubicaciones y unidades',
            onTap: () => _push(const CatalogosHubScreen()),
          ),
          Divider(
              height: 1, thickness: 1, indent: 64, color: AppColors.hairline),
          _adminTile(
            icon: Icons.verified_user_outlined,
            title: 'Seguridad',
            subtitle: 'Roles y cargos',
            onTap: () => _push(const SeguridadHubScreen()),
          ),
        ],
      ),
    );
  }

  Widget _adminTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ErpIconTile(icon: icon, size: 38, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textSubtle),
          ],
        ),
      ),
    );
  }

  // ---------------- TÍTULOS DE SECCIÓN ----------------
  Widget _buildSectionTitle({required String title, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barra de acento: sello visual del sistema (estilo mate/editorial).
        Container(
          margin: const EdgeInsets.only(top: 2, right: 9),
          width: 4,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.celesteDeep,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                    fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeModule {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeModule({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}
