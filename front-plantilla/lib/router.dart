import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/core/token_storage.dart';

import 'features/auth/login_page.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';
import 'features/users/create_user_page.dart';
import 'features/catalogs/vehicle_types_page.dart';
import 'features/companies/companies_page.dart';
import 'features/orders/orders_page.dart';
import 'features/orders/order_detail_page.dart';
import 'features/crm/clients_page.dart';
import 'features/crm/leads_page.dart';
import 'features/crm/opportunities_page.dart';
import 'features/crm/quotes_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    refreshListenable: TokenStorage.authState,
    redirect: (context, state) {
      final loggedIn = TokenStorage.isLoggedIn;
      final role = TokenStorage.currentRole;
      final goingToLogin = state.fullPath == '/';
      if (!loggedIn && !goingToLogin) return '/';
      if (loggedIn && goingToLogin) {
        if (role == 'conductor') return '/home'; // placeholder conductor
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
      // placeholders para gestión de usuarios
      GoRoute(path: '/users/create', builder: (context, state) => const CreateUserPage()),
      GoRoute(path: '/users/delete', builder: (context, state) => const _Placeholder(title: 'Borrar usuario')),
      GoRoute(path: '/users/update', builder: (context, state) => const _Placeholder(title: 'Actualizar datos')),
      // catálogos
      GoRoute(path: '/catalogs/vehicle_types', builder: (context, state) => const VehicleTypesPage()),
      // empresas
      GoRoute(path: '/companies', builder: (context, state) => const CompaniesPage()),
      // órdenes
      GoRoute(path: '/orders', builder: (context, state) => const OrdersPage()),
      GoRoute(path: '/orders/:id', builder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        return OrderDetailPage(orderId: id);
      }),
      // CRM - clientes
      GoRoute(path: '/crm/clients', builder: (context, state) => const ClientsPage()),
      // CRM - leads
      GoRoute(path: '/crm/leads', builder: (context, state) => const LeadsPage()),
      // CRM - oportunidades
      GoRoute(path: '/crm/opportunities', builder: (context, state) => const OpportunitiesPage()),
      // CRM - cotizaciones
      GoRoute(path: '/crm/quotes', builder: (context, state) => const QuotesPage()),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Ruta no encontrada: \\${state.error}')),
    ),
  );
});

class _Placeholder extends StatelessWidget {
  final String title;
  const _Placeholder({required this.title});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('En construcción')),
    );
  }
}


