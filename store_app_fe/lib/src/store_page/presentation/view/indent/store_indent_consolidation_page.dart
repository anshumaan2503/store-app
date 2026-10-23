import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../new_store_home_page.dart';

import '../../../controllers/stock_refill_request_controller.dart';
import '../../../domains/models/stock_refill_request_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFAF8F5);
const _stroke = Color(0xFFDFE1D6);

enum ConsolidationViewMode {
  indentWise,
  itemWise,
}

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
  ConsolidationViewMode _viewMode = ConsolidationViewMode.indentWise;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.invalidate(storeConsolidationPayloadProvider);
        ref.invalidate(pendingStoreConsolidationCountProvider);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(storeConsolidationPayloadProvider);
    ref.invalidate(pendingStoreConsolidationProvider);
    ref.invalidate(pendingIndentWiseConsolidationProvider);
    ref.invalidate(pendingStoreConsolidationCountProvider);
    ref.invalidate(refillRequestsListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final payloadAsync = ref.watch(storeConsolidationPayloadProvider);

    final content = Column(
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
                        hintText: 'Search by Indent #, Department, or Item...',
                        hintStyle: const TextStyle(color: _ink600, fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded,
                            size: 20, color: _ink600),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  ref
                                      .read(storeConsolidationSearchProvider
                                          .notifier)
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
                  Builder(
                    builder: (context) {
                      final isNarrow = MediaQuery.of(context).size.width < 420;
                      if (isNarrow) {
                        return Tooltip(
                          message: 'Refresh',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _refresh,
                            child: Container(
                              height: 44,
                              width: 44,
                              decoration: BoxDecoration(
                                color: _ink900,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.refresh_rounded,
                                  size: 20, color: _surface),
                            ),
                          ),
                        );
                      }
                      return FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _ink900,
                          foregroundColor: _surface,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Refresh',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Segmented View Toggle: Indent-Wise vs Item-Wise
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildViewTab(
                      mode: ConsolidationViewMode.indentWise,
                      label: 'Indent-Wise (Requisitions)',
                      icon: Icons.receipt_long_rounded,
                      count: payloadAsync.valueOrNull?.totalIndents ?? 0,
                    ),
                    const SizedBox(width: 8),
                    _buildViewTab(
                      mode: ConsolidationViewMode.itemWise,
                      label: 'Item-Wise (Consolidated)',
                      icon: Icons.inventory_2_outlined,
                      count: payloadAsync.valueOrNull?.itemWise.length ?? 0,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: _stroke),

            // Main Content Area
            Expanded(
              child: payloadAsync.when(
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
                          'Error loading store consolidation list:\n$err',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Color(0xFFC62828), fontSize: 13.5),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _refresh,
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
                data: (payload) {
                  final indentWise = payload.indentWise;
                  final itemWise = payload.itemWise;

                  final isEmpty = _viewMode == ConsolidationViewMode.indentWise
                      ? indentWise.isEmpty
                      : itemWise.isEmpty;

                  if (isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
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
                                      onPressed: _refresh,
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

                  if (_viewMode == ConsolidationViewMode.indentWise) {
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: indentWise.length,
                        itemBuilder: (context, idx) {
                          final indentGroup = indentWise[idx];
                          return _ConsolidatedIndentAccordionCard(
                            key: ValueKey(indentGroup.groupIndentNumber),
                            indentGroup: indentGroup,
                            onRefreshRequested: _refresh,
                          );
                        },
                      ),
                    );
                  } else {
                    return RefreshIndicator(
                      onRefresh: () async => _refresh(),
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: itemWise.length,
                        itemBuilder: (context, idx) {
                          final itemData = itemWise[idx];
                          return _ConsolidatedItemAccordionCard(
                            key: ValueKey(itemData.itemId),
                            itemData: itemData,
                          );
                        },
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );

    if (widget.isEmbedded) {
      return Container(
        color: const Color(0xFFFAF8EF),
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
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
              'Indent-wise requisition review • Hierarchical item & indent approvals',
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
            onPressed: _refresh,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: content),
    );
  }

  Widget _buildViewTab({
    required ConsolidationViewMode mode,
    required String label,
    required IconData icon,
    required int count,
  }) {
    final isSelected = _viewMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (_viewMode != mode) {
          setState(() => _viewMode = mode);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _ink900 : _surfaceAlt,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? _ink900 : _stroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? _surface : _ink700,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? _surface : _ink900,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? _surface.withValues(alpha: 0.2)
                      : _stroke.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? _surface : _ink900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// INDENT-WISE ACCORDION CARD (Hierarchical Approval)
/// Displays requisition metadata, item progress badge, Whole-Indent approval,
/// and expands into detailed item breakdowns with individual "Approve Item" buttons.
/// ============================================================================
class _ConsolidatedIndentAccordionCard extends StatefulWidget {
  final ConsolidatedIndentGroupModel indentGroup;
  final VoidCallback onRefreshRequested;

  const _ConsolidatedIndentAccordionCard({
    super.key,
    required this.indentGroup,
    required this.onRefreshRequested,
  });

  @override
  State<_ConsolidatedIndentAccordionCard> createState() =>
      _ConsolidatedIndentAccordionCardState();
}

class _ConsolidatedIndentAccordionCardState
    extends State<_ConsolidatedIndentAccordionCard> {
  bool _isExpanded = true;
  bool _isSubmitting = false;

  ConsolidatedIndentGroupModel get group => widget.indentGroup;

  Future<void> _approveWholeIndent(
      WidgetRef ref, {bool overrideMaxCapacity = false}) async {
    if (_isSubmitting) return;

    if (group.hasCapacityWarning && !overrideMaxCapacity) {
      final proceed = await _showGoAheadConfirmationDialog();
      if (proceed != true) return;
      return _approveWholeIndent(ref, overrideMaxCapacity: true);
    }

    setState(() => _isSubmitting = true);
    try {
      final res = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .approveWholeIndent(
            indentNumber: group.groupIndentNumber,
            remarks: overrideMaxCapacity
                ? 'Store Incharge Go Ahead Approval (Exceeds Max Capacity)'
                : 'Approved whole indent by Store Incharge',
            overrideMaxCapacity: overrideMaxCapacity,
          );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            content: Text(
              '✓ Indent ${group.groupIndentNumber} and all pending items have been approved! Indent is fully approved.',
            ),
          ),
        );
        widget.onRefreshRequested();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text('Error approving indent: $e'),
        ),
      );
    }
  }

  Future<void> _showRejectWholeIndentDialog(WidgetRef ref) async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFC62828),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Indent Requisition?',
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
              'Are you sure you want to reject indent requisition "${group.groupIndentNumber}" (${group.department})? All pending items will be marked as rejected.',
              style: const TextStyle(fontSize: 13, color: _ink700, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              cursorColor: _ink900,
              style: const TextStyle(
                color: _ink900,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection (optional)...',
                hintStyle: const TextStyle(fontSize: 12, color: _ink600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _ink900, width: 1.6),
                ),
              ),
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
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reject Indent', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      reasonController.dispose();
      setState(() => _isSubmitting = true);
      try {
        final res = await ref
            .read(stockRefillRequestControllerProvider.notifier)
            .rejectWholeIndent(
              indentNumber: group.groupIndentNumber,
              remarks: reason.isNotEmpty ? reason : 'Rejected by Store Approver',
            );
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              content: Text('✓ Indent ${group.groupIndentNumber} has been rejected.'),
            ),
          );
          widget.onRefreshRequested();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text('Error rejecting indent: $e'),
          ),
        );
      }
    } else {
      reasonController.dispose();
    }
  }

  Future<bool?> _showGoAheadConfirmationDialog() async {
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
              'One or more items in Indent requisition ${group.groupIndentNumber} reach or exceed the maximum warehouse capacity limit.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Requisition Details:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '• Indent: ${group.groupIndentNumber}\n• Dept: ${group.department} (${group.requestedBy})\n• Items to approve: ${group.pendingItemsCount}',
                    style: const TextStyle(fontSize: 12, color: _ink700, height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'As an authorized store incharge, you can give the go-ahead option to approve and continue with this indent anyway.',
              style: TextStyle(fontSize: 12, color: _ink600, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Go Ahead & Approve Indent',
                style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(userFindOneDataStreamProvider).value;
        final canApprove = user?.canIndentApprove ?? false;
        final canReject = user?.canIndentReject ?? false;
        final isNarrow = MediaQuery.of(context).size.width < 500;

        return Card(
          color: _surface,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: group.hasCapacityWarning
                  ? const Color(0xFFE65100).withValues(alpha: 0.6)
                  : _stroke,
              width: group.hasCapacityWarning ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Requisition Bar
              InkWell(
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(14),
                  bottom: Radius.circular(_isExpanded ? 0 : 14),
                ),
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: Indent ID, Auto-Refill badge, and expand arrow
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _ink900,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    group.groupIndentNumber,
                                    style: const TextStyle(
                                      color: _surface,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                                if (group.isAutoRefill)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEDE7F6),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFF673AB7)),
                                    ),
                                    child: const Text(
                                      'Night Auto-Refill',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF512DA8),
                                      ),
                                    ),
                                  ),
                                if (group.hasCapacityWarning)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3E0),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFE65100)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            size: 13,
                                            color: Color(0xFFE65100)),
                                        SizedBox(width: 4),
                                        Text(
                                          'Capacity Warning',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFE65100),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: _ink700,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Line 2: Dept, Requester, and Date
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.corporate_fare_rounded,
                                  size: 14, color: _ink600),
                              const SizedBox(width: 4),
                              Text(
                                '${group.department} • ${group.requestedBy}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink700,
                                ),
                              ),
                            ],
                          ),
                          if (group.createdAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 13, color: _ink600),
                                const SizedBox(width: 4),
                                Text(
                                  _formatDateTime(group.createdAt!),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: _ink600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Line 3: Progress chip & "Approve Indent" action button
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildProgressChip(),
                          if (!group.isFullyApproved && (canApprove || canReject))
                            Builder(
                              builder: (ctx) {
                                return Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (canReject)
                                      OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFFC62828),
                                        side: const BorderSide(color: Color(0xFFEF9A9A)),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isNarrow ? 10 : 12,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: _isSubmitting ? null : () => _showRejectWholeIndentDialog(ref),
                                      icon: const Icon(Icons.close_rounded, size: 15),
                                      label: Text(
                                        'Reject Indent',
                                        style: TextStyle(
                                          fontSize: isNarrow ? 11.5 : 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (canApprove)
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                        backgroundColor: _ink900,
                                        foregroundColor: _surface,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isNarrow ? 10 : 14,
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => _approveWholeIndent(ref),
                                      icon: _isSubmitting
                                          ? const SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: _surface),
                                            )
                                          : const Icon(Icons.done_all_rounded,
                                              size: 16),
                                      label: Text(
                                        'Approve Whole Indent',
                                        style: TextStyle(
                                          fontSize: isNarrow ? 11.5 : 12.5,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFF2E7D32)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_rounded,
                                      size: 14, color: Color(0xFF2E7D32)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Indent Fully Approved',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Expanded Item-Wise Breakdown
              if (_isExpanded) ...[
                const Divider(height: 1, color: _stroke),
                Container(
                  color: _surfaceAlt,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.list_alt_rounded,
                          size: 16, color: _ink700),
                      const SizedBox(width: 6),
                      Text(
                        'Requisition Items (${group.items.length})',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Total Qty: ${group.totalRequestedQty}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: group.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, itemIdx) {
                    final item = group.items[itemIdx];
                    return _ConsolidatedIndentItemRow(
                      key: ValueKey(item.id),
                      item: item,
                      groupKey: group.groupIndentNumber,
                      onItemApproved: () => widget.onRefreshRequested(),
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildProgressChip() {
    if (group.isFullyApproved) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'All ${group.totalItems} Items Approved',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2E7D32),
          ),
        ),
      );
    }

    if (group.approvedItemsCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFB74D)),
        ),
        child: Text(
          '${group.approvedItemsCount}/${group.totalItems} Items Approved',
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE65100),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8EF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _stroke),
      ),
      child: Text(
        'Pending Store Approval (${group.totalItems} Items)',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: _ink700,
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = local.day.toString().padLeft(2, '0');
    final month = months[local.month - 1];
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute';
  }
}

