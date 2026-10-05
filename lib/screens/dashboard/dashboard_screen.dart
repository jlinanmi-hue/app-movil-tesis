import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/session_service.dart';
import '../erp/erp_operaciones.dart';
import '../erp/erp_admin.dart';

/// HOME - Comercial Valencia (solo CELESTE + BLANCO)
/// Bienvenida + nombre usuario + 2 carruseles (Operaciones / Administración)
class DashboardScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const DashboardScreen({super.key, this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _go(int index) {
    HapticFeedback.selectionClick();
    widget.onNavigate?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SessionService.currentUserNotifier,
      builder: (context, userObj, child) {
        final user = SessionService.currentUser;
        final nombre = user?.nombreCompleto ?? 'Colaborador Valencia';
        final cargo = user?.cargo ?? 'Personal Autorizado';
        final inicial = nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : 'C';

        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hPad = constraints.maxWidth >= 600 ? 24.0 : 16.0;
                return RefreshIndicator(
                  color: AppColors.celeste,
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 600));
                    if (mounted) setState(() {});
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        // ============ HEADER + QUICK ACTIONS SOLAPADO ============
                        Stack(
                          children: [
                            Column(
                              children: [
                                _buildHeader(context, nombre, cargo, inicial),
                                const SizedBox(height: 44),
                              ],
                            ),
                            Positioned(
                              left: hPad,
                              right: hPad,
                              bottom: 0,
                              child: _buildQuickActions(context),
                            ),
                          ],
                        ),

                        // ============ CONTENIDO ============
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                              hPad, 14, hPad, 110),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Si hay búsqueda en vivo activa desde el header, mostrar resultados y atajos
                              if (_searchQuery.isNotEmpty) ...[
                                _buildLiveSearchResults(context),
                                const SizedBox(height: 20),
                              ],

                              _buildWelcomeBanner(context),
                              const SizedBox(height: 22),

                              _buildSectionTitle(
                                title: 'Operaciones',
                                subtitle: 'Órdenes, compras e inventario',
                                onSeeAll: () => _go(1),
                              ),
                              const SizedBox(height: 10),
                              _buildOperationsCarousel(context),
                              const SizedBox(height: 22),

                              _buildSectionTitle(
                                title: 'Métricas de Tesis',
                                subtitle: 'PODE, PEOR, PRS y TBPP en vivo',
                                onSeeAll: () => _go(2),
                              ),
                              const SizedBox(height: 10),
                              _buildKpiMetricsPreview(context),
                              const SizedBox(height: 22),

                              _buildSectionTitle(
                                title: 'Administración',
                                subtitle: 'Catálogos, personal y seguridad',
                                onSeeAll: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const CatalogosHubScreen(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              _buildAdminCarousel(context),
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
  Widget _buildHeader(
      BuildContext context, String nombre, String cargo, String inicial) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        18,
        MediaQuery.of(context).padding.top + 14,
        18,
        74,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.celeste, AppColors.celesteDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
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
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.6), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  inicial,
                  style: const TextStyle(
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
                    Text(
                      'Bienvenido',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
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
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35)),
                ),
                child: IconButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sin notificaciones pendientes.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(Icons.notifications_outlined,
                      color: Colors.white, size: 20),
                  tooltip: 'Notificaciones',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'IA generativa • En vivo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Comercial Valencia',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Buscador Global en Vivo
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() => _searchQuery = val.trim());
              },
              decoration: InputDecoration(
                hintText: 'Buscar órdenes, inventario, clientes...',
                hintStyle: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSubtle,
                ),
                prefixIcon: const Icon(
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
                        icon: const Icon(
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

  // ---------------- ACCIONES RÁPIDAS ----------------
  Widget _buildQuickActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.celesteBg),
        boxShadow: [
          BoxShadow(
            color: AppColors.celesteDark.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _quickItem(Icons.assignment_outlined, 'Órdenes', () => _go(1)),
          _quickItem(Icons.inventory_2_outlined, 'Inventario', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const InventarioHubScreen()));
          }),
          _quickItem(Icons.business_outlined, 'Proveed.', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ProveedoresScreen()));
          }),
          _quickItem(Icons.groups_outlined, 'Clientes', () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ClientesScreen()));
          }),
        ],
      ),
    );
  }

  Widget _quickItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.celesteTint,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: AppColors.celesteDark, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- BANNER BIENVENIDA ----------------
  Widget _buildWelcomeBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.celeste, AppColors.celesteDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.celeste.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Optimiza tu día con IA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Consulta stock, pedidos e indicadores en lenguaje natural.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _go(2),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Preguntar a Valencia AI',
                          style: TextStyle(
                            color: AppColors.celesteDark,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_rounded,
                            size: 15, color: AppColors.celesteDark),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.storefront_outlined,
                color: Colors.white, size: 36),
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
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.celesteBg, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.celesteDark, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Atajos directos para "$_searchQuery"',
                  style: const TextStyle(
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
                icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
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
                    color: Colors.white,
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
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            Text(
                              item['sub'] as String,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.celesteDark),
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

  // ---------------- RESUMEN VISUAL DE MÉTRICAS DE TESIS ----------------
  Widget _buildKpiMetricsPreview(BuildContext context) {
    final kpis = [
      {'code': 'PODE', 'name': 'Despacho', 'target': '≥ 95%', 'status': 'Cumple'},
      {'code': 'PEOR', 'name': 'Tasa Error', 'target': '≤ 3%', 'status': 'Óptimo'},
      {'code': 'PRS', 'name': 'Rotura Stock', 'target': '≤ 5%', 'status': 'Bajo'},
      {'code': 'TBPP', 'name': 'Picking IA', 'target': '≤ 10s', 'status': 'Rápido'},
    ];

    return InkWell(
      onTap: () => _go(2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.celesteBg),
          boxShadow: [
            BoxShadow(
              color: AppColors.celesteDark.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 18, color: AppColors.celesteDark),
                    SizedBox(width: 8),
                    Text(
                      'Objetivos de Investigación de Tesis',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () => _go(2),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ver detalle',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.celesteDark)),
                      SizedBox(width: 2),
                      Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.celesteDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: kpis.map((k) {
                return Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: AppColors.celesteTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          k['code']!,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.celesteDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          k['target']!,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                          ),
                          child: Text(
                            k['status']!,
                            style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- TÍTULOS DE SECCIÓN ----------------
  Widget _buildSectionTitle({
    required String title,
    required String subtitle,
    required VoidCallback onSeeAll,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(
                  fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
        TextButton(
          onPressed: onSeeAll,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Ver todo',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.celesteDark,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------- CARRUSEL OPERACIONES (solo 4) ----------------
  Widget _buildOperationsCarousel(BuildContext context) {
    void push(Widget s) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    }

    final items = [
      _HomeCardData(
        icon: Icons.assignment_outlined,
        title: 'Control Órdenes',
        subtitle: 'Pedidos, compra y recepción',
        onTap: () => push(const OrdenesHubScreen()),
      ),
      _HomeCardData(
        icon: Icons.inventory_2_outlined,
        title: 'Control Inventario',
        subtitle: 'Stock, Kardex y ajustes',
        onTap: () => push(const InventarioHubScreen()),
      ),
      _HomeCardData(
        icon: Icons.business_outlined,
        title: 'Proveedores',
        subtitle: 'Gestión abastecimiento',
        onTap: () => push(const ProveedoresScreen()),
      ),
      _HomeCardData(
        icon: Icons.groups_outlined,
        title: 'Clientes',
        subtitle: 'Directorio comercial',
        onTap: () => push(const ClientesScreen()),
      ),
    ];

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          return _buildCarouselCard(it, isFirst: i == 0);
        },
      ),
    );
  }

  // ---------------- CARRUSEL ADMINISTRACIÓN (solo 3) ----------------
  Widget _buildAdminCarousel(BuildContext context) {
    void push(Widget s) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    }

    final items = [
      _HomeCardData(
        icon: Icons.badge_outlined,
        title: 'Personal',
        subtitle: 'Gestión de personal',
        onTap: () => push(const PersonalScreen()),
      ),
      _HomeCardData(
        icon: Icons.folder_outlined,
        title: 'Catálogos',
        subtitle: 'Gestión de catálogos',
        onTap: () => push(const CatalogosHubScreen()),
      ),
      _HomeCardData(
        icon: Icons.lock_outline_rounded,
        title: 'Seguridad',
        subtitle: 'Roles y seguridad',
        onTap: () => push(const SeguridadHubScreen()),
      ),
    ];

    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, index) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final it = items[i];
          return _buildCarouselCard(it, isFirst: i == 0);
        },
      ),
    );
  }

  // ---------------- CARD DE CARRUSEL (imagen ref) ----------------
  Widget _buildCarouselCard(_HomeCardData data, {bool isFirst = false}) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 152,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFirst ? AppColors.celeste : AppColors.celesteBg,
            width: isFirst ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.celesteDark.withValues(
                  alpha: isFirst ? 0.12 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isFirst
                    ? AppColors.celeste
                    : AppColors.celesteTint,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                color: isFirst ? Colors.white : AppColors.celesteDark,
                size: 22,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Abrir',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.celesteDark,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded,
                        size: 14, color: AppColors.celesteDark),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCardData {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _HomeCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
