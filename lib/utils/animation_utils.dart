import 'package:flutter/material.dart';

/// ✨ ANIMATION UTILS
/// Kolekcija naprednih animacija za smooth UI
class AnimationUtils {
  /// 🌊 Slide fade transition
  static Widget slideFadeTransition({
    required Widget child,
    required Animation<double> animation,
    Offset beginOffset = const Offset(0.0, 0.3),
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// 🔄 Scale fade transition
  static Widget scaleFadeTransition({
    required Widget child,
    required Animation<double> animation,
    double beginScale = 0.8,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: beginScale,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.elasticOut,
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  /// 💫 Bounce transition
  static Widget bounceTransition({
    required Widget child,
    required Animation<double> animation,
  }) {
    return ScaleTransition(
      scale: Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.bounceOut,
        ),
      ),
      child: child,
    );
  }

  /// 🌟 Rotation fade transition
  static Widget rotationFadeTransition({
    required Widget child,
    required Animation<double> animation,
    double turns = 0.125,
  }) {
    return RotationTransition(
      turns: Tween<double>(
        begin: turns,
        end: 0.0,
      ).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
      ),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

/// 🎭 ANIMATED PAGE TRANSITION
class CustomPageRoute<T> extends PageRouteBuilder<T> {
  CustomPageRoute({
    required this.child,
    this.transitionType = PageTransitionType.slideUp,
    RouteSettings? settings,
  }) : super(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => child,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            switch (transitionType) {
              case PageTransitionType.slideUp:
                return AnimationUtils.slideFadeTransition(
                  child: child,
                  animation: animation,
                );
              case PageTransitionType.slideRight:
                return AnimationUtils.slideFadeTransition(
                  child: child,
                  animation: animation,
                  beginOffset: const Offset(1.0, 0.0),
                );
              case PageTransitionType.scale:
                return AnimationUtils.scaleFadeTransition(
                  child: child,
                  animation: animation,
                );
              case PageTransitionType.bounce:
                return AnimationUtils.bounceTransition(
                  child: child,
                  animation: animation,
                );
              case PageTransitionType.rotation:
                return AnimationUtils.rotationFadeTransition(
                  child: child,
                  animation: animation,
                );
            }
          },
        );
  final Widget child;
  final PageTransitionType transitionType;
}

/// 🎬 ANIMATED CONTAINER WRAPPER
class AnimatedCard extends StatefulWidget {
  const AnimatedCard({
    Key? key,
    required this.child,
    this.duration = const Duration(milliseconds: 600),
    this.isVisible = true,
    this.delay = 0,
  }) : super(key: key);
  final Widget child;
  final Duration duration;
  final bool isVisible;
  final int delay;

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Start animation with delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted && widget.isVisible) {
        _controller.forward();
      }
    });
  }

  @override
  void didUpdateWidget(AnimatedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 🎪 STAGGERED LIST ANIMATION
class StaggeredListView extends StatefulWidget {
  const StaggeredListView({
    Key? key,
    required this.children,
    this.staggerDelay = const Duration(milliseconds: 100),
    this.scrollDirection = Axis.vertical,
    this.physics,
  }) : super(key: key);
  final List<Widget> children;
  final Duration staggerDelay;
  final Axis scrollDirection;
  final ScrollPhysics? physics;

  @override
  State<StaggeredListView> createState() => _StaggeredListViewState();
}

class _StaggeredListViewState extends State<StaggeredListView> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: widget.scrollDirection,
      physics: widget.physics,
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return AnimatedCard(
          delay: index * widget.staggerDelay.inMilliseconds,
          child: widget.children[index],
        );
      },
    );
  }
}

/// 📱 FLOATING ACTION BUTTON sa animacijom
class AnimatedFAB extends StatefulWidget {
  const AnimatedFAB({
    Key? key,
    this.onPressed,
    required this.child,
    this.isVisible = true,
    this.backgroundColor,
  }) : super(key: key);
  final VoidCallback? onPressed;
  final Widget child;
  final bool isVisible;
  final Color? backgroundColor;

  @override
  State<AnimatedFAB> createState() => _AnimatedFABState();
}

class _AnimatedFABState extends State<AnimatedFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    if (widget.isVisible) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(AnimatedFAB oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: RotationTransition(
        turns: _rotationAnimation,
        child: FloatingActionButton(
          onPressed: widget.onPressed,
          backgroundColor: widget.backgroundColor,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 🎨 Page transition types
enum PageTransitionType {
  slideUp,
  slideRight,
  scale,
  bounce,
  rotation,
}
