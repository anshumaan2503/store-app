import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../controllers/guided_tour_controller.dart';
import '../../../../auth/controllers/users_controller.dart';

/// The exact verbatim SVG contents of the user-approved "Directional arrow (1).svg" asset.
const String _kDirectionalArrowSvg = '''<svg width="142" height="256" viewBox="0 0 142 256" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M1.50041 5.35261C52.7109 -12.3723 111.237 31.9399 130.746 120.564C140.5 169.308 133.185 218.051 116.114 253.501M140.5 235.776L116.114 253.501L101.483 209.189" stroke="#F9A825" stroke-width="3" stroke-linecap="round"/>
</svg>''';

/// Reusable Guided Tour Overlay directing the user to a target widget with an instruction card and directional arrow.
///
/// Can either automatically bind to active tour state via [guidedTourStateProvider]
/// or accept explicit parameters for standalone presentation.
class GuidedTourOverlay extends ConsumerStatefulWidget {
  final GlobalKey? targetKey;
  final String? title;
  final String? description;
  final int? currentStep;
  final int? totalSteps;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final void Function({required bool dontShowAgain}) onDismiss;
  final ValueChanged<bool>? onDontShowAgainChanged;
  final VoidCallback? onTargetTapped;
  final GuidedTourArrowDirection? arrowDirection;
  final Alignment? arrowAlignment;

  const GuidedTourOverlay({
    super.key,
    this.targetKey,
    this.title,
    this.description,
    this.currentStep,
    this.totalSteps,
    this.onNext,
    this.onPrevious,
    required this.onDismiss,
    this.onDontShowAgainChanged,
    this.onTargetTapped,
    this.arrowDirection,
    this.arrowAlignment,
  });

  /// Convenience factory to instantiate the overlay directly from a [GuidedTourStep].
  factory GuidedTourOverlay.fromStep({
    Key? key,
    required GuidedTourStep step,
    required int currentStepIndex,
    required int totalSteps,
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    required void Function({required bool dontShowAgain}) onDismiss,
    ValueChanged<bool>? onDontShowAgainChanged,
  }) {
    return GuidedTourOverlay(
      key: key,
      targetKey: step.targetKey,
      title: step.title,
      description: step.description,
      currentStep: currentStepIndex,
      totalSteps: totalSteps,
      onNext: onNext,
      onPrevious: onPrevious,
      onDismiss: onDismiss,
      onDontShowAgainChanged: onDontShowAgainChanged,
      onTargetTapped: step.onTargetTapped,
      arrowDirection: step.arrowDirection,
      arrowAlignment: step.arrowAlignment,
    );
  }

  @override
  ConsumerState<GuidedTourOverlay> createState() => _GuidedTourOverlayState();
}

