import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/auth/shared/providers/auth_model_provider.dart';
import '../../../controllers/store_cart_controller.dart';

/* ---------------- Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF8F9FA);
const _stroke = Color(0xFFDFE1D6);
const _brandPrimary = Color(0xFF2563EB);

Future<void> showCartTimerSettingsSheet(BuildContext context) async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const StoreCartTimerSettingsSheet(),
  );
}

class StoreCartTimerSettingsSheet extends ConsumerStatefulWidget {
  const StoreCartTimerSettingsSheet({super.key});

  @override
  ConsumerState<StoreCartTimerSettingsSheet> createState() =>
      _StoreCartTimerSettingsSheetState();
}

class _StoreCartTimerSettingsSheetState
    extends ConsumerState<StoreCartTimerSettingsSheet> {
  // Option 1: Cart hold timer (minutes)
  late bool _cartEnabled;
  late int _cartMinutes;

  // Option 2: Requisition requested timer (days)
  late bool _reqEnabled;
  late int _reqDays;

  // Option 3: Month-end uncollected items revert (toggle only)
  late bool _monthEndRevertEnabled;

  // Option 4: Indent approval workflow
  late bool _indentApprovalRequired;

  // Option 5: GRN cart workflow
  late bool _grnWorkflowEnabled;

  // Option 6: Indent 1-month auto-close
  late bool _indentAutoCloseEnabled;
  late int _indentAutoCloseDays;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(storeCartConfigProvider);
    _cartEnabled = config.cartTimeoutEnabled;
    _cartMinutes = config.cartTimeoutMinutes;
    _reqEnabled = config.requestTimeoutEnabled;
    _reqDays = config.requestTimeoutDays;
    _monthEndRevertEnabled = config.monthEndRevertEnabled;
    _indentApprovalRequired = config.indentApprovalRequired;
    _grnWorkflowEnabled = config.grnWorkflowEnabled;
    _indentAutoCloseEnabled = config.indentAutoCloseEnabled;
    _indentAutoCloseDays = config.indentAutoCloseDays;
  }

  Future<void> _handleSave() async {
    setState(() => _saving = true);
    final auth = ref.read(authModelProvider);
    final success =
        await ref.read(storeCartConfigProvider.notifier).updateConfig(
              minutes: _cartMinutes,
              enabled: _cartEnabled,
              requestDays: _reqDays,
              requestEnabled: _reqEnabled,
              monthEndRevertEnabled: _monthEndRevertEnabled,
              indentApprovalRequired: _indentApprovalRequired,
              grnWorkflowEnabled: _grnWorkflowEnabled,
              indentAutoCloseDays: _indentAutoCloseDays,
              indentAutoCloseEnabled: _indentAutoCloseEnabled,
              updatedBy: (auth?.name != null && auth!.name.isNotEmpty)
                  ? auth.name
                  : (auth?.uid ?? 'SuperAdmin'),
            );
    if (!mounted) return;
    setState(() => _saving = false);

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Settings saved! Indent Approval: ${_indentApprovalRequired ? "ON" : "OFF"} • GRN: ${_grnWorkflowEnabled ? "ON" : "OFF"} • Cart: ${_cartEnabled ? "$_cartMinutes m" : "OFF"}'
                    : 'Failed to update settings. Please try again.',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            success ? const Color(0xFF16A34A) : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: _brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Super Admin Control',
                      style: TextStyle(fontSize: 11.5, color: _ink600),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: _ink600),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Single scrollable list of all 3 options
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Cart Hold Auto-Revert
                  _buildOptionCard(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart Auto-Revert',
                    subtitle: _cartEnabled
                        ? 'Revert items after $_cartMinutes minutes in cart'
                        : 'Disabled: Items remain in cart indefinitely',
                    enabled: _cartEnabled,
                    onToggle: (val) => setState(() => _cartEnabled = val),
                    content: _cartEnabled
                        ? _buildStepper(
                            currentVal: _cartMinutes,
                            unit: 'minutes',
                            min: 1,
                            max: 120,
                            presets: const [2, 5, 10, 15, 30, 60],
                            onChanged: (val) =>
                                setState(() => _cartMinutes = val),
                          )
                        : null,
                  ),

                  const SizedBox(height: 12),

                  // 2. Requested Items Auto-Revert
                  _buildOptionCard(
                    icon: Icons.assignment_outlined,
                    title: 'Requested Items Auto-Revert',
                    subtitle: _reqEnabled
                        ? 'Revert unapproved requests after $_reqDays days'
                        : 'Disabled: Requests stay pending indefinitely',
                    enabled: _reqEnabled,
                    onToggle: (val) => setState(() => _reqEnabled = val),
                    content: _reqEnabled
                        ? _buildStepper(
                            currentVal: _reqDays,
                            unit: _reqDays == 1 ? 'day' : 'days',
                            min: 1,
                            max: 60,
                            presets: const [1, 3, 5, 7, 14, 30],
                            onChanged: (val) =>
                                setState(() => _reqDays = val),
                          )
                        : null,
                  ),

                  const SizedBox(height: 12),

                  // 3. Month-End Auto-Revert (Simple Toggle Only)
                  _buildOptionCard(
                    icon: Icons.calendar_month_outlined,
                    title: 'Month-End Auto-Revert',
                    subtitle: _monthEndRevertEnabled
                        ? 'Reverts uncollected ready-for-issue items to available stock at month end'
                        : 'Disabled: Uncollected items remain in ready-for-issue',
                    enabled: _monthEndRevertEnabled,
                    onToggle: (val) =>
                        setState(() => _monthEndRevertEnabled = val),
                    content: null,
                  ),

                  const SizedBox(height: 12),

                  // 4. Require Indent Approval Before Receiving
                  _buildOptionCard(
                    icon: Icons.fact_check_outlined,
                    title: 'Require Indent Approval',
                    subtitle: _indentApprovalRequired
                        ? 'Active: Raised indents must be approved under "Submitted Indents" before entering Receive'
                        : 'Disabled: Indents immediately appear in Receive without approval',
                    enabled: _indentApprovalRequired,
                    onToggle: (val) =>
                        setState(() => _indentApprovalRequired = val),
                    content: null,
                  ),

                  const SizedBox(height: 12),

                  // 5. GRN Cart & Inspection Workflow
                  _buildOptionCard(
                    icon: Icons.local_shipping_outlined,
                    title: 'GRN Cart & Verification',
                    subtitle: _grnWorkflowEnabled
                        ? 'Active: Items must be verified in GRN Cart with 1 invoice photo & approved before QR rack putaway'
                        : 'Disabled: Direct QR scan putaway with single photo',
                    enabled: _grnWorkflowEnabled,
                    onToggle: (val) =>
                        setState(() => _grnWorkflowEnabled = val),
                    content: null,
                  ),

                  const SizedBox(height: 12),

                  // 6. Auto-Close Stale Indents (1-Month Policy)
                  _buildOptionCard(
                    icon: Icons.hourglass_bottom_rounded,
                    title: 'Auto-Close Stale Indents',
                    subtitle: _indentAutoCloseEnabled
                        ? 'Active: Unfulfilled pending indents auto-close after $_indentAutoCloseDays days (~${(_indentAutoCloseDays / 30).toStringAsFixed(1)} mo)'
                        : 'Disabled: Indents remain open indefinitely until fulfilled or rejected',
                    enabled: _indentAutoCloseEnabled,
                    onToggle: (val) =>
                        setState(() => _indentAutoCloseEnabled = val),
                    content: _indentAutoCloseEnabled
                        ? _buildStepper(
                            currentVal: _indentAutoCloseDays,
                            unit: 'days',
                            min: 5,
                            max: 180,
                            presets: const [15, 30, 45, 60, 90],
                            onChanged: (val) =>
                                setState(() => _indentAutoCloseDays = val),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Save Button
          ElevatedButton(
            onPressed: _saving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink900,
              foregroundColor: _surface,
              disabledBackgroundColor: const Color(0xFFADB5BD),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Save Settings',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    Widget? content,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: enabled ? const Color(0xFFBFDBFE) : _stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: enabled ? const Color(0xFFEFF6FF) : const Color(0xFFF1F3F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: enabled ? _brandPrimary : _ink600,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: enabled ? const Color(0xFF15803D) : _ink600,
                        fontWeight: enabled ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeTrackColor: _ink900,
                activeThumbColor: _surface,
                onChanged: onToggle,
              ),
            ],
          ),
          if (content != null) ...[
            const SizedBox(height: 12),
            content,
          ],
        ],
      ),
    );
  }

  Widget _buildStepper({
    required int currentVal,
    required String unit,
    required int min,
    required int max,
    required List<int> presets,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Stepper bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: currentVal > min ? () => onChanged(currentVal - 1) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: currentVal > min ? _surfaceAlt : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _stroke),
                  ),
                  child: Icon(
                    Icons.remove,
                    color: currentVal > min ? _ink900 : const Color(0xFFADB5BD),
                    size: 16,
                  ),
                ),
              ),
              Text(
                '$currentVal $unit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink900,
                ),
              ),
              InkWell(
                onTap: currentVal < max ? () => onChanged(currentVal + 1) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: currentVal < max ? _surfaceAlt : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _stroke),
                  ),
                  child: Icon(
                    Icons.add,
                    color: currentVal < max ? _ink900 : const Color(0xFFADB5BD),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Quick presets
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: presets.map((p) {
            final isSelected = currentVal == p;
            return ChoiceChip(
              label: Text('$p'),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) onChanged(p);
              },
              selectedColor: const Color(0xFFEFF6FF),
              backgroundColor: _surface,
              visualDensity: VisualDensity.compact,
              labelPadding: const EdgeInsets.symmetric(horizontal: 4),
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? _brandPrimary : _ink700,
              ),
              side: BorderSide(
                color: isSelected ? _brandPrimary : _stroke,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
