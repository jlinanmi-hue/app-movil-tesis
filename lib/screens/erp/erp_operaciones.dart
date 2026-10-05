import 'package:flutter/material.dart';
import '../../core/services/modules_service.dart';
import '../../core/widgets/campus_card.dart';
import '../../models/erp_models.dart';
import '../erp/erp_list_screen.dart';
import 'erp_form.dart';

// ===================================================================
// OPERACIONES (solo 4): Órdenes, Inventario, Proveedores, Clientes
// Cada uno con contenedores del web: registrar / editar / eliminar /
// historial en tabla. Estilo Campus Cash celeste+blanco, responsive.
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
    // Ignora Maps/Listas (ej. cliente:{...}) que romperían dropdowns/textos
    if (v is Map || v is List) continue;
    final s = '$v'.trim();
    if (s.isEmpty || s == '—' || s == 'null') continue;
    out[f.key] = s;
  }
  return out;
}

// ---------------- 1. GESTIÓN CLIENTES (CRUD + historial pedidos) ----------------
class ClientesScreen extends StatefulWidget {
  const ClientesScreen({super.key});
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
      title: 'Gestión de Clientes',
      subtitle: 'Directorio comercial',
      heroLabel: 'Clientes registrados',
      heroValue: '128',
      heroCaption: '46 recurrentes • +12 este mes',
      heroIcon: Icons.groups_outlined,
      kpis: [
        CampusKpi(icon: Icons.groups_outlined, value: '128', label: 'Activos'),
        CampusKpi(icon: Icons.repeat_rounded, value: '46', label: 'Recurrentes'),
        CampusKpi(icon: Icons.star_outline_rounded, value: '18', label: 'Top'),
        CampusKpi(icon: Icons.person_off_outlined, value: '9', label: 'Inactivos'),
      ],
      tabs: const ['Activos', 'Recurrentes', 'Top compras', 'Inactivos', 'Eliminados'],
      loader: (s, t) => _svc.clientes(search: s, tab: t),
      rowIcon: Icons.person_outline_rounded,
      searchHint: 'Buscar por nombre, RUC o DNI...',
      historyLabel: 'Pedidos',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar cliente',
        fields: ErpForms.cliente(),
        onSave: (d) => _svc.crear('/clientes', d),
        onSaved: () {
          _reload();
          _snack(context, 'Cliente registrado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar cliente',
        fields: ErpForms.cliente(),
        initial: _rawInitial(e, ErpForms.cliente()),
        onSave: (d) => _svc.actualizar('/clientes', e.id, d),
        onSaved: () {
          _reload();
          _snack(context, 'Cliente actualizado.');
        },
      ),
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
  const ProveedoresScreen({super.key});
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
      title: 'Gestión de Proveedores',
      subtitle: 'Abastecimiento',
      heroLabel: 'Cumplimiento promedio',
      heroValue: '92%',
      heroCaption: '5 activos • ranking al día',
      heroIcon: Icons.local_shipping_outlined,
      kpis: [
        CampusKpi(icon: Icons.store_outlined, value: '5', label: 'Activos'),
        CampusKpi(icon: Icons.check_circle_outline_rounded, value: '92%', label: 'Cumple.'),
        CampusKpi(icon: Icons.warning_amber_rounded, value: '1', label: 'Riesgo'),
        CampusKpi(icon: Icons.delete_outline_rounded, value: '0', label: 'Elimin.'),
      ],
      tabs: const ['Activos', 'Inactivos', 'Eliminados'],
      loader: (s, t) => _svc.proveedores(search: s, tab: t),
      rowIcon: Icons.business_outlined,
      searchHint: 'Buscar proveedor o RUC...',
      historyLabel: 'Detalle',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar proveedor',
        fields: ErpForms.proveedor(),
        onSave: (d) => _svc.crear('/proveedores', d),
        onSaved: () {
          _reload();
          _snack(context, 'Proveedor registrado.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar proveedor',
        fields: ErpForms.proveedor(),
        initial: _rawInitial(e, ErpForms.proveedor()),
        onSave: (d) => _svc.actualizar('/proveedores', e.id, d),
        onSaved: () {
          _reload();
          _snack(context, 'Proveedor actualizado.');
        },
      ),
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
  const InventarioHubScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
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
                          Text('Control de Inventario',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3642))),
                          Text('Stock, Kardex y ajustes',
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
                  Tab(text: 'Stock y Productos'),
                  Tab(text: 'Kardex'),
                  Tab(text: 'Ajustes')
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _ProductosTab(),
                    _KardexTab(),
                    _AjustesTab(),
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

class _ProductosTab extends StatefulWidget {
  const _ProductosTab();
  @override
  State<_ProductosTab> createState() => _ProductosTabState();
}

class _ProductosTabState extends State<_ProductosTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Stock y Productos',
      subtitle: 'Catálogo maestro',
      heroLabel: 'Valorizado estimado',
      heroValue: 'S/ 24.5k',
      heroCaption: '320 SKUs • 3 en quiebre',
      heroIcon: Icons.inventory_2_outlined,
      kpis: [
        CampusKpi(icon: Icons.inventory_2_outlined, value: '320', label: 'SKUs'),
        CampusKpi(icon: Icons.warning_amber_rounded, value: '3', label: 'Bajo'),
        CampusKpi(icon: Icons.remove_shopping_cart_outlined, value: '1', label: 'Agot.'),
        CampusKpi(icon: Icons.delete_outline_rounded, value: '0', label: 'Elim.'),
      ],
      tabs: const ['Activos', 'Stock bajo', 'Eliminados'],
      loader: (s, t) => _svc.productos(search: s, tab: t),
      rowIcon: Icons.shopping_bag_outlined,
      searchHint: 'Buscar producto...',
      historyLabel: 'Kardex',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Registrar producto',
        fields: ErpForms.producto(),
        onSave: (d) => _svc.crear('/inventario/productos', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Producto registrado con detalles y stock inicial.');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar producto',
        fields: ErpForms.producto(),
        initial: _rawInitial(e, ErpForms.producto()),
        onSave: (d) => _svc.actualizar('/inventario/productos', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Producto actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/inventario/productos', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Producto eliminado.');
      },
      onHistory: (e) async {
        final rows = await _svc.generico('/inventario/movimientos');
        if (context.mounted) {
          ErpHistoryTable.show(context,
              title: 'Kardex • ${e.titulo}',
              columns: const ['Movimiento', 'Detalle', 'Cant.', 'Estado'],
              rows: rows
                  .take(8)
                  .map((x) => [x.titulo, x.subtitulo, x.monto, x.estado])
                  .toList());
        }
      },
    );
  }
}