class _GuidedTourOverlayState extends ConsumerState<GuidedTourOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final Animation<double> _curvedAnim;

  late final AnimationController _bounceCtrl;
  late final Animation<double> _bounceAnim;

  late final AnimationController _highlightFadeCtrl;
  late final Animation<double> _highlightFadeAnim;

  bool _isAutoScrolling = false;
  bool _dontShowAgain = false;
  bool _isDismissing = false;

  int _mountRetries = 0;
  static const int _maxMountRetries = 60;
  int? _lastStepIndex;
  Key? _lastScrolledTargetKey;

  final GlobalKey _cardKey = GlobalKey();
  double _measuredCardHeight = 210.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _curvedAnim = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Subtle restrained floating bounce for the directional arrow and focus ring
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0.0, end: 4.0).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    // Fade controller for the highlight spotlight and card when transitioning/scrolling
    _highlightFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _highlightFadeAnim = CurvedAnimation(
      parent: _highlightFadeCtrl,
      curve: Curves.easeOutCubic,
    );
    _highlightFadeCtrl.value = 1.0;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _highlightFadeCtrl.dispose();
    _bounceCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSkip() async {
    final tourState = ref.read(guidedTourStateProvider);
    final activeStep = tourState.currentStep;
    if (activeStep?.isMandatory == true) {
      _bounceCtrl.forward(from: 0.0);
      return;
    }
    if (_isDismissing) return;
    _isDismissing = true;
    try {
      await _animCtrl.reverse();
    } catch (_) {}
    try {
      final user = ref.read(userFindOneDataStreamProvider).value;
      ref.read(guidedTourControllerProvider).dismissTour(
        uid: user?.uid ?? '',
        dontShowAgain: _dontShowAgain,
      );
    } catch (_) {}
    widget.onDismiss(dontShowAgain: _dontShowAgain);
  }

  @override
  Widget build(BuildContext context) {
    // Resolve parameters from active tour state if not explicitly passed
    final tourState = ref.watch(guidedTourStateProvider);
    final activeStep = tourState.currentStep;

    final resolvedCurrentStep = widget.currentStep ?? tourState.currentStepIndex;
    if (_lastStepIndex != resolvedCurrentStep) {
      _lastStepIndex = resolvedCurrentStep;
      _mountRetries = 0;
      _lastScrolledTargetKey = null;
    }

    final resolvedTargetKey = widget.targetKey ?? activeStep?.targetKey;
    final resolvedTitle = widget.title ?? activeStep?.title ?? '';
    final resolvedDescription =
        widget.description ?? activeStep?.description ?? '';
    final resolvedTotalSteps = widget.totalSteps ??
        (tourState.totalSteps > 0 ? tourState.totalSteps : 1);
    final resolvedOnNext = widget.onNext ??
        (tourState.hasNext
            ? () => ref.read(guidedTourControllerProvider).nextStep()
            : null);

    if (resolvedTargetKey == null || (widget.targetKey == null && !tourState.hasSteps)) {
      return const SizedBox.shrink();
    }

    final targetContext = resolvedTargetKey.currentContext;
    final initialRenderBox = targetContext?.findRenderObject() as RenderBox?;

    final bool isTargetReady = targetContext != null &&
        initialRenderBox != null &&
        initialRenderBox.attached &&
        initialRenderBox.hasSize &&
        initialRenderBox.size.width > 0;

    if (!isTargetReady) {
      if (_mountRetries < _maxMountRetries) {
        _mountRetries++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
        return const SizedBox.shrink();
      }

      // Continuously poll while target is loading async data so that as soon as the
      // target widget mounts and renders, we attach to it and display the spotlight cut-out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final ctx = resolvedTargetKey.currentContext;
        final rb = ctx?.findRenderObject() as RenderBox?;
        if (ctx != null && rb != null && rb.attached && rb.hasSize && rb.size.width > 0) {
          setState(() {
            _mountRetries = 0;
          });
        } else {
          Future.delayed(const Duration(milliseconds: 180), () {
            if (mounted) {
              final c = resolvedTargetKey.currentContext;
              if (c != null) {
                setState(() {});
              }
            }
          });
        }
      });

      return AnimatedBuilder(
        animation: _curvedAnim,
        builder: (context, child) {
          final screenSize = MediaQuery.of(context).size;
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65 * _curvedAnim.value),
                  ),
                ),
              ),
              Positioned(
                top: (screenSize.height - _measuredCardHeight) / 2,
                left: math.max(16.0, (screenSize.width - math.min(screenSize.width - 32.0, 420.0)) / 2),
                width: math.min(screenSize.width - 32.0, 420.0),
                child: _buildInstructionCard(
                  title: resolvedTitle,
                  description: resolvedDescription,
                  currentStep: resolvedCurrentStep,
                  totalSteps: resolvedTotalSteps,
                  onNext: resolvedOnNext,
                  isMandatory: activeStep?.isMandatory ?? false,
                  onTargetTapped: activeStep?.onTargetTapped,
                ),
              ),
            ],
          );
        },
      );
    }

    _mountRetries = 0;

    // Automatically ensure target widget is scrolled into comfortable view if clipped/offscreen
    if (isTargetReady && targetContext != null && _lastScrolledTargetKey != resolvedTargetKey) {
      final targetRenderBox = initialRenderBox;
      final globalPos = targetRenderBox.localToGlobal(Offset.zero);
      final double top = globalPos.dy;
      final double bottom = globalPos.dy + targetRenderBox.size.height;
      final double screenHeight = MediaQuery.of(context).size.height;

      // Dynamically resolve enclosing scrollable viewport boundaries
      final scrollableState = Scrollable.maybeOf(targetContext);
      final scrollableBox =
          scrollableState?.context.findRenderObject() as RenderBox?;

      final double viewportTop;
      final double viewportBottom;

      if (scrollableBox != null &&
          scrollableBox.attached &&
          scrollableBox.hasSize) {
        final scrollableOrigin = scrollableBox.localToGlobal(Offset.zero);
        viewportTop = scrollableOrigin.dy;
        viewportBottom = viewportTop + scrollableBox.size.height;
      } else {
        final mediaQuery = MediaQuery.of(context);
        viewportTop = mediaQuery.padding.top + kToolbarHeight + 16.0;
        viewportBottom = screenHeight - 80.0;
      }

      // Check if target is out of view or too close to the scrollable's visible edge
      final bool isAbove = top < (viewportTop + 24.0);
      final bool isBelow = !isAbove && (bottom > (viewportBottom - 24.0));
      final bool needsScroll = isAbove || isBelow;

      _lastScrolledTargetKey = resolvedTargetKey;

      if (needsScroll) {
        _isAutoScrolling = true;
        _highlightFadeCtrl.value = 0.0;

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) return;
          final ctx = resolvedTargetKey.currentContext;
          if (ctx != null) {
            try {
              await Scrollable.ensureVisible(
                ctx,
                duration: const Duration(milliseconds: 380),
                curve: Curves.easeOutCubic,
                alignment: isAbove ? 0.20 : 0.75,
                alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
              );
            } catch (_) {}
          }
          if (mounted) {
            setState(() {
              _isAutoScrolling = false;
            });
            _highlightFadeCtrl.forward(from: 0.0);
          }
        });
      } else {
        if (_highlightFadeCtrl.value < 1.0 && !_isAutoScrolling) {
          _highlightFadeCtrl.forward();
        }
      }
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_curvedAnim, _bounceAnim, _highlightFadeAnim]),
      builder: (context, child) {
        final renderBox =
            resolvedTargetKey.currentContext?.findRenderObject() as RenderBox?;

        final mediaQuery = MediaQuery.of(context);
        final screenSize = mediaQuery.size;
        const double screenMargin = 16.0;

        // Viewport clipping guard: do not show highlight if target is physically outside scrollable viewport
        bool isOutsideViewport = false;
        if (renderBox != null && renderBox.attached && renderBox.hasSize) {
          final targetCtx = resolvedTargetKey.currentContext;
          final scrollableState =
              targetCtx != null ? Scrollable.maybeOf(targetCtx) : null;
          final scrollableBox =
              scrollableState?.context.findRenderObject() as RenderBox?;
          if (scrollableBox != null &&
              scrollableBox.attached &&
              scrollableBox.hasSize) {
            final sOrigin = scrollableBox.localToGlobal(Offset.zero);
            final vTop = sOrigin.dy;
            final vBottom = vTop + scrollableBox.size.height;
            final gTop = renderBox.localToGlobal(Offset.zero).dy;
            final gBottom = gTop + renderBox.size.height;
            if (gBottom <= (vTop + 2.0) || gTop >= (vBottom - 2.0)) {
              isOutsideViewport = true;
            }
          }
        }

        final double effectiveHighlightOpacity =
            (_isAutoScrolling || isOutsideViewport)
                ? 0.0
                : _highlightFadeAnim.value;

        if (renderBox == null ||
            !renderBox.hasSize ||
            !renderBox.attached ||
            renderBox.size.width == 0) {
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: _handleSkip,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.65 * _curvedAnim.value),
                  ),
                ),
              ),
              Positioned(
                top: (screenSize.height - _measuredCardHeight) / 2,
                left: math.max(16.0, (screenSize.width - math.min(screenSize.width - 32.0, 420.0)) / 2),
                width: math.min(screenSize.width - 32.0, 420.0),
                child: _buildInstructionCard(
                  title: resolvedTitle,
                  description: resolvedDescription,
                  currentStep: resolvedCurrentStep,
                  totalSteps: resolvedTotalSteps,
                  onNext: resolvedOnNext,
                  isMandatory: activeStep?.isMandatory ?? false,
                  onTargetTapped: activeStep?.onTargetTapped,
                ),
              ),
            ],
          );
        }

        // Resolve target's global coordinates relative to the current overlay coordinate system
        final overlayBox = context.findRenderObject() as RenderBox?;
        final globalTargetPos = renderBox.localToGlobal(Offset.zero);
        final targetOrigin = overlayBox != null
            ? overlayBox.globalToLocal(globalTargetPos)
            : globalTargetPos;
        final targetRect = targetOrigin & renderBox.size;

        // Rounded rectangle spotlight cut-out directly hugging the target button bounds
        final double cornerRadius = math.min(14.0, math.max(8.0, targetRect.height * 0.35));
        final holeRRect = RRect.fromRectAndRadius(
          targetRect.inflate(4.5),
          Radius.circular(cornerRadius),
        );

        // Responsive card dimensions
        const double maxCardWidth = 330.0;
        final double cardWidth = math.min(
          maxCardWidth,
          screenSize.width - (screenMargin * 2),
        );

        final cardBox =
            _cardKey.currentContext?.findRenderObject() as RenderBox?;
        if (cardBox != null && cardBox.hasSize && cardBox.size.height > 50.0) {
          _measuredCardHeight = cardBox.size.height;
        }

        // Dynamic Arrow Direction & Centralized Layout Calculation
        final resolvedArrowDirection = _GuidedTourArrowSystem.resolveDirection(
          targetRect: targetRect,
          screenSize: screenSize,
          direction: widget.arrowDirection ??
              activeStep?.arrowDirection ??
              GuidedTourArrowDirection.auto,
          alignmentHint: widget.arrowAlignment ?? activeStep?.arrowAlignment,
          cardHeight: _measuredCardHeight,
        );

        final arrowLayout = _GuidedTourArrowSystem.calculateLayout(
          targetRect: targetRect,
          screenSize: screenSize,
          viewPadding: mediaQuery.padding,
          cardWidth: cardWidth,
          cardHeight: _measuredCardHeight,
          direction: resolvedArrowDirection,
          bounceValue: _bounceAnim.value,
        );

        return Opacity(
          opacity: _curvedAnim.value.clamp(0.0, 1.0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Scrim layer with cut-out hole and pass-through hit testing
              _HoleHitTestWidget(
                holeRRect: effectiveHighlightOpacity <= 0.0 ? RRect.zero : holeRRect,
                onDimmedAreaTap: () {
                  if (activeStep?.isMandatory == true) {
                    _bounceCtrl.forward(from: 0.0);
                    return;
                  }
                  _handleSkip();
                },
                child: CustomPaint(
                  size: screenSize,
                  painter: _ScrimHolePainter(
                    holeRRect: holeRRect,
                    pulseFactor: (_bounceCtrl.value - 0.5) * 0.4,
                    highlightOpacity: effectiveHighlightOpacity,
                  ),
                ),
              ),

              // 2. Yellow Curved Directional Arrow (Visible on phone view only, hidden on browser/desktop view)
              if (screenSize.width < 600 && effectiveHighlightOpacity > 0.0)
                Positioned(
                  left: arrowLayout.arrowRect.left,
                  top: arrowLayout.arrowRect.top,
                  width: arrowLayout.arrowRect.width,
                  height: arrowLayout.arrowRect.height,
                  child: Opacity(
                    opacity: effectiveHighlightOpacity,
                    child: IgnorePointer(
                      child: arrowLayout.arrowWidget,
                    ),
                  ),
                ),

              // 3. Floating Instructional Card
              Positioned(
                left: arrowLayout.cardLeft,
                top: arrowLayout.cardTop,
                width: cardWidth,
                child: Opacity(
                  opacity: effectiveHighlightOpacity,
                  child: Transform.scale(
                    scale: 0.94 + (0.06 * _curvedAnim.value),
                    alignment: Alignment.topCenter,
                    child: _buildInstructionCard(
                      title: resolvedTitle,
                      description: resolvedDescription,
                      currentStep: resolvedCurrentStep,
                      totalSteps: resolvedTotalSteps,
                      onNext: resolvedOnNext,
                      isMandatory: activeStep?.isMandatory ?? false,
                      onTargetTapped: activeStep?.onTargetTapped,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInstructionCard({
    required String title,
    required String description,
    required int currentStep,
    required int totalSteps,
    VoidCallback? onNext,
    bool isMandatory = false,
    VoidCallback? onTargetTapped,
  }) {
    final int stepNumber = currentStep + 1;
    final int total = totalSteps > 0 ? totalSteps : 1;
    final String stepBadgeText = isMandatory ? 'Mandatory Tour' : '$stepNumber of $total';

    return Container(
      key: _cardKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFDFE1D6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF282321).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFFF9A825).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Step Indicator (e.g. "1 of 1" or dynamic "X of N") & Close 'X' Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFF9A825).withValues(alpha: 0.45),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isMandatory ? Icons.stars_rounded : Icons.touch_app_rounded,
                        size: 13,
                        color: const Color(0xFFF9A825),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stepBadgeText,
                        style: const TextStyle(
                          color: Color(0xFFB45309),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (!isMandatory)
                  InkWell(
                    onTap: _handleSkip,
                    borderRadius: BorderRadius.circular(12),
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Color(0xFF867471),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            // Dynamic Title
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF282321),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),

            const SizedBox(height: 5),

            // Dynamic Description
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFF5F5854),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),

            const SizedBox(height: 12),

            // Subtle divider
            Container(
              height: 1,
              color: const Color(0xFFF0EFEA),
            ),

            const SizedBox(height: 10),

            // Footer: Don't show again checkbox, Skip Tour button, and Next/Done button
            if (isMandatory) ...[
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() => _dontShowAgain = !_dontShowAgain);
                        ref
                            .read(guidedTourControllerProvider)
                            .setMandatoryHelpDontShowAgain(_dontShowAgain);
                        widget.onDontShowAgainChanged?.call(_dontShowAgain);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 17,
                              height: 17,
                              decoration: BoxDecoration(
                                color: _dontShowAgain
                                    ? const Color(0xFFF9A825)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _dontShowAgain
                                      ? const Color(0xFFF9A825)
                                      : const Color(0xFFB2ABA5),
                                  width: 1.4,
                                ),
                              ),
                              child: _dontShowAgain
                                  ? const Icon(
                                      Icons.check,
                                      size: 12,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 7),
                            const Flexible(
                              child: Text(
                                "Don't show again",
                                style: TextStyle(
                                  color: Color(0xFF756D69),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(guidedTourControllerProvider)
                          .setMandatoryHelpDontShowAgain(_dontShowAgain);
                      onTargetTapped?.call();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF9A825),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 15),
                    label: const Text(
                      'Open Help',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                InkWell(
                  onTap: () {
                    setState(() => _dontShowAgain = !_dontShowAgain);
                    widget.onDontShowAgainChanged?.call(_dontShowAgain);
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: _dontShowAgain
                                ? const Color(0xFFF9A825)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: _dontShowAgain
                                  ? const Color(0xFFF9A825)
                                  : const Color(0xFFB2ABA5),
                              width: 1.4,
                            ),
                          ),
                          child: _dontShowAgain
                              ? const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 7),
                        const Text(
                          "Don't show again",
                          style: TextStyle(
                            color: Color(0xFF756D69),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _handleSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4D4542),
                        backgroundColor: const Color(0xFFF5F4F0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: const BorderSide(
                            color: Color(0xFFDFE1D6),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Skip Tour',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4D4542),
                        ),
                      ),
                    ),
                    if (onNext != null && currentStep < totalSteps - 1) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onNext,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFF9A825),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ] else if (currentStep >= totalSteps - 1) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _handleSkip,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFFF9A825),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Done',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ],
        ),
      ),
    );
  }
}

