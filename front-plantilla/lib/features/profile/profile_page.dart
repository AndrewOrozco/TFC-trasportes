import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/theme.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _name;
  String? _role;
  String? _email;
  String? _phone;
  String? _documentId;
  String? _plate;
  String? _license;
  int? _battery;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchMe();
  }

  Future<void> _fetchMe() async {
    try {
      final rawBase = dotenv.env['API_BASE_URL'];
      final token = TokenStorage.token;
      if (rawBase == null || token == null) throw Exception('Falta configuración');
      final dio = Dio(BaseOptions(
        baseUrl: resolveBaseUrlForPlatform(rawBase),
        headers: {'Authorization': 'Bearer $token'},
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      ));
      final res = await dio.get('me');
      final Map<String, dynamic> data = (res.data as Map?)?.cast<String, dynamic>() ?? {};
      setState(() {
        _name = (data['operator_name'] ?? data['name'])?.toString();
        _role = (data['role'] ?? (data['roles'] is List ? (data['roles'] as List).first : null))?.toString();
        _email = data['email']?.toString();
        _phone = data['phone']?.toString();
        _documentId = (data['document_id'] ?? data['cedula'])?.toString();
        _plate = (data['vehicle_placa'] ?? data['plate'])?.toString();
        _license = (data['operator_licenses'] ?? data['operator_license'] ?? data['license'])?.toString();
        final dynamic bat = data['battery'];
        if (bat is int) _battery = bat; else if (bat is String) _battery = int.tryParse(bat);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; });
    }
  }

  Future<void> _onLogout() async {
    try {
      final rt = TokenStorage.refreshToken;
      final rawBase = dotenv.env['API_BASE_URL'];
      if (rt != null && rawBase != null && rawBase.isNotEmpty) {
        final dio = Dio(BaseOptions(
          baseUrl: resolveBaseUrlForPlatform(rawBase),
          headers: {'Authorization': 'Bearer ${TokenStorage.token ?? ''}'},
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ));
        await dio.post('auth/logout', data: {'refresh_token': rt});
      }
    } catch (_) {
      // Ignorar fallo de logout en servidor
    } finally {
      await TokenStorage.clear();
      if (!mounted) return;
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        color: Colors.white,
        elevation: 8,
        surfaceTintColor: Colors.white,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => context.go('/home'),
                icon: Icon(Icons.home, color: AppColors.azul),
                tooltip: 'Inicio',
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.notifications_none, color: AppColors.azul.withOpacity(0.45)),
                tooltip: 'Notificaciones',
              ),
              const SizedBox(width: 48),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.bolt_outlined, color: AppColors.azul.withOpacity(0.45)),
                tooltip: 'Clips',
              ),
              IconButton(
                onPressed: () {},
                icon: Icon(Icons.person, color: AppColors.azul),
                tooltip: 'Usuario',
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            // Header azul con avatar y nombre
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
              decoration: BoxDecoration(
                color: AppColors.azul,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white24,
                    child: ClipOval(
                      child: Image.asset(
                        'assets/avatar_placeholder.png',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person, size: 56, color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(_name ?? 'Usuario',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      )),
                  const SizedBox(height: 4),
                  Text((_role ?? 'Role').toUpperCase(),
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Campos de contacto
            if (_email != null) _InfoTile(icon: Icons.email_outlined, label: _email!),
            if (_email != null) const SizedBox(height: 10),
            if (_phone != null) _InfoTile(icon: Icons.phone_outlined, label: _phone!),
            if (_phone != null) const SizedBox(height: 10),
            if (_documentId != null) _InfoTile(icon: Icons.badge_outlined, label: _documentId!),
            if (_documentId != null) const SizedBox(height: 10),
            if (_license != null) _InfoTile(icon: Icons.credit_card, label: 'Licencia: ${_license!}'),
            if (_license != null) const SizedBox(height: 10),
            if (_plate != null)
              _InfoTile(
                icon: Icons.directions_car_outlined,
                label: _plate!,
                trailing: _battery != null ? _BatteryBadge(value: _battery!) : null,
              ),

            const SizedBox(height: 16),

            // Métricas
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.amarillo,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  _Stat(value: '32', label: 'Órdenes completadas'),
                  _Stat(value: '8', label: 'Alertas'),
                  _Stat(value: '2', label: 'Incidentes'),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Acciones
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    color: AppColors.amarillo,
                    foreground: AppColors.azul,
                    icon: Icons.edit,
                    label: 'Editar\nperfil',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    color: AppColors.rojo,
                    foreground: Colors.white,
                    icon: Icons.logout,
                    label: 'Cerrar sesión',
                    onTap: _onLogout,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  const _InfoTile({required this.icon, required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
        ],
        border: Border.all(color: AppColors.azul.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.azul, fontWeight: FontWeight.w600))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _BatteryBadge extends StatelessWidget {
  final int value; // 0-100
  const _BatteryBadge({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.azul.withOpacity(0.2)),
      ),
      child: Text('$value%', style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w800)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: AppColors.azul, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: AppColors.azul, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.color, required this.foreground, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 10),
              Text(label, textAlign: TextAlign.center, style: TextStyle(color: foreground, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}


