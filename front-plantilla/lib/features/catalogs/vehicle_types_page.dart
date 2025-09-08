import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class VehicleTypesPage extends StatefulWidget {
  const VehicleTypesPage({super.key});
  @override
  State<VehicleTypesPage> createState() => _VehicleTypesPageState();
}

class _VehicleType {
  final int id;
  final String name;
  final int? companyId;
  final String? companyName;
  const _VehicleType({required this.id, required this.name, this.companyId, this.companyName});
  factory _VehicleType.fromJson(Map<String, dynamic> json) {
    final dynamic rawCompany = json['company_id'] ?? json['companyId'] ?? json['company'];
    final int? parsedCompanyId = () {
      if (rawCompany == null) return null;
      if (rawCompany is num) return rawCompany.toInt();
      if (rawCompany is String) return int.tryParse(rawCompany);
      if (rawCompany is Map) {
        final dynamic cId = rawCompany['id'];
        if (cId is num) return cId.toInt();
        if (cId is String) return int.tryParse(cId);
      }
      return null;
    }();
    final String? parsedCompanyName = () {
      final dynamic raw = json['company_name'] ?? json['companyName'] ?? json['company'];
      if (raw == null) return null;
      if (raw is String) return raw;
      if (raw is Map) return (raw['name'] ?? raw['nombre'])?.toString();
      return null;
    }();
    return _VehicleType(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['nombre'] ?? '').toString(),
      companyId: parsedCompanyId,
      companyName: parsedCompanyName,
    );
  }
}

class _VehicleTypesPageState extends State<VehicleTypesPage> {
  bool _loading = true;
  String? _error;
  List<_VehicleType> _items = const [];
  bool get _isAdminOrSuper {
    final role = (TokenStorage.currentRole ?? '').toLowerCase();
    return role == 'admin' || role.contains('super');
  }
  bool get _isSuperAdmin {
    final role = (TokenStorage.currentRole ?? '').toLowerCase();
    return role.contains('super');
  }
  String? get _myCompanyId => TokenStorage.currentCompanyId;

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
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase ?? ''),
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('catalogs/vehicle_types');
      final List data = (res.data as List?) ?? [];
      _items = data.map((e) => _VehicleType.fromJson((e as Map).cast<String, dynamic>())).toList();
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Tipos de vehículo'),
        actions: [
          if (_isAdminOrSuper)
            IconButton(
              tooltip: 'Crear tipo',
              icon: const Icon(Icons.add),
              onPressed: _onCreate,
            ),
        ],
      ),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemBuilder: (context, index) {
                      final List<_VehicleType> display = _items.where((it) {
                        if (_isSuperAdmin) return true;
                        if (it.companyId == null) return true; // global
                        return _myCompanyId != null && _myCompanyId == it.companyId.toString();
                      }).toList();
                      final it = display[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                        child: ListTile(
                          leading: const Icon(Icons.local_shipping_outlined, color: AppColors.azul),
                          title: Text(it.name, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                          subtitle: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ScopeChip(companyId: it.companyId, companyName: it.companyName),
                              const SizedBox(width: 8),
                              Text('ID: ${it.id}', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                            ],
                          ),
                          trailing: _canDelete(it)
                              ? IconButton(
                                  tooltip: 'Eliminar',
                                  icon: const Icon(Icons.delete_outline, color: AppColors.rojo),
                                  onPressed: () => _onDelete(it.id),
                                )
                              : null,
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _items.where((it) {
                      if (_isSuperAdmin) return true;
                      if (it.companyId == null) return true;
                      return _myCompanyId != null && _myCompanyId == it.companyId.toString();
                    }).length,
                  ),
                ),
    );
  }

  Future<void> _onCreate() async {
    final controller = TextEditingController();
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nuevo tipo de vehículo'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Nombre'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Crear')),
          ],
        );
      },
    );
    if (name == null || name.isEmpty) return;
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase ?? ''),
        headers: {'Authorization': 'Bearer ${TokenStorage.token}'},
      ));
      final int? myCompanyId = int.tryParse(TokenStorage.currentCompanyId ?? '');
      final Map<String, dynamic> payload = {
        'name': name,
        if (!_isSuperAdmin && myCompanyId != null) 'company_id': myCompanyId,
      };
      await dio.post('catalogs/vehicle_types', data: payload);
      if (!mounted) return;
      await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tipo creado')));
    } on DioException catch (e) {
      final String msg = ((e.response?.data is Map && e.response?.data['detail'] != null)
              ? e.response?.data['detail'].toString()
              : null) ?? 'Error al crear';
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _onDelete(int id) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: const Text('¿Seguro que deseas eliminar este tipo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase ?? ''),
        headers: {'Authorization': 'Bearer ${TokenStorage.token}'},
      ));
      await dio.delete('catalogs/vehicle_types/$id');
      if (!mounted) return;
      await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tipo eliminado')));
    } on DioException catch (e) {
      final String msg = ((e.response?.data is Map && e.response?.data['detail'] != null)
              ? e.response?.data['detail'].toString()
              : null) ?? 'Error al eliminar';
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  bool _canDelete(_VehicleType it) {
    if (_isSuperAdmin) return true;
    if (!_isAdminOrSuper) return false;
    return it.companyId != null && _myCompanyId != null && _myCompanyId == it.companyId.toString();
  }
}

class _ScopeChip extends StatelessWidget {
  final int? companyId;
  final String? companyName;
  const _ScopeChip({required this.companyId, required this.companyName});

  @override
  Widget build(BuildContext context) {
    final String? myCompany = TokenStorage.currentCompanyId;
    final bool isGlobal = companyId == null;
    final bool isMine = !isGlobal && (myCompany != null && myCompany == companyId.toString());
    final String label = isGlobal
        ? 'Global'
        : (isMine ? 'Mi empresa' : (companyName?.isNotEmpty == true ? companyName! : 'Empresa $companyId'));
    final Color border = isGlobal ? AppColors.azul.withOpacity(0.30) : AppColors.amarillo.withOpacity(0.60);
    final Color bg = isGlobal ? AppColors.azul.withOpacity(0.06) : AppColors.amarillo.withOpacity(0.18);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: 1),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.azul)),
    );
  }
}