/// Holds the calculated bounding box, transformed widget, and card position for the arrow.
class _GuidedTourArrowLayout {
  final Rect arrowRect;
  final Widget arrowWidget;
  final double cardTop;
  final double cardLeft;

  const _GuidedTourArrowLayout({
    required this.arrowRect,
    required this.arrowWidget,
    required this.cardTop,
    required this.cardLeft,
  });
}

/// Centralized geometry calculations, bounded sizing, and orientation transforms
/// for the approved yellow curved directional arrow.
class _GuidedTourArrowSystem {
  static const double svgViewBoxWidth = 142.0;
  static const double svgViewBoxHeight = 256.0;

  // Exact tip and start coordinates from the approved Directional arrow (1).svg asset:
  // Path start: (1.50041, 5.35261)
  // Arrowhead tip: (116.114, 253.501)
  static const double startRatioX = 1.50041 / svgViewBoxWidth; // ~0.0106
  static const double startRatioY = 5.35261 / svgViewBoxHeight; // ~0.0209
  static const double tipRatioX = 116.114 / svgViewBoxWidth; // ~0.8177
  static const double tipRatioY = 253.501 / svgViewBoxHeight; // ~0.9902

  static const double minArrowHeight = 120.0;
  static const double defaultArrowHeight = 240.0;

