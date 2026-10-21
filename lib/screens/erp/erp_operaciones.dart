import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/campus_card.dart';
import '../../core/widgets/erp_ui.dart';
import '../../models/erp_models.dart';
import '../erp/erp_list_screen.dart';
import 'despacho_tab.dart';
import 'erp_form.dart';
import 'erp_history_screen.dart';
import 'kardex_tab.dart';
import 'nueva_compra_screen.dart';
import 'nuevo_cliente_screen.dart';
import 'nuevo_pedido_screen.dart';
import 'nuevo_proveedor_screen.dart';
import 'pedido_detalle_dialog.dart';
import 'productos_catalogo_tab.dart';
import 'recepcion_tab.dart';

// ===================================================================
// OPERACIONES (solo 4): Órdenes, Inventario, Proveedores, Clientes
// Cada uno con contenedores del web: registrar / editar / eliminar /
// historial en tabla. Estilo Campus Cash celeste+blanco, responsive.
// ===================================================================

void _snack(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), behavior: SnackBarBehavior.floating));
}

// ---------------- 1. GESTIÓN CLIENTES (CRUD + historial pedidos) ----------------
class ClientesScreen extends StatefulWidget {
  /// true cuando vive dentro de la pestaña de un hub (sin cabecera propia).
  final bool incrustado;
  const ClientesScreen({super.key, this.incrustado = false});
  @override
  State<ClientesScreen> createState() => _ClientesScreenState();
}

class _ClientesScreenState extends State<ClientesScreen> {
  int _refresh = 0;
  final _svc = ModulesService();

  void _reload() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_refresh),
      incrustado: widget.incrustado, // dentro de un hub no repite cabecera
      title: 'Gestión de Clientes',
      subtitle: 'Directorio comercial',
      tabs: const ['Activos', 'Inactivos'],
      loader: (s, t) => _svc.clientes(search: s, tab: t),
      rowIcon: Icons.person_outline_rounded,
      searchHint: 'Buscar por nombre, RUC o DNI...',
      historyLabel: 'Pedidos',
      onCreate: () async {
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => const NuevoClienteScreen(),
        ));
        if (!context.mounted) return;
        if (ok != true) return;
        _reload();
        _snack(context, 'Cliente registrado.');
      },
      onEdit: (e) async {
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => NuevoClienteScreen(cliente: e),
        ));
        if (!context.mounted) return;
        if (ok != true) return;
        _reload();
        _snack(context, 'Cliente actualizado.');
      },
      onDelete: (e) async {
        await _svc.eliminar('/clientes', e.id);
        _reload();
        if (context.mounted) _snack(context, 'Cliente eliminado.');
      },
      onHistory: (e) async {
        final rows = await _svc.historialPedidos(e.id);
        if (context.mounted) {
          ErpHistoryTable.show(context,
              title: 'Historial pedidos • ${e.titulo}',
              columns: const ['Código', 'Fecha', 'Total', 'Estado'],
              rows: rows);
        }
      },
    );
  }
}

// ---------------- 2. GESTIÓN PROVEEDORES (CRUD + detalle) ----------------
class ProveedoresScreen extends StatefulWidget {
  /// true cuando vive dentro de la pestaña de un hub (sin cabecera propia).
  final bool incrustado;
  const ProveedoresScreen({super.key, this.incrustado = false});
  @override
  State<ProveedoresScreen> createState() => _ProveedoresScreenState();
}

class _ProveedoresScreenState extends State<ProveedoresScreen> {
  int _refresh = 0;
  final _svc = ModulesService();
  void _reload() => setState(() => _refresh++);

  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_refresh),
      incrustado: widget.incrustado, // dentro de un hub no repite cabecera
      title: 'Gestión de Proveedores',
      subtitle: 'Abastecimiento',
      tabs: const ['Activos', 'Inactivos', 'Eliminados'],
      loader: (s, t) => _svc.proveedores(search: s, tab: t),
      rowIcon: Icons.business_outlined,
      searchHint: 'Buscar proveedor o RUC...',
      historyLabel: 'Detalle',
      onCreate: () async {
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => const NuevoProveedorScreen(),
        ));
        if (!context.mounted) return;
        if (ok != true) return;
        _reload();
        _snack(context, 'Proveedor registrado.');
      },
      onEdit: (e) async {
        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => NuevoProveedorScreen(proveedor: e),
        ));
        if (!context.mounted) return;
        if (ok != true) return;
        _reload();
        _snack(context, 'Proveedor actualizado.');
      },
      onDelete: (e) async {
        await _svc.eliminar('/proveedores', e.id);
        _reload();
        if (context.mounted) _snack(context, 'Proveedor eliminado.');
      },
      onHistory: (e) {
        ErpHistoryTable.show(context,
            title: 'Detalle • ${e.titulo}',
            columns: const ['Campo', 'Valor'],
            rows: [
              ['Proveedor', e.titulo],
              ['Documento', e.subtitulo],
              ['Dato', e.monto],
              ['Estado', e.estado],
            ]);
      },
    );
  }
}

