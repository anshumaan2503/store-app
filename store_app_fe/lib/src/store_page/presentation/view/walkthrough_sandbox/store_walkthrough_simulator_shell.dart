import 'package:flutter/material.dart';

/* ---------------- Design Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFAF8F0);
const _stroke = Color(0xFFDFE1D6);
const _brandPrimary = Color(0xFF1E3A8A);

/// Reusable completion dialog shown when an interactive sandbox tour finishes.
void showSimulatorCompletionDialog({
  required BuildContext context,
  required String tourTitle,
  required String description,
  required VoidCallback onReplay,
  required VoidCallback onGoToLive,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Celebration Badge
                Center(
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1010B981),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFF059669),
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text(
                  'Training Completed!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),

                // Tour Title Subheading
                Text(
                  tourTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _brandPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),

                // Description Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke),
                  ),
                  child: Text(
                    description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // Action Buttons
                Row(
                  children: [
                    // Practice Again Button
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink900,
                          side: const BorderSide(color: _stroke, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onReplay();
                        },
                        icon: const Icon(Icons.replay_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Practice Again',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Go to Live Page Button
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _ink900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          onGoToLive();
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Go to Live Page',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Shared wrapper shell for all Training Sandbox simulator screens.
class StoreWalkthroughSimulatorShell extends StatelessWidget {
  final String title;
  final String currentStepLabel;
  final int currentStep;
  final int totalSteps;
  final VoidCallback onExit;
  final VoidCallback onReset;
  final Widget child;

  const StoreWalkthroughSimulatorShell({
    super.key,
    required this.title,
    required this.currentStepLabel,
    required this.currentStep,
    required this.totalSteps,
    required this.onExit,
    required this.onReset,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFF3),
      body: SafeArea(
        child: Column(
          children: [
            // Top Persistent Header
            _buildTopHeader(context),

            // Persistent Training Sandbox Banner
            _buildSafetyBanner(context),

            // Main Interactive Simulator Body
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 600;
    final isVeryNarrow = w < 400;

    return Container(
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 12, 10, isMobile ? 8 : 14, 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _stroke)),
      ),
      child: Row(
        children: [
          // Exit Training Button
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onExit,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 10, vertical: 6),
              decoration: BoxDecoration(
                color: _surfaceAlt,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 16, color: _ink900),
                  if (!isVeryNarrow) ...[
                    const SizedBox(width: 4),
                    Text(
                      isMobile ? 'Exit' : 'Exit Training',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: isMobile ? 6 : 10),

          // Title & Sandbox Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 11, color: Color(0xFFB45309)),
                          if (!isMobile) ...[
                            const SizedBox(width: 3),
                            const Text(
                              'TRAINING SANDBOX',
                              style: TextStyle(
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.w800,
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: isMobile ? 13 : 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Step $currentStep of $totalSteps: $currentStepLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 10.5 : 11.5,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: isMobile ? 6 : 10),

          // Reset Scenario Button
          Tooltip(
            message: 'Reset scenario to initial state',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onReset,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(Icons.refresh_rounded, size: 18, color: _ink900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFFEFF6FF),
        border: Border(bottom: BorderSide(color: Color(0xFFBFDBFE))),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF1D4ED8)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Safe Practice Sandbox: All items & actions use demo data. No real inventory will be affected.',
              style: TextStyle(
                color: Color(0xFF1E40AF),
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