  static const double minArrowLength = 100.0;
  static const double defaultArrowLength = 200.0;

  static const double estimatedCardHeight = 218.0;
  static const double screenMargin = 16.0;

  /// Resolves the effective [GuidedTourArrowDirection] from configuration, alignment hints, or screen heuristics.
  static GuidedTourArrowDirection resolveDirection({
    required Rect targetRect,
    required Size screenSize,
    GuidedTourArrowDirection direction = GuidedTourArrowDirection.auto,
    Alignment? alignmentHint,
    double cardHeight = estimatedCardHeight,
  }) {
    if (direction == GuidedTourArrowDirection.top) {
      // If there's insufficient vertical clearance above the target, flip to bottom so target remains fully visible
      if (targetRect.top - cardHeight - 16.0 < 40.0 &&
          (targetRect.bottom + cardHeight + 20.0 <= screenSize.height)) {
        return GuidedTourArrowDirection.bottom;
      }
      return GuidedTourArrowDirection.top;
    }
    if (direction == GuidedTourArrowDirection.bottom) {
      // If there's insufficient vertical clearance below the target, flip to top so target remains fully visible
      if (targetRect.bottom + cardHeight + 16.0 > screenSize.height - 16.0 &&
          (targetRect.top - cardHeight - 16.0 >= 40.0)) {
        return GuidedTourArrowDirection.top;
      }
      return GuidedTourArrowDirection.bottom;
    }
    if (direction != GuidedTourArrowDirection.auto) {
      return direction;
    }
    if (alignmentHint != null) {
      if (alignmentHint.y < -0.3) return GuidedTourArrowDirection.top;
      if (alignmentHint.y > 0.3) return GuidedTourArrowDirection.bottom;
      if (alignmentHint.x < -0.3) return GuidedTourArrowDirection.left;
      if (alignmentHint.x > 0.3) return GuidedTourArrowDirection.right;
    }
    // Auto heuristic based on available vertical space:
    // If target is in the lower portion of the screen (e.g. Scan FAB), place arrow above it pointing down.
    if (targetRect.center.dy >= screenSize.height * 0.5) {
      return GuidedTourArrowDirection.top;
    } else {
      return GuidedTourArrowDirection.bottom;
    }
  }

