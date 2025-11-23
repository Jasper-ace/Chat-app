import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/firebase_auth_viewmodel.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

import '../../../core/theme/widgets/animated_theme_toggle.dart';

import '../../settings/views/settings_screen.dart';

class FirebaseDashboardScreen extends ConsumerWidget {
  const FirebaseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(firebaseAuthViewModelProvider);
    final authViewModel = ref.read(firebaseAuthViewModelProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Dashboard', style: AppTextStyles.appBarTitle),
        actions: [
          const AnimatedThemeToggle(),
          const SizedBox(width: AppDimensions.spacing8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await authViewModel.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout),
                    SizedBox(width: AppDimensions.spacing8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back!', style: AppTextStyles.headlineSmall),
                    const SizedBox(height: AppDimensions.spacing8),
                    if (authState.userData != null) ...[
                      Text(
                        authState.userData!.displayName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        authState.userData!.email,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'TRADIE',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (authState.userData!.tradeType != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.tradieBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                authState.userData!.tradeType!.toUpperCase(),
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.tradieBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),

            // Quick actions
            Text(
              'Quick Actions',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),

            Expanded(
              child: GridView.count(
                crossAxisCount: AppDimensions.gridCrossAxisCount,
                crossAxisSpacing: AppDimensions.gridSpacing,
                mainAxisSpacing: AppDimensions.gridSpacing,
                children: [
                  _buildActionCard(
                    context,
                    icon: Icons.chat,
                    title: 'Messages',
                    subtitle: 'Chat with homeowners',
                    color: Colors.blueAccent,
                    onTap: () {
                      final userId = authState.userData?.autoId ?? 1;
                      authViewModel.openChat(context, userId);
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.work,
                    title: 'My Jobs',
                    subtitle: 'View active jobs',
                    color: AppColors.tradieBlue,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Jobs screen coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.schedule,
                    title: 'Availability',
                    subtitle: 'Manage schedule',
                    color: AppColors.tradieOrange,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Availability screen coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.person,
                    title: 'Profile',
                    subtitle: 'Update your info',
                    color: AppColors.tradieGreen,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Profile screen coming soon!'),
                        ),
                      );
                    },
                  ),
                  _buildActionCard(
                    context,
                    icon: Icons.settings,
                    title: 'Settings',
                    subtitle: 'App preferences',
                    color: AppColors.grey600,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const AnimatedThemeCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingMedium),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusLarge,
                  ),
                ),
                child: Icon(icon, size: AppDimensions.iconLarge, color: color),
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
