import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});
  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final _svc = CrmService();
  final _q = TextEditingController();
  String _estado = 'nuevo';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await _svc.listLeads(q: _q.text.trim(), estado: _estado);
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? existing?['nombre'] ?? '');
    final industryCtrl = TextEditingController(text: existing?['industria']?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?['notas']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nuevo lead' : 'Editar lead'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nombre/Empresa')),
            const SizedBox(height: 8),
            TextField(controller: industryCtrl, decoration: const InputDecoration(hintText: 'Industria')),
            const SizedBox(height: 8),
            TextField(controller: notesCtrl, decoration: const InputDecoration(hintText: 'Notas')),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final payload = {
      'name': nameCtrl.text.trim(),
      'industria': industryCtrl.text.trim(),
      'notas': notesCtrl.text.trim(),
      'estado': _estado,
    };
    try {
      if (existing == null) {
        await _svc.createLead(payload);
      } else {
        final id = (existing['id'] as num).toInt();
        await _svc.updateLead(id, payload);
      }
      if (!mounted) return; await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leads'), actions: [
        IconButton(icon: const Icon(Icons.person_add), onPressed: () => _openEditor()),
      ]),
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
              IconButton(onPressed: () => context.go('/home'), icon: const Icon(Icons.home, color: AppColors.azul), tooltip: 'Inicio'),
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
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: InputDecoration(hintText: 'Buscar lead', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); _fetch(); })),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _estado,
                items: const [
                  DropdownMenuItem(value: 'nuevo', child: Text('Nuevo')),
                  DropdownMenuItem(value: 'contactado', child: Text('Contactado')),
                  DropdownMenuItem(value: 'calificado', child: Text('Calificado')),
                  DropdownMenuItem(value: 'descartado', child: Text('Descartado')),
                ],
                onChanged: (v) { setState(() => _estado = v ?? _estado); _fetch(); },
              ),
            ]),
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
                            final String name = (it['name'] ?? it['nombre'] ?? '').toString();
                            final String estado = (it['estado'] ?? '').toString();
                            final String nota = (it['notas'] ?? '').toString();
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                              child: ListTile(
                                leading: const Icon(Icons.contact_mail, color: AppColors.azul),
                                title: Text(name, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                                subtitle: Text('$estado  ·  $nota', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                                onTap: () => _openEditor(existing: it),
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



