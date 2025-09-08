import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/features/crm/client_contacts_page.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class ClientsPage extends StatefulWidget {
  const ClientsPage({super.key});
  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  final _svc = CrmService();
  final _search = TextEditingController();
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
      _items = await _svc.listClients(query: _search.text.trim());
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['razon_social'] ?? existing?['name'] ?? existing?['nombre'] ?? '');
    final nitCtrl = TextEditingController(text: existing?['nit']?.toString() ?? '');
    final emailCtrl = TextEditingController(text: existing?['email']?.toString() ?? '');
    final telCtrl = TextEditingController(text: existing?['telefono']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nuevo cliente' : 'Editar cliente'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Razón social (requerido)')),
          const SizedBox(height: 8),
          TextField(controller: nitCtrl, decoration: const InputDecoration(hintText: 'NIT (requerido)')),
          const SizedBox(height: 8),
          TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email (opcional)')),
          const SizedBox(height: 8),
          TextField(controller: telCtrl, decoration: const InputDecoration(hintText: 'Teléfono (opcional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    final payload = {
      'razon_social': nameCtrl.text.trim(),
      'nit': nitCtrl.text.trim(),
      if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
      if (telCtrl.text.trim().isNotEmpty) 'telefono': telCtrl.text.trim(),
    };
    try {
      if (existing == null) {
        await _svc.createClient(payload);
      } else {
        final int id = (existing['id'] as num).toInt();
        await _svc.updateClient(id, payload);
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
      appBar: AppBar(
        title: const Text('Clientes'),
        actions: [
          IconButton(icon: const Icon(Icons.add_business), onPressed: () => _openEditor()),
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
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o NIT',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _fetch(); }),
              ),
              onSubmitted: (_) => _fetch(),
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
                            final String name = (it['razon_social'] ?? it['name'] ?? it['nombre'] ?? '').toString();
                            final String nit = (it['nit'] ?? '').toString();
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                              child: ListTile(
                                leading: const Icon(Icons.business, color: AppColors.azul),
                                title: Text(name, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                                subtitle: Text('NIT: $nit', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                                onTap: () => _openEditor(existing: it),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'contactos') {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => ClientContactsPage(client: it)));
                                    } else if (v == 'invitar') {
                                      final ok = await showDialog<_InviteData>(
                                        context: context,
                                        builder: (ctx) => _InviteDialog(client: it),
                                      );
                                      if (ok != null) {
                                        try {
                                          await CrmService().inviteContactToPortal(clientId: (it['id'] as num).toInt(), email: ok.email, password: ok.password);
                                          if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitación enviada')));
                                        } catch (e) {
                                          if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                        }
                                      }
                                    }
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(value: 'contactos', child: Text('Contactos')),
                                    PopupMenuItem(value: 'invitar', child: Text('Invitar a portal')),
                                  ],
                                ),
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

class _InviteData { final String email; final String password; const _InviteData(this.email, this.password); }

class _InviteDialog extends StatelessWidget {
  final Map<String, dynamic> client;
  const _InviteDialog({required this.client});

  @override
  Widget build(BuildContext context) {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    return AlertDialog(
      title: const Text('Invitar a portal cliente'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Cliente: ' + (client['name'] ?? client['nombre'] ?? '').toString()),
        const SizedBox(height: 8),
        TextField(controller: emailCtrl, decoration: const InputDecoration(hintText: 'Email del contacto')),
        const SizedBox(height: 8),
        TextField(controller: passCtrl, decoration: const InputDecoration(hintText: 'Contraseña (opcional)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(onPressed: () => Navigator.pop(context, _InviteData(emailCtrl.text.trim(), passCtrl.text.trim())), child: const Text('Invitar')),
      ],
    );
  }
}