  /// Calculates arrow geometry, sizing, directional transforms, and card placement.
  static _GuidedTourArrowLayout calculateLayout({
    required Rect targetRect,
    required Size screenSize,
    required EdgeInsets viewPadding,
    required double cardWidth,
    double cardHeight = estimatedCardHeight,
    required GuidedTourArrowDirection direction,
    required double bounceValue,
  }) {
    final double bounceOffset = bounceValue * 0.75;
    final bool isBrowser = screenSize.width >= 600;

    switch (direction) {
      case GuidedTourArrowDirection.top:
      case GuidedTourArrowDirection.auto:
        // Arrow sits ABOVE target, pointing DOWN (natural untransformed SVG)
        final double availableHeight =
            targetRect.top - viewPadding.top - cardHeight - 24.0;
        final double arrowHeight = availableHeight < defaultArrowHeight
            ? availableHeight.clamp(minArrowHeight, defaultArrowHeight)
            : defaultArrowHeight;
        final double arrowWidth =
            arrowHeight * (svgViewBoxWidth / svgViewBoxHeight);

        final double arrowTipY = targetRect.top - (18.0 + bounceOffset);
        final double arrowTop = arrowTipY - (arrowHeight * tipRatioY);
        final double arrowStartY = arrowTop + (arrowHeight * startRatioY);

        final double arrowTipX = (targetRect.left + (targetRect.width * 0.65))
            .clamp(screenMargin + 60.0, screenSize.width - screenMargin - 20.0);
        double arrowLeft = arrowTipX - (arrowWidth * tipRatioX);
        arrowLeft = arrowLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - arrowWidth - screenMargin),
        );