class _KardexTab extends StatelessWidget {
  const _KardexTab();
  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    return ErpListScreen(
      title: 'Kardex y Movimientos',
      subtitle: 'Entradas y salidas',
      heroLabel: 'Movimientos hoy',
      heroValue: '34',
      heroCaption: '18 entradas • 16 salidas',
      heroIcon: Icons.swap_vert_rounded,
      kpis: [
        CampusKpi(icon: Icons.arrow_downward_rounded, value: '18', label: 'Entradas'),
        CampusKpi(icon: Icons.arrow_upward_rounded, value: '16', label: 'Salidas'),
        CampusKpi(icon: Icons.tune_rounded, value: '2', label: 'Ajustes'),
        CampusKpi(icon: Icons.today_outlined, value: 'Hoy', label: 'Filtro'),
      ],
      tabs: const ['Todos', 'Entradas', 'Salidas'],
      loader: (s, t) => svc.movimientos(search: s, tab: t),
      rowIcon: Icons.receipt_outlined,
      searchHint: 'Buscar movimiento...',
    );
  }
}

class _AjustesTab extends StatefulWidget {
  const _AjustesTab();
  @override
  State<_AjustesTab> createState() => _AjustesTabState();
}

class _AjustesTabState extends State<_AjustesTab> {
  int _r = 0;
  @override
  Widget build(BuildContext context) {
    final svc = ModulesService();
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Ajustes de Inventario',
      subtitle: 'Mermas, daños y vencimientos',
      heroLabel: 'Impacto mes',
      heroValue: 'S/ 320',
      heroCaption: '6 ajustes • 2 mermas',
      heroIcon: Icons.tune_rounded,
      kpis: [
        CampusKpi(icon: Icons.tune_rounded, value: '6', label: 'Ajustes'),
        CampusKpi(icon: Icons.warning_amber_rounded, value: '2', label: 'Mermas'),
        CampusKpi(icon: Icons.attach_money_rounded, value: '320', label: 'Impacto'),
        CampusKpi(icon: Icons.today_outlined, value: 'Hoy', label: 'Filtro'),
      ],
      tabs: const ['Todos', 'Mermas', 'Daños'],
      loader: (s, t) => svc.ajustes(search: s, tab: t),
      rowIcon: Icons.handyman_outlined,
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

// ---------------- 4. CONTROL ÓRDENES (hub completo) ----------------
class OrdenesHubScreen extends StatelessWidget {
  const OrdenesHubScreen({super.key});
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
                          Text('Control de Órdenes',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0A3642))),
                          Text('Clientes, compra, recepción e historial',
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
                  Tab(text: 'Pedidos'),
                  Tab(text: 'Compra'),
                  Tab(text: 'Recepción'),
                  Tab(text: 'Historial'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [
                    _PedidosTab(),
                    _CompraTab(),
                    _RecepcionTab(),
                    _HistorialOrdenesTab(),
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

class _PedidosTab extends StatefulWidget {
  const _PedidosTab();
  @override
  State<_PedidosTab> createState() => _PedidosTabState();
}

class _PedidosTabState extends State<_PedidosTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Órdenes de Clientes',
      subtitle: 'Nueva + historial',
      heroLabel: 'Pedidos hoy',
      heroValue: '21',
      heroCaption: 'S/ 8,450 • 5 despachados',
      heroIcon: Icons.receipt_long_outlined,
      kpis: [
        CampusKpi(icon: Icons.inbox_outlined, value: '21', label: 'Hoy'),
        CampusKpi(icon: Icons.hourglass_empty_rounded, value: '6', label: 'Valid.'),
        CampusKpi(icon: Icons.inventory_outlined, value: '11', label: 'Prep.'),
        CampusKpi(icon: Icons.local_shipping_outlined, value: '5', label: 'Desp.'),
      ],
      tabs: const ['Nueva', 'Historial'],
      loader: (s, t) => _svc.pedidos(search: s, tab: t),
      rowIcon: Icons.shopping_cart_outlined,
      searchHint: 'Buscar pedido o cliente...',
      historyLabel: 'Detalle',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Nuevo pedido de cliente',
        fields: ErpForms.pedidoCliente(),
        onSave: (d) => _svc.crear('/pedidos', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Pedido registrado (cliente + canal + ítems).');
        },
      ),
      onEdit: (e) => ErpFormSheet.show(
        context,
        title: 'Editar pedido',
        fields: ErpForms.pedidoCliente(),
        onSave: (d) => _svc.actualizar('/pedidos', e.id, d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Pedido actualizado.');
        },
      ),
      onDelete: (e) async {
        await _svc.eliminar('/pedidos', e.id);
        setState(() => _r++);
        if (context.mounted) _snack(context, 'Pedido eliminado.');
      },
      onHistory: (e) {
        ErpHistoryTable.show(context,
            title: 'Detalle • ${e.titulo}',
            columns: const ['Campo', 'Valor'],
            rows: [
              ['Código', e.titulo],
              ['Cliente/Fecha', e.subtitulo],
              ['Total', e.monto],
              ['Estado', e.estado],
            ]);
      },
    );
  }
}

