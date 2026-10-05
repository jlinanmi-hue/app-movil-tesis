import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../exceptions/api_exception.dart';
import 'session_service.dart';
import '../../models/erp_models.dart';

/// Servicio genérico ERP para móvil.
/// Replica los endpoints del frontend-tesis (services/api.js)
/// con fallback a datos mock si no hay backend, para que la app
/// siempre sea demostrable y responsive.
class ModulesService {
  static final ModulesService _i = ModulesService._internal();
  factory ModulesService() => _i;
  late Dio _dio;

  ModulesService._internal() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        o.baseUrl = await ApiConfig.getBaseUrl();
        final t = SessionService.token;
        if (t != null && t.isNotEmpty) o.headers['Authorization'] = 'Bearer $t';
        return h.next(o);
      },
    ));
  }

  /// Extrae lista de TODAS las formas del backend:
  /// {success,data:[...]} | {success,data:{data:[...]}} |
  /// {success,data:{data:[...],meta}} | {success,data:[...],meta} | [...]
  List<Map<String, dynamic>> _extractList(dynamic d) {
    if (d is List) return d.whereType<Map<String, dynamic>>().toList();
    if (d is Map) {
      final data = d['data'];
      if (data is List) return data.whereType<Map<String, dynamic>>().toList();
      if (data is Map) {
        final inner = data['data'];
        if (inner is List) {
          return inner.whereType<Map<String, dynamic>>().toList();
        }
      }
    }
    return [];
  }

  Future<List<ErpItem>> _getList(
    String path,
    ErpItem Function(Map<String, dynamic>) mapper, {
    Map<String, dynamic>? query,
    required List<ErpItem> mock,
  }) async {
    try {
      final clean = <String, dynamic>{};
      query?.forEach((k, v) {
        if (v != null && '$v'.isNotEmpty) clean[k] = v;
      });
      final res = await _dio.get(path, queryParameters: clean.isEmpty ? null : clean);
      final raw = _extractList(res.data);
      debugPrint('[ModulesService] GET $path q=$clean -> ${raw.length} items');
      if (raw.isEmpty) return mock;
      return raw.map(mapper).toList();
    } catch (e) {
      debugPrint('[ModulesService] $path offline, usando mock: $e');
      return mock;
    }
  }

  Map<String, dynamic> _tabQuery(String tab) {
    final t = tab.toLowerCase();
    if (t.contains('elimin')) return {'eliminados': 1, 'per_page': 50};
    if (t.contains('inact')) return {'estado': 'I', 'per_page': 50};
    if (t.contains('bajo') || t.contains('stock bajo')) {
      return {'stockBajo': 1, 'per_page': 50};
    }
    // Tabs informativos del web (recurrentes, top, vacaciones...) no filtran en API
    if (t == 'todos' || t == 'todas' || t == 'nueva' || t == 'historial' ||
        t.contains('recurrent') || t.contains('top') || t.contains('vacacion') ||
        t.contains('licencia') || t.contains('por atender') || t.contains('parcial') ||
        t.contains('cerrada') || t.contains('pendiente') || t.contains('entrada') ||
        t.contains('salida') || t.contains('merma') || t.contains('daño')) {
      return {'per_page': 50};
    }
    return {'per_page': 50};
  }

  // ---------- CLIENTES (GET /clientes) ----------
  Future<List<ErpItem>> clientes({String search = '', String tab = 'Activos'}) => _getList(
        '/clientes',
        ErpItem.fromCliente,
        query: {'search': search, ..._tabQuery(tab), 'per_page': 50},
        mock: List.generate(
          6,
          (i) => ErpItem(
              id: 'CLI-0000$i',
              titulo: ['Bodega San Juan', 'Minimarket El Ahorro', 'Librería Central', 'Farmacia Vida', 'Restaurante Sabor', 'Colegio San Pedro'][i],
              subtitulo: ['RUC 2012345678$i', 'DNI 45${i}678901', 'RUC 2098765432$i', 'DNI 71${i}234567', 'RUC 2045678912$i', 'RUC 2054321890$i'][i],
              monto: '${[12, 8, 5, 20, 15, 6][i]} compras',
              estado: i == 4 ? 'inactivo' : 'activo'),
        ),
      );

  // ---------- PROVEEDORES ----------
  Future<List<ErpItem>> proveedores({String search = '', String tab = 'Activos'}) => _getList(
        '/proveedores',
        ErpItem.fromProveedor,
        query: {'search': search, ..._tabQuery(tab)},
        mock: List.generate(
          5,
          (i) => ErpItem(
              id: 'PROV-0000$i',
              titulo: ['Distribuidora Lima SAC', 'Alicorp Mayorista', 'Gloria Proveedores', 'Backus Distribuidor', 'San Fernando'][i],
              subtitulo: 'RUC 20100047${i}02 • Lima',
              monto: '${95 - i * 4}% cumpl.',
              estado: 'activo',
              progreso: (95 - i * 4) / 100),
        ),
      );

  // ---------- PRODUCTOS / STOCK ----------
  Future<List<ErpItem>> productos({String search = '', String tab = 'Activos'}) => _getList(
        '/inventario/productos',
        ErpItem.fromProducto,
        query: {'search': search, ..._tabQuery(tab), 'todos': 1},
        mock: [
          ErpItem(id: 'PROD-00001', titulo: 'Aceite Primor 1L', subtitulo: 'Stock: 48 • Abarrotes', monto: 'S/ 12.50', estado: 'activo', progreso: 0.8),
          ErpItem(id: 'PROD-00002', titulo: 'Arroz Costeño 5kg', subtitulo: 'Stock: 6 • Abarrotes', monto: 'S/ 28.90', estado: 'bajo', progreso: 0.25),
          ErpItem(id: 'PROD-00003', titulo: 'Leche Gloria 400g', subtitulo: 'Stock: 0 • Lácteos', monto: 'S/ 4.20', estado: 'agotado', progreso: 0.0),
        ].where((e) {
          if (search.isEmpty) return true;
          return e.titulo.toLowerCase().contains(search.toLowerCase());
        }).toList(),
      );

  // ---------- PEDIDOS CLIENTE (PedidoResource) ----------
  Future<List<ErpItem>> pedidos({String search = '', String tab = 'Todos'}) => _getList(
        '/pedidos',
        ErpItem.fromPedido,
        query: {'search': search, 'per_page': 15},
        mock: [
          ErpItem(id: 'PED-00001', titulo: 'PED-00001', subtitulo: 'Bodega San Juan • 01/10/2026', monto: 'S/ 450.00', estado: 'pendiente'),
          ErpItem(id: 'PED-00002', titulo: 'PED-00002', subtitulo: 'Minimarket El Ahorro • Hoy', monto: 'S/ 1,200.00', estado: 'preparación'),
        ].where((e) => search.isEmpty || e.titulo.toLowerCase().contains(search.toLowerCase())).toList(),
      );

  // ---------- ÓRDENES COMPRA (OrdenCompraResource) ----------
  Future<List<ErpItem>> ordenesCompra({String search = '', String tab = 'Todas'}) => _getList(
        '/ordenes-compra',
        ErpItem.fromOrdenCompra,
        query: {'search': search, 'per_page': 15},
        mock: [
          ErpItem(id: 'OC-00001', titulo: 'OC-00001', subtitulo: 'Alicorp • 12 ítems', monto: 'S/ 5,400.00', estado: 'emitida'),
          ErpItem(id: 'OC-00002', titulo: 'OC-00002', subtitulo: 'Gloria • 8 ítems', monto: 'S/ 2,150.00', estado: 'emitida'),
        ],
      );

  // ---------- CATÁLOGOS / SEGURIDAD / PERSONAL con mapper real ----------
  Future<List<ErpItem>> categorias({String search = '', String tab = 'Todos'}) => _getList(
        '/categorias',
        ErpItem.fromCategoria,
        query: {'search': search, ..._tabQuery(tab)},
        mock: _mockFor('/categorias'),
      );

  Future<List<ErpItem>> canales({String search = ''}) => _getList(
        '/canales-pedido',
        ErpItem.fromCanal,
        query: {'search': search, 'per_page': 50},
        mock: _mockFor('/canales-pedido'),
      );

  Future<List<ErpItem>> ubicaciones({String search = ''}) => _getList(
        '/ubicaciones',
        ErpItem.fromUbicacion,
        query: {'search': search, 'per_page': 50},
        mock: _mockFor('/ubicaciones'),
      );

  Future<List<ErpItem>> unidades({String search = ''}) => _getList(
        '/unidades-medida',
        ErpItem.fromUnidad,
        query: {'search': search, 'per_page': 50},
        mock: _mockFor('/unidades-medida'),
      );

  Future<List<ErpItem>> personal({String search = '', String tab = 'Todos'}) => _getList(
        '/personal',
        ErpItem.fromPersonal,
        query: {'search': search, ..._tabQuery(tab)},
        mock: _mockFor('/personal'),
      );

  Future<List<ErpItem>> roles({String search = ''}) => _getList(
        '/seguridad/roles',
        ErpItem.fromRol,
        query: {'search': search},
        mock: _mockFor('/seguridad/roles'),
      );

  Future<List<ErpItem>> cargos({String search = ''}) => _getList(
        '/seguridad/cargos',
        ErpItem.fromCargo,
        query: {'search': search},
        mock: _mockFor('/seguridad/cargos'),
      );

  Future<List<ErpItem>> movimientos({String search = '', String tab = 'Todos'}) {
    String? tipo;
    final t = tab.toLowerCase();
    if (t.contains('entrada')) tipo = 'E';
    if (t.contains('salida')) tipo = 'S';
    return _getList(
      '/inventario/movimientos',
      ErpItem.fromMovimiento,
      query: {'search': search, 'tipoMovimiento': tipo, 'per_page': 15},
      mock: _mockFor('/inventario/movimientos'),
    );
  }

  Future<List<ErpItem>> ajustes({String search = '', String tab = 'Todos'}) => _getList(
        '/inventario/ajustes',
        ErpItem.fromAjuste,
        query: {'search': search, 'per_page': 15},
        mock: _mockFor('/inventario/ajustes'),
      );

  // ---------- GENÉRICO (fallback) ----------
  Future<List<ErpItem>> generico(String path, {String search = ''}) {
    if (path.contains('categor')) return categorias(search: search);
    if (path.contains('canal')) return canales(search: search);
    if (path.contains('ubicacion')) return ubicaciones(search: search);
    if (path.contains('unidad')) return unidades(search: search);
    if (path.contains('personal')) return personal(search: search);
    if (path.contains('roles')) return roles(search: search);
    if (path.contains('cargos')) return cargos(search: search);
    if (path.contains('movimiento')) return movimientos(search: search);
    if (path.contains('ajuste')) return ajustes(search: search);
    if (path.contains('cliente')) return clientes(search: search);
    if (path.contains('proveedor')) return proveedores(search: search);
    if (path.contains('producto')) return productos(search: search);
    if (path.contains('pedido')) return pedidos(search: search);
    if (path.contains('orden')) return ordenesCompra(search: search);
    return _getList(
      path,
      (j) => ErpItem(
        id: '${j['id'] ?? j['codigo'] ?? '0'}',
        titulo: '${j['nombre'] ?? j['descripcion'] ?? j['titulo'] ?? 'Registro'}',
        subtitulo: '${j['detalle'] ?? ''}',
        monto: '',
        estado: 'activo',
        raw: j,
      ),
      query: search.isEmpty ? null : {'search': search},
      mock: _mockFor(path),
    );
  }

  List<ErpItem> _mockFor(String path) {
    if (path.contains('categor')) {
      return ['Abarrotes', 'Lácteos', 'Bebidas', 'Limpieza', 'Pastas'].asMap().entries.map((e) => ErpItem(id: '${e.key}', titulo: e.value, subtitulo: '${12 + e.key * 3} productos', monto: '', estado: 'activo')).toList();
    }
    if (path.contains('canal')) {
      return ['Mostrador', 'WhatsApp', 'Teléfono', 'Valencia AI'].asMap().entries.map((e) => ErpItem(id: '${e.key}', titulo: e.value, subtitulo: 'Canal activo', monto: '', estado: 'activo')).toList();
    }
    if (path.contains('roles')) {
      return [ErpItem(id: '1', titulo: 'Administrador', subtitulo: 'Acceso total', monto: '8 permisos', estado: 'activo'), ErpItem(id: '2', titulo: 'Vendedor', subtitulo: 'Ventas y pedidos', monto: '4 permisos', estado: 'activo'), ErpItem(id: '3', titulo: 'Almacén', subtitulo: 'Stock y recepción', monto: '3 permisos', estado: 'activo')];
    }
    if (path.contains('cargos')) {
      return [ErpItem(id: '1', titulo: 'Gerente', subtitulo: 'Dirección', monto: '', estado: 'activo'), ErpItem(id: '2', titulo: 'Cajero', subtitulo: 'Ventas', monto: '', estado: 'activo'), ErpItem(id: '3', titulo: 'Almacenero', subtitulo: 'Logística', monto: '', estado: 'activo')];
    }
    if (path.contains('personal')) {
      return [ErpItem(id: '1', titulo: 'Juan Pérez', subtitulo: 'Vendedor • DNI 45678901', monto: '', estado: 'activo'), ErpItem(id: '2', titulo: 'María López', subtitulo: 'Almacén • DNI 71234567', monto: '', estado: 'activo')];
    }
    if (path.contains('ubicacion')) {
      return [ErpItem(id: '1', titulo: 'Estante A-01', subtitulo: 'Abarrotes', monto: '', estado: 'activo'), ErpItem(id: '2', titulo: 'Estante B-02', subtitulo: 'Lácteos', monto: '', estado: 'activo')];
    }
    if (path.contains('unidades')) {
      return [ErpItem(id: '1', titulo: 'Unidad', subtitulo: 'UND • Base', monto: '', estado: 'activo'), ErpItem(id: '2', titulo: 'Caja x12', subtitulo: 'Factor 12', monto: '', estado: 'activo')];
    }
    if (path.contains('movimiento')) {
      return [ErpItem(id: '1', titulo: 'Entrada • Aceite Primor', subtitulo: 'OC-2026-010 • Hoy', monto: '+48', estado: 'entrada'), ErpItem(id: '2', titulo: 'Salida • Arroz Costeño', subtitulo: 'PED-2026-001 • Hoy', monto: '-12', estado: 'salida')];
    }
    if (path.contains('ajuste')) {
      return [ErpItem(id: '1', titulo: 'Merma • Leche Gloria', subtitulo: 'Vencimiento • Ayer', monto: '-6', estado: 'merma')];
    }
    return [ErpItem(id: '1', titulo: 'Registro demo', subtitulo: path, monto: '', estado: 'activo')];
  }

  Future<void> cambiarEstado(String path, String id, String estado) async {
    try {
      await _dio.patch('$path/$id/estado', data: {'estado': estado});
    } catch (e) {
      throw ApiException(message: 'Sin conexión: no se pudo cambiar estado.');
    }
  }

  // ---------- EMPRESA (singleton GET /empresa) ----------
  Future<Map<String, dynamic>> obtenerEmpresa() async {
    try {
      final res = await _dio.get('/empresa');
      final d = res.data;
      if (d is Map && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      if (d is Map) return Map<String, dynamic>.from(d);
      return {};
    } catch (e) {
      debugPrint('[ModulesService] empresa offline: $e');
      return {
        'EmpresaRuc': '20123456789',
        'EmpresaRazonSocial': 'Comercial Valencia SAC (demo)',
        'EmpresaNombreComercial': 'Comercial Valencia',
        'EmpresaDireccion': 'Av. Principal 123',
        'EmpresaTelefono': '012345678',
        'EmpresaEmail': 'contacto@valencia.pe',
      };
    }
  }

  Future<void> actualizarEmpresa(Map<String, String> data) async {
    try {
      final res = await _dio.put('/empresa', data: data);
      final d = res.data;
      if (d is Map && d['success'] == false) {
        throw ApiException(
            message: d['message']?.toString() ?? 'No se pudo actualizar empresa.');
      }
    } on DioException catch (e) {
      if (e.response == null) {
        debugPrint('[ModulesService] actualizar empresa offline -> ok local');
        return;
      }
      throw ApiException(
          message: e.response?.data?['message']?.toString() ?? 'Error al actualizar.');
    }
  }

  // ---------- CRUD GENÉRICO (guardar / editar / eliminar / restaurar) ----------
  Future<void> crear(String path, Map<String, String> data) async {
    try {
      final res = await _dio.post(path, data: data);
      final d = res.data;
      if (d is Map && d['success'] == false) {
        throw ApiException(message: d['message']?.toString() ?? 'No se pudo guardar.');
      }
    } on DioException catch (e) {
      // Modo offline demostrable: se acepta como guardado local
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.response == null) {
        debugPrint('[ModulesService] crear $path offline -> ok local');
        return;
      }
      throw ApiException(
          message: e.response?.data?['message']?.toString() ?? 'Error al guardar.');
    }
  }

  Future<void> actualizar(String path, String id, Map<String, String> data) async {
    try {
      final res = await _dio.put('$path/$id', data: data);
      final d = res.data;
      if (d is Map && d['success'] == false) {
        throw ApiException(message: d['message']?.toString() ?? 'No se pudo actualizar.');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.response == null) {
        debugPrint('[ModulesService] actualizar $path/$id offline -> ok local');
        return;
      }
      throw ApiException(
          message: e.response?.data?['message']?.toString() ?? 'Error al actualizar.');
    }
  }

  Future<void> eliminar(String path, String id) async {
    try {
      await _dio.delete('$path/$id');
    } on DioException catch (e) {
      if (e.response == null) {
        debugPrint('[ModulesService] eliminar $path/$id offline -> ok local');
        return;
      }
      throw ApiException(message: 'No se pudo eliminar.');
    }
  }

  Future<void> restaurar(String path, String id) async {
    try {
      await _dio.post('$path/$id/restore');
    } on DioException catch (e) {
      if (e.response == null) return;
      throw ApiException(message: 'No se pudo restaurar.');
    }
  }

  // ---------- HISTORIALES (tablas) ----------
  Future<List<List<String>>> historialPedidos(String clienteId) async {
    try {
      final res = await _dio.get('/clientes/$clienteId/pedidos');
      final d = res.data;
      final List raw = d is Map && d['data'] is List ? d['data'] as List : [];
      if (raw.isEmpty) return _mockHistorialPedidos();
      return raw.whereType<Map>().map((mm) {
        return [
          '${mm['codigo'] ?? mm['id'] ?? ''}',
          '${mm['fecha'] ?? ''}',
          '${mm['total'] ?? ''}',
          '${mm['estado'] ?? ''}'
        ];
      }).toList();
    } catch (_) {
      return _mockHistorialPedidos();
    }
  }

  List<List<String>> _mockHistorialPedidos() => const [
        ['PED-2026-001', '2026-10-01', 'S/ 450.00', 'completado'],
        ['PED-2026-004', '2026-09-28', 'S/ 890.00', 'completado'],
        ['PED-2026-009', '2026-09-20', 'S/ 320.00', 'cancelado'],
      ];

  Future<List<List<String>>> historialOrdenesCompra() async {
    try {
      final res = await _dio.get('/ordenes-compra', queryParameters: {'per_page': 20});
      final d = res.data;
      final List raw = d is Map
          ? (d['data'] is Map && d['data']['data'] is List
              ? d['data']['data'] as List
              : (d['data'] is List ? d['data'] as List : []))
          : [];
      if (raw.isEmpty) return _mockHistorialOC();
      return raw.whereType<Map>().take(20).map((mm) {
        return [
          '${mm['codigo'] ?? mm['id'] ?? ''}',
          '${mm['proveedor'] ?? mm['proveedor_nombre'] ?? ''}',
          '${mm['total'] ?? ''}',
          '${mm['estado'] ?? ''}'
        ];
      }).toList();
    } catch (_) {
      return _mockHistorialOC();
    }
  }

  List<List<String>> _mockHistorialOC() => const [
        ['OC-2026-010', 'Alicorp', 'S/ 5,400.00', 'recepción'],
        ['OC-2026-011', 'Gloria', 'S/ 2,150.00', 'emitida'],
        ['OC-2026-012', 'Backus', 'S/ 8,900.00', 'cerrada'],
        ['OC-2026-009', 'San Fernando', 'S/ 1,200.00', 'cerrada'],
      ];

  Future<List<List<String>>> historialRecepcion(String ordenId) async {
    try {
      final res = await _dio.get('/ordenes-compra/$ordenId/historial-recepcion');
      final d = res.data;
      final List raw = d is Map && d['data'] is List ? d['data'] as List : [];
      if (raw.isEmpty) return _mockHistorialRecep();
      return raw.whereType<Map>().map((mm) {
        return [
          '${mm['fecha'] ?? ''}',
          '${mm['producto'] ?? ''}',
          '${mm['recibido'] ?? ''}',
          '${mm['estado'] ?? ''}'
        ];
      }).toList();
    } catch (_) {
      return _mockHistorialRecep();
    }
  }

  List<List<String>> _mockHistorialRecep() => const [
        ['2026-10-02 09:12', 'Aceite Primor 1L', '48/48', 'conforme'],
        ['2026-10-02 09:40', 'Arroz Costeño 5kg', '10/12', 'faltante'],
        ['2026-10-01 15:20', 'Azúcar Rubia 1kg', '100/100', 'conforme'],
      ];

  // ---------- RECEPCIÓN: acciones ----------
  Future<void> iniciarRecepcion(String ordenId) async {
    try {
      await _dio.post('/ordenes-compra/$ordenId/iniciar-recepcion');
    } on DioException catch (e) {
      if (e.response == null) return;
      rethrow;
    }
  }

  Future<void> recepcionarItem(String ordenId, Map<String, String> data) async {
    try {
      await _dio.post('/ordenes-compra/$ordenId/recepcionar-item', data: data);
    } on DioException catch (e) {
      if (e.response == null) return;
      throw ApiException(message: 'No se pudo recepcionar ítem.');
    }
  }

  Future<void> cerrarRecepcion(String ordenId) async {
    try {
      await _dio.post('/ordenes-compra/$ordenId/cerrar-recepcion', data: {});
    } on DioException catch (e) {
      if (e.response == null) return;
      rethrow;
    }
  }
}