/// ============================================================================
/// INDENT ITEM ROW (Detailed View for each item within an indent)
/// Shows authoritative stock data, buffer status, editable approved quantity,
/// and individual "Approve Item" button with capacity check.
/// ============================================================================
class _ConsolidatedIndentItemRow extends ConsumerStatefulWidget {
  final ConsolidatedIndentItemModel item;
  final String groupKey;
  final VoidCallback onItemApproved;

  const _ConsolidatedIndentItemRow({
    super.key,
    required this.item,
    required this.groupKey,
    required this.onItemApproved,
  });

  @override
  ConsumerState<_ConsolidatedIndentItemRow> createState() =>
      _ConsolidatedIndentItemRowState();
}

class _ConsolidatedIndentItemRowState
    extends ConsumerState<_ConsolidatedIndentItemRow> {
  late TextEditingController _qtyController;
  late num _approvedQty;
  bool _isApproving = false;

  ConsolidatedIndentItemModel get item => widget.item;

  @override
  void initState() {
    super.initState();
    _approvedQty = item.indentQty > 0 ? item.indentQty : item.requestedQty;
    _qtyController = TextEditingController(text: _approvedQty.toString());
  }

  @override
  void dispose() {
    _qtyController.dispose();
    super.dispose();
  }

  bool get _exceedsMax {
    if (item.maxCapacity <= 0) return false;
    return (item.currentStock + _approvedQty) > item.maxCapacity;
  }

  bool get _exceedsBuffer {
    if (item.maxCapacity <= 0) return false;
    final buffer = item.maxAllowedBuffer;
    return (item.currentStock + _approvedQty) > buffer;
  }

  void _applyMaintainMaxCap() {
    if (item.maxCapacity <= 0) return;
    final allowed = (item.maxCapacity - item.currentStock).clamp(0, item.requestedQty);
    setState(() {
      _approvedQty = allowed;
      _qtyController.text = allowed.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Approved quantity adjusted to $allowed ${item.unit} to maintain warehouse maximum capacity (${item.maxCapacity}).',
        ),
      ),
    );
  }

  Future<void> _approveItem({bool overrideMaxCapacity = false}) async {
    if (_isApproving) return;

    if (_approvedQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('Approved quantity must be greater than zero.'),
        ),
      );
      return;
    }

    if (_exceedsBuffer && !overrideMaxCapacity) {
      final proceed = await _showItemGoAheadDialog();
      if (proceed != true) return;
      return _approveItem(overrideMaxCapacity: true);
    }

    setState(() => _isApproving = true);

    try {
      final res = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .approveIndentItem(
            id: item.id,
            approvedQty: _approvedQty,
            remarks: overrideMaxCapacity
                ? 'Store Incharge Go Ahead Approval (Exceeds Max Capacity)'
                : 'Approved by Store Incharge',
            overrideMaxCapacity: overrideMaxCapacity,
          );

      if (!mounted) return;
      setState(() => _isApproving = false);

      if (res != null) {
        final isAllApproved = res['indentFullyApproved'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            content: Text(
              isAllApproved
                  ? '🎉 All items in Indent ${widget.groupKey} are now approved! Indent is automatically fully approved.'
                  : '✓ Item "${item.itemName}" approved ($_approvedQty ${item.unit}).',
            ),
          ),
        );
        widget.onItemApproved();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApproving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text('Error approving item: $e'),
        ),
      );
    }
  }

  Future<void> _showRejectItemDialog() async {
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Color(0xFFC62828),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Reject Indent Item?',
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
              'Reject item "${item.itemName}" (${item.requestedQty} ${item.unit}) from Indent ${widget.groupKey}?',
              style: const TextStyle(fontSize: 13, color: _ink700, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              cursorColor: _ink900,
              style: const TextStyle(
                color: _ink900,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'Enter reason for rejection (optional)...',
                hintStyle: const TextStyle(fontSize: 12, color: _ink600),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: _ink900, width: 1.6),
                ),
              ),
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
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reject Item', style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final reason = reasonController.text.trim();
      reasonController.dispose();
      setState(() => _isApproving = true);
      try {
        final res = await ref
            .read(stockRefillRequestControllerProvider.notifier)
            .rejectIndentItem(
              id: item.id,
              remarks: reason.isNotEmpty ? reason : 'Rejected by Store Approver',
            );
        if (!mounted) return;
        setState(() => _isApproving = false);
        if (res != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFFC62828),
              behavior: SnackBarBehavior.floating,
              content: Text('✓ Item "${item.itemName}" has been rejected.'),
            ),
          );
          widget.onItemApproved();
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isApproving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text('Error rejecting item: $e'),
          ),
        );
      }
    } else {
      reasonController.dispose();
    }
  }

  Future<bool?> _showItemGoAheadDialog() async {
    final totalProjected = item.currentStock + _approvedQty;
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
              'Approving $_approvedQty ${item.unit} for "${item.itemName}" exceeds the warehouse maximum capacity limit:',
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
                  _dialogStatRow('Approving Qty:', '$_approvedQty ${item.unit}'),
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
              'Authorize Go Ahead to proceed with over-capacity approval for this item.',
              style: TextStyle(fontSize: 12, color: _ink600, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Go Ahead & Approve',
                style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  static Widget _dialogStatRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: _ink700,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                color: color ?? _ink900,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final canApprove = user?.canIndentApprove ?? false;
    final canReject = user?.canIndentReject ?? false;
    final isApproved = item.isApproved;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isApproved
              ? const Color(0xFF2E7D32).withValues(alpha: 0.3)
              : _exceedsBuffer
                  ? const Color(0xFFE65100).withValues(alpha: 0.5)
                  : _stroke,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Item Code, Name, Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName.isNotEmpty
                          ? item.itemName
                          : 'Item: ${item.itemCode}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _ink900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (item.itemCode.isNotEmpty)
                          Text(
                            item.itemCode,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _ink600,
                              fontFamily: 'monospace',
                            ),
                          ),
                        Text(
                          '• Unit: ${item.unit}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _ink600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isApproved)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2E7D32)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 13, color: Color(0xFF2E7D32)),
                      SizedBox(width: 4),
                      Text(
                        'APPROVED',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE65100),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Authoritative Warehouse Stock Metrics
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _metricChip(
                icon: Icons.warehouse_rounded,
                label: 'Current Stock',
                value: '${item.currentStock} ${item.unit}',
                color: _ink900,
                bg: const Color(0xFFFAF8EF),
              ),
              _metricChip(
                icon: Icons.speed_rounded,
                label: 'Max Capacity',
                value: item.maxCapacity > 0
                    ? '${item.maxCapacity} ${item.unit}'
                    : 'No Limit',
                color: item.maxCapacity > 0 ? _ink700 : _ink600,
                bg: const Color(0xFFFAF8EF),
              ),
              if (_exceedsBuffer)
                _metricChip(
                  icon: Icons.error_rounded,
                  label: 'Buffer Limit Exceeded',
                  value: '> ${item.maxAllowedBuffer} ${item.unit}',
                  color: const Color(0xFFC62828),
                  bg: const Color(0xFFFFEBEE),
                )
              else if (_exceedsMax)
                _metricChip(
                  icon: Icons.warning_amber_rounded,
                  label: 'Over Max Capacity',
                  value: '${(item.currentStock + _approvedQty)} / ${item.maxCapacity}',
                  color: const Color(0xFFE65100),
                  bg: const Color(0xFFFFF3E0),
                )
              else
                _metricChip(
                  icon: Icons.check_circle_rounded,
                  label: 'Capacity Status',
                  value: 'Within Limits',
                  color: const Color(0xFF2E7D32),
                  bg: const Color(0xFFE8F5E9),
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Quantity Row: Requested vs Approved + Action Button
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _stroke),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Requested: ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink600,
                      ),
                    ),
                    Text(
                      '${item.requestedQty} ${item.unit}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _ink900,
                      ),
                    ),
                  ],
                ),

                if (!isApproved) ...[
                  if (canApprove)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Approved Qty: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _ink900,
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 18, color: _ink700),
                        onPressed: _approvedQty > 1
                            ? () {
                                setState(() {
                                  _approvedQty -= 1;
                                  _qtyController.text = _approvedQty.toString();
                                });
                              }
                            : null,
                      ),
                      SizedBox(
                        width: 52,
                        height: 32,
                        child: TextField(
                          controller: _qtyController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _ink900,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 6),
                            filled: true,
                            fillColor: _surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(6),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                          ),
                          onChanged: (val) {
                            final n = num.tryParse(val);
                            if (n != null && n > 0) {
                              setState(() => _approvedQty = n);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: const Icon(Icons.add_circle_outline,
                            size: 18, color: _ink700),
                        onPressed: () {
                          setState(() {
                            _approvedQty += 1;
                            _qtyController.text = _approvedQty.toString();
                          });
                        },
                      ),
                      Text(
                        item.unit,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: _ink700,
                        ),
                      ),
                    ],
                  ),

                  // Item Actions: Reject & Approve
                  if (canApprove || canReject)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (canReject)
                          OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFEF9A9A)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isApproving ? null : () => _showRejectItemDialog(),
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: const Text(
                          'Reject',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                        if (canApprove)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _ink900,
                              foregroundColor: _surface,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 0,
                            ),
                            onPressed: _isApproving ? null : () => _approveItem(),
                            icon: _isApproving
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: _surface),
                                  )
                                : const Icon(Icons.check_rounded, size: 15),
                            label: const Text(
                              'Approve Item',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: const Text(
                        'Pending Approval',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _ink600,
                        ),
                      ),
                    ),
                ] else ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Approved: ',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _ink600,
                        ),
                      ),
                      Text(
                        '${item.indentQty} ${item.unit}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                      if (item.storeApprovedBy.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          'by ${item.storeApprovedBy}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _ink600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Suggest Max Qty Button (if over capacity)
          if (!isApproved && item.isAutoRefill && _exceedsMax) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: _applyMaintainMaxCap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_fix_high_rounded,
                        size: 13, color: Color(0xFFE65100)),
                    const SizedBox(width: 4),
                    Text(
                      'Maintain Max Warehouse Limit (Cap to ${item.maxCapacity - item.currentStock} ${item.unit})',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Reason / Purpose if present
          if (item.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${item.reason}',
              style: const TextStyle(
                fontSize: 11.5,
                color: _ink600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
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
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// ITEM-WISE ACCORDION CARD (Alternate Aggregated View)
/// Displays indents grouped across departments by Item master.
/// ============================================================================
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


  bool get _exceedsBuffer {
    final maxCap = widget.itemData.maxCapacity;
    if (maxCap <= 0) return false;
    final buffer = widget.itemData.maxAllowedBuffer;
    final totalProjected = widget.itemData.currentStock + _totalSelectedQty;
    return totalProjected > buffer;
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
            child: const Text('Cancel',
                style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
            label: const Text('Go Ahead & Approve',
                style: TextStyle(fontWeight: FontWeight.w800)),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
  }

  static Widget _dialogStatRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: _ink700,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        Text(value,
            style: TextStyle(
                fontSize: 12,
                color: color ?? _ink900,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final canApprove = user?.canIndentApprove ?? false;
    final item = widget.itemData;
    final isNarrow = MediaQuery.of(context).size.width < 500;

    return Card(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: _exceedsBuffer
              ? const Color(0xFFE65100).withValues(alpha: 0.6)
              : _stroke,
          width: _exceedsBuffer ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          InkWell(
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(14),
              bottom: Radius.circular(_isExpanded ? 0 : 14),
            ),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.itemName.isNotEmpty
                                  ? item.itemName
                                  : 'Item: ${item.itemCode}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.itemCode.isNotEmpty
                                  ? 'Code: ${item.itemCode} • Unit: ${item.unit}'
                                  : 'Unit: ${item.unit}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: _ink600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: _ink700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stock metrics
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _metricChip(
                        icon: Icons.inventory_2_outlined,
                        label: 'Current Stock',
                        value: '${item.currentStock} ${item.unit}',
                        color: _ink900,
                        bg: const Color(0xFFFAF8EF),
                      ),
                      _metricChip(
                        icon: Icons.speed_rounded,
                        label: 'Max Capacity',
                        value: item.maxCapacity > 0
                            ? '${item.maxCapacity} ${item.unit}'
                            : 'No Limit',
                        color: item.maxCapacity > 0 ? _ink700 : _ink600,
                        bg: const Color(0xFFFAF8EF),
                      ),
                      _metricChip(
                        icon: Icons.pending_actions_rounded,
                        label: 'Total Indented',
                        value: '${item.totalIndentQty} ${item.unit}',
                        color: const Color(0xFFE65100),
                        bg: const Color(0xFFFFF3E0),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: _stroke),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Department Requisitions for this item:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: _ink900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...item.indents.map((ind) {
                    final isChecked = _selectedIndentIds.contains(ind.id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          setState(() {
                            if (isChecked) {
                              _selectedIndentIds.remove(ind.id);
                            } else {
                              _selectedIndentIds.add(ind.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isChecked ? const Color(0xFFF7F5F0) : _surfaceAlt,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isChecked ? _ink900.withValues(alpha: 0.6) : _stroke,
                              width: isChecked ? 1.2 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: isChecked,
                                activeColor: _ink900,
                                checkColor: Colors.white,
                                side: const BorderSide(color: Color(0xFF757575), width: 1.8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
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
                              const SizedBox(width: 4),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ind.indentNumber,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: _ink900,
                                      ),
                                    ),
                                    Text(
                                      '${ind.costCenter ?? ind.company ?? "Requisition"} • ${ind.requestedBy}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _ink600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${ind.indentQty} ${ind.unitOfMeasure}',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 10),

                  // Bottom action row
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Total Selected: $_totalSelectedQty ${item.unit}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                      if (canApprove)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: _surface,
                            padding: EdgeInsets.symmetric(
                              horizontal: isNarrow ? 12 : 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () => _submitStoreApproval(),
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _surface),
                              )
                            : const Icon(Icons.check_circle_outline_rounded,
                                size: 16),
                        label: Text(
                          'Approve Selected (${_selectedIndentIds.length})',
                          style: TextStyle(
                            fontSize: isNarrow ? 11.5 : 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
