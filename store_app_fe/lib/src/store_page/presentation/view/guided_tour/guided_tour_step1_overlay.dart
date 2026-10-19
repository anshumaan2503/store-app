import 'package:flutter/material.dart';

import 'guided_tour_overlay.dart';

export 'guided_tour_overlay.dart';

/// Backwards-compatible Guided Tour Step 1 overlay wrapper.
///
/// Wraps the generic [GuidedTourOverlay] with the default title, description,
/// and step indicators for the Issue Requester tour.
class GuidedTourStep1Overlay extends StatelessWidget {
  final GlobalKey targetKey;
  final void Function({required bool dontShowAgain}) onDismiss;
  final ValueChanged<bool>? onDontShowAgainChanged;
  final VoidCallback? onTargetTapped;

  const GuidedTourStep1Overlay({
    super.key,
    required this.targetKey,
    required this.onDismiss,
    this.onDontShowAgainChanged,
    this.onTargetTapped,
  });

  @override
  Widget build(BuildContext context) {
    return GuidedTourOverlay(
      targetKey: targetKey,
      title: 'Create an Issue Request',
      description:
          "Tap Scan for Issue Request to scan an item's QR code and quickly start your request.",
      currentStep: 0,
      totalSteps: 1,
      onDismiss: onDismiss,
      onDontShowAgainChanged: onDontShowAgainChanged,
      onTargetTapped: onTargetTapped,
    );
  }
}
