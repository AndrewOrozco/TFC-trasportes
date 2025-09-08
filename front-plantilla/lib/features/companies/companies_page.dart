import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class CompaniesPage extends StatefulWidget {
  const CompaniesPage({super.key});
  @override
  State<CompaniesPage> createState() => _CompaniesPageState();
}

class _CompanyItem {
  final int id;
  final String name;
  final String nit;
  const _CompanyItem({required this.id, required this.name, required this.nit});
  factory _CompanyItem.fromJson(Map<String, dynamic> json) {
    return _CompanyItem(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['nombre'] ?? '').toString(),
      nit: (json['nit'] ?? '').toString(),
    );
  }
}

class _CompaniesPageState extends State<CompaniesPage> {
  bool _loading = true;
  String? _error;
  List<_CompanyItem> _items = const [];
  bool get _isSuperAdmin => (TokenStorage.currentRole ?? '').toLowerCase().contains('super');

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase ?? ''),
        headers: {'Authorization': 'Bearer ${TokenStorage.token}'},
      ));
      final res = await dio.get('companies');
      final List data = (res.data as List?) ?? [];
      _items = data.map((e) => _CompanyItem.fromJson((e as Map).cast<String, dynamic>())).toList();
    } on DioException catch (e) {
      _error = (e.response?.data is Map && (e.response?.data['detail'] != null))
          ? e.response?.data['detail'].toString()
          : e.message;
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Empresas'),
        actions: [
          if (_isSuperAdmin)
            IconButton(icon: const Icon(Icons.add_business), tooltip: 'Crear empresa', onPressed: _onCreate),
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
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, textAlign: TextAlign.center)))
              : RefreshIndicator(
                  onRefresh: _fetch,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                    itemBuilder: (context, index) {
                      final it = _items[index];
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                        child: ListTile(
                          leading: const Icon(Icons.business, color: AppColors.azul),
                          title: Text(it.name, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                          subtitle: Text('NIT: ${it.nit}  ·  ID: ${it.id}', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _items.length,
                  ),
                ),
    );
  }

  Future<void> _onCreate() async {
    final nameCtrl = TextEditingController();
    final nitCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva empresa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nombre')), 
            const SizedBox(height: 8),
            TextField(controller: nitCtrl, decoration: const InputDecoration(hintText: 'NIT'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
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
      await dio.post('companies', queryParameters: {
        'name': nameCtrl.text.trim(),
        'nit': nitCtrl.text.trim(),
      });
      if (!mounted) return; await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empresa creada')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}


