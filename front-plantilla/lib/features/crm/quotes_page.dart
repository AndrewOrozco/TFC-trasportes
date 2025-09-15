import 'package:flutter/material.dart';
import 'package:frontend/services/crm_service.dart';
import 'package:frontend/core/token_storage.dart';
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

  // Sheet de búsqueda de clientes
  // Minimalista: campo de texto con debounce simple y lista paginada

  

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
    Map<String, dynamic>? selectedClient;
    String? selectedClientLabel;
    final tipoCtrl = TextEditingController(text: 'liquida');
    final distanciaCtrl = TextEditingController();
    final pesoCtrl = TextEditingController();
    final noctCtrl = ValueNotifier<bool>(false);
    final urgenteCtrl = ValueNotifier<bool>(false);
    final peligrosoCtrl = ValueNotifier<bool>(false);

    final descCtrl = TextEditingController(text: 'Transporte 120 km');
    final cantCtrl = TextEditingController(text: '1');
    final puCtrl = TextEditingController();

    Future<void> _calc() async {
      try {
        final pricing = await _svc.calculatePricing({
          'tipo_servicio': tipoCtrl.text.trim(),
          'distancia_km': double.tryParse(distanciaCtrl.text.trim()) ?? 0,
          'peso_ton': double.tryParse(pesoCtrl.text.trim()) ?? 0,
          'es_peligroso': peligrosoCtrl.value,
          'nocturno': noctCtrl.value,
          'urgente': urgenteCtrl.value,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Precio estimado: ' + (pricing['precio']?.toString() ?? '-'))));
      } catch (e) {
        if (!mounted) return;
        String msg = 'Error pricing: ' + e.toString();
        try {
          // ignore: avoid_dynamic_calls
          final dioe = e as dynamic; // DioException si aplica
          final uri = dioe.requestOptions?.uri?.toString();
          final status = dioe.response?.statusCode;
          if (uri != null) msg = '[$status] ' + uri;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, setSt) {
        return AlertDialog(
          title: const Text('Nueva cotización'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InkWell(
                onTap: () async {
                  final picked = await showModalBottomSheet<Map<String, dynamic>>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => _ClientSearchSheet(svc: _svc),
                  );
                  if (picked != null) {
                    selectedClient = picked;
                    selectedClientLabel = '${picked['razon_social'] ?? ''} — ${(picked['nit'] ?? '').toString()}';
                    setSt(() {});
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(hintText: 'Seleccionar cliente'),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      selectedClientLabel ?? 'client_id (cliente existente)',
                      style: TextStyle(color: selectedClientLabel == null ? Colors.grey : Colors.black87),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(controller: tipoCtrl, decoration: const InputDecoration(hintText: 'tipo_servicio (liquida/seca/especial)')),
              const SizedBox(height: 8),
              TextField(controller: distanciaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Distancia (km)')),
              const SizedBox(height: 8),
              TextField(controller: pesoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Peso (ton)')),
              const SizedBox(height: 8),
              ValueListenableBuilder<bool>(
                valueListenable: noctCtrl,
                builder: (context, v, _) => CheckboxListTile(value: v, onChanged: (nv) { noctCtrl.value = nv ?? false; setSt(() {}); }, title: const Text('Nocturno')),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: urgenteCtrl,
                builder: (context, v, _) => CheckboxListTile(value: v, onChanged: (nv) { urgenteCtrl.value = nv ?? false; setSt(() {}); }, title: const Text('Urgente')),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: peligrosoCtrl,
                builder: (context, v, _) => CheckboxListTile(value: v, onChanged: (nv) { peligrosoCtrl.value = nv ?? false; setSt(() {}); }, title: const Text('Es peligroso')),
              ),
              const Divider(height: 20),
              const Align(alignment: Alignment.centerLeft, child: Text('Ítem')),
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'descripcion')),
              const SizedBox(height: 8),
              TextField(controller: cantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'cantidad')),
              const SizedBox(height: 8),
              TextField(controller: puCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'precio_unitario')),
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
      if (selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un cliente')));
        return;
      }
      final created = await _svc.createQuote({
        'client_id': (selectedClient!['id'] as num).toInt(),
        'tipo_servicio': tipoCtrl.text.trim(),
        'distancia_km': double.tryParse(distanciaCtrl.text.trim()) ?? 0,
        'peso_ton': double.tryParse(pesoCtrl.text.trim()) ?? 0,
        'es_peligroso': peligrosoCtrl.value,
        'nocturno': noctCtrl.value,
        'urgente': urgenteCtrl.value,
        if ((selectedClient!['company_id'] ?? TokenStorage.currentCompanyId) != null)
          'company_id': int.tryParse((selectedClient!['company_id']?.toString() ?? TokenStorage.currentCompanyId!) ),
        'items': [
          {
            'descripcion': descCtrl.text.trim(),
            'cantidad': int.tryParse(cantCtrl.text.trim()) ?? 1,
            'precio_unitario': double.tryParse(puCtrl.text.trim()) ?? 0,
          }
        ],
      });
      final qid = (created['id'] as num?)?.toInt();
      if (qid != null) await _convertAndAssign(qid);
      if (!mounted) return; await _fetch();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cotización creada')));
    } catch (e) {
      if (!mounted) return;
      String msg = 'Error: ' + e.toString();
      try {
        final dioe = e as dynamic;
        final uri = dioe.requestOptions?.uri?.toString();
        final status = dioe.response?.statusCode;
        if (uri != null) msg = '[$status] ' + uri;
      } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _convertAndAssign(int quotationId) async {
    try {
      await _svc.acceptQuote(quotationId);
      final order = await _svc.convertQuoteToOrder(quotationId);
      final orderId = (order['id'] as num?)?.toInt() ?? (order['order_id'] as num?)?.toInt() ?? quotationId;

      final vehicle = await _pickVehicle();
      if (vehicle == null) return;
      final oper = await _pickOperator();
      if (oper == null) return;

      await _svc.assignOrder(orderId: orderId, vehicleId: (vehicle['id'] as num).toInt(), operatorId: (oper['id'] as num).toInt());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden asignada')));
      // Navegación al detalle
      // ignore: use_build_context_synchronously
      context.go('/orders/$orderId');
    } catch (e) {
      if (!mounted) return; String msg = 'Error: ' + e.toString();
      try { final dioe = e as dynamic; final uri = dioe.requestOptions?.uri?.toString(); final status = dioe.response?.statusCode; if (uri != null) msg = '[$status] ' + uri; } catch (_) {}
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<Map<String, dynamic>?> _pickVehicle() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SimpleListPicker(
        title: 'Seleccionar vehículo',
        loader: (page) => _svc.listVehicles(page: page),
        titleFrom: (it) => (it['placa'] ?? '').toString(),
        subtitleFrom: (it) => (it['tipo_nombre'] ?? '').toString(),
      ),
    );
  }

  Future<Map<String, dynamic>?> _pickOperator() async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SimpleListPicker(
        title: 'Seleccionar operador',
        loader: (page) => _svc.listOperators(role: 'conductor', page: page),
        titleFrom: (it) => (it['nombre'] ?? it['operator_name'] ?? 'Operador').toString(),
        subtitleFrom: (it) => 'Lic: ' + ((it['licencias'] ?? it['operator_licenses'] ?? '').toString()),
      ),
    );
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
                            itemBuilder: (ctx) {
                              final estadoLower = estado.toLowerCase();
                              final yaAceptada = estadoLower == 'aceptada' || estadoLower == 'convertida' || estadoLower == 'orden_generada';
                              return [
                                const PopupMenuItem(value: 'enviar', child: Text('Enviar')),
                                if (!yaAceptada) const PopupMenuItem(value: 'aceptar', child: Text('Aceptar')),
                                if (!yaAceptada) const PopupMenuItem(value: 'convertir', child: Text('Convertir a orden')),
                              ];
                            },
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

// Picker genérico simple para listas paginadas
class _SimpleListPicker extends StatefulWidget {
  final String title;
  final Future<List<Map<String, dynamic>>> Function(int page) loader;
  final String Function(Map<String, dynamic>) titleFrom;
  final String Function(Map<String, dynamic>)? subtitleFrom;

  const _SimpleListPicker({
    required this.title,
    required this.loader,
    required this.titleFrom,
    this.subtitleFrom,
  });

  @override
  State<_SimpleListPicker> createState() => _SimpleListPickerState();
}

class _SimpleListPickerState extends State<_SimpleListPicker> {
  final List<Map<String, dynamic>> _rows = [];
  int _page = 1;
  bool _loading = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading || _end) return;
    setState(() { _loading = true; });
    try {
      final data = await widget.loader(_page);
      if (data.isEmpty) {
        _end = true;
      } else {
        _rows.addAll(data);
        _page += 1;
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ]),
            const SizedBox(height: 8),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  if (!_end && !_loading && n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                    _load();
                  }
                  return false;
                },
                child: ListView.separated(
                  itemCount: _rows.length + (_loading ? 1 : 0),
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index >= _rows.length) {
                      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                    }
                    final it = _rows[index];
                    final title = widget.titleFrom(it);
                    final subtitle = widget.subtitleFrom?.call(it);
                    return ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(title),
                      subtitle: subtitle != null && subtitle.isNotEmpty ? Text(subtitle) : null,
                      onTap: () => Navigator.pop(context, it),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}





// Sheet para buscar y seleccionar cliente
class _ClientSearchSheet extends StatefulWidget {
  final CrmService svc;
  const _ClientSearchSheet({required this.svc});
  @override
  State<_ClientSearchSheet> createState() => _ClientSearchSheetState();
}

class _ClientSearchSheetState extends State<_ClientSearchSheet> {
  final _q = TextEditingController();
  final List<Map<String, dynamic>> _results = [];
  int _page = 1;
  bool _loading = false;
  bool _end = false;

  @override
  void initState() {
    super.initState();
    _search(reset: true);
  }

  Future<void> _search({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) { _results.clear(); _page = 1; _end = false; }
    });
    try {
      final rows = await widget.svc.listClients(query: _q.text.trim(), page: _page, perPage: 20);
      if (rows.isEmpty) { _end = true; }
      _results.addAll(rows);
      _page += 1;
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Seleccionar cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _q,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o NIT',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: () => _search(reset: true)),
              ),
              onSubmitted: (_) => _search(reset: true),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _results.isEmpty && !_loading
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No hay clientes'),
                        const SizedBox(height: 8),
                        TextButton.icon(onPressed: () { Navigator.pop(context); context.go('/crm/clients'); }, icon: const Icon(Icons.person_add_alt), label: const Text('Crear cliente')),
                      ]),
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (!_end && !_loading && n.metrics.pixels >= n.metrics.maxScrollExtent - 100) {
                          _search();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        itemCount: _results.length + (_loading ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          if (index >= _results.length) {
                            return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                          }
                          final it = _results[index];
                          final title = (it['razon_social'] ?? '').toString();
                          final subtitle = 'NIT: ' + ((it['nit'] ?? '').toString());
                          return ListTile(
                            leading: const Icon(Icons.business),
                            title: Text(title),
                            subtitle: Text(subtitle),
                            onTap: () => Navigator.pop(context, it),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
