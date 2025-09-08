import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class QuotesPage extends StatefulWidget {
  const QuotesPage({super.key});
  @override
  State<QuotesPage> createState() => _QuotesPageState();
}

class _QuotesPageState extends State<QuotesPage> {
  final _svc = CrmService();
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
      _items = await _svc.listQuotes();
    } catch (e) { _error = e.toString(); }
    finally { if (mounted) setState(() { _loading = false; }); }
  }

  Future<void> _openCreator() async {
    final clientCtrl = TextEditingController();
    final tipoCtrl = TextEditingController();
    final distanciaCtrl = TextEditingController();
    final pesoCtrl = TextEditingController();
    final riesgoCtrl = TextEditingController();
    final noctCtrl = ValueNotifier<bool>(false);
    final urgenteCtrl = ValueNotifier<bool>(false);

    Future<void> _calc() async {
      try {
        final pricing = await _svc.calculatePricing({
          'distancia_km': double.tryParse(distanciaCtrl.text.trim()) ?? 0,
          'peso_t': double.tryParse(pesoCtrl.text.trim()) ?? 0,
          'riesgo': double.tryParse(riesgoCtrl.text.trim()) ?? 0,
          'nocturno': noctCtrl.value,
          'urgente': urgenteCtrl.value,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Precio estimado: ' + (pricing['precio']?.toString() ?? '-'))));
      } catch (e) {
        if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error pricing: $e')));
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setSt) {
        return AlertDialog(
          title: const Text('Nueva cotización'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: clientCtrl, decoration: const InputDecoration(hintText: 'Cliente')),
              const SizedBox(height: 8),
              TextField(controller: tipoCtrl, decoration: const InputDecoration(hintText: 'Tipo de servicio')),
              const SizedBox(height: 8),
              TextField(controller: distanciaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Distancia (km)')),
              const SizedBox(height: 8),
              TextField(controller: pesoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Peso (t)')),
              const SizedBox(height: 8),
              TextField(controller: riesgoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Riesgo')),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: noctCtrl,
                builder: (context, v, _) => CheckboxListTile(value: v, onChanged: (nv) { noctCtrl.value = nv ?? false; setSt(() {}); }, title: const Text('Nocturno')),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: urgenteCtrl,
                builder: (context, v, _) => CheckboxListTile(value: v, onChanged: (nv) { urgenteCtrl.value = nv ?? false; setSt(() {}); }, title: const Text('Urgente')),
              ),
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: _calc, icon: const Icon(Icons.calculate), label: const Text('Calcular precio'))),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Crear')),
          ],
        );
      }),
    );
    if (ok != true) return;
    try {
      await _svc.createQuote({
        'cliente': clientCtrl.text.trim(),
        'tipo_servicio': tipoCtrl.text.trim(),
        'items': [
          {
            'distancia_km': double.tryParse(distanciaCtrl.text.trim()) ?? 0,
            'peso_t': double.tryParse(pesoCtrl.text.trim()) ?? 0,
            'riesgo': double.tryParse(riesgoCtrl.text.trim()) ?? 0,
            'nocturno': noctCtrl.value,
            'urgente': urgenteCtrl.value,
          }
        ],
      });
      if (!mounted) return; await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cotización creada')));
    } catch (e) {
      if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cotizaciones'), actions: [
        IconButton(icon: const Icon(Icons.add), onPressed: _openCreator),
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
                      final String id = (it['id'] ?? '').toString();
                      final String cliente = (it['cliente'] ?? it['cliente_nombre'] ?? '').toString();
                      final String estado = (it['estado'] ?? 'borrador').toString();
                      return Card(
                        elevation: 0,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: AppColors.azul.withOpacity(0.1), width: 1)),
                        child: ListTile(
                          leading: const Icon(Icons.request_quote, color: AppColors.azul),
                          title: Text('COT $id · $cliente', style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
                          subtitle: Text(estado, style: TextStyle(color: AppColors.azul.withOpacity(0.7))),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              try {
                                if (v == 'enviar') await _svc.sendQuote((it['id'] as num).toInt());
                                if (v == 'aceptar') await _svc.acceptQuote((it['id'] as num).toInt());
                                if (v == 'convertir') await _svc.convertQuoteToOrder((it['id'] as num).toInt());
                                if (!mounted) return; await _fetch();
                              } catch (e) {
                                if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                              }
                            },
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: 'enviar', child: Text('Enviar')),
                              PopupMenuItem(value: 'aceptar', child: Text('Aceptar')),
                              PopupMenuItem(value: 'convertir', child: Text('Convertir a orden')),
                            ],
                          ),
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


