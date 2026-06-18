import 'package:flutter/material.dart';

/// A reusable widget that wraps any child with a staggered fade + slide-up
/// entrance animation. Use inside a list of items to create a cascading reveal.
///
/// Usage:
/// ```dart
/// StaggeredListItem(
///   index: 0,
///   animationController: _animCtrl,
///   child: MyCard(),
/// )
/// ```
class StaggeredListItem extends StatelessWidget {
  final int index;
  final AnimationController animationController;
  final Widget child;
  final double slideOffset;
  final Duration? customDelay;

  const StaggeredListItem({
    super.key,
    required this.index,
    required this.animationController,
    required this.child,
    this.slideOffset = 30.0,
    this.customDelay,
  });

  @override
  Widget build(BuildContext context) {
    // Each item starts its animation slightly after the previous one
    final double start = (index * 0.08).clamp(0.0, 0.6);
    final double end = (start + 0.4).clamp(0.0, 1.0);

    final curvedAnimation = CurvedAnimation(
      parent: animationController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: curvedAnimation.value,
          child: Transform.translate(
            offset: Offset(0, slideOffset * (1 - curvedAnimation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// A tap-scale button wrapper that adds a spring-bounce micro-interaction
/// when the user taps. Wrap any widget (buttons, cards) with this.
class TapScaleWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  const TapScaleWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.95,
  });

  @override
  State<TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<TapScaleWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDown).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap?.call();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}
