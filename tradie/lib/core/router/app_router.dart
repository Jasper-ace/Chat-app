import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/views/firebase_login_screen.dart';
import '../../features/auth/views/firebase_register_screen.dart';
import '../../features/auth/views/firebase_dashboard_screen.dart';
import '../../features/auth/viewmodels/firebase_auth_viewmodel.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(firebaseAuthViewModelProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isAuthenticated = authState.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      // If not authenticated and not on login/register page, redirect to login
      if (!isAuthenticated && !isLoggingIn && !isRegistering) {
        return '/login';
      }

      // If authenticated and on login/register page, redirect to dashboard
      if (isAuthenticated && (isLoggingIn || isRegistering)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const FirebaseLoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const FirebaseRegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const FirebaseDashboardScreen(),
      ),
    ],
  );
});