// ---------------- 3. CONTROL INVENTARIO (hub: Stock / Kardex / Ajustes) ----------------
class InventarioHubScreen extends StatelessWidget {
  /// Pestaña inicial: 0 Stock y Productos · 1 Kardex · 2 Ajustes.
  final int initialIndex;

  const InventarioHubScreen({super.key, this.initialIndex = 0});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialIndex.clamp(0, 2),
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        // UNA sola cabecera para todo el hub (pestañas segmentadas).
        body: Column(
          children: [
            ErpHeader(
              title: 'Control de Inventario',
              subtitle: 'Stock, Kardex y ajustes',
              bottom: const ErpSegmentedTabs(
                tabs: [
                  ErpTabSpec('Stock y Productos',
                      icon: Icons.inventory_2_rounded),
                  ErpTabSpec('Kardex', icon: Icons.receipt_outlined),
                  ErpTabSpec('Ajustes', icon: Icons.handyman_outlined),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ProductosTab(),
                  KardexTab(),
                  AjustesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AjustesTab extends StatefulWidget {
  const AjustesTab({super.key});
  @override
  State<AjustesTab> createState() => AjustesTabState();
}

class AjustesTabState extends State<AjustesTab> {
  int _r = 0;
  bool _mostrarHistorial = false;

  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    if (_mostrarHistorial) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _mostrarHistorial = false),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('Volver a Ajustes', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ErpHistoryScreen(
              incrustado: true,
              title: 'Historial de Ajustes y Mermas',
              subtitle: 'Registro de pérdidas y correcciones de stock',
              columns: const ['Tipo Ajuste', 'Motivo / Detalle', 'Cantidad', 'Fecha', 'Estado'],
              loader: () async {
                final items = await svc.ajustes();
                return items.map((e) {
                  final j = e.raw;
                  final tipo = (j['Ajuste_inventario_tipo'] ?? j['tipo'] ?? e.titulo).toString();
                  final motivo = (j['Ajuste_inventario_motivo'] ?? j['motivo'] ?? 'Conteo físico').toString();
                  final cant = e.monto.isNotEmpty
                      ? e.monto
                      : (j['Ajuste_inventario_cantidad'] != null ? '-${j['Ajuste_inventario_cantidad']} uds.' : '—');
                  final fecha = ErpItem.formatDate(j['Ajuste_inventario_fecha'] ?? j['fecha'] ?? j['created_at']);
                  return [tipo, motivo, cant, fecha.isNotEmpty ? fecha : '—', e.estado];
                }).toList();
              },
            ),
          ),
        ],
      );
    }
    return ErpListScreen(
      key: ValueKey(_r),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: 'Ajustes de Inventario',
      tabs: const ['Todos', 'Mermas', 'Daños'],
      loader: (s, t) => svc.ajustes(search: s, tab: t),
      rowIcon: Icons.handyman_outlined,
      historyLabel: 'Tabla',
      onHistory: (_) {
        setState(() => _mostrarHistorial = true);
      },
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar ajuste manual',
        fields: [
          ...ErpForms.producto().take(1),
          ErpForms.recepcion().last,
        ],
        onSave: (d) => svc.crear('/inventario/ajustes', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Ajuste registrado.');
        },
      ),
      onDelete: (e) async {
        await svc.eliminar('/inventario/ajustes', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Ajuste eliminado.');
      },
    );
  }
}

// ---------------- 4. HUBS DE ÓRDENES (pedidos y compras separados) ----------------
// El flujo comercial de clientes (Pedidos + Despacho) va por un lado y el de
// abastecimiento (Compras + Recepción) por otro: nunca se mezclan en la misma
// barra de pestañas.

/// Vista anidada Pedidos | Despacho (se usa dentro del hub de operaciones).
class PedidosDespachoView extends StatelessWidget {
  final int initialIndex;
  const PedidosDespachoView({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex.clamp(0, 1),
      child: Column(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: ErpSegmentedTabs(
              tabs: [
                ErpTabSpec('Pedidos', icon: Icons.receipt_long_rounded),
                ErpTabSpec('Despacho', icon: Icons.delivery_dining_rounded),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                PedidosTab(),
                DespachoTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista anidada Compras | Recepción (se usa dentro del hub de operaciones).
class ComprasRecepcionView extends StatelessWidget {
  final int initialIndex;
  const ComprasRecepcionView({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialIndex.clamp(0, 1),
      child: Column(
        children: const [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
            child: ErpSegmentedTabs(
              tabs: [
                ErpTabSpec('Compras', icon: Icons.request_page_rounded),
                ErpTabSpec('Recepción', icon: Icons.unarchive_rounded),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                CompraTab(),
                RecepcionTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hub de PEDIDOS: órdenes de clientes y despacho, nada más.
class PedidosHubScreen extends StatelessWidget {
  /// Pestaña inicial: 0 Pedidos · 1 Despacho.
  final int initialIndex;

  const PedidosHubScreen({super.key, this.initialIndex = 0});
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
              title: 'Pedidos',
              subtitle: 'Órdenes de clientes y despacho',
              bottom: const ErpSegmentedTabs(
                tabs: [
                  ErpTabSpec('Pedidos', icon: Icons.receipt_long_rounded),
                  ErpTabSpec('Despacho', icon: Icons.delivery_dining_rounded),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  PedidosTab(),
                  DespachoTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hub de COMPRAS: órdenes de compra y recepción de mercadería, nada más.
class ComprasHubScreen extends StatelessWidget {
  /// Pestaña inicial: 0 Compras · 1 Recepción.
  final int initialIndex;

  const ComprasHubScreen({super.key, this.initialIndex = 0});
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
              title: 'Compras',
              subtitle: 'Órdenes a proveedores y recepción',
              bottom: const ErpSegmentedTabs(
                tabs: [
                  ErpTabSpec('Compras', icon: Icons.request_page_rounded),
                  ErpTabSpec('Recepción', icon: Icons.unarchive_rounded),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  CompraTab(),
                  RecepcionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Historial en tablas (pedidos, compras, recepción) como pantalla propia.
class HistorialOrdenesScreen extends StatelessWidget {
  const HistorialOrdenesScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Column(
        children: [
          const ErpHeader(
            title: 'Historial',
            subtitle: 'Pedidos, compras y recepción en tablas',
          ),
          const Expanded(child: HistorialOrdenesTab()),
        ],
      ),
    );
  }
}

class PedidosTab extends StatefulWidget {
  const PedidosTab({super.key});
  @override
  State<PedidosTab> createState() => PedidosTabState();
}

class PedidosTabState extends State<PedidosTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: 'Órdenes de Clientes',
      subtitle: 'Listado de pedidos',
      tabs: const ['Todos', 'Pendientes', 'Completados', 'Cancelados'],
      loader: (s, t) => _svc.pedidos(search: s, tab: t),
      rowIcon: Icons.shopping_cart_outlined,
      searchHint: 'Buscar pedido o cliente...',
      onCreate: () async {
        // Proceso completo: cliente → productos → envío → guardar.
        final creado = await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NuevoPedidoScreen()),
        );
        if (creado == true && mounted) setState(() => _r++);
      },
      // Al tocar una fila: modal compacto con detalle + listado breve de
      // productos, y acciones Editar / Eliminar (solo si está pendiente).
      onRowTap: (e) => PedidoDetalleDialog.mostrar(
        context,
        pedidoId: e.id,
        resumen: e.raw,
        onEditar: () async {
          final actualizado = await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => NuevoPedidoScreen(pedidoId: e.id)),
          );
          if (!mounted) return;
          if (actualizado == true) {
            setState(() => _r++);
            if (context.mounted) _snack(context, 'Pedido actualizado.');
          }
        },
        onEliminar: () async {
          await _svc.eliminar('/pedidos', e.id);
          if (!mounted) return;
          setState(() => _r++);
          if (context.mounted) _snack(context, 'Pedido eliminado.');
        },
      ),
    );
  }
}

class CompraTab extends StatefulWidget {
  const CompraTab({super.key});
  @override
  State<CompraTab> createState() => CompraTabState();
}

class CompraTabState extends State<CompraTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      incrustado: true, // la ÚNICA cabecera es la del hub
      title: 'Órdenes de Compra',
      subtitle: 'Órdenes a proveedores',
      tabs: const ['Todas', 'Pendientes', 'Cerradas', 'Anuladas'],
      loader: (s, t) => _svc.ordenesCompra(search: s, tab: t),
      rowIcon: Icons.request_page_outlined,
      searchHint: 'Buscar OC o proveedor...',
      historyLabel: 'Recepción',
      onCreate: () async {
        final ok = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const NuevaCompraScreen()),
        );
        if (!mounted) return;
        if (ok == true) setState(() => _r++);
      },
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar orden',
        fields: ErpForms.ordenCompra(),
        onSave: (d) => _svc.actualizar('/ordenes-compra', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Orden actualizada.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/ordenes-compra', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Orden eliminada.');
      },
      onHistory: (e) async {
        final rows = await _svc.historialRecepcion(e.id);
        if (context.mounted) {
          ErpHistoryTable.show(context,
              title: 'Historial recepción • ${e.titulo}',
              columns: const ['Fecha', 'Producto', 'Recibido', 'Estado'],
              rows: rows);
        }
      },
    );
  }
}

// Historial global con tablas: clientes, pedidos, OC, recepción
class HistorialOrdenesTab extends StatelessWidget {
  const HistorialOrdenesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    final cards = [
      (
        'Historial clientes',
        'Pedidos por cliente con tabla',
        Icons.groups_outlined,
        () async {
          final rows = await svc.historialPedidos('1');
          if (context.mounted) {
            ErpHistoryTable.show(context,
                title: 'Historial • Clientes / Pedidos',
                columns: const ['Código', 'Fecha', 'Total', 'Estado'],
                rows: rows);
          }
        }
      ),
      (
        'Historial pedidos',
        'Todos los pedidos en tabla',
        Icons.receipt_long_outlined,
        () async {
          final items = await svc.pedidos();
          if (context.mounted) {
            ErpHistoryTable.show(
                context,
                title: 'Historial • Órdenes de clientes',
                columns: const ['Código', 'Cliente', 'Total', 'Estado'],
                rows: items
                    .map((e) => [e.titulo, e.subtitulo, e.monto, e.estado])
                    .toList());
          }
        }
      ),
      (
        'Historial compras',
        'Órdenes de compra en tabla',
        Icons.shopping_basket_outlined,
        () async {
          final rows = await svc.historialOrdenesCompra();
          if (context.mounted) {
            ErpHistoryTable.show(context,
                title: 'Historial • Órdenes de compra',
                columns: const ['OC', 'Proveedor', 'Total', 'Estado'],
                rows: rows);
          }
        }
      ),
      (
        'Historial recepción',
        'Recepciones por orden en tabla',
        Icons.unarchive_outlined,
        () async {
          final rows = await svc.historialRecepcion('1');
          if (context.mounted) {
            ErpHistoryTable.show(context,
                title: 'Historial • Recepción mercadería',
                columns: const ['Fecha', 'Producto', 'Recibido', 'Estado'],
                rows: rows);
          }
        }
      ),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: cards.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final c = cards[i];
        return InkWell(
          onTap: c.$4,
          borderRadius: BorderRadius.circular(20),
          child: CampusCard(
            child: Row(
              children: [
                ErpIconTile(icon: c.$3, size: 44, radius: 14),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1,
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark)),
                        Text(c.$2,
                            style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted)),
                      ]),
                ),
                Icon(Icons.table_chart_outlined,
                    color: AppColors.celesteDark),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Atajos para compatibilidad con home antiguo
class PedidosScreen extends StatelessWidget {
  const PedidosScreen({super.key});
  @override
  Widget build(BuildContext context) => const PedidosHubScreen();
}

class OrdenesCompraScreen extends StatelessWidget {
  const OrdenesCompraScreen({super.key});
  @override
  Widget build(BuildContext context) => const ComprasHubScreen();
}

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});
  @override
  Widget build(BuildContext context) => const InventarioHubScreen();
}
