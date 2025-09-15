import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/services/crm_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool get _isConductor => (TokenStorage.currentRole ?? '').toLowerCase().contains('conductor');
  bool get _isAdminOrSuper {
    final role = (TokenStorage.currentRole ?? '').toLowerCase();
    return role == 'admin' || role.contains('super');
  }
  bool get _isSuperAdmin => (TokenStorage.currentRole ?? '').toLowerCase().contains('super');
  bool get _isComercial => (TokenStorage.currentRole ?? '').toLowerCase() == 'comercial';
  bool _initializing = false;
  List<Map<String, dynamic>> _companies = const [];
  int? _selectedCompanyId;
  void _log(String message) { debugPrint('[Home] ' + message); }
  // Dashboard metrics
  String _metricDrivers = '—';
  String _metricVehicles = '—';
  String _metricActiveOrders = '—';
  // Assigned orders for conductor
  List<Map<String, dynamic>> _assignedOrders = const [];
  bool _ordersLoading = false;
  // Comercial data
  final CrmService _crm = CrmService();
  List<Map<String, dynamic>> _quotes = const [];
  List<Map<String, dynamic>> _orders = const [];
  List<Map<String, dynamic>> _clients = const [];
  bool _commercialLoading = false;

  @override
  void initState() {
    super.initState();
    _maybeFetchRole();
    if (_isSuperAdmin) {
      _loadCompaniesStandalone();
    }
    // Attempt initial dashboard load (will work if token/base are ready)
    _loadDashboard();
    if (_isConductor) _loadAssignedOrders();
    if (_isComercial) _loadCommercialData();
  }

  Future<void> _maybeFetchRole() async {
    if ((TokenStorage.currentRole ?? '').isEmpty) {
      setState(() => _initializing = true);
      try {
        final rawBase = dotenv.env['API_BASE_URL'];
        final token = TokenStorage.token;
        if (rawBase != null && rawBase.isNotEmpty && token != null) {
          final dio = Dio(BaseOptions(
            baseUrl: resolveBaseUrlForPlatform(rawBase),
            headers: {'Authorization': 'Bearer $token'},
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 15),
          ));
          final res = await dio.get('me');
          final Map<String, dynamic> data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
          final String? role = (data['role'] ?? (data['roles'] is List ? (data['roles'] as List).first : null))?.toString();
          final String? companyId = (data['company_id'] ?? data['companyId'])?.toString();
          TokenStorage.setRoleAndCompany(role: role, companyId: companyId);
          _log('me -> role=' + (role?.toString() ?? 'null') + ', companyId=' + (companyId?.toString() ?? 'null'));
          if ((role ?? '').toLowerCase().contains('super')) {
            final cres = await dio.get('companies');
            final List cl = (cres.data as List?) ?? [];
            _companies = cl.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
            if (_companies.isNotEmpty) {
              _selectedCompanyId = (_companies.first['id'] as num).toInt();
              _log('companies loaded: count=' + _companies.length.toString() + ', firstId=' + _selectedCompanyId.toString());
            }
          }
          // Load dashboard after role/company retrieved
          await _loadDashboard(companyId: _selectedCompanyId);
          if (((role ?? '').toLowerCase()).contains('conductor')) {
            await _loadAssignedOrders();
          }
          if (((role ?? '').toLowerCase()) == 'comercial') {
            await _loadCommercialData();
          }
        }
      } catch (_) {
        // ignora errores silenciosamente; el layout por defecto seguirá mostrándose
      } finally {
        if (mounted) setState(() => _initializing = false);
      }
    }
  }

  Future<void> _loadCompaniesStandalone() async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || rawBase.isEmpty || token == null) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final cres = await dio.get('companies');
      final List cl = (cres.data as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _companies = cl.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
        if (_companies.isNotEmpty) {
          _selectedCompanyId = (_companies.first['id'] as num).toInt();
        }
      });
      _log('companies standalone loaded: ' + _companies.length.toString());
      await _loadDashboard(companyId: _selectedCompanyId);
    } catch (_) {}
  }

  Future<void> _loadDashboard({int? companyId}) async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || rawBase.isEmpty || token == null) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final qp = <String, dynamic>{ if (companyId != null) 'company_id': companyId };
      _log('GET dashboard with query: ' + qp.toString());
      final res = await dio.get('dashboard', queryParameters: qp);
      final Map<String, dynamic> data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      _log('dashboard response: ' + data.toString());
      if (!mounted) return;
      setState(() {
        _metricDrivers = (data['conductores'] ?? data['drivers'] ?? '—').toString();
        _metricVehicles = (data['vehiculos'] ?? data['vehicles'] ?? '—').toString();
        _metricActiveOrders = (data['ordenes_activas'] ?? data['active_orders'] ?? '—').toString();
      });
    } on DioException catch (e) {
      _log('dashboard error: code=' + (e.response?.statusCode?.toString() ?? 'null') + ', body=' + (e.response?.data?.toString() ?? e.message ?? 'error'));
      if (!mounted) return;
      setState(() {
        _metricDrivers = '0';
        _metricVehicles = '0';
        _metricActiveOrders = '0';
      });
      final code = e.response?.statusCode ?? 0;
      final msg = (e.response?.data is Map && e.response?.data['detail'] != null)
          ? e.response?.data['detail'].toString()
          : 'Error $code';
      // Mostrar aviso solo cuando el endpoint no existe o falla
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dashboard no disponible: $msg')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _metricDrivers = '0';
        _metricVehicles = '0';
        _metricActiveOrders = '0';
      });
    }
  }

  Future<void> _loadAssignedOrders() async {
    setState(() => _ordersLoading = true);
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || rawBase.isEmpty || token == null) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('orders/me', queryParameters: {
        'status': 'programado',
        'page': 1,
        'per_page': 10,
      });
      final List list = (res.data as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _assignedOrders = list.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _ordersLoading = false);
    }
  }

  Future<void> _loadCommercialData() async {
    setState(() { _commercialLoading = true; });
    try {
      // Quotes
      final quotes = await _crm.listQuotes(page: 1, perPage: 10);
      // Clients
      final clients = await _crm.listClients(page: 1, perPage: 10);
      // Orders (en curso)
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      List<Map<String, dynamic>> orders = const [];
      if (rawBase != null && rawBase.isNotEmpty && token != null) {
        final dio = Dio(BaseOptions(
          baseUrl: resolveBaseUrlForPlatform(rawBase),
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));
        final res = await dio.get('orders', queryParameters: {'status': 'en_curso', 'page': 1, 'per_page': 10});
        final dynamic body = res.data;
        List list;
        if (body is List) list = body; else if (body is Map) { final m = body.cast<String, dynamic>(); list = (m['items'] ?? m['data'] ?? m['results'] ?? []) as List; } else list = const [];
        orders = list.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
      if (!mounted) return;
      setState(() {
        _quotes = quotes;
        _clients = clients;
        _orders = orders;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() { _commercialLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.azul,
        elevation: 0,
        toolbarHeight: 88,
        centerTitle: false,
        titleSpacing: 16,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TFC', style: TextStyle(
              color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
            SizedBox(height: 2),
            Text('TRANSPORTES', style: TextStyle(
              color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
        actions: const [SizedBox(width: 8)],
      ),
      drawer: Drawer(
        backgroundColor: AppColors.azul,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined, color: Colors.white),
                title: const Text('Transporte de carga', style: TextStyle(color: Colors.white)),
                onTap: () => Navigator.pushNamed(context, '/operaciones'),
              ),
              ListTile(
                leading: const Icon(Icons.construction, color: Colors.white),
                title: const Text('Obras civiles', style: TextStyle(color: Colors.white)),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.restaurant, color: Colors.white),
                title: const Text('Servicios de casino', style: TextStyle(color: Colors.white)),
                onTap: () {},
              ),
              const Divider(color: Colors.white24),
              if (_isAdminOrSuper)
              ExpansionTile(
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                title: const Text('Usuarios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1, color: Colors.white),
                    title: const Text('Crear usuario', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/users/create');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_remove_alt_1, color: Colors.white),
                    title: const Text('Borrar usuario', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/users/delete');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.manage_accounts, color: Colors.white),
                    title: const Text('Actualizar datos', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/users/update');
                    },
                  ),
                ],
              ),
              // Órdenes (visible para admin/comercial/super)
              if (_isAdminOrSuper || ((TokenStorage.currentRole ?? '').toLowerCase() == 'comercial'))
              ListTile(
                leading: const Icon(Icons.receipt_long, color: Colors.white),
                title: const Text('Órdenes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/orders'); },
              ),
              if (_isAdminOrSuper)
              ListTile(
                leading: const Icon(Icons.business, color: Colors.white),
                title: const Text('Empresas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/companies'); },
              ),
              // CRM - Clientes (admin/comercial/super)
              if (_isAdminOrSuper || ((TokenStorage.currentRole ?? '').toLowerCase() == 'comercial'))
              ListTile(
                leading: const Icon(Icons.groups_2, color: Colors.white),
                title: const Text('Clientes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/crm/clients'); },
              ),
              if (_isAdminOrSuper || ((TokenStorage.currentRole ?? '').toLowerCase() == 'comercial'))
              ListTile(
                leading: const Icon(Icons.contact_mail, color: Colors.white),
                title: const Text('Leads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/crm/leads'); },
              ),
              if (_isAdminOrSuper || ((TokenStorage.currentRole ?? '').toLowerCase() == 'comercial'))
              ListTile(
                leading: const Icon(Icons.trending_up, color: Colors.white),
                title: const Text('Oportunidades', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/crm/opportunities'); },
              ),
              if (_isAdminOrSuper || ((TokenStorage.currentRole ?? '').toLowerCase() == 'comercial'))
              ListTile(
                leading: const Icon(Icons.request_quote, color: Colors.white),
                title: const Text('Cotizaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                onTap: () { Navigator.pop(context); context.go('/crm/quotes'); },
              ),
              if (_isAdminOrSuper)
              ExpansionTile(
                iconColor: Colors.white,
                collapsedIconColor: Colors.white,
                title: const Text('Catálogos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                childrenPadding: const EdgeInsets.only(left: 16),
                children: [
                  ListTile(
                    leading: const Icon(Icons.local_shipping, color: Colors.white),
                    title: const Text('Tipos de vehículo', style: TextStyle(color: Colors.white)),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/catalogs/vehicle_types');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _isConductor ? null : FloatingActionButton(
        onPressed: () {},
        backgroundColor: AppColors.amarillo,
        foregroundColor: AppColors.azul,
        child: const Icon(Icons.shopping_cart_outlined),
      ),
      floatingActionButtonLocation: _isConductor ? null : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: _isConductor ? null : const CircularNotchedRectangle(),
        notchMargin: _isConductor ? 0 : 6,
        color: Colors.white,
        elevation: 8,
        surfaceTintColor: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => setState(() => _currentIndex = 0),
                icon: Icon(
                  _currentIndex == 0 ? Icons.home : Icons.home_outlined,
                  color: _currentIndex == 0 ? AppColors.azul : AppColors.azul.withOpacity(0.45),
                ),
                tooltip: 'Inicio',
              ),
              IconButton(
                onPressed: () => setState(() => _currentIndex = 1),
                icon: Icon(
                  _currentIndex == 1 ? Icons.notifications : Icons.notifications_none,
                  color: _currentIndex == 1 ? AppColors.azul : AppColors.azul.withOpacity(0.45),
                ),
                tooltip: 'Notificaciones',
              ),
              const SizedBox(width: 48),
              IconButton(
                onPressed: () => setState(() => _currentIndex = 2),
                icon: Icon(
                  _currentIndex == 2 ? Icons.bolt : Icons.bolt_outlined,
                  color: _currentIndex == 2 ? AppColors.azul : AppColors.azul.withOpacity(0.45),
                ),
                tooltip: 'Clips',
              ),
              IconButton(
                onPressed: () {
                  setState(() => _currentIndex = 3);
                  context.go('/profile');
                },
                icon: Icon(
                  _currentIndex == 3 ? Icons.person : Icons.person_outline,
                  color: _currentIndex == 3 ? AppColors.azul : AppColors.azul.withOpacity(0.45),
                ),
                tooltip: 'Usuario',
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _initializing
            ? const Center(child: CircularProgressIndicator())
            : _isConductor
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      _PanelCard(
                        title: 'GPS',
                        child: SizedBox(
                          height: 220,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(-12.0464, -77.0428),
                                zoom: 12,
                              ),
                              markers: {
                                const Marker(
                                  markerId: MarkerId('vehiculo-demo'),
                                  position: LatLng(-12.0464, -77.0428),
                                  infoWindow: InfoWindow(title: 'Vehículo'),
                                )
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              liteModeEnabled: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _AssignedOrdersCard(),
                    ],
                  )
                : _isSuperAdmin
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(children: [
                        const Text('Empresa:', style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 12),
                        if (_companies.isNotEmpty)
                          DropdownButton<int>(
                            value: _selectedCompanyId,
                            items: _companies
                                .map((c) => DropdownMenuItem<int>(
                                      value: (c['id'] as num).toInt(),
                                      child: Text(
                                        (c['name'] ?? 'Empresa').toString(),
                                        style: const TextStyle(color: AppColors.azul),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() => _selectedCompanyId = v);
                              if (v != null) {
                                _log('company changed to ' + v.toString());
                                _loadDashboard(companyId: v);
                              }
                            },
                            style: const TextStyle(color: AppColors.azul),
                            dropdownColor: Colors.white,
                          ),
                      ]),
                      const SizedBox(height: 16),
                      _MetricsCard(
                        title: 'Resumen de la empresa',
                        metrics: [
                          _Metric(value: _metricDrivers, label: 'Conductores'),
                          _Metric(value: _metricVehicles, label: 'Vehículos'),
                          _Metric(value: _metricActiveOrders, label: 'Órdenes activas'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _ServiceTile(color: AppColors.amarillo, icon: Icons.business, title: 'Empresas', onTap: () => context.go('/companies'), dark: false),
                          _ServiceTile(color: AppColors.azul, icon: Icons.list_alt, title: 'Catálogos', onTap: () => context.go('/catalogs/vehicle_types'), dark: true),
                        ],
                      ),
                    ],
                  )
                : _isComercial
                ? RefreshIndicator(
                    onRefresh: _loadCommercialData,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        _MetricsCard(
                          title: 'Mi desempeño',
                          metrics: [
                            _Metric(value: (_quotes.length).toString(), label: 'Cotizaciones'),
                            _Metric(value: (_orders.length).toString(), label: 'Órdenes en curso'),
                            _Metric(value: _metricActiveOrders, label: 'Activas (global)'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(children: [
                          Expanded(child: ElevatedButton.icon(onPressed: () => context.go('/crm/quotes'), icon: const Icon(Icons.request_quote), label: const Text('Nueva cotización'))),
                          const SizedBox(width: 12),
                          Expanded(child: OutlinedButton.icon(onPressed: () => context.go('/crm/clients'), icon: const Icon(Icons.group_add), label: const Text('Nuevo cliente'))),
                        ]),
                        const SizedBox(height: 16),
                        _PanelCard(title: 'Últimas cotizaciones', child: _commercialLoading && _quotes.isEmpty
                            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                            : ListView.separated(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final it = _quotes[index];
                                  final id = (it['id'] ?? '').toString();
                                  final estado = (it['estado'] ?? '').toString();
                                  return ListTile(leading: const Icon(Icons.request_quote), title: Text('COT $id', style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)), subtitle: Text(estado));
                                },
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemCount: _quotes.length,
                              )),
                        const SizedBox(height: 16),
                        _PanelCard(title: 'Órdenes en curso', child: _commercialLoading && _orders.isEmpty
                            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                            : ListView.separated(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final it = _orders[index];
                                  final id = (it['id'] ?? '').toString();
                                  final estado = (it['estado'] ?? it['status'] ?? '').toString();
                                  return ListTile(leading: const Icon(Icons.receipt_long), title: Text('Orden $id', style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)), subtitle: Text('Estado: ' + estado), onTap: () => context.push('/orders/$id'));
                                },
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemCount: _orders.length,
                              )),
                        const SizedBox(height: 16),
                        _PanelCard(title: 'Clientes recientes', child: _commercialLoading && _clients.isEmpty
                            ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()))
                            : ListView.separated(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final it = _clients[index];
                                  final nombre = (it['razon_social'] ?? it['name'] ?? 'Cliente').toString();
                                  final nit = (it['nit'] ?? '').toString();
                                  return ListTile(leading: const Icon(Icons.business), title: Text(nombre, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)), subtitle: Text('NIT: ' + nit));
                                },
                                separatorBuilder: (_, __) => const Divider(height: 1),
                                itemCount: _clients.length,
                              )),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _PanelCard(
                              title: 'GPS',
                              child: SizedBox(
                                height: 180,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GoogleMap(
                                    initialCameraPosition: const CameraPosition(
                                      target: LatLng(-12.0464, -77.0428), // Lima como ejemplo
                                      zoom: 12,
                                    ),
                                    markers: {
                                      const Marker(
                                        markerId: MarkerId('vehiculo-demo'),
                                        position: LatLng(-12.0464, -77.0428),
                                        infoWindow: InfoWindow(title: 'Vehículo'),
                                      )
                                    },
                                    zoomControlsEnabled: false,
                                    myLocationButtonEnabled: false,
                                    liteModeEnabled: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _PanelCard(
                              title: 'Órdenes Generadas',
                              child: Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.azul, width: 3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _MetricsCard(
                        title: 'Órdenes Activas',
                        metrics: [
                          _Metric(value: _metricActiveOrders, label: 'Órdenes activas'),
                          const _Metric(value: '—', label: 'Vehículos en mantenimiento'),
                          const _Metric(value: '—', label: 'Alertas'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.15,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _ServiceTile(
                            color: AppColors.amarillo,
                            icon: Icons.local_shipping_outlined,
                            title: 'Transporte de carga',
                            onTap: () => Navigator.pushNamed(context, '/operaciones'),
                            dark: false,
                          ),
                          _ServiceTile(
                            color: AppColors.azul,
                            icon: Icons.construction,
                            title: 'Obras civiles',
                            onTap: () {},
                            dark: true,
                          ),
                          _ServiceTile(
                            color: AppColors.rojo,
                            icon: Icons.restaurant,
                            title: 'Servicios de casino',
                            onTap: () {},
                            dark: true,
                          ),
                        ],
                      ),
                    ],
                  ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Color color; final IconData icon; final String title; final VoidCallback onTap; final bool dark;
  const _ServiceTile({required this.color, required this.icon, required this.title, required this.onTap, this.dark=false, super.key});
  @override
  Widget build(BuildContext context) {
    final textColor = dark ? Colors.white : AppColors.azul;
    final iconColor = dark ? Colors.white : AppColors.azul;
    return Material(
      color: color, borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 32, color: iconColor),
            const Spacer(),
            Text(title, style: TextStyle(
                color: textColor, fontWeight: FontWeight.w800, height: 1.1)),
          ]),
        ),
      ),
    );
  }
}

class _BellAction extends StatelessWidget {
  final VoidCallback onTap;
  const _BellAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            onPressed: onTap,
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            tooltip: 'Notificaciones',
          ),
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('2', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PanelCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.azul.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, color: AppColors.azul, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MetricsCard extends StatelessWidget {
  final String title;
  final List<_Metric> metrics;
  const _MetricsCard({required this.title, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amarillo,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AppColors.azul, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: metrics.map((m) => Expanded(child: _MetricItem(metric: m))).toList(),
          ),
        ],
      ),
    );
  }
}

class _Metric {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});
}

class _MetricItem extends StatelessWidget {
  final _Metric metric;
  const _MetricItem({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(metric.value, style: TextStyle(color: AppColors.azul, fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(metric.label, style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _AssignedOrdersCard extends StatelessWidget {
  const _AssignedOrdersCard();
  @override
  Widget build(BuildContext context) {
    final items = const [
      {'id': 'OP-001', 'estado': 'En ruta'},
      {'id': 'OP-002', 'estado': 'Pendiente'},
      {'id': 'OP-003', 'estado': 'Entregado'},
    ];
    return _PanelCard(
      title: 'Pedidos asignados',
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.azul.withOpacity(0.2), width: 2),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            final it = items[index];
            return ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text('Orden ${it['id']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
              subtitle: Text('Estado: ${it['estado']}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.azul)),
              trailing: const Icon(Icons.chevron_right),
            );
          },
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemCount: items.length,
        ),
      ),
    );
  }
}