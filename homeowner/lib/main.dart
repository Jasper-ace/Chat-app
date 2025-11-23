import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: HomeOwnerApp()));
}

class HomeOwnerApp extends ConsumerWidget {
  const HomeOwnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Watch the theme provider to trigger rebuilds when theme changes
    ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    return AnimatedTheme(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOutCubic,
      data: themeNotifier.themeMode == ThemeMode.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      child: MaterialApp.router(
        title: 'Home Owner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeNotifier.themeMode,
        routerConfig: router,
      ),
    );
  }
}
