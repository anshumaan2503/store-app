import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:store_app/src/store_page/controllers/scanner_settings_controller.dart';

class ScannerModeSelectorBar extends ConsumerWidget {
  final ScannerWorkflow workflow;

  const ScannerModeSelectorBar({
    super.key,
    required this.workflow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(scannerSettingsProvider);
    final activeMode = settings.getMode(workflow);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDFE1D6)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPill(
            context: context,
            ref: ref,
            mode: ScannerTargetMode.both,
            label: 'Both',
            icon: Icons.all_inclusive_rounded,
            isSelected: activeMode == ScannerTargetMode.both,
          ),
          const SizedBox(width: 4),
          _buildPill(
            context: context,
            ref: ref,
            mode: ScannerTargetMode.itemOnly,
            label: 'Item only',
            icon: Icons.inventory_2_outlined,
            isSelected: activeMode == ScannerTargetMode.itemOnly,
          ),
          const SizedBox(width: 4),
          _buildPill(
            context: context,
            ref: ref,
            mode: ScannerTargetMode.placeOnly,
            label: 'Place only',
            icon: Icons.meeting_room_outlined,
            isSelected: activeMode == ScannerTargetMode.placeOnly,
          ),
        ],
      ),
    );
  }

  Widget _buildPill({
    required BuildContext context,
    required WidgetRef ref,
    required ScannerTargetMode mode,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(scannerSettingsProvider.notifier).setMode(workflow, mode);
      },
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF282321) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF867471),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF4D4542),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

