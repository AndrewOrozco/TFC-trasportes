import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _Company {
  final int id;
  final String name;
  const _Company({required this.id, required this.name});

  factory _Company.fromJson(Map<String, dynamic> json) {
    return _Company(
      id: (json['id'] as num).toInt(),
      name: (json['name'] ?? json['nombre'] ?? '').toString(),
    );
  }
}

class _CreateUserPageState extends State<CreateUserPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _plate = TextEditingController();
  final TextEditingController _opName = TextEditingController();
  final TextEditingController _opLicense = TextEditingController(text: 'C2');
  String _role = 'comercial';
  bool _submitting = false;
  List<_Company> _companies = const [];
  int? _selectedCompanyId; // solo para super_admin
  String? _effectiveRole;

  // Vehículo
  bool _isOwnVehicle = true;
  int? _vehicleTypeId; // seleccionado
  List<Map<String, dynamic>> _vehicleTypes = const []; // desde /vehicle_types

  // Empresa (cuando super_admin crea admin)
  final TextEditingController _companyName = TextEditingController();
  final TextEditingController _companyNit = TextEditingController();
  bool _createNewCompany = false;

  bool get _isSuperAdmin {
    final role = (_effectiveRole ?? TokenStorage.currentRole ?? '').toLowerCase();
    return role.contains('super') || role == 'owner' || role == 'root';
  }

  bool get _isAdminCurrent {
    final role = (_effectiveRole ?? TokenStorage.currentRole ?? '').toLowerCase();
    return role == 'admin' || _isSuperAdmin;
  }

  bool get _shouldAskVehicle => _isAdminCurrent && _role == 'conductor';

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _plate.dispose();
    _opName.dispose();
    _opLicense.dispose();
    _companyName.dispose();
    _companyNit.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _effectiveRole = TokenStorage.currentRole;
    if ((_effectiveRole ?? '').isEmpty) {
      _ensureRoleFromApi();
    }
    if (_isSuperAdmin) _loadCompanies();
    _loadVehicleTypes();
    // coherencia de rol inicial
    if (_isSuperAdmin) {
      if (_role != 'super_admin' && _role != 'admin') _role = 'admin';
    } else {
      if (_role != 'comercial' && _role != 'conductor') _role = 'comercial';
    }
  }
  Future<void> _loadVehicleTypes() async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      if (rawBase == null || rawBase.isEmpty) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer ${TokenStorage.token}'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('catalogs/vehicle_types');
      final List data = (res.data as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _vehicleTypes = data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
        if (_vehicleTypes.isNotEmpty) {
          _vehicleTypeId = (_vehicleTypes.first['id'] as num).toInt();
        }
      });
    } catch (_) {
      // fallback a 1..4 si el backend aún no expone el catálogo
      if (!mounted) return;
      setState(() {
        _vehicleTypes = const [
          {'id': 1, 'name': 'Sencillo'},
          {'id': 2, 'name': 'Doble Troque'},
          {'id': 3, 'name': 'Tractomula'},
          {'id': 4, 'name': 'Cisterna'},
        ];
        _vehicleTypeId ??= 1;
      });
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      if (rawBase == null || rawBase.isEmpty) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer ${TokenStorage.token}'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('companies');
      final List data = (res.data as List?) ?? [];
      setState(() {
        _companies = data.map((e) => _Company.fromJson(e as Map<String, dynamic>)).toList();
        if (_companies.isNotEmpty) _selectedCompanyId = _companies.first.id;
      });
    } catch (_) {}
  }

  Future<void> _ensureRoleFromApi() async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || rawBase.isEmpty || token == null) return;
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('me');
      final Map<String, dynamic> data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      final String? role = (data['role'] ?? (data['roles'] is List ? (data['roles'] as List).first : null))?.toString();
      final String? companyId = (data['company_id'] ?? data['companyId'])?.toString();
      TokenStorage.setRoleAndCompany(role: role, companyId: companyId);
      if (!mounted) return;
      setState(() {
        _effectiveRole = role ?? _effectiveRole;
        if (_isSuperAdmin) {
          if (_role != 'super_admin' && _role != 'admin') _role = 'admin';
        } else {
          if (_role != 'comercial' && _role != 'conductor') _role = 'comercial';
        }
      });
    } catch (_) {}
  }

  List<DropdownMenuItem<String>> _roleItems() {
    final current = (_effectiveRole ?? TokenStorage.currentRole ?? '').toLowerCase();
    final isSuper = current.contains('super') || current == 'owner' || current == 'root';
    if (isSuper) {
      return const [
        DropdownMenuItem(value: 'super_admin', child: Text('Super admin')),
        DropdownMenuItem(value: 'admin', child: Text('Admin')),
      ];
    }
    if (current == 'admin') {
      return const [
        DropdownMenuItem(value: 'comercial', child: Text('Comercial')),
        DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
      ];
    }
    return const [
      DropdownMenuItem(value: 'comercial', child: Text('Comercial')),
      DropdownMenuItem(value: 'conductor', child: Text('Conductor')),
    ];
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      final String? rawBase = dotenv.env['API_BASE_URL'];
      if (rawBase == null || rawBase.isEmpty) throw Exception('Falta API_BASE_URL');
      final String baseUrl = resolveBaseUrlForPlatform(rawBase);
      final String? token = TokenStorage.token;
      if (token == null) throw Exception('Sin token de autenticación');

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));

      final Map<String, dynamic> payload = {
        'email': _email.text.trim(),
        'password': _password.text,
        'role': _role,
      };
      int? cid;
      if (_isSuperAdmin) {
        if (_createNewCompany && _role == 'admin') {
          // crear empresa primero (solo tiene sentido cuando creamos un admin)
          if (_companyName.text.trim().isEmpty || _companyNit.text.trim().isEmpty) {
            throw Exception('Ingresa nombre y NIT de la empresa');
          }
          final cres = await dio.post('companies', queryParameters: {
            'name': _companyName.text.trim(),
            'nit': _companyNit.text.trim(),
          });
          final Map<String, dynamic> cdata = (cres.data as Map?)?.cast<String, dynamic>() ?? {};
          cid = (cdata['id'] as num?)?.toInt();
        } else {
          cid = _selectedCompanyId;
        }
      } else {
        cid = int.tryParse(TokenStorage.currentCompanyId ?? '')
            ?? (TokenStorage.currentCompanyId != null ? int.parse(TokenStorage.currentCompanyId!) : null);
      }
      if (cid != null) payload['company_id'] = cid;

      final res = await dio.post('users', data: payload);

      // Si es conductor, crear vehículo primero y luego operador vinculando user_id y primary_vehicle_id
      if (_role == 'conductor' && _isAdminCurrent) {
        final Map<String, dynamic> created = (res.data as Map?)?.cast<String, dynamic>() ?? {};
        final int? userId = (created['id'] as num?)?.toInt();

        final String nombre = _opName.text.isNotEmpty ? _opName.text.trim() : _email.text.split('@').first;
        final String licencias = _opLicense.text.isNotEmpty ? _opLicense.text.trim() : 'C2';

        int? vehicleId;
        if (_plate.text.isNotEmpty && _vehicleTypeId != null) {
          try {
            final vres = await dio.post('ops/vehicles', data: {
              'placa': _plate.text.trim(),
              'tipo_id': _vehicleTypeId,
              'propio': _isOwnVehicle,
              if (cid != null) 'company_id': cid,
              if (cid == null) 'company_id': int.tryParse(TokenStorage.currentCompanyId ?? ''),
            });
            if (vres.data is Map) {
              vehicleId = ((vres.data as Map)['id'] as num?)?.toInt();
            }
          } catch (e) {
            // creación de vehículo opcional; continuar sin vehicleId
          }
        }

        if (userId != null) {
          try {
            await dio.post('ops/operators', data: {
              'nombre': nombre,
              'rol': 'conductor',
              'licencias': licencias,
              // user linkage (send both styles)
              'user_id': userId,
              'userId': userId,
              // primary vehicle linkage (optional; both styles)
              if (vehicleId != null) 'primary_vehicle_id': vehicleId,
              if (vehicleId != null) 'primaryVehicleId': vehicleId,
              // company scope (prefer selected; fallback to token)
              if (cid != null) 'company_id': cid,
              if (cid == null) 'company_id': int.tryParse(TokenStorage.currentCompanyId ?? ''),
            });
          } catch (e) {
            // log opcional
          }
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario creado')));
      if (context.canPop()) { context.pop(); } else { context.go('/home'); }
    } on DioException catch (e) {
      final r = e.response;
      final int status = r?.statusCode ?? 0;
      final Map<String, dynamic> data = (r?.data is Map)
          ? (r!.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final String serverMsg = (data['detail'] ?? data['message'] ?? data['error'] ?? '').toString();
      String msg;
      if (status == 409) {
        msg = serverMsg.isNotEmpty ? serverMsg : 'El correo ya está registrado.';
      } else if (status == 422) {
        msg = serverMsg.isNotEmpty ? serverMsg : 'Datos inválidos. Revisa el formulario.';
      } else {
        msg = serverMsg.isNotEmpty ? serverMsg : 'Error al crear usuario (código $status).';
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear usuario')),
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Text('Datos del usuario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.azul)),
                    const SizedBox(height: 16),
                    TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Correo', prefixIcon: Icon(Icons.email_outlined, color: Colors.black54)), validator: (v) { if (v == null || v.isEmpty) return 'Ingresa el correo'; final r = RegExp(r'^[^@]+@[^@]+\.[^@]+'); if (!r.hasMatch(v)) return 'Correo no válido'; return null; }),
                    const SizedBox(height: 12),
                    TextFormField(controller: _password, obscureText: true, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Contraseña', prefixIcon: Icon(Icons.lock_outline, color: Colors.black54)), validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(hintText: 'Rol', prefixIcon: Icon(Icons.security, color: Colors.black54)),
                      child: DropdownButtonHideUnderline(
                        child: Builder(builder: (context) {
                          final items = _roleItems();
                          final String? safeValue = items.any((e) => e.value == _role) ? _role : (items.isNotEmpty ? items.first.value : null);
                          return DropdownButton<String>(value: safeValue, items: items, onChanged: (v) => setState(() => _role = v ?? _role), dropdownColor: Colors.white, style: const TextStyle(color: Colors.black87));
                        }),
                      ),
                    ),

                    // --- Selección/creación de empresa (si super_admin crea cualquier rol) ---
                    if (_isSuperAdmin) const SizedBox(height: 12),
                    if (_isSuperAdmin) const Text('Empresa', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.azul)),
                    if (_isSuperAdmin) const SizedBox(height: 8),
                    if (_isSuperAdmin)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Crear nueva empresa (solo para rol admin)', style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)),
                        value: _createNewCompany,
                        onChanged: (v) => setState(() => _createNewCompany = v),
                      ),
                    if (_isSuperAdmin && !_createNewCompany)
                      InputDecorator(
                        decoration: const InputDecoration(hintText: 'Selecciona empresa', prefixIcon: Icon(Icons.business_outlined, color: Colors.black54)),
                        child: DropdownButtonHideUnderline(
                          child: Builder(builder: (context) {
                            final items = _companies
                                .map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name, style: const TextStyle(color: Colors.black87))))
                                .toList();
                            final int? safeValue = items.any((e) => e.value == _selectedCompanyId)
                                ? _selectedCompanyId
                                : (items.isNotEmpty ? items.first.value : null);
                            return DropdownButton<int>(
                              value: safeValue,
                              items: items,
                              onChanged: (v) => setState(() => _selectedCompanyId = v),
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black87),
                            );
                          }),
                        ),
                      ),
                    if (_isSuperAdmin && _createNewCompany) const SizedBox(height: 8),
                    if (_isSuperAdmin && _createNewCompany)
                      TextFormField(controller: _companyName, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Nombre de la empresa', prefixIcon: Icon(Icons.badge_outlined, color: Colors.black54)), validator: (v) { if (!(_isSuperAdmin && _role == 'admin' && _createNewCompany)) return null; if (v == null || v.isEmpty) return 'Ingresa el nombre'; return null; }),
                    if (_isSuperAdmin && _createNewCompany) const SizedBox(height: 8),
                    if (_isSuperAdmin && _createNewCompany)
                      TextFormField(controller: _companyNit, style: const TextStyle(color: Colors.black87), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'NIT', prefixIcon: Icon(Icons.confirmation_number_outlined, color: Colors.black54)), validator: (v) { if (!(_isSuperAdmin && _role == 'admin' && _createNewCompany)) return null; if (v == null || v.isEmpty) return 'Ingresa el NIT'; return null; }),

                    // ---- Datos del conductor y vehículo cuando admin crea conductor ----
                    if (_shouldAskVehicle) const SizedBox(height: 12),
                    if (_shouldAskVehicle) const Text('Datos del conductor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.azul)),
                    if (_shouldAskVehicle) const SizedBox(height: 8),
                    if (_shouldAskVehicle)
                      TextFormField(controller: _opName, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Nombre', prefixIcon: Icon(Icons.person_outline, color: Colors.black54)), validator: (v) { if (!_shouldAskVehicle) return null; if (v == null || v.isEmpty) return 'Ingresa el nombre'; return null; }),
                    if (_shouldAskVehicle) const SizedBox(height: 8),
                    if (_shouldAskVehicle)
                      TextFormField(controller: _opLicense, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Licencia (ej: C2)', prefixIcon: Icon(Icons.credit_card, color: Colors.black54)), validator: (v) { if (!_shouldAskVehicle) return null; if (v == null || v.isEmpty) return 'Ingresa la licencia'; return null; }),

                    if (_shouldAskVehicle) const SizedBox(height: 12),
                    if (_shouldAskVehicle) const Text('Datos del vehículo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.azul)),
                    if (_shouldAskVehicle) const SizedBox(height: 8),
                    if (_shouldAskVehicle)
                      TextFormField(controller: _plate, style: const TextStyle(color: Colors.black87), decoration: const InputDecoration(hintText: 'Placa', prefixIcon: Icon(Icons.directions_car_outlined, color: Colors.black54)), validator: (v) { if (!_shouldAskVehicle) return null; if (v == null || v.isEmpty) return 'Ingresa la placa'; return null; }),
                    if (_shouldAskVehicle) const SizedBox(height: 8),
                    if (_shouldAskVehicle)
                      InputDecorator(
                        decoration: const InputDecoration(hintText: 'Tipo de vehículo', prefixIcon: Icon(Icons.local_shipping_outlined, color: Colors.black54)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _vehicleTypeId,
                            items: _vehicleTypes.isNotEmpty
                                ? _vehicleTypes
                                    .map((e) => DropdownMenuItem(
                                          value: (e['id'] as num).toInt(),
                                          child: Text((e['name'] ?? e['nombre'] ?? '').toString(), style: const TextStyle(color: Colors.black87)),
                                        ))
                                    .toList()
                                : const [
                                    DropdownMenuItem(value: 1, child: Text('Sencillo', style: TextStyle(color: Colors.black87))),
                                    DropdownMenuItem(value: 2, child: Text('Doble Troque', style: TextStyle(color: Colors.black87))),
                                    DropdownMenuItem(value: 3, child: Text('Tractomula', style: TextStyle(color: Colors.black87))),
                                    DropdownMenuItem(value: 4, child: Text('Cisterna', style: TextStyle(color: Colors.black87))),
                                  ],
                            onChanged: (v) => setState(() => _vehicleTypeId = v),
                            dropdownColor: Colors.white,
                            style: const TextStyle(color: Colors.black87),
                          ),
                        ),
                      ),
                    if (_shouldAskVehicle) const SizedBox(height: 8),
                    if (_shouldAskVehicle)
                      SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Es propio', style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)), value: _isOwnVehicle, onChanged: (v) => setState(() => _isOwnVehicle = v)),

                    const SizedBox(height: 18),
                    ElevatedButton(onPressed: _submitting ? null : _submit, child: _submitting ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Crear usuario')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



