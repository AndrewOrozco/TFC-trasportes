import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class OpportunitiesPage extends StatefulWidget {
  const OpportunitiesPage({super.key});
  @override
  State<OpportunitiesPage> createState() => _OpportunitiesPageState();
}

class _OpportunitiesPageState extends State<OpportunitiesPage> {
  final _svc = CrmService();
  final _q = TextEditingController();
  String _etapa = 'prospecto';
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
      _items = await _svc.listOpportunities(etapa: _etapa, q: _q.text.trim());
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final clienteCtrl = TextEditingController(text: existing?['cliente_nombre'] ?? existing?['cliente']?.toString() ?? '');
    final valorCtrl = TextEditingController(text: existing?['valor_est']?.toString() ?? '');
    final probCtrl = TextEditingController(text: existing?['probabilidad']?.toString() ?? '');
    final notasCtrl = TextEditingController(text: existing?['notas']?.toString() ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Nueva oportunidad' : 'Editar oportunidad'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: clienteCtrl, decoration: const InputDecoration(hintText: 'Cliente')),
            const SizedBox(height: 8),
            TextField(controller: valorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Valor estimado')),
            const SizedBox(height: 8),
            TextField(controller: probCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Probabilidad (%)')),
            const SizedBox(height: 8),
            TextField(controller: notasCtrl, decoration: const InputDecoration(hintText: 'Notas')),
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
      'cliente': clienteCtrl.text.trim(),
      'valor_est': double.tryParse(valorCtrl.text.trim()) ?? 0,
      'probabilidad': int.tryParse(probCtrl.text.trim()) ?? 0,
      'etapa': _etapa,
      'notas': notasCtrl.text.trim(),
    };
    try {
      if (existing == null) {
        await _svc.createOpportunity(payload);
      } else {
        final id = (existing['id'] as num).toInt();
        await _svc.updateOpportunity(id, payload);
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
      appBar: AppBar(title: const Text('Oportunidades'), actions: [
        IconButton(icon: const Icon(Icons.add_chart), onPressed: () => _openEditor()),
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
                  decoration: InputDecoration(hintText: 'Buscar oportunidad', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.clear), onPressed: () { _q.clear(); _fetch(); })),
                  onSubmitted: (_) => _fetch(),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _etapa,
                items: const [
                  DropdownMenuItem(value: 'prospecto', child: Text('Prospecto')),
                  DropdownMenuItem(value: 'calificado', child: Text('Calificado')),
                  DropdownMenuItem(value: 'propuesta', child: Text('Propuesta')),
                  DropdownMenuItem(value: 'ganada', child: Text('Ganada')),
                  DropdownMenuItem(value: 'perdida', child: Text('Perdida')),
                ],
                onChanged: (v) { setState(() => _etapa = v ?? _etapa); _fetch(); },
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
                            final String cliente = (it['cliente_nombre'] ?? it['cliente'] ?? '').toString();
                            final String etapa = (it['etapa'] ?? '').toString();
                            final String valor = (it['valor_est'] ?? '').toString();
                            return Card(
                              elevation: 0,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                              child: ListTile(
                                leading: const Icon(Icons.trending_up, color: AppColors.azul),
                                title: Text(cliente.isEmpty ? 'Oportunidad' : cliente, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                                subtitle: Text('$etapa  ·  $valor', style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
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


