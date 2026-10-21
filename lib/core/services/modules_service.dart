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

  // ---- CAPA DE RENDIMIENTO: caché, deduplicación y corte de circuito ----
  // · Las lecturas GET se sirven de memoria mientras sigan vigentes.
  // · Ráfagas de GET idénticos comparten un único request (dedup).
  // · Si el backend deja de responder, se atiende con caché/mocks durante
  //   una ventana corta en vez de castigar la navegación con timeouts.
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, Future<dynamic>> _enVuelo = {};
  DateTime? _sinRedHasta;

  static const Duration _ttlListas = Duration(seconds: 60);
  static const Duration _ttlOperativo = Duration(seconds: 20);
  static const Duration _ttlCatalogos = Duration(minutes: 5);
  static const Duration _ventanaSinRed = Duration(seconds: 20);

  bool get _sinRed =>
      _sinRedHasta != null && DateTime.now().isBefore(_sinRedHasta!);

  void _marcarSinRed() => _sinRedHasta = DateTime.now().add(_ventanaSinRed);
  void _marcarConRed() => _sinRedHasta = null;

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
      onResponse: (r, h) {
        // Toda escritura invalida las lecturas cacheadas.
        if (r.requestOptions.method != 'GET') _cache.clear();
        _marcarConRed();
        return h.next(r);
      },
      onError: (e, h) {
        // response == null ⇒ error de red → activa el corte de circuito.
        if (e.response == null) {
          _marcarSinRed();
        } else {
          _marcarConRed();
        }
        return h.next(e);
      },
    ));
  }

  // ---------------------- utilidades de la capa GET ----------------------

  static String _clave(String path, Map<String, dynamic> clean) {
    if (clean.isEmpty) return path;
    final partes = clean.entries.map((e) => '${e.key}=${e.value}').toList()
      ..sort();
    return '$path?${partes.join('&')}';
  }

  /// Limpia la caché de lecturas (usar en pull-to-refresh manual).
  void limpiarCache() => _cache.clear();

  /// GET con caché + deduplicación + corte de circuito.
  /// [porDefecto] se usa como respaldo cuando la lectura no puede traer datos
  /// nuevos (sin red o sin caché previa). Si es null, el error se propaga.
  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? query,
    Duration ttl = _ttlListas,
    required T Function(dynamic data) decode,
    T? porDefecto,
  }) {
    final clean = <String, dynamic>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) clean[k] = v;
    });
    final clave = _clave(path, clean);

    final hit = _cache[clave];
    if (hit != null && DateTime.now().isBefore(hit.expira)) {
      return Future.value(hit.valor as T);
    }

    final vuelo = _enVuelo[clave];
    if (vuelo != null) return vuelo.then((v) => v as T);

    if (_sinRed) {
      if (hit != null) return Future.value(hit.valor as T);
      if (porDefecto != null) return Future.value(porDefecto);
    }

    final futuro = () async {
      try {
        final res = await _dio.get(path,
            queryParameters: clean.isEmpty ? null : clean);
        final valor = decode(res.data);
        _cache[clave] = _CacheEntry(valor, DateTime.now().add(ttl));
        return valor;
      } on DioException {
        if (hit != null) return hit.valor as T;
        if (porDefecto != null) return porDefecto;
        rethrow;
      } finally {
        _enVuelo.remove(clave);
      }
    }();

    _enVuelo[clave] = futuro;
    return futuro;
  }

  /// Calienta en segundo plano las lecturas más usadas (tras el login).
  /// Se ejecuta en secuencia para no saturar al servidor de desarrollo.
  Future<void> precargar() async {
    if (SessionService.token == null) return;
    final tareas = <Future<dynamic>>[
      clientes(),
      productosCatalogo(),
      pedidos(),
      ordenesCompra(),
      productos(),
      proveedores(),
      categorias(),
      zonasDeliveryActivas(),
    ];
    for (final t in tareas) {
      try {
        await t;
      } catch (_) {
        // La precarga es best-effort: jamás debe romper la app.
      }
    }
  }

  @visibleForTesting
  void debugReiniciar({HttpClientAdapter? adapter}) {
    _cache.clear();
    _enVuelo.clear();
    _sinRedHasta = null;
    if (adapter != null) _dio.httpClientAdapter = adapter;
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
  }) {
    return _get<List<ErpItem>>(
      path,
      query: query,
      decode: (d) {
        final raw = _extractList(d);
        return raw.map(mapper).toList();
      },
      // El mock solo entra cuando la lectura falla (sin backend), nunca
      // cuando el backend responde con una lista legítimamente vacía.
      porDefecto: mock,
    );
  }

  Map<String, dynamic> _tabQuery(String tab) {
    final t = tab.toLowerCase().trim();
    if (t.contains('elimin')) return {'eliminados': 1, 'per_page': 50};
    if (t.contains('inact')) return {'estado': 'I', 'per_page': 50};
    if (t.contains('activ')) return {'estado': 'A', 'per_page': 50};
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

  static String _normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[áàäâ]'), 'a');
    s = s.replaceAll(RegExp(r'[éèëê]'), 'e');
    s = s.replaceAll(RegExp(r'[íìïî]'), 'i');
    s = s.replaceAll(RegExp(r'[óòöô]'), 'o');
    s = s.replaceAll(RegExp(r'[úùüû]'), 'u');
    s = s.replaceAll(RegExp(r'[ñ]'), 'n');
    return s;
  }

  @visibleForTesting
  static String debugNormalizar(String s) => _normalize(s);

  // ---------- CLIENTES (GET /clientes) ----------
  Future<List<ErpItem>> clientes({String search = '', String tab = 'Activos'}) async {
    final q = search.trim();
    final items = await _getList(
      '/clientes',
      ErpItem.fromCliente,
      query: {'search': q, ..._tabQuery(tab), 'per_page': 50},
      mock: List.generate(
        6,
        (i) => ErpItem(
            id: 'CLI-0000$i',
            titulo: ['Bodega San Juan', 'Minimarket El Ahorro', 'Librería Central', 'Farmacia Vida', 'Restaurante Sabor', 'Colegio San Pedro'][i],
            subtitulo: ['RUC 20123456780 • Tel: 987654321 • Av. Lima 123', 'DNI 45678901 • Tel: 998877665 • Jr. Unión 456', 'RUC 20987654321 • Tel: 912345678 • Av. Grau 789', 'DNI 71234567 • Tel: 944556677 • Calle Real 321', 'RUC 20456789123 • Tel: 933221100 • Av. Arequipa 555', 'RUC 20543218901 • Tel: 922110033 • Av. Tacna 888'][i],
            monto: '',
            estado: i == 4 ? 'inactivo' : 'activo'),
      ),
    );

    if (q.isEmpty) return items;

    final normQ = _normalize(q);
    final hasMatches = items.any((e) =>
        _normalize(e.titulo).contains(normQ) ||
        _normalize(e.subtitulo).contains(normQ) ||
        _normalize(e.id).contains(normQ));

    if (hasMatches && items.isNotEmpty) {
      return items;
    }

    // Fallback tolerante para Postgres (LIKE case-sensitive):
    // Cargar catálogo completo y filtrar sin distinción de mayúsculas/minúsculas ni tildes
    final allItems = await _getList(
      '/clientes',
      ErpItem.fromCliente,
      query: {'search': '', ..._tabQuery(tab), 'per_page': 100},
      mock: items,
    );

    return allItems.where((e) {
      final t = _normalize(e.titulo);
      final s = _normalize(e.subtitulo);
      final id = _normalize(e.id);
      final rawStr = _normalize(e.raw.values.map((v) => '$v').join(' '));
      return t.contains(normQ) || s.contains(normQ) || id.contains(normQ) || rawStr.contains(normQ);
    }).toList();
  }

  // ---------- PROVEEDORES ----------
  Future<List<ErpItem>> proveedores({String search = '', String tab = 'Activos'}) async {
    final q = search.trim();
    final items = await _getList(
      '/proveedores',
      ErpItem.fromProveedor,
      query: {'search': q, ..._tabQuery(tab)},
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

    if (q.isEmpty) return items;

    final normQ = _normalize(q);
    final hasMatches = items.any((e) =>
        _normalize(e.titulo).contains(normQ) ||
        _normalize(e.subtitulo).contains(normQ) ||
        _normalize(e.id).contains(normQ));

    if (hasMatches && items.isNotEmpty) return items;

    final allItems = await _getList(
      '/proveedores',
      ErpItem.fromProveedor,
      query: {'search': '', ..._tabQuery(tab)},
      mock: items,
    );

    return allItems.where((e) {
      final t = _normalize(e.titulo);
      final s = _normalize(e.subtitulo);
      final id = _normalize(e.id);
      final rawStr = _normalize(e.raw.values.map((v) => '$v').join(' '));
      return t.contains(normQ) || s.contains(normQ) || id.contains(normQ) || rawStr.contains(normQ);
    }).toList();
  }

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
  Future<List<ErpItem>> pedidos({String search = '', String tab = 'Todos'}) async {
    final list = await _getList(
      '/pedidos',
      ErpItem.fromPedido,
      query: {'search': search, 'per_page': 50},
      mock: [
        ErpItem(id: 'PED-00001', titulo: 'PED-00001', subtitulo: 'Bodega San Juan • 01/10/2026', monto: 'S/ 450.00', estado: 'pendiente'),
        ErpItem(id: 'PED-00002', titulo: 'PED-00002', subtitulo: 'Minimarket El Ahorro • Hoy', monto: 'S/ 1,200.00', estado: 'preparación'),
        ErpItem(id: 'PED-00003', titulo: 'PED-00003', subtitulo: 'Librería Central • Ayer', monto: 'S/ 380.00', estado: 'completado'),
      ].where((e) => search.isEmpty || e.titulo.toLowerCase().contains(search.toLowerCase()) || e.subtitulo.toLowerCase().contains(search.toLowerCase())).toList(),
    );
    final t = tab.toLowerCase().trim();
    if (t == 'todos' || t.isEmpty) return list;
    if (t.contains('pend')) {
      return list.where((e) {
        final st = e.estado.toLowerCase();
        return st.contains('pend') || st.contains('prep') || st.contains('emit');
      }).toList();
    }
    if (t.contains('complet') || t.contains('entreg')) {
      return list.where((e) {
        final st = e.estado.toLowerCase();
        return st.contains('comp') || st.contains('entr') || st.contains('cerr');
      }).toList();
    }
    if (t.contains('cancel') || t.contains('anul')) {
      return list.where((e) {
        final st = e.estado.toLowerCase();
        return st.contains('canc') || st.contains('anul');
      }).toList();
    }
    return list;
  }

  // ---------- ÓRDENES COMPRA (OrdenCompraResource) ----------
  Future<List<ErpItem>> ordenesCompra({String search = '', String tab = 'Todas'}) async {
    final list = await _getList(
      '/ordenes-compra',
      ErpItem.fromOrdenCompra,
      query: {'search': search, 'per_page': 50},
      mock: [
        ErpItem(id: 'OC-00001', titulo: 'OC-00001', subtitulo: 'Alicorp • 12 ítems', monto: 'S/ 5,400.00', estado: 'emitida'),
        ErpItem(id: 'OC-00002', titulo: 'OC-00002', subtitulo: 'Gloria • 8 ítems', monto: 'S/ 2,150.00', estado: 'emitida'),
        ErpItem(id: 'OC-00003', titulo: 'OC-00003', subtitulo: 'Backus • 20 ítems', monto: 'S/ 8,900.00', estado: 'cerrada'),
      ],
    );
    final t = tab.toLowerCase().trim();
    if (t == 'todas' || t == 'todos' || t.isEmpty) return list;
    if (t.contains('pend') || t.contains('emit')) {
      return list.where((e) {
        final st = e.estado.toLowerCase();
        return st.contains('pend') || st.contains('emit') || st.contains('recep');
      }).toList();
    }
    if (t.contains('cerrad') || t.contains('complet')) {
      return list.where((e) => e.estado.toLowerCase().contains('cerr') || e.estado.toLowerCase().contains('comp')).toList();
    }
    if (t.contains('anul') || t.contains('cancel')) {
      return list.where((e) {
        final st = e.estado.toLowerCase();
        return st.contains('anul') || st.contains('canc');
      }).toList();
    }
    return list;
  }

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

  // ---------- SUNAT / RENIEC: búsqueda oficial por documento ----------

  /// Consulta un RUC (11 dígitos) o DNI (8 dígitos) ante SUNAT/RENIEC a
  /// través del backend y devuelve los datos normalizados para
  /// autocompletar el formulario de [target] ('cliente' o 'proveedor').
  Future<SunatConsulta> consultarDocumentoSunat(
    String documento, {
    String target = 'cliente',
    bool refrescar = false,
  }) async {
    final doc = documento.trim();
    try {
      return await _get<SunatConsulta>(
        '/sunat/ruc/$doc',
        query: {'target': target, if (refrescar) 'refresh': '1'},
        // El backend ya cachea en BD; aquí solo evitamos repetir en sesión.
        ttl: const Duration(minutes: 30),
        decode: (d) {
          if (d is! Map) {
            throw ApiException(
                message: 'Respuesta inesperada del servicio SUNAT.');
          }
          if (d['success'] == false) {
            throw ApiException(
                message:
                    '${d['message'] ?? 'No se pudo consultar el documento.'}');
          }
          final payload = d['data'] is Map
              ? Map<String, dynamic>.from(d['data'] as Map)
              : <String, dynamic>{};
          return SunatConsulta.desdePayload(payload, doc, target);
        },
      );
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      throw ApiException(
          message: d is Map && d['message'] != null
              ? '${d['message']}'
              : 'No se pudo consultar el documento en SUNAT.');
    }
  }

  // ---------- CLIENTES / PROVEEDORES: alta y edición ----------

  /// Registra ([id] == null) o actualiza un cliente en el backend.
  Future<void> guardarCliente(Map<String, String> data, {String? id}) =>
      _guardarRegistro('/clientes', data,
          id: id, fallback: 'No se pudo guardar el cliente.');

  /// Registra ([id] == null) o actualiza un proveedor en el backend.
  Future<void> guardarProveedor(Map<String, String> data, {String? id}) =>
      _guardarRegistro('/proveedores', data,
          id: id, fallback: 'No se pudo guardar el proveedor.');

  Future<void> _guardarRegistro(
    String path,
    Map<String, String> data, {
    String? id,
    required String fallback,
  }) async {
    try {
      final res = id == null
          ? await _dio.post(path, data: data)
          : await _dio.put('$path/$id', data: data);
      final d = res.data;
      if (d is Map && d['success'] == false) {
        throw ApiException(message: _mensajeError(d, fallback));
      }
    } on DioException catch (e) {
      // Offline: se acepta como guardado local (igual que crear/actualizar).
      if (e.response == null) return;
      throw ApiException(message: _mensajeError(e.response?.data, fallback));
    }
  }

  /// Extrae el primer mensaje útil de una respuesta de error del backend.
  String _mensajeError(dynamic d, String fallback) {
    if (d is Map) {
      final errs = d['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) return '${first.first}';
        return '$first';
      }
      if (d['message'] != null) return '${d['message']}';
    }
    return fallback;
  }

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
  Future<Map<String, dynamic>> obtenerEmpresa() {
    return _get<Map<String, dynamic>>(
      '/empresa',
      ttl: _ttlCatalogos,
      decode: (d) {
        if (d is Map && d['data'] is Map) {
          return Map<String, dynamic>.from(d['data'] as Map);
        }
        if (d is Map) return Map<String, dynamic>.from(d);
        return {};
      },
      porDefecto: const {
        'EmpresaRuc': '20123456789',
        'EmpresaRazonSocial': 'Comercial Valencia SAC (demo)',
        'EmpresaNombreComercial': 'Comercial Valencia',
        'EmpresaDireccion': 'Av. Principal 123',
        'EmpresaTelefono': '012345678',
        'EmpresaEmail': 'contacto@valencia.pe',
      },
    );
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
        final totalRaw = mm['total'] ?? mm['PedidoTotal'];
        final total = totalRaw != null ? 'S/ $totalRaw'.replaceAll('S/ S/ ', 'S/ ') : '';
        final fecha = ErpItem.formatDate(mm['fecha'] ?? mm['PedidoFecha_pedido'] ?? mm['created_at']);
        final estado = '${mm['estado_texto'] ?? mm['estado'] ?? mm['PedidoEstado_pedido'] ?? 'completado'}';
        return [
          '${mm['codigo'] ?? mm['id'] ?? 'PED'}',
          fecha.isNotEmpty ? fecha : '—',
          total,
          estado
        ];
      }).toList();
    } catch (_) {
      return _mockHistorialPedidos();
    }
  }

  List<List<String>> _mockHistorialPedidos() => const [
        ['PED-2026-001', '01/10/2026', 'S/ 450.00', 'completado'],
        ['PED-2026-004', '28/09/2026', 'S/ 890.00', 'completado'],
        ['PED-2026-009', '20/09/2026', 'S/ 320.00', 'cancelado'],
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
        String provNombre = '';
        final prov = mm['proveedor'];
        if (prov is Map) {
          provNombre = '${prov['razon_social'] ?? prov['nombre'] ?? prov['ProveedorRazonSocial'] ?? prov['ruc'] ?? ''}'.trim();
        } else if (prov != null) {
          provNombre = prov.toString().trim();
        }
        if (provNombre.isEmpty) {
          provNombre = '${mm['proveedor_nombre'] ?? ''}'.trim();
        }

        final codigo = '${mm['codigo'] ?? mm['id'] ?? 'OC'}';
        final totalRaw = mm['total'] ?? mm['Orden_CompraTotal'];
        final total = totalRaw != null ? 'S/ $totalRaw'.replaceAll('S/ S/ ', 'S/ ') : '';
        final estado = '${mm['estado_texto'] ?? mm['estado'] ?? mm['Orden_CompraEstado'] ?? 'emitida'}';

        return [
          codigo,
          provNombre.isNotEmpty ? provNombre : 'Proveedor',
          total,
          estado,
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

  /// Detalle crudo de una orden de compra (OrdenCompraResource con `detalles`).
  Future<Map<String, dynamic>> ordenCompraDetalle(String id) async {
    try {
      return await _get<Map<String, dynamic>>(
        '/ordenes-compra/$id',
        ttl: _ttlOperativo,
        decode: (d) => d is Map && d['data'] is Map
            ? Map<String, dynamic>.from(d['data'] as Map)
            : const <String, dynamic>{},
      );
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      throw ApiException(
          message: d is Map && d['message'] != null
              ? '${d['message']}'
              : 'No se pudo cargar la orden de compra.');
    }
  }

  /// Órdenes de compra más recientes (crudas) para la bandeja de recepción.
  Future<List<Map<String, dynamic>>> recepcionOrdenes(
      {String search = '', int perPage = 50}) {
    return _get<List<Map<String, dynamic>>>(
      '/ordenes-compra',
      query: {if (search.isNotEmpty) 'search': search, 'per_page': perPage},
      ttl: _ttlOperativo,
      decode: (d) {
        final list = _extractList(d);
        list.sort((a, b) {
          final fa = DateTime.tryParse(
                  '${a['fecha'] ?? a['fecha_formateada'] ?? ''}') ??
              DateTime(1970);
          final fb = DateTime.tryParse(
                  '${b['fecha'] ?? b['fecha_formateada'] ?? ''}') ??
              DateTime(1970);
          return fb.compareTo(fa);
        });
        return list;
      },
      porDefecto: const [],
    );
  }

  /// Recepciona un ítem: incrementa stock físico y asienta entrada en Kárdex.
  Future<void> recepcionarItem(String ordenId,
      {required String detalleId, required double cantidad}) async {
    await _postAccion(
      '/ordenes-compra/$ordenId/recepcionar-item',
      {'detalle_id': detalleId, 'cantidad_recibida': cantidad},
      'No se pudo recepcionar el ítem.',
    );
  }

  /// Rechaza formalmente un ítem de la orden (no ingresa al almacén).
  Future<void> rechazarItemRecepcion(String ordenId,
      {required String detalleId,
      String motivo = 'Producto rechazado en recepción'}) async {
    await _postAccion(
      '/ordenes-compra/$ordenId/rechazar-item',
      {'detalle_id': detalleId, 'motivo': motivo},
      'No se pudo rechazar el producto.',
    );
  }

  /// Cierra la recepción (Cerrada Conforme / Cerrada con Faltante).
  Future<Map<String, dynamic>> cerrarRecepcion(String ordenId) async {
    try {
      final res = await _dio.post('/ordenes-compra/$ordenId/cerrar-recepcion',
          data: {});
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return const {'success': true};
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = 'No se pudo cerrar la recepción.';
      if (d is Map) {
        final errs = d['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (d['message'] != null) {
          msg = '${d['message']}';
        }
      }
      throw ApiException(message: msg);
    }
  }

  /// POST genérico para acciones de recepción con mensaje de error claro.
  Future<void> _postAccion(
      String path, Map<String, dynamic> data, String fallback) async {
    try {
      await _dio.post(path, data: data);
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = fallback;
      if (d is Map) {
        final errs = d['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (d['message'] != null) {
          msg = '${d['message']}';
        }
      }
      throw ApiException(message: msg);
    }
  }

  // ---------- COMPRAS: alta de órdenes ----------
  /// Nueva orden de compra tradicional (proveedor + productos + fecha estimada).
  Future<Map<String, dynamic>> crearOrdenCompraProceso(
          Map<String, dynamic> payload) =>
      _postProceso(
          '/ordenes-compra', payload, 'No se pudo registrar la orden de compra.');

  /// Compra rápida a PYME Vecina con ingreso inmediato a stock y Kárdex.
  Future<Map<String, dynamic>> compraRapidaProceso(
          Map<String, dynamic> payload) =>
      _postProceso('/ordenes-compra/compra-rapida', payload,
          'No se pudo registrar la compra rápida.');

  /// POST genérico con respuesta (message/errors) para altas del proceso.
  Future<Map<String, dynamic>> _postProceso(
      String path, Map<String, dynamic> payload, String fallback) async {
    try {
      final res = await _dio.post(path, data: payload);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return const {'success': true};
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = fallback;
      if (d is Map) {
        final errs = d['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (d['message'] != null) {
          msg = '${d['message']}';
        }
      }
      throw ApiException(message: msg);
    }
  }

  // ---------- STOCK Y PRODUCTOS: catálogo paginado (15 en 15) ----------
  /// Página del catálogo de productos activos con su stock y presentaciones.
  Future<Map<String, dynamic>> productosPagina({
    String search = '',
    int page = 1,
    int perPage = 15,
  }) async {
    try {
      final res = await _dio.get('/inventario/productos', queryParameters: {
        if (search.isNotEmpty) 'search': search,
        'estado': 'A',
        'page': page,
        'per_page': perPage,
      });
      final d = res.data;
      final data = d is Map ? d['data'] : null;
      if (data is Map) {
        final rawItems = data['data'];
        final items = rawItems is List
            ? rawItems
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : <Map<String, dynamic>>[];
        return {
          'items': items,
          'lastPage': (data['last_page'] is num)
              ? (data['last_page'] as num).toInt()
              : page,
          'total': (data['total'] is num) ? (data['total'] as num).toInt() : 0,
          'currentPage': (data['current_page'] is num)
              ? (data['current_page'] as num).toInt()
              : page,
        };
      }
      if (data is List) {
        final items = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return {
          'items': items,
          'lastPage': 1,
          'total': items.length,
          'currentPage': 1,
        };
      }
      return {
        'items': <Map<String, dynamic>>[],
        'lastPage': page,
        'total': 0,
        'currentPage': page,
      };
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      throw ApiException(
          message: d is Map && d['message'] != null
              ? '${d['message']}'
              : 'No se pudo cargar el catálogo de productos.');
    }
  }

  // ---------- KARDEX (tabla con filtros de fecha y tipo) ----------
  Future<List<Map<String, dynamic>>> kardexMovimientos({
    String? tipo,
    String? fechaDesde,
    String? fechaHasta,
    int perPage = 60,
  }) async {
    try {
      final res = await _dio.get('/inventario/movimientos', queryParameters: {
        if (tipo != null && tipo.isNotEmpty) 'tipoMovimiento': tipo,
        if (fechaDesde != null && fechaDesde.isNotEmpty) 'fechaDesde': fechaDesde,
        if (fechaHasta != null && fechaHasta.isNotEmpty) 'fechaHasta': fechaHasta,
        'per_page': perPage,
      });
      return _extractList(res.data);
    } catch (e) {
      debugPrint('[ModulesService] kardex offline: $e');
      return [];
    }
  }

  // ---------- CATÁLOGO PRODUCTOS (solo consulta, con presentaciones) ----------
  Future<List<Map<String, dynamic>>> productosCatalogo() async {
    try {
      final res = await _dio.get('/inventario/productos-select');
      return _extractList(res.data);
    } catch (e) {
      debugPrint('[ModulesService] catálogo productos offline: $e');
      return [];
    }
  }

  // ---------- ZONAS DE DELIVERY ACTIVAS ----------
  Future<List<Map<String, dynamic>>> zonasDeliveryActivas() async {
    try {
      final res = await _dio.get('/zonas-delivery/activas');
      return _extractList(res.data);
    } catch (e) {
      debugPrint('[ModulesService] zonas delivery offline: $e');
      return [];
    }
  }

  // ---------- NUEVO PEDIDO (proceso completo de la web) ----------
  Future<Map<String, dynamic>> crearPedidoProceso(Map<String, dynamic> payload) async {
    try {
      final res = await _dio.post('/pedidos', data: payload);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return const {'success': true};
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = 'No se pudo guardar el pedido.';
      if (d is Map) {
        final errs = d['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (d['message'] != null) {
          msg = '${d['message']}';
        }
      }
      throw ApiException(message: msg);
    }
  }

  /// Detalle completo de un pedido (PedidoResource: cliente, zonas,
  /// delivery y líneas de producto). Usado por el modal de detalle y por
  /// el modo edición del wizard de pedidos.
  Future<Map<String, dynamic>> pedidoDetalle(String pedidoId) async {
    try {
      final res = await _dio.get('/pedidos/$pedidoId');
      final d = res.data;
      if (d is Map && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      return const {};
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = 'No se pudo cargar el detalle del pedido.';
      if (d is Map && d['message'] != null) msg = '${d['message']}';
      throw ApiException(message: msg);
    }
  }

  /// Actualiza un pedido existente (PUT /pedidos/{id}): campos de cabecera,
  /// cliente, delivery y acciones de productos (agregar/eliminar).
  Future<Map<String, dynamic>> actualizarPedidoProceso(
      String pedidoId, Map<String, dynamic> payload) async {
    try {
      final res = await _dio.put('/pedidos/$pedidoId', data: payload);
      final d = res.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return const {'success': true};
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
            message: 'Sin conexión con el servidor. Intenta nuevamente.');
      }
      final d = e.response?.data;
      var msg = 'No se pudo actualizar el pedido.';
      if (d is Map) {
        final errs = d['errors'];
        if (errs is Map && errs.isNotEmpty) {
          final first = errs.values.first;
          msg = first is List && first.isNotEmpty ? '${first.first}' : '$first';
        } else if (d['message'] != null) {
          msg = '${d['message']}';
        }
      }
      throw ApiException(message: msg);
    }
  }

  // ---------- DESPACHO (bandeja + cierre por ítems) ----------
  Future<List<Map<String, dynamic>>> despachoPedidos({
    String search = '',
    String? fechaDesde,
    String? fechaHasta,
    int perPage = 60,
  }) async {
    try {
      final res = await _dio.get('/despacho/pedidos', queryParameters: {
        if (search.isNotEmpty) 'search': search,
        if (fechaDesde != null && fechaDesde.isNotEmpty) 'fecha_desde': fechaDesde,
        if (fechaHasta != null && fechaHasta.isNotEmpty) 'fecha_hasta': fechaHasta,
        'per_page': perPage,
      });
      return _extractList(res.data);
    } catch (e) {
      debugPrint('[ModulesService] despacho offline: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> despachoDetalle(String pedidoId) async {
    try {
      final res = await _dio.get('/despacho/pedidos/$pedidoId');
      final d = res.data;
      if (d is Map && d['data'] is Map) {
        return Map<String, dynamic>.from(d['data'] as Map);
      }
      return {};
    } on DioException catch (e) {
      throw ApiException(
          message: e.response?.data?['message']?.toString() ??
              'No se pudo cargar el detalle del pedido.');
    }
  }

  Future<void> despachoCompletar(String pedidoId, {String? observacion}) async {
    try {
      await _dio.post('/despacho/pedidos/$pedidoId/completar',
          data: {
            if (observacion != null && observacion.isNotEmpty)
              'observacion': observacion
          });
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(message: 'Sin conexión con el servidor.');
      }
      final status = e.response?.statusCode;
      final msg = e.response?.data?['message']?.toString();
      if (status == 409) {
        throw ApiException(
            message: msg ?? 'Este pedido ya fue procesado previamente.');
      }
      throw ApiException(message: msg ?? 'No se pudo cerrar el despacho.');
    }
  }

  Future<void> despachoFaltante(
    String pedidoId, {
    required String observacion,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      await _dio.post('/despacho/pedidos/$pedidoId/faltante',
          data: {'observacion': observacion, 'items': items});
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(message: 'Sin conexión con el servidor.');
      }
      final status = e.response?.statusCode;
      final msg = e.response?.data?['message']?.toString();
      if (status == 409) {
        throw ApiException(
            message: msg ?? 'Este pedido ya fue procesado previamente.');
      }
      throw ApiException(
          message: msg ?? 'No se pudo cerrar el despacho con faltante.');
    }
  }

  // =========================================================================
  // VALENCIA VISION (Gemini 1.5 Flash 1-Tile)
  // =========================================================================

  /// Procesa una imagen de lista de compras o productos mediante visión por computadora.
  Future<Map<String, dynamic>> procesarPedidoVision({
    required String base64Image,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final res = await _dio.post(
        '/vision/procesar-pedido',
        data: {
          'imagen_base64': base64Image,
          'mime_type': mimeType,
        },
      );
      if (res.data != null && res.data['success'] == true) {
        return Map<String, dynamic>.from(res.data['data'] ?? {});
      }
      throw ApiException(
        message: res.data?['message']?.toString() ??
            'Error al interpretar la imagen.',
      );
    } on DioException catch (e) {
      if (e.response == null) {
        throw ApiException(
          message: 'Sin conexión con el servidor para procesar visión.',
        );
      }
      final msg = e.response?.data?['message']?.toString();
      throw ApiException(
        message: msg ?? 'Error al procesar la imagen con IA.',
      );
    }
  }

  /// Auditoría opcional explícita de discrepancia para investigación de tesis.
  Future<Map<String, dynamic>> auditarResultadoVision({
    required String tokenAuditoria,
    required String pedidoId,
    required List<Map<String, dynamic>> itemsGuardados,
  }) async {
    try {
      final res = await _dio.post(
        '/vision/auditar-resultado',
        data: {
          'token_auditoria': tokenAuditoria,
          'pedido_id': pedidoId,
          'items_guardados': itemsGuardados,
        },
      );
      return Map<String, dynamic>.from(res.data?['data'] ?? {});
    } catch (_) {
      return {};
    }
  }
}

/// Entrada de la caché de lecturas (valor + vencimiento) del servicio ERP.
class _CacheEntry {
  final dynamic valor;
  final DateTime expira;
  const _CacheEntry(this.valor, this.expira);
}