        final double maxTopWithoutOverlap = targetRect.top - cardHeight - 14.0;
        final double cardTop = isBrowser
            ? math.max(
                viewPadding.top + 70.0,
                math.min(viewPadding.top + 100.0, maxTopWithoutOverlap),
              )
            : math.max(
                viewPadding.top + 70.0,
                math.min(arrowStartY - cardHeight, maxTopWithoutOverlap),
              );
        double cardLeft = (screenSize.width - cardWidth) / 2;
        cardLeft = cardLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - cardWidth - screenMargin),
        );

        return _GuidedTourArrowLayout(
          arrowRect: Rect.fromLTWH(arrowLeft, arrowTop, arrowWidth, arrowHeight),
          arrowWidget: SvgPicture.string(
            _kDirectionalArrowSvg,
            width: arrowWidth,
            height: arrowHeight,
            fit: BoxFit.contain,
          ),
          cardTop: cardTop,
          cardLeft: cardLeft,
        );

      case GuidedTourArrowDirection.bottom:
        // Arrow sits BELOW target, pointing UP (vertical flip)
        final double availableHeight = screenSize.height -
            targetRect.bottom -
            viewPadding.bottom -
            cardHeight -
            24.0;
        final double arrowHeight = availableHeight < defaultArrowHeight
            ? availableHeight.clamp(minArrowHeight, defaultArrowHeight)
            : defaultArrowHeight;
        final double arrowWidth =
            arrowHeight * (svgViewBoxWidth / svgViewBoxHeight);

        // Flipped tip ratio Y is (1 - tipRatioY) = ~0.0098
        const double flippedTipRatioY = 1.0 - tipRatioY;
        const double flippedStartRatioY = 1.0 - startRatioY;

        final double arrowTipY = targetRect.bottom + (18.0 + bounceOffset);
        final double arrowTop = arrowTipY - (arrowHeight * flippedTipRatioY);
        final double arrowStartY = arrowTop + (arrowHeight * flippedStartRatioY);

        final double arrowTipX = (targetRect.left + (targetRect.width * 0.65))
            .clamp(screenMargin + 60.0, screenSize.width - screenMargin - 20.0);
        double arrowLeft = arrowTipX - (arrowWidth * tipRatioX);
        arrowLeft = arrowLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - arrowWidth - screenMargin),
        );

        final double minTopWithoutOverlap = targetRect.bottom + 20.0;
        final double maxSafeCardTop = math.max(
          minTopWithoutOverlap,
          screenSize.height - cardHeight - viewPadding.bottom - screenMargin,
        );
        final double cardTop = isBrowser
            ? (targetRect.bottom + 36.0).clamp(
                minTopWithoutOverlap,
                maxSafeCardTop,
              )
            : math.min(
                screenSize.height - viewPadding.bottom - cardHeight - 10.0,
                math.max(minTopWithoutOverlap, arrowStartY + 8.0),
              );
        double cardLeft = (screenSize.width - cardWidth) / 2;
        cardLeft = cardLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - cardWidth - screenMargin),
        );

        return _GuidedTourArrowLayout(
          arrowRect: Rect.fromLTWH(arrowLeft, arrowTop, arrowWidth, arrowHeight),
          arrowWidget: Transform.scale(
            scaleY: -1,
            child: SvgPicture.string(
              _kDirectionalArrowSvg,
              width: arrowWidth,
              height: arrowHeight,
              fit: BoxFit.contain,
            ),
          ),
          cardTop: cardTop,
          cardLeft: cardLeft,
        );

      case GuidedTourArrowDirection.left:
        // Arrow sits to the LEFT of target, pointing RIGHT
        final double availableWidth =
            targetRect.left - screenMargin - 24.0;
        final double arrowLen = availableWidth < defaultArrowLength
            ? availableWidth.clamp(minArrowLength, defaultArrowLength)
            : defaultArrowLength;
        final double arrowThick =
            arrowLen * (svgViewBoxWidth / svgViewBoxHeight);

        // In RotatedBox(quarterTurns: 3): box has width = arrowLen, height = arrowThick
        final double tipXOffset = arrowLen * tipRatioY; // ~0.9902
        final double tipYOffset = arrowThick * (1.0 - tipRatioX); // ~0.1823

        final double arrowTipX = targetRect.left - (18.0 + bounceOffset);
        final double arrowLeft = arrowTipX - tipXOffset;
        final double arrowTipY = (targetRect.top + (targetRect.height * 0.5))
            .clamp(viewPadding.top + 60.0, screenSize.height - viewPadding.bottom - 60.0);
        final double arrowTop = arrowTipY - tipYOffset;

        final double cardTop = math.max(
          viewPadding.top + 70.0,
          math.min(arrowTop - cardHeight - 8.0, screenSize.height - viewPadding.bottom - cardHeight - 10.0),
        );
        double cardLeft = (screenSize.width - cardWidth) / 2;
        cardLeft = cardLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - cardWidth - screenMargin),
        );

        return _GuidedTourArrowLayout(
          arrowRect: Rect.fromLTWH(
            arrowLeft.clamp(screenMargin, math.max(screenMargin, screenSize.width - arrowLen - screenMargin)),
            arrowTop.clamp(viewPadding.top + 10.0, math.max(viewPadding.top + 10.0, screenSize.height - viewPadding.bottom - arrowThick - 10.0)),
            arrowLen,
            arrowThick,
          ),
          arrowWidget: RotatedBox(
            quarterTurns: 3,
            child: SvgPicture.string(
              _kDirectionalArrowSvg,
              width: arrowThick,
              height: arrowLen,
              fit: BoxFit.contain,
            ),
          ),
          cardTop: cardTop,
          cardLeft: cardLeft,
        );

      case GuidedTourArrowDirection.right:
        // Arrow sits to the RIGHT of target, pointing LEFT
        final double availableWidth =
            screenSize.width - targetRect.right - screenMargin - 24.0;
        final double arrowLen = availableWidth < defaultArrowLength
            ? availableWidth.clamp(minArrowLength, defaultArrowLength)
            : defaultArrowLength;
        final double arrowThick =
            arrowLen * (svgViewBoxWidth / svgViewBoxHeight);

        // Flipped horizontal: tip is at (0.0098 * arrowLen, 0.1823 * arrowThick)
        final double tipXOffset = arrowLen * (1.0 - tipRatioY); // ~0.0098
        final double tipYOffset = arrowThick * (1.0 - tipRatioX); // ~0.1823

        final double arrowTipX = targetRect.right + (18.0 + bounceOffset);
        final double arrowLeft = arrowTipX - tipXOffset;
        final double arrowTipY = (targetRect.top + (targetRect.height * 0.5))
            .clamp(viewPadding.top + 60.0, screenSize.height - viewPadding.bottom - 60.0);
        final double arrowTop = arrowTipY - tipYOffset;

        final double cardTop = math.max(
          viewPadding.top + 70.0,
          math.min(arrowTop - cardHeight - 8.0, screenSize.height - viewPadding.bottom - cardHeight - 10.0),
        );
        double cardLeft = (screenSize.width - cardWidth) / 2;
        cardLeft = cardLeft.clamp(
          screenMargin,
          math.max(screenMargin, screenSize.width - cardWidth - screenMargin),
        );

        return _GuidedTourArrowLayout(
          arrowRect: Rect.fromLTWH(
            arrowLeft.clamp(screenMargin, math.max(screenMargin, screenSize.width - arrowLen - screenMargin)),
            arrowTop.clamp(viewPadding.top + 10.0, math.max(viewPadding.top + 10.0, screenSize.height - viewPadding.bottom - arrowThick - 10.0)),
            arrowLen,
            arrowThick,
          ),
          arrowWidget: Transform.scale(
            scaleX: -1,
            child: RotatedBox(
              quarterTurns: 3,
              child: SvgPicture.string(
                _kDirectionalArrowSvg,
                width: arrowThick,
                height: arrowLen,
                fit: BoxFit.contain,
              ),
            ),
          ),
          cardTop: cardTop,
          cardLeft: cardLeft,
        );
    }
  }
}

