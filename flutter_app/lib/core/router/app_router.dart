// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crisis_response_app/features/auth/screens/login_screen.dart';
import 'package:crisis_response_app/features/auth/screens/admin_login_screen.dart';
import 'package:crisis_response_app/features/home/screens/main_scaffold.dart';
import 'package:crisis_response_app/features/admin/screens/admin_dashboard_screen.dart';
import 'package:crisis_response_app/features/emergency/screens/emergency_detail_screen.dart';
import 'package:crisis_response_app/features/home/screens/request_help_screen.dart';
import 'package:crisis_response_app/features/ai_assistant/screens/ai_assistant_screen.dart';
import 'package:crisis_response_app/core/constants/app_constants.dart';
import 'package:crisis_response_app/features/responder/screens/responder_dashboard_screen.dart';
//import '../../features/splash/splash_screen.dart';

final _storage = const FlutterSecureStorage();

final GoRouter appRouter = GoRouter(
  initialLocation: RouteNames.login,
  redirect: (context, state) async {
    // Never redirect away from splash
    //if (state.matchedLocation == RouteNames.splash) return null;

    final token = await _storage.read(key: StorageKeys.accessToken);
    final expiry = await _storage.read(key: StorageKeys.sessionExpiry);
    final role = await _storage.read(key: StorageKeys.userRole);

    final isLoggedIn = token != null &&
        expiry != null &&
        DateTime.now().isBefore(DateTime.parse(expiry));

    final onAuthPage = state.matchedLocation == RouteNames.login ||
        state.matchedLocation == RouteNames.adminLogin;

    if (!isLoggedIn && !onAuthPage) {
      final protectedRoutes = [
        RouteNames.adminDashboard,
        RouteNames.responderDashboard,
      ];
      if (protectedRoutes.contains(state.matchedLocation)) {
        return RouteNames.login;
      }
    }

    if (isLoggedIn && onAuthPage) {
      if (role == 'admin') return RouteNames.adminDashboard;
      if (role == 'responder') return RouteNames.responderDashboard;
      return RouteNames.home;
    }

    return null;
  },
  routes: [
    // GoRoute(
    //   path: RouteNames.splash,
    //   builder: (context, state) => const SplashScreen(),
    // ),
    GoRoute(
      path: RouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: RouteNames.adminLogin,
      builder: (context, state) => const AdminLoginScreen(),
    ),
    GoRoute(
      path: RouteNames.home,
      builder: (context, state) => const MainScaffold(),
      routes: [
        GoRoute(
          path: 'request-help',
          builder: (context, state) => const RequestHelpScreen(),
        ),
        GoRoute(
          path: 'assistant',
          builder: (context, state) => const AiAssistantScreen(),
        ),
        GoRoute(
          path: 'emergency/:type',
          builder: (context, state) => EmergencyDetailScreen(
            type: state.pathParameters['type'] ?? 'flood',
          ),
        ),
      ],
    ),
    GoRoute(
      path: RouteNames.adminDashboard,
      builder: (context, state) => const AdminDashboardScreen(),
    ),
    GoRoute(
      path: RouteNames.responderDashboard,
      builder: (_, __) => const ResponderDashboardScreen(),
    ),
  ],
  errorBuilder: (context, state) => Scaffold(
    backgroundColor: const Color(0xFF0A1628),
    body: Center(
      child: Text(
        'Page not found: ${state.uri}',
        style: const TextStyle(color: Colors.white),
      ),
    ),
  ),
);