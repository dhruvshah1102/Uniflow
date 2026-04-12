import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/student/student_module_screen.dart';
import '../screens/faculty/faculty_dashboard_screen.dart';
import '../screens/admin/admin_curator_screen.dart';
import '../core/constants/app_colors.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: '/login',
      refreshListenable: authProvider,
      redirect: (context, state) {
        final isLoading = authProvider.isLoading;
        final user = authProvider.currentUser;
        final onLogin = state.matchedLocation == '/login';

        // Still initializing — stay where you are
        if (isLoading) return null;

        // Not logged in → always go to login
        if (user == null) {
          return onLogin ? null : '/login';
        }

        // Logged in but trying to access login → redirect to own dashboard
        if (onLogin) {
          switch (user.role) {
            case 'student': return '/student/dashboard';
            case 'faculty': return '/faculty/dashboard';
            case 'admin':   return '/admin/dashboard';
          }
        }

        // Logged in and trying to access WRONG role's screen → redirect to own
        final loc = state.matchedLocation;
        if (user.role == 'student' && loc.startsWith('/faculty')) return '/student/dashboard';
        if (user.role == 'student' && loc.startsWith('/admin'))   return '/student/dashboard';
        if (user.role == 'faculty' && loc.startsWith('/student')) return '/faculty/dashboard';
        if (user.role == 'faculty' && loc.startsWith('/admin'))   return '/faculty/dashboard';
        if (user.role == 'admin'   && loc.startsWith('/student')) return '/admin/dashboard';
        if (user.role == 'admin'   && loc.startsWith('/faculty')) return '/admin/dashboard';

        return null; // all good, stay on current route
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/student/dashboard',
          builder: (context, state) => StudentDashboardScreen(
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
        GoRoute(
          path: '/faculty/dashboard',
          builder: (context, state) => FacultyDashboardScreen(
            initialTab: state.uri.queryParameters['tab'],
          ),
        ),
        GoRoute(
          path: '/admin/dashboard',
          builder: (context, state) => const AdminCuratorScreen(),
        ),
      ],
    );
  }
}

// SPLASH / LOADING STATE
class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Transform.rotate(
              angle: 0.785398, // 45 degrees in radians
              child: Container(
                width: 40,
                height: 40,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Uniflow',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.ink900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
