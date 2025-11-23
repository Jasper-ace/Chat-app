import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/theme_provider.dart';
import '../app_colors.dart';
import '../app_dimensions.dart';

class AnimatedThemeToggle extends ConsumerStatefulWidget {
  const AnimatedThemeToggle({super.key});

  @override
  ConsumerState<AnimatedThemeToggle> createState() =>
      _AnimatedThemeToggleState();
}

class _AnimatedThemeToggleState extends ConsumerState<AnimatedThemeToggle>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _colorController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _rotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.elasticOut),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _colorAnimation = ColorTween(begin: AppColors.warning, end: AppColors.info)
        .animate(
          CurvedAnimation(parent: _colorController, curve: Curves.easeInOut),
        );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  void _animateToggle() {
    _rotationController.forward().then((_) {
      _rotationController.reset();
    });

    _scaleController.forward().then((_) {
      _scaleController.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    // Update color animation based on current theme
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (currentTheme == AppThemeMode.dark) {
        _colorController.forward();
      } else {
        _colorController.reverse();
      }
    });

    IconData icon;
    switch (currentTheme) {
      case AppThemeMode.light:
        icon = Icons.light_mode;
        break;
      case AppThemeMode.dark:
        icon = Icons.dark_mode;
        break;
      case AppThemeMode.system:
        icon = Icons.settings_system_daydream;
        break;
    }

    return GestureDetector(
      onTap: () {
        _animateToggle();

        // Cycle through themes with a slight delay for animation
        Future.delayed(const Duration(milliseconds: 200), () {
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
        });
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationAnimation,
          _scaleAnimation,
          _colorAnimation,
        ]),
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Transform.rotate(
              angle: _rotationAnimation.value * 2 * 3.14159,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (_colorAnimation.value ?? AppColors.warning).withOpacity(
                        0.2,
                      ),
                      (_colorAnimation.value ?? AppColors.warning).withOpacity(
                        0.1,
                      ),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_colorAnimation.value ?? AppColors.warning)
                          .withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: _colorAnimation.value ?? AppColors.warning,
                  size: AppDimensions.iconMedium,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class AnimatedThemeCard extends ConsumerStatefulWidget {
  const AnimatedThemeCard({super.key});

  @override
  ConsumerState<AnimatedThemeCard> createState() => _AnimatedThemeCardState();
}

class _AnimatedThemeCardState extends ConsumerState<AnimatedThemeCard>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _glowController;
  late Animation<double> _flipAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _flipAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start glow animation loop
    _glowController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _flipController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _animateFlip() {
    _flipController.forward().then((_) {
      _flipController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final themeNotifier = ref.read(themeProvider.notifier);

    IconData themeIcon;
    String themeTitle;
    String themeSubtitle;
    Color themeColor;
    Gradient cardGradient;

    switch (currentTheme) {
      case AppThemeMode.light:
        themeIcon = Icons.light_mode;
        themeTitle = 'Light Mode';
        themeSubtitle = 'Tap to switch';
        themeColor = AppColors.warning;
        cardGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.warning.withOpacity(0.1),
            AppColors.warning.withOpacity(0.05),
          ],
        );
        break;
      case AppThemeMode.dark:
        themeIcon = Icons.dark_mode;
        themeTitle = 'Dark Mode';
        themeSubtitle = 'Tap to switch';
        themeColor = AppColors.info;
        cardGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.info.withOpacity(0.1),
            AppColors.info.withOpacity(0.05),
          ],
        );
        break;
      case AppThemeMode.system:
        themeIcon = Icons.settings_system_daydream;
        themeTitle = 'System Mode';
        themeSubtitle = 'Tap to switch';
        themeColor = AppColors.primary;
        cardGradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primary.withOpacity(0.05),
          ],
        );
        break;
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_flipAnimation, _glowAnimation]),
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateY(_flipAnimation.value * 3.14159),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              gradient: cardGradient,
              boxShadow: [
                BoxShadow(
                  color: themeColor.withOpacity(
                    0.2 + (_glowAnimation.value * 0.1),
                  ),
                  blurRadius: 8 + (_glowAnimation.value * 4),
                  spreadRadius: 1 + (_glowAnimation.value * 2),
                ),
              ],
            ),
            child: Card(
              elevation: 0,
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _animateFlip();

                  Future.delayed(const Duration(milliseconds: 400), () {
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
                  });
                },
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingMedium),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(
                          AppDimensions.paddingMedium,
                        ),
                        decoration: BoxDecoration(
                          color: themeColor.withOpacity(
                            0.1 + (_glowAnimation.value * 0.1),
                          ),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radiusLarge,
                          ),
                          border: Border.all(
                            color: themeColor.withOpacity(
                              0.3 + (_glowAnimation.value * 0.2),
                            ),
                            width: 1 + (_glowAnimation.value * 1),
                          ),
                        ),
                        child: Icon(
                          themeIcon,
                          size: AppDimensions.iconLarge,
                          color: themeColor,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      Text(
                        themeTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: themeColor,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppDimensions.spacing4),
                      Text(
                        themeSubtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
