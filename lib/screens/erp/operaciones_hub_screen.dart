import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../ai_chat/ai_chat_screen.dart';
import 'erp_operaciones.dart';

/// HUB CENTRAL DE OPERACIONES ERP (Comercial Valencia)
/// Unifica Pedidos, Inventario, Clientes, Proveedores y Compras
/// con navegación fluida, buscador en vivo y acceso rápido a IA.
class OperacionesHubScreen extends StatefulWidget {
  final int initialTabIndex;

  const OperacionesHubScreen({super.key, this.initialTabIndex = 0});

  @override
  State<OperacionesHubScreen> createState() => _OperacionesHubScreenState();
}

class _OperacionesHubScreenState extends State<OperacionesHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<_OperacionTabItem> _tabs = const [
    _OperacionTabItem(
      label: 'Pedidos',
      icon: Icons.receipt_long_rounded,
      description: 'Órdenes de clientes y flujo comercial',
    ),
    _OperacionTabItem(
      label: 'Inventario',
      icon: Icons.inventory_2_rounded,
      description: 'Stock, Kárdex y ajustes de almacén',
    ),
    _OperacionTabItem(
      label: 'Clientes',
      icon: Icons.groups_rounded,
      description: 'Directorio y fidelización de clientes',
    ),
    _OperacionTabItem(
      label: 'Proveedores',
      icon: Icons.local_shipping_rounded,
      description: 'Abastecimiento y cumplimiento',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, _tabs.length - 1),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: AppColors.celesteBg.withValues(alpha: 0.5),
        titleSpacing: 16,
        leading: Navigator.canPop(context)
            ? IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.celesteDark),
              )
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Operaciones ERP',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              _tabs[_tabController.index].description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Botón directo a Valencia AI
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                AiChatScreen.show(context);
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.celesteTint, Color(0xFFE0F7FA)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.celesteBg),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValenciaBotIcon(
                      size: 18,
                      headColor: AppColors.celesteDark,
                      visorColor: AppColors.textDark,
                      eyeColor: AppColors.celeste,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Asistente IA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.celesteDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            height: 48,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.celesteBg, width: 1),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              indicatorColor: AppColors.celesteDark,
              indicatorPadding: const EdgeInsets.only(bottom: 2),
              labelColor: AppColors.celesteDark,
              unselectedLabelColor: AppColors.textMuted,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              tabs: _tabs.map((tab) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(tab.icon, size: 16),
                      const SizedBox(width: 6),
                      Text(tab.label),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          OrdenesHubScreen(),
          InventarioHubScreen(),
          ClientesScreen(),
          ProveedoresScreen(),
        ],
      ),
    );
  }
}

class _OperacionTabItem {
  final String label;
  final IconData icon;
  final String description;

  const _OperacionTabItem({
    required this.label,
    required this.icon,
    required this.description,
  });
}
