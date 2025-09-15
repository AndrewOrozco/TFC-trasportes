import 'package:flutter/material.dart';
import 'package:frontend/theme.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/token_storage.dart';
import 'package:frontend/core/api_base.dart';
 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final String? baseUrl = dotenv.env['API_BASE_URL'];
      if (baseUrl == null || baseUrl.isEmpty) {
        throw Exception('Falta API_BASE_URL en .env');
      }

      final dio = Dio(
        BaseOptions(
          baseUrl: resolveBaseUrlForPlatform(baseUrl),
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      dio.interceptors.add(LogInterceptor(request: true, requestBody: true, responseBody: false));

      final res = await dio.post(
        'auth/login',
        data: {
          'grant_type': 'password',
          'username': _emailController.text.trim(),
          'password': _passwordController.text,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      if (!mounted) return;
      // Guarda token si el backend devuelve JWT
      final data = res.data;
      final String? accessToken = data is Map<String, dynamic> ? data['access_token'] as String? : null;
      final String? refreshToken = data is Map<String, dynamic> ? data['refresh_token']?.toString() : null;
      if (accessToken != null) {
        await TokenStorage.saveTokens(accessToken: accessToken, refreshToken: refreshToken);
        // leer role/company_id directamente de la respuesta si vienen
        final String? roleResp = (data['role'])?.toString();
        final String? companyResp = (data['company_id'] ?? data['companyId'])?.toString();
        if (roleResp != null || companyResp != null) {
          TokenStorage.setRoleAndCompany(role: roleResp, companyId: companyResp);
        }
        // fallback: /me si siguen faltando
        if (TokenStorage.currentRole == null || TokenStorage.currentCompanyId == null) {
          try {
            final me = await dio.get('me', options: Options(headers: {'Authorization': 'Bearer $accessToken'}));
            final Map<String, dynamic> meData = (me.data as Map?)?.cast<String, dynamic>() ?? {};
            final String? role = (meData['role'] ?? (meData['roles'] is List ? (meData['roles'] as List).first : null))?.toString();
            final String? companyId = (meData['companyId'] ?? meData['company_id'])?.toString();
            TokenStorage.setRoleAndCompany(role: role, companyId: companyId);
          } catch (_) {}
        }
      }
      context.go('/home');
    } on DioException catch (e) {
      if (!mounted) return;
      final r = e.response;
      final int status = r?.statusCode ?? 0;
      final Map<String, dynamic> data = (r?.data is Map)
          ? (r!.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      final String detail = (data['detail'] ?? data['message'] ?? data['error'] ?? '').toString();
      String msg;
      if (status == 401) {
        msg = detail.isNotEmpty ? detail : 'Credenciales inválidas';
      } else {
        final uri = e.requestOptions.uri.toString();
        msg = detail.isNotEmpty ? detail : 'Error de login (código $status)';
        msg = '[$status] ' + uri + (detail.isNotEmpty ? ' · ' + detail : '');
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error de login: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'TFC',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 56,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Text(
                      'TRANSPORTES',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 36),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Inicia sesión',
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              style: TextStyle(color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Correo electrónico',
                                prefixIcon: Icon(Icons.email_outlined, color: Colors.black54),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Ingresa tu correo';
                                final r = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                                if (!r.hasMatch(v)) return 'Correo no válido';
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              style: TextStyle(color: Colors.black87),
                              decoration: const InputDecoration(
                                hintText: 'Contraseña',
                                prefixIcon: Icon(Icons.lock_outline, color: Colors.black54),
                              ),
                              validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                            ),
                            const SizedBox(height: 18),
                            ElevatedButton(
                              onPressed: _isLoading ? null : _onLogin,
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text('Iniciar sesión'),
                            ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () {},
                              style: TextButton.styleFrom(foregroundColor: Colors.white70),
                              child: const Text('¿Olvidaste tu contraseña?'),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _ColorPill(color: AppColors.amarillo),
                        SizedBox(width: 6),
                        _ColorPill(color: AppColors.azul),
                        SizedBox(width: 6),
                        _ColorPill(color: AppColors.rojo),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPill extends StatelessWidget {
  final Color color;
  const _ColorPill({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      width: 42,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(32),
      ),
    );
  }
}







