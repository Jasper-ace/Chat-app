import 'package:flutter/material.dart';

class TypingIndicatorWidget extends StatefulWidget {
  final bool isVisible;
  final String? userName;
  final Color? color;

  const TypingIndicatorWidget({
    super.key,
    required this.isVisible,
    this.userName,
    this.color,
  });

  @override
  State<TypingIndicatorWidget> createState() => _TypingIndicatorWidgetState();
}

class _TypingIndicatorWidgetState extends State<TypingIndicatorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(TypingIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animationController.repeat();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'typing',
              style: TextStyle(
                color: widget.color ?? Colors.white70,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            _buildDots(),
          ],
        );
      },
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Create a staggered animation for each dot
            final delay = index * 0.2;
            final animationValue = (_animationController.value - delay).clamp(
              0.0,
              1.0,
            );
            final opacity = (animationValue * 2).clamp(0.0, 1.0);
            final scale = 0.5 + (opacity * 0.5);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: BoxDecoration(
                    color: (widget.color ?? Colors.white70).withOpacity(
                      opacity,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// Instagram-style typing indicator for message list
class MessageTypingIndicator extends StatelessWidget {
  final bool isVisible;
  final String? avatarUrl;

  const MessageTypingIndicator({
    super.key,
    required this.isVisible,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: isVisible ? 60 : 0,
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      child: isVisible
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar
                CircleAvatar(
                  backgroundImage: avatarUrl != null
                      ? NetworkImage(avatarUrl!)
                      : const NetworkImage(
                          'https://cdn-icons-png.flaticon.com/512/149/149071.png',
                        ),
                  radius: 16,
                ),
                const SizedBox(width: 8),

                // Typing bubble
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                      bottomLeft: Radius.circular(4),
                    ),
                  ),
                  child: const TypingDotsAnimation(),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}

// Animated dots for typing bubble
class TypingDotsAnimation extends StatefulWidget {
  const TypingDotsAnimation({super.key});

  @override
  State<TypingDotsAnimation> createState() => _TypingDotsAnimationState();
}

class _TypingDotsAnimationState extends State<TypingDotsAnimation>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    }).toList();

    // Start animations with staggered delays
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              child: Transform.translate(
                offset: Offset(0, -_animations[index].value * 8),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

// Online status indicator
class OnlineStatusIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const OnlineStatusIndicator({
    super.key,
    required this.isOnline,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : Colors.grey,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