class _CompraTab extends StatefulWidget {
  const _CompraTab();
  @override
  State<_CompraTab> createState() => _CompraTabState();
}

class _CompraTabState extends State<_CompraTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Órdenes de Compra',
      subtitle: 'Nueva + historial a proveedor',
      heroLabel: 'Compra abierta',
      heroValue: 'S/ 16.4k',
      heroCaption: '3 órdenes • 1 en recepción',
      heroIcon: Icons.shopping_basket_outlined,
      kpis: [
        CampusKpi(icon: Icons.description_outlined, value: '3', label: 'Abiertas'),
        CampusKpi(icon: Icons.unarchive_outlined, value: '1', label: 'Recep.'),
        CampusKpi(icon: Icons.check_circle_outline_rounded, value: '12', label: 'Cerradas'),
        CampusKpi(icon: Icons.cancel_outlined, value: '0', label: 'Anul.'),
      ],
      tabs: const ['Nueva', 'Historial'],
      loader: (s, t) => _svc.ordenesCompra(search: s, tab: t),
      rowIcon: Icons.request_page_outlined,
      searchHint: 'Buscar OC o proveedor...',
      historyLabel: 'Recepción',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Nueva orden de compra',
        fields: ErpForms.ordenCompra(),
        onSave: (d) => _svc.crear('/ordenes-compra', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Orden de compra generada (proveedor + ítems).');
        },
      ),
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

