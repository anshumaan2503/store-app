import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:store_app/src/components/ui_tokens.dart';

/// Motion Suite & Interactive Animation Widgets for Store App
/// Preserves existing business logic and colors while adding 60fps modern micro-interactions.

/// 1. AppHoverCard (Task 2.4): 1.02x scale & soft elevation pop on hover
class AppHoverCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Border? border;
  final double scaleFactor;

  const AppHoverCard({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.border,
    this.scaleFactor = 1.02,
  });

  @override
  State<AppHoverCard> createState() => _AppHoverCardState();
}

class _AppHoverCardState extends State<AppHoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = widget.borderRadius ?? AppRadii.borderS16;

    final defaultBg = widget.backgroundColor ??
        (isDark ? theme.cardColor : theme.colorScheme.surface);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppAnimationTokens.hover,
          curve: AppAnimationTokens.cubic,
          transform: Matrix4.identity()
            ..scale(_isHovered ? widget.scaleFactor : 1.0),
          transformAlignment: Alignment.center,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: defaultBg,
            borderRadius: radius,
            border: widget.border ??
                Border.all(
                  color: _isHovered
                      ? theme.colorScheme.primary.withValues(alpha: 0.4)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06)),
                  width: 1.0,
                ),
            boxShadow: _isHovered
                ? AppShadows.hover(context)
                : AppShadows.soft(context),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// 2. StaggeredFadeIn (Task 2.3): Staggered entry animation for grid items and list cards
class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final int offsetMs;
  final Axis direction;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppAnimationTokens.transition,
    this.offsetMs = 60,
    this.direction = Axis.vertical,
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: AppAnimationTokens.entrance,
    );

    final startOffset = widget.direction == Axis.vertical
        ? const Offset(0.0, 0.08)
        : const Offset(0.08, 0.0);

    _slideAnimation = Tween<Offset>(
      begin: startOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: AppAnimationTokens.entrance,
    ));

    Future.delayed(Duration(milliseconds: widget.index * widget.offsetMs), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/// 3. PulsingStatusDot (Task 2.9): Glowing pulse dot for live WebSocket & active status badges
class PulsingStatusDot extends StatefulWidget {
  final Color color;
  final double size;
  final bool isPulsing;

  const PulsingStatusDot({
    super.key,
    required this.color,
    this.size = 10.0,
    this.isPulsing = true,
  });

  @override
  State<PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<PulsingStatusDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppAnimationTokens.pulse,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _opacityAnimation = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.isPulsing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant PulsingStatusDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing != oldWidget.isPulsing) {
      if (widget.isPulsing) {
        _controller.repeat();
      } else {
        _controller.stop();
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
    return SizedBox(
      width: widget.size * 2,
      height: widget.size * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isPulsing)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withValues(alpha: _opacityAnimation.value),
                    ),
                  ),
                );
              },
            ),
          Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. ShimmerSkeleton (Task 2.6): Smooth shimmer placeholder replacing default spinners
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C2A34) : const Color(0xFFEBEBF0);
    final highlightColor = isDark ? const Color(0xFF3D3A48) : const Color(0xFFF5F5FA);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadii.borderS8,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                math.max(0.0, _controller.value - 0.3),
                _controller.value,
                math.min(1.0, _controller.value + 0.3),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 5. AnimatedCounterText (Task 2.14): Rolling number increment animation for KPI metrics
class AnimatedCounterText extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String prefix;
  final String suffix;
  final Duration duration;

  const AnimatedCounterText({
    super.key,
    required this.value,
    this.style,
    this.prefix = '',
    this.suffix = '',
    this.duration = AppAnimationTokens.slow,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: AppAnimationTokens.entrance,
      builder: (context, val, child) {
        final displayText = value is int
            ? val.toInt().toString()
            : val.toStringAsFixed(1);
        return Text(
          '$prefix$displayText$suffix',
          style: style,
        );
      },
    );
  }
}

/// 6. AppExpandableContainer (Task 2.10): Accordion / filter expand-collapse animation
class AppExpandableContainer extends StatelessWidget {
  final bool isExpanded;
  final Widget child;
  final Duration duration;

  const AppExpandableContainer({
    super.key,
    required this.isExpanded,
    required this.child,
    this.duration = AppAnimationTokens.normal,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox(width: double.infinity, height: 0),
      secondChild: child,
      crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: duration,
      sizeCurve: AppAnimationTokens.fastOutSlowIn,
    );
  }
}

/// 7. AppAnimatedTabView (Task 2.7): Smooth fade & slide transition for tab switching
class AppAnimatedTabView extends StatelessWidget {
  final int currentTabIndex;
  final List<Widget> tabs;

  const AppAnimatedTabView({
    super.key,
    required this.currentTabIndex,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppAnimationTokens.transition,
      switchInCurve: AppAnimationTokens.entrance,
      switchOutCurve: AppAnimationTokens.exit,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.02, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(currentTabIndex),
        child: tabs[math.min(currentTabIndex, tabs.length - 1)],
      ),
    );
  }
}

/// 8. AppBouncingScrollBehavior (Task 2.8): Physics-based smooth scrolling across dynamic lists
class AppBouncingScrollBehavior extends MaterialScrollBehavior {
  const AppBouncingScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    // ClampingScrollPhysics eliminates heavy spring bounce calculations and rubber-band friction,
    // delivering immediate, silky-smooth 60fps scrolling response on laptop browsers.
    return const ClampingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Return child directly so that dedicated screen scrollbars render cleanly
    // without redundant double-painting and GPU frame drops.
    return child;
  }
}

/// 9. AppButtonMotion (Task 2.5): Micro-scale tactile dip on press for buttons
class AppButtonMotion extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const AppButtonMotion({
    super.key,
    required this.child,
    this.onTap,
  });

  @override
  State<AppButtonMotion> createState() => _AppButtonMotionState();
}

class _AppButtonMotionState extends State<AppButtonMotion> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: AppAnimationTokens.fast,
          curve: AppAnimationTokens.cubic,
          child: widget.child,
        ),
      ),
    );
  }
}

/// 10. AppBackButton: Modern styled back button pill with hover animations, tactile motion & shadow
class AppBackButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Color? color;
  final Color? backgroundColor;

  const AppBackButton({
    super.key,
    this.onPressed,
    this.color,
    this.backgroundColor,
  });

  @override
  State<AppBackButton> createState() => _AppBackButtonState();
}

class _AppBackButtonState extends State<AppBackButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const ink900 = Color(0xFF282321);
    const stroke = Color(0xFFDFE1D6);
    const surfaceAlt = Color(0xFFFFF4E2);
    const surfaceHover = Color(0xFFFFF9EE);
    const strokeHover = Color(0xFF282321);

    final effectiveBg = widget.backgroundColor ?? (_isHovered ? surfaceHover : surfaceAlt);
    final effectiveBorderColor = _isHovered ? strokeHover : stroke;
    final scale = _isPressed ? 0.94 : (_isHovered ? 1.05 : 1.0);

    return Tooltip(
      message: 'Back',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onPressed ?? () => Navigator.maybePop(context),
          child: AnimatedScale(
            scale: scale,
            duration: AppAnimationTokens.fast,
            curve: AppAnimationTokens.cubic,
            child: AnimatedContainer(
              duration: AppAnimationTokens.fast,
              curve: AppAnimationTokens.cubic,
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: effectiveBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: effectiveBorderColor,
                  width: _isHovered ? 1.4 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _isHovered
                        ? ink900.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: _isHovered ? 10 : 6,
                    offset: _isHovered ? const Offset(0, 4) : const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: widget.color ?? ink900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
