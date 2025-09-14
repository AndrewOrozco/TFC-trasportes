import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/theme.dart';

class ClientContactsPage extends StatefulWidget {
  final Map<String, dynamic> client;
  const ClientContactsPage({required this.client, super.key});

  @override
  State<ClientContactsPage> createState() => _ClientContactsPageState();
}

class _ClientContactsPageState extends State<ClientContactsPage> {
  final _svc = CrmService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  int get _clientId => (widget.client['id'] as num).toInt();
  String get _clientName => (widget.client['name'] ?? widget.client['nombre'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() { _loading = true; _error = null; });
    try {
      _items = await _svc.listContacts(_clientId);
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name'] ?? existing?['nombre'] ?? '');
    final roleCtrl = TextEditingController(text: existing?['cargo']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['telefono']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nuevo contacto' : 'Editar contacto'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nombre')),
          const SizedBox(height: 8),
          TextField(controller: roleCtrl, decoration: const InputDecoration(hintText: 'Cargo')),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email')),
          const SizedBox(height: 8),
          TextField(controller: phoneCtrl, decoration: const InputDecoration(hintText: 'Teléfono')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final payload = {
      'name': nameCtrl.text.trim(),
      'cargo': roleCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'telefono': phoneCtrl.text.trim(),
    };
    try {
      if (existing == null) {
        await _svc.createContact(_clientId, payload);
      } else {
        final id = (existing['id'] as num).toInt();
        await _svc.updateContact(_clientId, id, payload);
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
      appBar: AppBar(title: Text('Contactos · ' + _clientName), actions: [
        IconButton(icon: const Icon(Icons.person_add_alt), onPressed: () => _openEditor()),
      ]),
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
                      final String name = (it['name'] ?? it['nombre'] ?? '').toString();
                      final String cargo = (it['cargo'] ?? '').toString();
                      final String email = (it['email'] ?? '').toString();
                      final String phone = (it['telefono'] ?? '').toString();
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                        child: ListTile(
                          leading: const Icon(Icons.person, color: AppColors.azul),
                          title: Text(name, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                          subtitle: Text('$cargo  ·  $email  ·  $phone', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                          onTap: () => _openEditor(existing: it),
                        ),
                      );
                    },
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemCount: _items.length,
                  ),
                ),
    );
  }
}



