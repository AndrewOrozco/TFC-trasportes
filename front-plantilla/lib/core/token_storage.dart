import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _kAccessTokenKey = 'access_token';
  static const String _kRefreshTokenKey = 'refresh_token';

  static String? _cachedToken;
  static String? _cachedRefreshToken;
  static DateTime? _cachedExpiryUtc;
  static String? _cachedRole;
  static String? _cachedCompanyId;

  // Notifica cambios de sesión para GoRouter
  static final ValueNotifier<bool> authState = ValueNotifier<bool>(false);

  static Future<void> init() async {
    _cachedToken = await _storage.read(key: _kAccessTokenKey);
    _cachedRefreshToken = await _storage.read(key: _kRefreshTokenKey);
    if (_cachedToken != null) {
      final payload = _decodeJwtPayload(_cachedToken!);
      _cachedExpiryUtc = _extractExpiryUtc(payload);
      _cachedRole = _extractRole(payload);
      _cachedCompanyId = _extractCompanyId(payload);
    } else {
      _cachedExpiryUtc = null;
      _cachedRole = null;
      _cachedCompanyId = null;
    }
    authState.value = isLoggedIn;
  }

  static bool get isLoggedIn => _cachedToken != null && !isExpired;

  static bool get isExpired {
    if (_cachedExpiryUtc == null) return true;
    return DateTime.now().toUtc().isAfter(_cachedExpiryUtc!);
  }

  static String? get token => _cachedToken;
  static String? get refreshToken => _cachedRefreshToken;
  static String? get currentRole => _cachedRole;
  static String? get currentCompanyId => _cachedCompanyId;

  static Future<void> saveToken(String token) async {
    _cachedToken = token;
    final payload = _decodeJwtPayload(token);
    _cachedExpiryUtc = _extractExpiryUtc(payload);
    _cachedRole = _extractRole(payload);
    _cachedCompanyId = _extractCompanyId(payload);
    await _storage.write(key: _kAccessTokenKey, value: token);
    authState.value = isLoggedIn;
  }

  static Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    await saveToken(accessToken);
    if (refreshToken != null) {
      _cachedRefreshToken = refreshToken;
      await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
    }
  }

  static Future<void> clear() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    _cachedExpiryUtc = null;
    _cachedRole = null;
    _cachedCompanyId = null;
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
    authState.value = false;
  }

  // Helpers de decodificación de JWT
  static Map<String, dynamic> _decodeJwtPayload(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return <String, dynamic>{};
      final normalized = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static DateTime? _extractExpiryUtc(Map<String, dynamic> payload) {
    final dynamic exp = payload['exp'];
    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    }
    return null;
  }

  static String? _extractRole(Map<String, dynamic> payload) {
    final dynamic role = payload['role'] ?? payload['roles'];
    if (role is String) return role;
    if (role is List && role.isNotEmpty) return role.first.toString();
    return null;
  }

  static String? _extractCompanyId(Map<String, dynamic> payload) {
    final dynamic cid = payload['companyId'] ?? payload['company_id'] ?? payload['tenantId'];
    if (cid == null) return null;
    return cid.toString();
  }

  // Permite establecer rol y empresa desde una llamada /me cuando el JWT no trae claims
  static void setRoleAndCompany({String? role, String? companyId}) {
    _cachedRole = role ?? _cachedRole;
    _cachedCompanyId = companyId ?? _cachedCompanyId;
    authState.value = isLoggedIn;
  }
}