/// Custom RenderObject widget that lets touches directly inside [holeRRect]
/// pass through to the underlying target button, while intercepting taps
/// on the dimmed scrim area.
class _HoleHitTestWidget extends SingleChildRenderObjectWidget {
  final RRect holeRRect;
  final VoidCallback onDimmedAreaTap;

  const _HoleHitTestWidget({
    required this.holeRRect,
    required this.onDimmedAreaTap,
    required Widget child,
  }) : super(child: child);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHoleHitTest(holeRRect: holeRRect, onDimmedAreaTap: onDimmedAreaTap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderHoleHitTest renderObject,
  ) {
    renderObject
      ..holeRRect = holeRRect
      ..onDimmedAreaTap = onDimmedAreaTap;
  }
}

class _RenderHoleHitTest extends RenderProxyBox {
  _RenderHoleHitTest({
    required RRect holeRRect,
    required VoidCallback onDimmedAreaTap,
  })  : _holeRRect = holeRRect,
        _onDimmedAreaTap = onDimmedAreaTap;

  RRect _holeRRect;
  set holeRRect(RRect val) {
    if (_holeRRect != val) {
      _holeRRect = val;
      markNeedsPaint();
    }
  }

  VoidCallback _onDimmedAreaTap;
  set onDimmedAreaTap(VoidCallback val) => _onDimmedAreaTap = val;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    // If the tap is inside the cut-out hole, pass through to the real button beneath
    if (_holeRRect.contains(position)) {
      return false;
    }
    // Check child hits (e.g. instruction card)
    if (hitTestChildren(result, position: position)) {
      return true;
    }
    // Dimmed area hit
    result.add(BoxHitTestEntry(this, position));
    return true;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      if (!_holeRRect.contains(event.position)) {
        _onDimmedAreaTap();
      }
    }
  }
}

