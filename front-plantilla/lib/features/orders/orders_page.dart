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
      final res = await dio.get('orders', queryParameters: {
        'status': _status,
        'page': 1,
        'per_page': 20,
        // company_id lo decide el backend según rol; super_admin puede pasar por query si quiere
      });
      final List data = (res.data as List?) ?? [];
      _items = data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
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
                if (_isAdminOrComercial)
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: const Text('Crear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
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


