import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';

class CrmService {
  CrmService();

  Dio _dio() {
    final rawBase = dotenv.env['API_BASE_URL'] ?? '';
    return Dio(BaseOptions(
      baseUrl: resolveBaseUrlForPlatform(rawBase),
      headers: {
        if (TokenStorage.token != null) 'Authorization': 'Bearer ${TokenStorage.token}',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
  }

  // Clientes
  Future<List<Map<String, dynamic>>> listClients({String? query, int page = 1, int perPage = 20}) async {
    final res = await _dio().get('crm/clientes', queryParameters: {
      if (query != null && query.isNotEmpty) 'q': query,
      'page': page,
      'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/clientes', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateClient(int id, Map<String, dynamic> payload) async {
    final res = await _dio().patch('crm/clientes/$id', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  // Contactos de cliente
  Future<List<Map<String, dynamic>>> listContacts(int clientId, {int page = 1, int perPage = 20}) async {
    final res = await _dio().get('crm/clientes/$clientId/contactos', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createContact(int clientId, Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/clientes/$clientId/contactos', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateContact(int clientId, int contactId, Map<String, dynamic> payload) async {
    final res = await _dio().patch('crm/clientes/$clientId/contactos/$contactId', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  // Invitación al portal del cliente: crea user con rol 'client' ligado al cliente
  Future<void> inviteContactToPortal({required int clientId, required String email, String? password}) async {
    await _dio().post('users', data: {
      'email': email,
      if (password != null && password.isNotEmpty) 'password': password,
      'role': 'client',
      'client_id': clientId,
    });
  }

  // Leads
  Future<List<Map<String, dynamic>>> listLeads({String? q, String? estado, int page = 1, int perPage = 20}) async {
    final res = await _dio().get('crm/leads', queryParameters: {
      if (q != null && q.isNotEmpty) 'q': q,
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      'page': page,
      'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createLead(Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/leads', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateLead(int id, Map<String, dynamic> payload) async {
    final res = await _dio().patch('crm/leads/$id', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  // Oportunidades
  Future<List<Map<String, dynamic>>> listOpportunities({String? etapa, String? q, int page = 1, int perPage = 20}) async {
    final res = await _dio().get('crm/oportunidades', queryParameters: {
      if (etapa != null && etapa.isNotEmpty) 'etapa': etapa,
      if (q != null && q.isNotEmpty) 'q': q,
      'page': page,
      'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createOpportunity(Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/oportunidades', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateOpportunity(int id, Map<String, dynamic> payload) async {
    final res = await _dio().patch('crm/oportunidades/$id', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  // Cotizaciones
  Future<List<Map<String, dynamic>>> listQuotes({int page = 1, int perPage = 20}) async {
    final res = await _dio().get('crm/cotizaciones', queryParameters: {
      'page': page,
      'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> createQuote(Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/cotizaciones', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> calculatePricing(Map<String, dynamic> payload) async {
    final res = await _dio().post('crm/pricing/calculate', data: payload);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> sendQuote(int id) async {
    await _dio().post('crm/cotizaciones/$id/enviar');
  }

  Future<void> acceptQuote(int id) async {
    await _dio().post('crm/cotizaciones/$id/aceptar');
  }

  Future<void> convertQuoteToOrder(int id) async {
    await _dio().post('crm/cotizaciones/$id/convertir');
  }
}


