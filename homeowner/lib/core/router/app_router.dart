import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/views/firebase_login_screen.dart';
import '../../features/auth/views/register_screen.dart';
import '../../features/auth/views/firebase_dashboard_screen.dart';
import '../../features/auth/viewmodels/firebase_auth_viewmodel.dart';
import '../../features/chat/views/chat_list_screen.dart';
import '../../features/chat/views/chat_screen.dart';
import '../../features/chat/views/select_user_screen.dart';
import '../../features/job_posting/views/job_post_form_screen.dart';
import '../../features/job_posting/views/job_post_success_sccreen.dart';
import '../../features/job_posting/views/job_list_screen.dart';
import '../../features/job_posting/views/job_details_screen.dart';

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
            otherUserType: extra?['otherUserType'] ?? 'tradie',
          );
        },
      ),
      GoRoute(
        path: '/post-job',
        builder: (context, state) => const JobPostFormScreen(),
      ),
      GoRoute(
        path: '/job-success',
        builder: (context, state) => const JobPostSuccessScreen(),
      ),
      GoRoute(
        path: '/my-jobs',
        builder: (context, state) => const JobListScreen(),
      ),
      GoRoute(
        path: '/jobs/:jobId',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;

          if (extra != null) {
            return JobDetailsScreen(job: extra);
          }

          // If no extra data, navigate back to job list
          Future.microtask(() => context.go('/my-jobs'));
          return const SizedBox.shrink();
        },
      ),
    ],
  );
});
