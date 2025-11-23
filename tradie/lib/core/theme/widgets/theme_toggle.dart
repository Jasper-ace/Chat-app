import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';

class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);
    final currentTheme = ref.watch(themeProvider);

    return PopupMenuButton<AppThemeMode>(
      icon: Icon(
        _getThemeIcon(currentTheme),
        color: Theme.of(context).iconTheme.color,
      ),
      onSelected: (AppThemeMode themeMode) {
        themeNotifier.setTheme(themeMode);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.light,
          child: Row(
            children: [
              Icon(
                Icons.light_mode,
                color: currentTheme == AppThemeMode.light
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Light',
                style: TextStyle(
                  color: currentTheme == AppThemeMode.light
                      ? Theme.of(context).primaryColor
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.dark,
          child: Row(
            children: [
              Icon(
                Icons.dark_mode,
                color: currentTheme == AppThemeMode.dark
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Dark',
                style: TextStyle(
                  color: currentTheme == AppThemeMode.dark
                      ? Theme.of(context).primaryColor
                      : null,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<AppThemeMode>(
          value: AppThemeMode.system,
          child: Row(
            children: [
              Icon(
                Icons.settings_system_daydream,
                color: currentTheme == AppThemeMode.system
                    ? Theme.of(context).primaryColor
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'System',
                style: TextStyle(
                  color: currentTheme == AppThemeMode.system
                      ? Theme.of(context).primaryColor
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getThemeIcon(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }
}

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeProvider.notifier);
    final currentTheme = ref.watch(themeProvider);

    return IconButton(
      onPressed: () {
        // Cycle through themes: light -> dark -> system -> light
        switch (currentTheme) {
          case AppThemeMode.light:
            themeNotifier.setTheme(AppThemeMode.dark);
            break;
          case AppThemeMode.dark:
            themeNotifier.setTheme(AppThemeMode.system);
            break;
          case AppThemeMode.system:
            themeNotifier.setTheme(AppThemeMode.light);
            break;
        }
      },
      icon: Icon(_getThemeIcon(currentTheme)),
      tooltip: _getThemeTooltip(currentTheme),
    );
  }

  IconData _getThemeIcon(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return Icons.light_mode;
      case AppThemeMode.dark:
        return Icons.dark_mode;
      case AppThemeMode.system:
        return Icons.settings_system_daydream;
    }
  }

  String _getThemeTooltip(AppThemeMode themeMode) {
    switch (themeMode) {
      case AppThemeMode.light:
        return 'Switch to dark mode';
      case AppThemeMode.dark:
        return 'Switch to system mode';
      case AppThemeMode.system:
        return 'Switch to light mode';
    }
  }
}
