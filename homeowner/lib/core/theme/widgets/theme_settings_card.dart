import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../app_colors.dart';
import '../app_dimensions.dart';
import '../app_text_styles.dart';

class ThemeSettingsCard extends ConsumerWidget {
  const ThemeSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: AppColors.primary,
                  size: AppDimensions.iconMedium,
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Text(
                  'Theme Settings',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              'Choose your preferred theme mode',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing16),

            // Theme options
            _buildThemeOption(
              context,
              ref,
              AppThemeMode.light,
              Icons.light_mode,
              'Light Mode',
              'Always use light theme',
              currentTheme,
              themeNotifier,
            ),
            const SizedBox(height: AppDimensions.spacing8),
            _buildThemeOption(
              context,
              ref,
              AppThemeMode.dark,
              Icons.dark_mode,
              'Dark Mode',
              'Always use dark theme',
              currentTheme,
              themeNotifier,
            ),
            const SizedBox(height: AppDimensions.spacing8),
            _buildThemeOption(
              context,
              ref,
              AppThemeMode.system,
              Icons.settings_system_daydream,
              'System Mode',
              'Follow device theme setting',
              currentTheme,
              themeNotifier,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode themeMode,
    IconData icon,
    String title,
    String subtitle,
    AppThemeMode currentTheme,
    ThemeNotifier themeNotifier,
  ) {
    final isSelected = currentTheme == themeMode;

    return InkWell(
      onTap: () => themeNotifier.setTheme(themeMode),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.paddingMedium),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.grey300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.onSurfaceVariant,
              size: AppDimensions.iconMedium,
            ),
            const SizedBox(width: AppDimensions.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isSelected ? AppColors.primary : null,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
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
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: AppDimensions.iconMedium,
              ),
          ],
        ),
      ),
    );
  }
}
