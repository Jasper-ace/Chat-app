import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.system) {
    _loadTheme();
  }

  static const String _themeKey = 'theme_mode';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt(_themeKey) ?? AppThemeMode.system.index;
    state = AppThemeMode.values[themeIndex];
  }

  Future<void> setTheme(AppThemeMode themeMode) async {
    state = themeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, themeMode.index);
  }

  ThemeMode get themeMode {
    switch (state) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  bool get isDarkMode {
    return state == AppThemeMode.dark;
  }

  bool get isLightMode {
    return state == AppThemeMode.light;
  }

  bool get isSystemMode {
    return state == AppThemeMode.system;
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeMode>(
  (ref) => ThemeNotifier(),
);
