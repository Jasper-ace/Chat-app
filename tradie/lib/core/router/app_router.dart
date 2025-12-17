import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/views/firebase_login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/firebase_dashboard_screen.dart';
import '../../features/auth/viewmodels/firebase_auth_viewmodel.dart';
import '../../features/chat/views/chat_list_screen.dart';
import '../../features/chat/views/chat_screen.dart';
import '../../features/chat/views/select_user_screen.dart';
import '../../features/chat/views/settings_screen.dart';
import '../../features/job_posting/myJobs.dart';
import '../../features/job_posting/view_details.dart';

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
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const FirebaseDashboardScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/new',
        builder: (context, state) => const SelectUserScreen(),
      ),
      GoRoute(
        path: '/chat/:chatId',
        builder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return ChatScreen(
            chatId: chatId,
            otherUserName: extra?['otherUserName'] ?? 'User',
            otherUserId: extra?['otherUserId'] ?? '',
            otherUserType: extra?['otherUserType'] ?? 'homeowner',
          );
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/my-jobs',
        builder: (context, state) => const MyJobsScreen(),
      ),
      GoRoute(
        path: '/job-details',
        builder: (context, state) {
          final job = state.extra as Map<String, dynamic>;
          return JobDetailsScreen(job: job);
        },
      ),
    ],
  );
});
