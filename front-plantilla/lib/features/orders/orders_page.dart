import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  String _status = 'en_curso';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  bool get _isAdminOrComercial {
    final role = (TokenStorage.currentRole ?? '').toLowerCase();
    return role == 'admin' || role == 'comercial' || role.contains('super');
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || rawBase.isEmpty || token == null) throw Exception('Sin configuración/token');
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final Map<String, dynamic> baseQuery = {
        'page': 1,
        'per_page': 20,
      };
      if (_status.isNotEmpty) {
        baseQuery['status'] = _status; // algunos backends usan 'status'
        baseQuery['estado'] = _status; // otros usan 'estado'
      }
      Response res = await dio.get('orders', queryParameters: baseQuery);
      final dynamic body = res.data;
      List list;
      if (body is List) {
        list = body;
      } else if (body is Map) {
        final Map<String, dynamic> m = body.cast<String, dynamic>();
        list = (m['items'] ?? m['orders'] ?? m['results'] ?? m['data'] ?? m['rows'] ?? m['records'] ?? []) as List;
      } else {
        list = const [];
      }
      _items = list.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();

      // Si se pidió con filtro y vino vacío, reintentar sin filtro por si la API usa otro nombre
      if (_items.isEmpty && _status.isNotEmpty) {
        res = await dio.get('orders', queryParameters: {
          'page': 1,
          'per_page': 20,
        });
        final dynamic b2 = res.data;
        List list2;
        if (b2 is List) {
          list2 = b2;
        } else if (b2 is Map) {
          final Map<String, dynamic> m = b2.cast<String, dynamic>();
          list2 = (m['items'] ?? m['orders'] ?? m['results'] ?? m['data'] ?? m['rows'] ?? m['records'] ?? []) as List;
        } else {
          list2 = const [];
        }
        _items = list2.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
      }
    } on DioException catch (e) {
      _error = (e.response?.data is Map && (e.response?.data['detail'] != null))
          ? e.response?.data['detail'].toString()
          : e.message;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Órdenes')),
      bottomNavigationBar: BottomAppBar(
        shape: null,
        notchMargin: 0,
        color: Colors.white,
        elevation: 8,
        surfaceTintColor: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(onPressed: () => context.go('/home'), icon: Icon(Icons.home, color: AppColors.azul), tooltip: 'Inicio'),
              IconButton(onPressed: () {}, icon: Icon(Icons.notifications_none, color: AppColors.azul.withOpacity(0.45)), tooltip: 'Notificaciones'),
              const SizedBox(width: 48),
              IconButton(onPressed: () {}, icon: Icon(Icons.bolt_outlined, color: AppColors.azul.withOpacity(0.45)), tooltip: 'Clips'),
              IconButton(onPressed: () => context.go('/profile'), icon: Icon(Icons.person_outline, color: AppColors.azul.withOpacity(0.45)), tooltip: 'Usuario'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('Estado:', style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _status,
                  items: const [
                    DropdownMenuItem(value: 'en_curso', child: Text('En curso')),
                    DropdownMenuItem(value: 'programado', child: Text('Programado')),
                    DropdownMenuItem(value: 'entregada', child: Text('Entregada')),
                  ],
                  onChanged: (v) { setState(() => _status = v ?? _status); _fetch(); },
                ),
                const Spacer(),
                // Se elimina el botón Crear: las órdenes nacen desde cotizaciones
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
                    : _items.isEmpty
                        ? const Center(child: Text('No hay órdenes para este estado'))
                        : RefreshIndicator(
                            onRefresh: _fetch,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                              itemBuilder: (context, index) {
                                final it = _items[index];
                                final String id = (it['id'] ?? it['code'] ?? '').toString();
                                final String estado = (it['estado'] ?? it['status'] ?? '').toString();
                                final String desc = (it['descripcion'] ?? it['description'] ?? '').toString();
                                return Card(
                                  elevation: 0,
                                  color: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                                  child: ListTile(
                                    leading: const Icon(Icons.receipt_long, color: AppColors.azul),
                                    title: Text('Orden $id', style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                                    subtitle: Text('Estado: $estado  ·  $desc', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                                    onTap: () => context.push('/orders/$id'),
                                  ),
                                );
                              },
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemCount: _items.length,
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}