class _RecepcionTab extends StatefulWidget {
  const _RecepcionTab();
  @override
  State<_RecepcionTab> createState() => _RecepcionTabState();
}

class _RecepcionTabState extends State<_RecepcionTab> {
  int _r = 0;
  final _svc = ModulesService();
  @override
  Widget build(BuildContext context) {
    return ErpListScreen(
      key: ValueKey(_r),
      title: 'Recepción de Mercadería',
      subtitle: 'Iniciar, recepcionar y cerrar',
      heroLabel: 'Por atender',
      heroValue: '4',
      heroCaption: '2 parciales • 8 conformes',
      heroIcon: Icons.inventory_2_outlined,
      kpis: [
        CampusKpi(icon: Icons.inbox_outlined, value: '4', label: 'Por atender'),
        CampusKpi(icon: Icons.timelapse_rounded, value: '2', label: 'Parciales'),
        CampusKpi(icon: Icons.check_circle_outline_rounded, value: '8', label: 'Conformes'),
        CampusKpi(icon: Icons.warning_amber_rounded, value: '1', label: 'Faltante'),
      ],
      tabs: const ['Por atender', 'Parciales', 'Cerradas'],
      loader: (s, t) => _svc.ordenesCompra(search: s, tab: t),
      rowIcon: Icons.unarchive_outlined,
      searchHint: 'Buscar orden...',
      historyLabel: 'Historial',
      onCreate: () => ErpFormSheet.show(
        context,
        title: 'Recepcionar mercadería',
        fields: ErpForms.recepcion(),
        onSave: (d) => _svc.recepcionarItem(d['orden_id'] ?? '1', d),
        onSaved: () {
          setState(() => _r++);
          _snack(context, 'Ítem recepcionado (parcial / rechazo / cierre).');
        },
      ),
      onHistory: (e) async {
        final rows = await _svc.historialRecepcion(e.id);
        if (context.mounted) {
          ErpHistoryTable.show(context,
              title: 'Historial • ${e.titulo}',
              columns: const ['Fecha', 'Producto', 'Recibido', 'Estado'],
              rows: rows);
        }
      },
    );
  }
}

// Historial global con tablas: clientes, pedidos, OC, recepción
class _HistorialOrdenesTab extends StatelessWidget {
  const _HistorialOrdenesTab();
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
      padding: const EdgeInsets.only(bottom: 24),
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
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: const Color(0xFFEAF9FE),
                      borderRadius: BorderRadius.circular(14)),
                  alignment: Alignment.center,
                  child: Icon(c.$3, color: const Color(0xFF0096C7)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.$1,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A3642))),
                        Text(c.$2,
                            style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4A7C8E))),
                      ]),
                ),
                const Icon(Icons.table_chart_outlined,
                    color: Color(0xFF0096C7)),
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
  Widget build(BuildContext context) => const OrdenesHubScreen();
}

class OrdenesCompraScreen extends StatelessWidget {
  const OrdenesCompraScreen({super.key});
  @override
  Widget build(BuildContext context) => const OrdenesHubScreen();
}

class ProductosScreen extends StatelessWidget {
  const ProductosScreen({super.key});
  @override
  Widget build(BuildContext context) => const InventarioHubScreen();
}
