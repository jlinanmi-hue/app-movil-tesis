import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/widgets/erp_ui.dart';
import '../../core/widgets/notification_bell_widget.dart';
import '../../core/widgets/valencia_bot_icon.dart';
import '../ai_chat/ai_chat_screen.dart';
import 'erp_operaciones.dart';
import 'kardex_tab.dart';
import 'productos_catalogo_tab.dart';

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
      description: 'Pedidos de clientes, despacho e historial',
    ),
    _OperacionTabItem(
      label: 'Compras',
      icon: Icons.request_page_rounded,
      description: 'Órdenes de compra, recepción e historial',
    ),
    _OperacionTabItem(
      label: 'Stock y Productos',
      icon: Icons.inventory_2_rounded,
      description: 'Catálogo y stock de productos',
    ),
    _OperacionTabItem(
      label: 'Kardex',
      icon: Icons.receipt_outlined,
      description: 'Movimientos de almacén',
    ),
    _OperacionTabItem(
      label: 'Ajustes',
      icon: Icons.handyman_outlined,
      description: 'Ajustes de inventario y mermas',
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
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          // ÚNICA cabecera del hub: degradado celeste de marca + segmentos.
          ErpHeader(
            title: 'Operaciones ERP',
            subtitle: _tabs[_tabController.index].description,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    AiChatScreen.show(context);
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.celesteBg),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ValenciaBotIcon(
                          size: 16,
                          headColor: AppColors.celesteDark,
                          visorColor: AppColors.textDark,
                          eyeColor: AppColors.celeste,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Asistente IA',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.celesteDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const NotificationBellWidget(size: 18),
            ],
            bottom: ErpSegmentedTabs(
              controller: _tabController,
              tabs: [
                for (final t in _tabs) ErpTabSpec(t.label, icon: t.icon),
              ],
            ),
          ),
          // Cada pestaña es una interfaz directa, SIN sub-cabeceras apiladas.
          // Pedidos y Compras agrupan su propio flujo en vistas anidadas.
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                PedidosDespachoView(),
                ComprasRecepcionView(),
                ProductosTab(),
                KardexTab(),
                AjustesTab(),
                ClientesScreen(incrustado: true),
                ProveedoresScreen(incrustado: true),
              ],
            ),
          ),
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
