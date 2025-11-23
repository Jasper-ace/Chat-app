import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/widgets/theme_settings_card.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTextStyles.appBarTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Settings Section
            const ThemeSettingsCard(),
            const SizedBox(height: AppDimensions.spacing24),

            // Other Settings Sections
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.notifications,
                          color: AppColors.primary,
                          size: AppDimensions.iconMedium,
                        ),
                        const SizedBox(width: AppDimensions.spacing8),
                        Text(
                          'Notifications',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildSettingItem(
                      context,
                      Icons.notifications_active,
                      'Push Notifications',
                      'Receive notifications for new jobs',
                      true,
                      (value) {
                        // Handle notification toggle
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Push notifications ${value ? 'enabled' : 'disabled'}',
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacing8),
                    _buildSettingItem(
                      context,
                      Icons.email,
                      'Email Notifications',
                      'Receive email updates',
                      false,
                      (value) {
                        // Handle email toggle
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Email notifications ${value ? 'enabled' : 'disabled'}',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_circle,
                          color: AppColors.primary,
                          size: AppDimensions.iconMedium,
                        ),
                        const SizedBox(width: AppDimensions.spacing8),
                        Text(
                          'Account',
                          style: AppTextStyles.titleLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacing16),
                    _buildActionItem(
                      context,
                      Icons.person,
                      'Edit Profile',
                      'Update your personal information',
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile screen coming soon!'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.spacing8),
                    _buildActionItem(
                      context,
                      Icons.security,
                      'Privacy & Security',
                      'Manage your privacy settings',
                      () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Privacy settings coming soon!'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.onSurfaceVariant,
          size: AppDimensions.iconMedium,
        ),
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.titleMedium),
              const SizedBox(height: AppDimensions.spacing4),
              Text(
                subtitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildActionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing8),
        child: Row(
          children: [
            Icon(
              icon,
              color: AppColors.onSurfaceVariant,
              size: AppDimensions.iconMedium,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppDimensions.spacing4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
