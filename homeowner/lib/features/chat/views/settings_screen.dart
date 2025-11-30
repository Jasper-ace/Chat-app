import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/viewmodels/firebase_auth_viewmodel.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.appBarTitle.copyWith(color: Colors.white),
        ),
      ),
      body: ListView(
        children: [
          _buildSection(
            title: 'Notifications',
            children: [
              _buildSwitchTile(
                title: 'Enable Notifications',
                subtitle: 'Receive message notifications',
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                },
              ),
              _buildSwitchTile(
                title: 'Sound',
                subtitle: 'Play sound for new messages',
                value: _soundEnabled,
                onChanged: (value) {
                  setState(() => _soundEnabled = value);
                },
              ),
              _buildSwitchTile(
                title: 'Vibration',
                subtitle: 'Vibrate for new messages',
                value: _vibrationEnabled,
                onChanged: (value) {
                  setState(() => _vibrationEnabled = value);
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Chat',
            children: [
              _buildTile(
                icon: Icons.archive,
                title: 'Archived Chats',
                subtitle: 'View archived conversations',
                onTap: () {
                  // Navigate to archived chats
                },
              ),
              _buildTile(
                icon: Icons.block,
                title: 'Blocked Users',
                subtitle: 'Manage blocked users',
                onTap: () {
                  // Navigate to blocked users
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Privacy',
            children: [
              _buildTile(
                icon: Icons.visibility,
                title: 'Privacy Settings',
                subtitle: 'Control who can see your information',
                onTap: () {
                  // Navigate to privacy settings
                },
              ),
            ],
          ),
          _buildSection(
            title: 'Account',
            children: [
              _buildTile(
                icon: Icons.person,
                title: 'Profile',
                subtitle: 'View and edit your profile',
                onTap: () {
                  // Navigate to profile
                },
              ),
              _buildTile(
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Sign out of your account',
                onTap: () => _handleLogout(),
                textColor: Colors.red,
              ),
            ],
          ),
          _buildSection(
            title: 'About',
            children: [
              _buildTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'App version and information',
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'Homeowner Chat',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.chat, size: 48),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.paddingMedium,
            AppDimensions.paddingLarge,
            AppDimensions.paddingMedium,
            AppDimensions.paddingSmall,
          ),
          child: Text(
            title,
            style: AppTextStyles.titleSmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          color: Colors.white,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.primary),
      title: Text(
        title,
        style: AppTextStyles.titleMedium.copyWith(color: textColor),
      ),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: AppTextStyles.titleMedium),
      subtitle: Text(subtitle, style: AppTextStyles.bodySmall),
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(firebaseAuthViewModelProvider.notifier).logout();
      if (mounted) {
        context.go('/login');
      }
    }
  }
}
