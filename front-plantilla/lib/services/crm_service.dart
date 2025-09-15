import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:frontend/core/api_base.dart';
import 'package:frontend/core/token_storage.dart';

class CrmService {
  CrmService();

  Dio _dio() {
    final rawBase = dotenv.env['API_BASE_URL'] ?? '';
    final dio = Dio(BaseOptions(
      baseUrl: resolveBaseUrlForPlatform(rawBase),
      headers: {
        if (TokenStorage.token != null) 'Authorization': 'Bearer ${TokenStorage.token}',
      },
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    dio.interceptors.add(LogInterceptor(request: true, requestBody: true, responseBody: false));
    return dio;
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

  Future<Map<String, dynamic>> convertQuoteToOrder(int id, {String? rutaOrigen, String? rutaDestino}) async {
    final res = await _dio().post('crm/cotizaciones/$id/convertir', data: {
      'quotation_id': id,
      if (rutaOrigen != null) 'ruta_origen': rutaOrigen,
      if (rutaDestino != null) 'ruta_destino': rutaDestino,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  // OPS: vehicles/operators/assignments/events
  Future<List<Map<String, dynamic>>> listVehicles({int page = 1, int perPage = 20}) async {
    final res = await _dio().get('ops/vehicles', queryParameters: { 'page': page, 'per_page': perPage });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> listOperators({String? role, int page = 1, int perPage = 20}) async {
    final res = await _dio().get('ops/operators', queryParameters: {
      if (role != null && role.isNotEmpty) 'role': role,
      'page': page, 'per_page': perPage,
    });
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<Map<String, dynamic>> assignOrder({required int orderId, required int vehicleId, required int operatorId, int? allyId, String? turno, int? horasConduccion}) async {
    final res = await _dio().post('ops/orders/$orderId/assignments', data: {
      'vehicle_id': vehicleId,
      'operator_id': operatorId,
      if (allyId != null) 'ally_id': allyId,
      if (turno != null) 'turno': turno,
      if (horasConduccion != null) 'horas_conduccion': horasConduccion,
    });
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> addOrderEvent({required int orderId, required String tipo, String? message, double? lat, double? lng}) async {
    await _dio().post('ops/orders/$orderId/events', data: {
      'tipo': tipo,
      if (message != null) 'message': message,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
    });
  }

  Future<List<Map<String, dynamic>>> listOrderEvents(int orderId) async {
    final res = await _dio().get('ops/orders/$orderId/events');
    final List data = (res.data as List?) ?? [];
    return data.cast<Map>().map((e) => (e as Map).cast<String, dynamic>()).toList();
  }

  Future<void> updateOrderStatus({required int orderId, required String estado}) async {
    await _dio().patch('ops/orders/$orderId/estado', queryParameters: { 'estado': estado });
  }
}


