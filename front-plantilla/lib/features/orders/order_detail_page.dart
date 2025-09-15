import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';

class OrderDetailPage extends StatefulWidget {
  final int orderId;
  const OrderDetailPage({super.key, required this.orderId});
  @override
  State<OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<OrderDetailPage> {
  final _svc = CrmService();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];
  String _estado = 'programado';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      _events = await _svc.listOrderEvents(widget.orderId);
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _addEvent() async {
    final msgCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Agregar evento'),
        content: TextField(controller: msgCtrl, decoration: const InputDecoration(hintText: 'Mensaje')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true) return;
    await _svc.addOrderEvent(orderId: widget.orderId, tipo: 'evento', message: msgCtrl.text.trim());
    await _load();
  }

  Future<void> _changeStatus() async {
    final estados = ['programado','en_curso','completado','cancelado'];
    final sel = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: estados.map((e) => ListTile(title: Text(e), onTap: () => Navigator.pop(context, e))).toList(),
        ),
      ),
    );
    if (sel == null) return;
    await _svc.updateOrderStatus(orderId: widget.orderId, estado: sel);
    setState(() { _estado = sel; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: const BackButton(), title: Text('Orden #${widget.orderId}'), actions: [
        TextButton(onPressed: _changeStatus, child: Text(_estado, style: const TextStyle(color: Colors.white)))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _addEvent, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                    itemBuilder: (context, index) {
                      final it = _events[index];
                      return ListTile(
                        leading: const Icon(Icons.timeline),
                        title: Text((it['tipo'] ?? '').toString()),
                        subtitle: Text((it['message'] ?? '').toString()),
                      );
                    },
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemCount: _events.length,
                  ),
                ),
    );
  }
}


