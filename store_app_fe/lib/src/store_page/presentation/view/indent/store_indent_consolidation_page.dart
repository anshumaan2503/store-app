import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/stock_refill_request_controller.dart';
import '../../../domains/models/stock_refill_request_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFAF8F5);
const _stroke = Color(0xFFDFE1D6);

class StoreIndentConsolidationPage extends ConsumerStatefulWidget {
  const StoreIndentConsolidationPage({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<StoreIndentConsolidationPage> createState() =>
      _StoreIndentConsolidationPageState();
}

class _StoreIndentConsolidationPageState
    extends ConsumerState<StoreIndentConsolidationPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(pendingStoreConsolidationProvider);
        ref.invalidate(pendingStoreConsolidationCountProvider);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consolidationAsync = ref.watch(pendingStoreConsolidationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Store Indent Consolidation & Approval',
                    style: TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
              ),
            ),
            Text(
              'Consolidate department & night indents by item • Enforce max warehouse capacity',
              style: TextStyle(
                color: _ink600,
                fontWeight: FontWeight.w500,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
        backgroundColor: _surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: _ink900),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _stroke, height: 1),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh consolidation list',
            icon: const Icon(Icons.refresh_rounded, color: _ink900),
            onPressed: () {
              ref.invalidate(pendingStoreConsolidationProvider);
              ref.invalidate(pendingStoreConsolidationCountProvider);
              ref.invalidate(refillRequestsListProvider);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search & Filter header bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: _surface,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) {
                        ref
                            .read(storeConsolidationSearchProvider.notifier)
                            .state = v.trim();
                      },
                      decoration: InputDecoration(
                        hintText: 'Search items by name or item code...',
                        hintStyle: const TextStyle(color: _ink600, fontSize: 13),
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20, color: _ink600),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(
                                          storeConsolidationSearchProvider.notifier)
                                      .state = '';
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: _surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _stroke),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _stroke),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _ink900, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      ref.invalidate(pendingStoreConsolidationProvider);
                      ref.invalidate(pendingStoreConsolidationCountProvider);
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _stroke),

            // Main List or Empty State
            Expanded(
              child: consolidationAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: _ink900),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 44, color: Color(0xFFC62828)),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading indents for store consolidation:\n$err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFC62828), fontSize: 13.5),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.invalidate(pendingStoreConsolidationProvider);
                            ref.invalidate(pendingStoreConsolidationCountProvider);
                          },
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Try Again'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (items) {
                  if (items.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(pendingStoreConsolidationProvider);
                        ref.invalidate(pendingStoreConsolidationCountProvider);
                        await ref.read(pendingStoreConsolidationProvider.future);
                      },
                      child: LayoutBuilder(
                        builder: (context, constraints) => SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        size: 54, color: Color(0xFF2E7D32)),
                                    const SizedBox(height: 14),
                                    const Text(
                                      'All Indents Consolidated & Approved',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: _ink900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'There are currently no department indents or night auto-refills awaiting store approval.\nStore Receivers can process approved indents in the GRN Inward section.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        color: _ink600,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        ref.invalidate(pendingStoreConsolidationProvider);
                                        ref.invalidate(pendingStoreConsolidationCountProvider);
                                      },
                                      icon: const Icon(Icons.refresh_rounded, size: 16),
                                      label: const Text('Check for New Indents'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _ink900,
                                        side: const BorderSide(color: _stroke),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(pendingStoreConsolidationProvider);
                      ref.invalidate(pendingStoreConsolidationCountProvider);
                      await ref.read(pendingStoreConsolidationProvider.future);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, idx) {
                        final itemData = items[idx];
                        return _ConsolidatedItemAccordionCard(
                          key: ValueKey(itemData.itemId),
                          itemData: itemData,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An accordion card representing a single Item with all its pending indents (Dept 1, Dept 2, Night Auto-Refill)
class _ConsolidatedItemAccordionCard extends ConsumerStatefulWidget {
  final ConsolidatedStoreItemModel itemData;

  const _ConsolidatedItemAccordionCard({
    super.key,
    required this.itemData,
  });

  @override
  ConsumerState<_ConsolidatedItemAccordionCard> createState() =>
      _ConsolidatedItemAccordionCardState();
}

class _ConsolidatedItemAccordionCardState
    extends ConsumerState<_ConsolidatedItemAccordionCard> {
  bool _isExpanded = true;
  late Set<String> _selectedIndentIds;
  late Map<String, num> _quantities;
  late Map<String, TextEditingController> _controllers;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedIndentIds = {
      for (final ind in widget.itemData.indents) ind.id,
    };
    _quantities = {
      for (final ind in widget.itemData.indents) ind.id: ind.indentQty,
    };
    _controllers = {
      for (final ind in widget.itemData.indents)
        ind.id: TextEditingController(text: ind.indentQty.toString()),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  num get _totalSelectedQty {
    num total = 0;
    for (final id in _selectedIndentIds) {
      total += (_quantities[id] ?? 0);
    }
    return total;
  }

  bool get _exceedsMax {
    final maxCap = widget.itemData.maxCapacity;
    if (maxCap <= 0) return false;
    final totalProjected = widget.itemData.currentStock + _totalSelectedQty;
    return totalProjected > maxCap;
  }

  bool get _exceedsBuffer {
    final maxCap = widget.itemData.maxCapacity;
    if (maxCap <= 0) return false;
    final buffer = widget.itemData.maxAllowedBuffer;
    final totalProjected = widget.itemData.currentStock + _totalSelectedQty;
    return totalProjected > buffer;
  }

  /// Finds the automated night refill indent (point #3), if present and ticked
  StockRefillRequestModel? get _autoRefillIndent {
    for (final ind in widget.itemData.indents) {
      if (ind.isAutoRefill && _selectedIndentIds.contains(ind.id)) {
        return ind;
      }
    }
    return null;
  }

  /// Calculates suggestion quantity to reduce auto-refill to strictly maintain max capacity
  num? get _suggestedAutoQty {
    final auto = _autoRefillIndent;
    if (auto == null) return null;
    final maxCap = widget.itemData.maxCapacity;
    if (maxCap <= 0) return null;

    final otherSelectedQty = _totalSelectedQty - (_quantities[auto.id] ?? 0);
    final allowedForAuto =
        maxCap - (widget.itemData.currentStock + otherSelectedQty);

    return allowedForAuto.clamp(0, auto.indentQty);
  }

  void _applyMaintainMaxQtySuggestion() {
    final auto = _autoRefillIndent;
    final suggested = _suggestedAutoQty;
    if (auto == null || suggested == null) return;

    setState(() {
      _quantities[auto.id] = suggested;
      _controllers[auto.id]?.text = suggested.toString();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF1E88E5),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Night Auto-Refill quantity adjusted to $suggested ${widget.itemData.unit} to maintain Max Capacity ($maxCap). Note: Not saved to DB until submitted.',
        ),
      ),
    );
  }

  num get maxCap => widget.itemData.maxCapacity;

  Future<void> _submitStoreApproval({bool overrideMaxCapacity = false}) async {
    if (_isSubmitting) return;

    if (_selectedIndentIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('Please select at least one indent to approve.'),
        ),
      );
      return;
    }

    if (_exceedsBuffer && !overrideMaxCapacity) {
      final proceed = await _showGoAheadConfirmationDialog();
      if (proceed != true) return;
      return _submitStoreApproval(overrideMaxCapacity: true);
    }

    final itemsPayload = <Map<String, dynamic>>[];
    for (final id in _selectedIndentIds) {
      final qty = _quantities[id] ?? 0;
      if (qty <= 0) continue;
      itemsPayload.add({
        'indentId': id,
        'approvedQty': qty,
        'remarks': overrideMaxCapacity
            ? 'Store Incharge Go Ahead Approval (Exceeds Max Capacity)'
            : 'Consolidated & Approved by Store Incharge',
      });
    }

    if (itemsPayload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('All selected quantities must be greater than zero.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final ok = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .consolidatedStoreApprove(
            items: itemsPayload,
            overallRemarks: overrideMaxCapacity
                ? 'Store Incharge Go Ahead Authorization (Exceeded Max Capacity)'
                : 'Store Incharge Batch Consolidation',
            overrideMaxCapacity: overrideMaxCapacity,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            content: Text(
              'Successfully approved ${itemsPayload.length} indents for "${widget.itemData.itemName}". Ready for Store Inward GRN receipt!',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text('Error approving indents: $e'),
        ),
      );
    }
  }

  Future<bool?> _showGoAheadConfirmationDialog() async {
    final item = widget.itemData;
    final totalProjected = item.currentStock + _totalSelectedQty;

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Authorize Go Ahead?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ink900,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selected indents reach or exceed the maximum warehouse capacity for ${item.itemName} (${item.itemCode}):',
              style: const TextStyle(fontSize: 13, color: _ink700, height: 1.35),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stroke),
              ),
              child: Column(
                children: [
                  _dialogStatRow('Current Stock:', '${item.currentStock} ${item.unit}'),
                  const SizedBox(height: 5),
                  _dialogStatRow('Indents to Approve:', '$_totalSelectedQty ${item.unit}'),
                  const Divider(height: 14),
                  _dialogStatRow(
                    'Projected Total:',
                    '$totalProjected ${item.unit}',
                    bold: true,
                    color: const Color(0xFFE65100),
                  ),
                  const SizedBox(height: 5),
                  _dialogStatRow('Max Capacity:', '${item.maxCapacity} ${item.unit}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'As an authorized store user, you can give the go-ahead option to approve and continue with these indents anyway.',
              style: TextStyle(fontSize: 12, color: _ink600, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Go Ahead & Approve', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  static Widget _dialogStatRow(String label, String value, {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: _ink700, fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: 12, color: color ?? _ink900, fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.itemData;
    final auto = _autoRefillIndent;
    final suggested = _suggestedAutoQty;

    return Card(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _exceedsBuffer
              ? const Color(0xFFEF9A9A)
              : _exceedsMax
                  ? const Color(0xFFFFCC80)
                  : _stroke,
          width: _exceedsBuffer || _exceedsMax ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Accordion Header
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _exceedsBuffer
                    ? const Color(0xFFFFEBEE).withValues(alpha: 0.5)
                    : _exceedsMax
                        ? const Color(0xFFFFF8E1).withValues(alpha: 0.5)
                        : _surfaceAlt.withValues(alpha: 0.5),
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.category_rounded,
                          size: 20,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                if (item.itemCode.isNotEmpty) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: Text(
                                      item.itemCode,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: _ink700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '• ${item.indents.length} Indents Pending Consolidation',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _ink600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Expand / Collapse Icon
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _ink700,
                        size: 26,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Capacity & Selection Metrics Chips Row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _metricChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Current Stock',
                        value: '${item.currentStock} ${item.unit}',
                        color: const Color(0xFF1565C0),
                        bg: const Color(0xFFE3F2FD),
                      ),
                      _metricChip(
                        icon: Icons.speed_rounded,
                        label: 'Max Capacity',
                        value: item.maxCapacity > 0
                            ? '${item.maxCapacity} ${item.unit}'
                            : 'Unset',
                        color: const Color(0xFF4527A0),
                        bg: const Color(0xFFEDE7F6),
                      ),
                      _metricChip(
                        icon: _exceedsBuffer
                            ? Icons.error_rounded
                            : _exceedsMax
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_rounded,
                        label: 'Total Selected',
                        value: '$_totalSelectedQty ${item.unit}',
                        color: _exceedsBuffer
                            ? const Color(0xFFC62828)
                            : _exceedsMax
                                ? const Color(0xFFE65100)
                                : const Color(0xFF2E7D32),
                        bg: _exceedsBuffer
                            ? const Color(0xFFFFEBEE)
                            : _exceedsMax
                                ? const Color(0xFFFFF3E0)
                                : const Color(0xFFE8F5E9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Accordion Body
          if (_isExpanded) ...[
            const Divider(height: 1, color: _stroke),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Select all / Deselect toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select indents to approve & adjust quantity:',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _ink700,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedIndentIds.length == item.indents.length) {
                              _selectedIndentIds.clear();
                            } else {
                              _selectedIndentIds = {
                                for (final ind in item.indents) ind.id,
                              };
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(50, 30),
                        ),
                        child: Text(
                          _selectedIndentIds.length == item.indents.length
                              ? 'Deselect All'
                              : 'Select All',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Indent Items List
                  for (int i = 0; i < item.indents.length; i++) ...[
                    _buildIndentRow(i + 1, item.indents[i]),
                    if (i < item.indents.length - 1)
                      const Divider(height: 14, color: _stroke),
                  ],

                  const SizedBox(height: 14),

                  // Capacity Warning & Smart Suggestion Box
                  if (_exceedsMax || _exceedsBuffer)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _exceedsBuffer
                            ? const Color(0xFFFFF0F0)
                            : const Color(0xFFFFF9E6),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _exceedsBuffer
                              ? const Color(0xFFFFCDD2)
                              : const Color(0xFFFFE082),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFE65100),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _exceedsBuffer
                                      ? 'Capacity Limit Exceeded (Go Ahead Available)'
                                      : 'Warning: Exceeds Maximum Capacity',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Current Stock (${item.currentStock}) + Selected Indents ($_totalSelectedQty) = ${item.currentStock + _totalSelectedQty} ${item.unit}. '
                            'Maximum Capacity is ${item.maxCapacity} ${item.unit} (Allowable limit with 5% buffer: ${item.maxAllowedBuffer} ${item.unit}).',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _ink700,
                              height: 1.35,
                            ),
                          ),

                          // Smart Suggestion for Night Auto-Refill (Point 3)
                          if (auto != null &&
                              suggested != null &&
                              suggested < (_quantities[auto.id] ?? 0)) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFBBDEFB),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    color: Color(0xFF1976D2),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: _ink900,
                                        ),
                                        children: [
                                          const TextSpan(
                                            text: 'Suggestion: ',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const TextSpan(
                                              text: 'Reduce Night Auto-Refill by '),
                                          TextSpan(
                                            text:
                                                '${(_quantities[auto.id] ?? 0) - suggested} ${item.unit} ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFFC62828),
                                            ),
                                          ),
                                          TextSpan(
                                              text:
                                                  '(to $suggested ${item.unit}) to maintain max capacity ($maxCap ${item.unit}).'),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton.icon(
                                    onPressed: _applyMaintainMaxQtySuggestion,
                                    icon: const Icon(Icons.flash_on_rounded,
                                        size: 15),
                                    label: const Text('Maintain Max Qty'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1976D2),
                                      foregroundColor: Colors.white,
                                      elevation: 1,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                  const SizedBox(height: 14),

                  // Bottom Action Bar inside Accordion
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      final summaryWidget = Text(
                        'Total to Approve: $_totalSelectedQty ${item.unit}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _exceedsBuffer
                              ? const Color(0xFFE65100)
                              : const Color(0xFF2E7D32),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );

                      final approveButton = ElevatedButton.icon(
                        onPressed: (_isSubmitting || _selectedIndentIds.isEmpty)
                            ? null
                            : () => _submitStoreApproval(overrideMaxCapacity: _exceedsBuffer),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _exceedsBuffer
                              ? const Color(0xFFE65100)
                              : const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          disabledBackgroundColor: const Color(0xFFE0E0E0),
                          disabledForegroundColor: const Color(0xFF9E9E9E),
                        ),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _exceedsBuffer
                                    ? Icons.warning_amber_rounded
                                    : Icons.verified_rounded,
                                size: 17,
                              ),
                        label: Text(
                          _exceedsBuffer
                              ? 'Go Ahead & Approve (${_selectedIndentIds.length})'
                              : 'Approve Selected (${_selectedIndentIds.length})',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            summaryWidget,
                            const SizedBox(height: 8),
                            approveButton,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: summaryWidget),
                          const SizedBox(width: 8),
                          approveButton,
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIndentRow(int index, StockRefillRequestModel ind) {
    final isSelected = _selectedIndentIds.contains(ind.id);
    final isAuto = ind.isAutoRefill;
    final unit = widget.itemData.unit;
    final currentQty = _quantities[ind.id] ?? ind.indentQty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? (isAuto ? const Color(0xFFF3E5F5).withValues(alpha: 0.3) : const Color(0xFFF1F8E9).withValues(alpha: 0.4))
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Checkbox
          Checkbox(
            value: isSelected,
            activeColor: isAuto ? const Color(0xFF7B1FA2) : const Color(0xFF2E7D32),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIndentIds.add(ind.id);
                } else {
                  _selectedIndentIds.remove(ind.id);
                }
              });
            },
          ),

          // 2. Index + Source Badge + User Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '$index. ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _ink900,
                      ),
                    ),
                    if (isAuto)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE7F6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFD1C4E9)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.nightlight_round,
                                size: 11, color: Color(0xFF6A1B9A)),
                            SizedBox(width: 4),
                            Text(
                              'Night Auto-Refill (Automatic)',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF6A1B9A),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFBBDEFB)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.badge_outlined,
                                size: 11, color: Color(0xFF1565C0)),
                            const SizedBox(width: 4),
                            Text(
                              (ind.costCenter?.isNotEmpty ?? false)
                                  ? '${ind.costCenter} (${ind.requestedBy})'
                                  : 'Dept Indent (${ind.requestedBy})',
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      ind.indentNumber.isNotEmpty ? ind.indentNumber : ind.requestNo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (ind.reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, left: 18),
                    child: Text(
                      ind.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: _ink600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 3. Quantity input field / editor (Stepper & TextField)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded,
                    size: 18, color: _ink700),
                tooltip: 'Decrease quantity',
                onPressed: isSelected && currentQty > 1
                    ? () {
                        setState(() {
                          final next = currentQty - 1;
                          _quantities[ind.id] = next;
                          _controllers[ind.id]?.text = next.toString();
                        });
                      }
                    : null,
              ),
              SizedBox(
                width: 60,
                height: 36,
                child: TextFormField(
                  controller: _controllers[ind.id],
                  enabled: isSelected,
                  textAlign: TextAlign.center,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _ink900,
                  ),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    isDense: true,
                    filled: true,
                    fillColor: isSelected ? _surface : const Color(0xFFEEEEEE),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _ink900, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final n = num.tryParse(val.trim());
                    if (n != null && n >= 0) {
                      setState(() {
                        _quantities[ind.id] = n;
                      });
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded,
                    size: 18, color: _ink700),
                tooltip: 'Increase quantity',
                onPressed: isSelected
                    ? () {
                        setState(() {
                          final next = currentQty + 1;
                          _quantities[ind.id] = next;
                          _controllers[ind.id]?.text = next.toString();
                        });
                      }
                    : null,
              ),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: _ink700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