/// Painter that shades the viewport with a focused dark scrim, leaving [holeRRect]
/// completely non-faded and transparent, and paints an elevated dual-tone highlight bezel
/// with drop-shadow so the highlighted target has the same crisp foreground prominence as the popup card.
class _ScrimHolePainter extends CustomPainter {
  final RRect holeRRect;
  final double pulseFactor;
  final Color scrimColor;
  final Color focusColor;
  final double highlightOpacity;

  _ScrimHolePainter({
    required this.holeRRect,
    required this.pulseFactor,
    this.scrimColor = const Color(0x66000000),
    this.focusColor = const Color(0xFFF9A825),
    this.highlightOpacity = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Offset.zero & size);

    if (highlightOpacity <= 0.001 || holeRRect.isEmpty) {
      canvas.drawPath(backgroundPath, Paint()..color = scrimColor);
      return;
    }

    final holePath = Path()..addRRect(holeRRect);
    final scrimPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      holePath,
    );

    // 1. Draw the darkened backdrop scrim (fades out the rest of the page)
    canvas.drawPath(scrimPath, Paint()..color = scrimColor);

    // 2. Outer elevation shadow: casts shadow from the cutout hole onto the dark scrim,
    // visually lifting the highlighted widget up to the foreground plane with the popup card.
    final elevationShadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.36 * highlightOpacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawRRect(holeRRect.inflate(2.0), elevationShadowPaint);

    // 3. Ambient golden spotlight glow around the target
    final glowAlpha = ((0.28 + pulseFactor) * highlightOpacity).clamp(0.0, 0.45);
    final glowPaint = Paint()
      ..color = focusColor.withValues(alpha: glowAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawRRect(holeRRect, glowPaint);

    // 4. Outer Amber / Gold Focus Ring (2.4px solid)
    final strokePaint = Paint()
      ..color = focusColor.withValues(alpha: highlightOpacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;
    canvas.drawRRect(holeRRect, strokePaint);

    // 5. Inner Crisp Highlight Bezel (Pure white luminous 1.2px rim)
    // Matches the solid, crisp white elevation of the floating popup card
    final innerHighlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.85 * highlightOpacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(holeRRect.deflate(1.2), innerHighlightPaint);
  }

  @override
  bool shouldRepaint(covariant _ScrimHolePainter old) =>
      old.holeRRect != holeRRect ||
      old.pulseFactor != pulseFactor ||
      old.scrimColor != scrimColor ||
      old.highlightOpacity != highlightOpacity;
}
