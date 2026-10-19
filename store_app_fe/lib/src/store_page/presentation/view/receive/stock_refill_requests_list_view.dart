import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_receive_controller.dart';
import '../../../domains/models/stock_refill_request_model.dart';
import '../../widgets/store_ui_state_widgets.dart';
import '../indent/indent_lifecycle_timeline_sheet.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/store_grn_controller.dart';
import '../indent/grn_cart_sheet.dart';
import '../indent/grn_detail_approval_sheet.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

typedef IndentRequestsListView = StockRefillRequestsListView;

class StockRefillRequestsListView extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  final bool isSubmittedIndentsSection;

  const StockRefillRequestsListView({
    super.key,
    this.initialStatusFilter,
    this.isSubmittedIndentsSection = false,
  });

  @override
  ConsumerState<StockRefillRequestsListView> createState() =>
      _StockRefillRequestsListViewState();
}

class _StockRefillRequestsListViewState
    extends ConsumerState<StockRefillRequestsListView> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _sourceFilter = 'ALL'; // 'ALL' | 'AUTO' | 'REQUESTER'
  bool _isExecutingEod = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(refillRequestFilterStatusProvider.notifier).state =
            widget.initialStatusFilter!;
      });
    }
  }

  Future<void> _triggerEodScheduler() async {
    if (_isExecutingEod) return;
    setState(() => _isExecutingEod = true);

    try {
      final res = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .triggerEodScheduler();

      if (!mounted) return;

      if (res != null) {
        final count = (res['data'] is Map ? res['data']['eligibleItemCount'] : null) ?? 0;
        final groupNum = (res['data'] is Map ? res['data']['groupIndentNumber'] : null)?.toString() ?? '';

        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _stroke),
            ),
            title: const Row(
              children: [
                Icon(Icons.nightlight_round, color: Color(0xFF512DA8), size: 24),
                SizedBox(width: 8),
                Text(
                  'End-of-Day Auto-Indent',
                  style: TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            content: Text(
              count > 0
                  ? 'Consolidated indent #$groupNum created with $count item(s) and submitted to approval workflow.'
                  : 'All products currently have stock above their minimum threshold. No auto-indents needed today.',
              style: const TextStyle(color: _ink700, fontSize: 13.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to trigger End-of-Day scheduler.'),
            backgroundColor: Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExecutingEod = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d/$m/$y $hh:$mm';
  }

  Future<void> _showEditQtyDialog(StockRefillRequestModel req) async {
    final qtyController = TextEditingController(
      text: req.indentQty > 0 ? req.indentQty.toString() : '1',
    );
    final reasonController = TextEditingController(text: req.reason);
    bool isSubmitting = false;
    final isPending = req.isPending;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: _stroke),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPending
                          ? const Color(0xFFFFF3E0)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPending
                          ? Icons.edit_note_rounded
                          : Icons.add_shopping_cart_rounded,
                      color: isPending
                          ? const Color(0xFFE65100)
                          : const Color(0xFF1565C0),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isPending
                          ? 'Edit Indent Quantity'
                          : 'Amend Approved Indent',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _ink900,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPending
                          ? 'Change requested quantity for ${req.itemDescription} (${req.indentNumber.isNotEmpty ? req.indentNumber : req.requestNo}).'
                          : 'This indent is approved and awaiting receipt. Increasing quantity will submit an amendment for approver re-approval.',
                      style: const TextStyle(
                        color: _ink700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Balance Stock (at request):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink600,
                            ),
                          ),
                          Text(
                            'Avail: ${req.balanceQty}  |  Total: ${req.currentTotalQty}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ink900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Requested Quantity *',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: () {
                            final current = num.tryParse(qtyController.text) ?? 1;
                            if (current > 1) {
                              setDialogState(() {
                                qtyController.text = (current - 1).toString();
                              });
                            }
                          },
                          icon: const Icon(Icons.remove_rounded, size: 18, color: _ink900),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F2ED),
                            foregroundColor: _ink900,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink900,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            cursorColor: _ink900,
                            decoration: InputDecoration(
                              suffixText: req.unitOfMeasure,
                              filled: true,
                              fillColor: _surfaceAlt.withValues(alpha: 0.3),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _stroke),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            final current = num.tryParse(qtyController.text) ?? 0;
                            setDialogState(() {
                              qtyController.text = (current + 1).toString();
                            });
                          },
                          icon: const Icon(Icons.add_rounded, size: 18, color: _ink900),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F2ED),
                            foregroundColor: _ink900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Reason / Remarks (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      style: const TextStyle(
                        color: _ink900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: _ink900,
                      decoration: InputDecoration(
                        hintText: 'e.g. Adjusted refill quantity based on current consumption',
                        hintStyle: TextStyle(
                          color: _ink600.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                        filled: true,
                        fillColor: _surfaceAlt.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.all(12),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _stroke),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _ink900, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel', style: TextStyle(color: _ink600)),
                ),
                ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final newQty = num.tryParse(qtyController.text.trim());
                          if (newQty == null || newQty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a valid quantity greater than 0'),
                                backgroundColor: Color(0xFFC62828),
                              ),
                            );
                            return;
                          }

                          setDialogState(() {
                            isSubmitting = true;
                          });

                          final res = await ref
                              .read(stockRefillRequestControllerProvider.notifier)
                              .updateIndentQuantity(
                                id: req.id,
                                indentQty: newQty,
                                reason: reasonController.text.trim(),
                              );

                          if (!mounted || !dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);

                          if (res != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPending
                                      ? 'Indent quantity updated to $newQty ${req.unitOfMeasure}'
                                      : 'Quantity amended to $newQty ${req.unitOfMeasure}. Moved to Approver review.',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                          } else {
                            final err = ref.read(stockRefillRequestControllerProvider).error?.toString() ??
                                'Failed to update quantity';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(err),
                                backgroundColor: const Color(0xFFC62828),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPending
                        ? const Color(0xFFE65100)
                        : const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: Text(
                    isSubmitting
                        ? 'Updating...'
                        : (isPending ? 'Save Quantity' : 'Request Amendment'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showGrnListModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final grnAsync = ref.watch(storeGrnListProvider);
            final mediaQuery = MediaQuery.of(context);
            return Container(
              constraints: BoxConstraints(
                maxHeight: mediaQuery.size.height * 0.85,
              ),
              decoration: const BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Goods Receipt Notes (GRN)',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: _ink900),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: _stroke),
                  Expanded(
                    child: grnAsync.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (err, _) =>
                          Center(child: Text('Error loading GRNs: $err')),
                      data: (grnList) {
                        if (grnList.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No GRN records found. Add approved indents to GRN Cart to submit one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _ink600),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: grnList.length,
                          itemBuilder: (ctx, idx) {
                            final g = grnList[idx];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              color: _surfaceAlt,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: const BorderSide(color: _stroke),
                              ),
                              child: ListTile(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  showGrnDetailApprovalSheet(context, grn: g);
                                },
                                title: Row(
                                  children: [
                                    Text(
                                      g.grnNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: g.status == 'APPROVED'
                                            ? Colors.green.shade50
                                            : (g.status == 'REJECTED'
                                                ? Colors.red.shade50
                                                : Colors.orange.shade50),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        g.status.replaceAll('_', ' '),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: g.status == 'APPROVED'
                                              ? Colors.green.shade800
                                              : (g.status == 'REJECTED'
                                                  ? Colors.red.shade800
                                                  : Colors.orange.shade900),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${g.items.length} items • Total: ₹${g.totalValue.toStringAsFixed(2)} • By ${g.submittedByName}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: _ink600,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: _ink700),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showApprovalDialog(
    StockRefillRequestModel req,
    bool isApprove,
  ) async {
    final remarksController = TextEditingController();
    final actionName = isApprove ? 'Approve' : 'Reject';
    final actionColor =
        isApprove ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    bool directStockIn = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: _stroke),
              ),
              title: Row(
                children: [
                  Icon(
                    isApprove
                        ? Icons.check_circle_outline_rounded
                        : Icons.cancel_outlined,
                    color: actionColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$actionName Indent Request',
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to $actionName the indent request for ${req.itemDescription} (${req.indentNumber.isNotEmpty ? req.indentNumber : req.requestNo})?',
                      style: const TextStyle(
                        color: _ink700,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Indent Quantity:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink600,
                                ),
                              ),
                              Text(
                                '+${req.indentQty} ${req.unitOfMeasure}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: actionColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Balance Stock (at request):',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ink600,
                                ),
                              ),
                              Text(
                                'Avail: ${req.balanceQty} / Total: ${req.currentTotalQty}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isApprove) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: directStockIn
                              ? const Color(0xFFE8F5E9)
                              : const Color(0xFFFAF8EF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: directStockIn
                                ? const Color(0xFFA5D6A7)
                                : _stroke,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              directStockIn
                                  ? Icons.inventory_2_rounded
                                  : Icons.pending_actions_rounded,
                              color: directStockIn
                                  ? const Color(0xFF2E7D32)
                                  : _ink600,
                              size: 22,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Credit stock immediately into inventory',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                      color: directStockIn
                                          ? const Color(0xFF1B5E20)
                                          : _ink900,
                                    ),
                                  ),
                                  Text(
                                    directStockIn
                                        ? 'Adds +${req.indentQty} ${req.unitOfMeasure} directly to available count now'
                                        : 'Standard Flow: Approve for Purchasing (Stock received physically later via Receiving)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: directStockIn
                                          ? const Color(0xFF2E7D32)
                                          : _ink600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: directStockIn,
                              activeTrackColor: const Color(0xFF2E7D32),
                              onChanged: (val) {
                                setDialogState(() {
                                  directStockIn = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Text(
                      'Review Remarks (Optional)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ink700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: remarksController,
                      maxLines: 2,
                      style: const TextStyle(
                        color: _ink900,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                      ),
                      cursorColor: _ink900,
                      decoration: InputDecoration(
                        hintText: isApprove
                            ? (directStockIn
                                ? 'e.g. Received shipment and approved stock refill'
                                : 'e.g. Approved for purchasing / procurement')
                            : 'e.g. Alternative stock already allocated',
                        hintStyle: const TextStyle(
                          color: _ink600,
                          fontSize: 13,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFFAF8F0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _stroke),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel', style: TextStyle(color: _ink600)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: actionColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    isApprove
                        ? (directStockIn
                            ? 'Approve & Instant Credit'
                            : 'Approve (Send to Purchase)')
                        : actionName,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      final notifier =
          ref.read(stockRefillRequestControllerProvider.notifier);
      final ok = isApprove
          ? await notifier.approveRequest(
              req.id,
              reviewRemarks: remarksController.text,
              directStockIn: directStockIn,
            )
          : await notifier.rejectRequest(
              req.id,
              reviewRemarks: remarksController.text,
            );

      if (!mounted) return;
      final indentNum = req.indentNumber.isNotEmpty
          ? req.indentNumber
          : req.requestNo;
      if (ok) {
        if (directStockIn) {
          ref.invalidate(itemFindOneStreamProvider(req.itemId));
          ref.invalidate(itemPagedStreamProvider);
          ref.invalidate(findAllReceiveDataStreamProvider);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: actionColor,
            content: Text(
              isApprove
                  ? (directStockIn
                      ? 'Indent $indentNum approved & stock credited (+${req.indentQty} ${req.unitOfMeasure}) successfully!'
                      : 'Indent $indentNum approved successfully (awaiting physical receipt).')
                  : 'Indent $indentNum rejected successfully.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text('Failed to $actionName indent request.'),
          ),
        );
      }
    }
  }

  Future<void> _showCreditStockDialog(StockRefillRequestModel req) async {
    final remarksController = TextEditingController();
    final qtyController = TextEditingController(
      text: '${req.indentQty > 0 ? req.indentQty : 1}',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: _stroke),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: Color(0xFF2E7D32),
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Receive Stock into Inventory',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Directly credit physical inventory for ${req.itemDescription} (${req.indentNumber.isNotEmpty ? req.indentNumber : req.requestNo}).',
                  style: const TextStyle(
                    color: _ink700,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Approved Quantity:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1B5E20),
                            ),
                          ),
                          Text(
                            '+${req.indentQty} ${req.unitOfMeasure}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Current Available Stock:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _ink600,
                            ),
                          ),
                          Text(
                            '${req.balanceQty} ${req.unitOfMeasure}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ink900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Quantity to Receive',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: qtyController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFFAF8F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Remarks (Optional)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _ink700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: remarksController,
                  maxLines: 2,
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Physical stock placed into warehouse rack',
                    hintStyle: const TextStyle(
                      color: _ink600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAF8F0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(color: _ink600)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Confirm & Credit Stock',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final qty = num.tryParse(qtyController.text.trim()) ?? req.indentQty;
      final ok = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .creditStock(
            req.id,
            creditQty: qty,
            reviewRemarks: remarksController.text.trim(),
          );

      if (!mounted) return;
      if (ok) {
        ref.invalidate(itemFindOneStreamProvider(req.itemId));
        ref.invalidate(itemPagedStreamProvider);
        ref.invalidate(findAllReceiveDataStreamProvider);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(
              'Stock credited successfully! Added +$qty ${req.unitOfMeasure} for ${req.itemDescription}. Available count updated.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFC62828),
            content: Text('Failed to credit stock for indent.'),
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteRequest(StockRefillRequestModel req) async {
    final indentLabel =
        req.indentNumber.isNotEmpty ? req.indentNumber : req.requestNo;
    final itemLabel =
        req.itemName.isNotEmpty ? req.itemName : req.itemDescription;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _stroke),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFC62828),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Delete Indent Request',
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
                'Are you sure you want to permanently delete $indentLabel for "$itemLabel"?',
                style: const TextStyle(
                  color: _ink700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFE65100), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will permanently remove this requisition (${req.indentQty} ${req.unitOfMeasure}). This action cannot be undone.',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Cancel', style: TextStyle(color: _ink600)),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogCtx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC62828),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
              ),
              icon: const Icon(Icons.delete_rounded, size: 16, color: Colors.white),
              label: const Text(
                'Delete Permanently',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final ok = await ref
        .read(stockRefillRequestControllerProvider.notifier)
        .deleteRequest(req.id);

    if (!mounted) return;

    if (ok) {
      ref.read(grnCartProvider.notifier).removeIndent(req.id);
      ref.invalidate(itemFindOneStreamProvider(req.itemId));
      ref.invalidate(itemPagedStreamProvider);
      ref.invalidate(uncreditedApprovedIndentsProvider(req.itemId));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2E7D32),
          content: Text('$indentLabel deleted successfully'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('Failed to delete indent request'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStatus = ref.watch(refillRequestFilterStatusProvider);
    final requestsAsync = ref.watch(refillRequestsListProvider);

    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isApprovalEnabled =
        ref.watch(storeCartConfigProvider).indentApprovalRequired;
    final canApprove = user?.isSuperAdmin == true ||
        (user?.appWorks.contains('storrefillapprove') ?? false) ||
        (user?.appWorks.contains('storreceiveapprove') ?? false) ||
        (user?.appWorks.contains('storissueapprove') ?? false) ||
        (user?.appWorks.contains('storeadmin') ?? false);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      children: [
        // Search & Filter header
        Card(
          color: _surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _stroke),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Search row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (v) {
                          ref.read(refillRequestSearchProvider.notifier).state =
                              v.trim();
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search indents by number, item, reason...',
                          prefixIcon: Icon(Icons.search_rounded, size: 20),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        style: const TextStyle(color: _ink900, fontSize: 13.5),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      icon: const Icon(Icons.refresh_rounded, color: _ink900),
                      onPressed: () {
                        ref.invalidate(refillRequestsListProvider);
                        ref.invalidate(pendingRefillRequestsCountProvider);
                      },
                    ),
                    if (!isMobile) ...[
                      if (canApprove) ...[
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF512DA8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: _isExecutingEod ? null : _triggerEodScheduler,
                          icon: _isExecutingEod
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.nightlight_round, size: 15, color: Colors.white),
                          label: const Text(
                            'Run EOD Scheduler',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      if (ref.watch(storeCartConfigProvider).grnWorkflowEnabled) ...[
                        const SizedBox(width: 4),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => showGrnCartSheet(context),
                          icon: const Icon(Icons.assignment_turned_in_outlined, size: 15, color: Colors.white),
                          label: Text(
                            'GRN Cart (${ref.watch(grnCartProvider).length})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            iconColor: const Color(0xFF1565C0),
                            side: const BorderSide(color: Color(0xFF90CAF9)),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showGrnListModal(context),
                          icon: const Icon(Icons.receipt_long_outlined, size: 15, color: Color(0xFF1565C0)),
                          label: const Text(
                            'GRN Notes',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
                if (isMobile && (canApprove || ref.watch(storeCartConfigProvider).grnWorkflowEnabled)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (canApprove)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF512DA8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: _isExecutingEod ? null : _triggerEodScheduler,
                          icon: _isExecutingEod
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.nightlight_round, size: 15, color: Colors.white),
                          label: const Text(
                            'Run EOD Scheduler',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (ref.watch(storeCartConfigProvider).grnWorkflowEnabled) ...[
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: 0,
                          ),
                          onPressed: () => showGrnCartSheet(context),
                          icon: const Icon(Icons.assignment_turned_in_outlined, size: 15, color: Colors.white),
                          label: Text(
                            'GRN Cart (${ref.watch(grnCartProvider).length})',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1565C0),
                            iconColor: const Color(0xFF1565C0),
                            side: const BorderSide(color: Color(0xFF90CAF9)),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () => _showGrnListModal(context),
                          icon: const Icon(Icons.receipt_long_outlined, size: 15, color: Color(0xFF1565C0)),
                          label: const Text(
                            'GRN Notes',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                const Divider(height: 12, color: _stroke),
                // Status Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'All Statuses', currentStatus),
                      const SizedBox(width: 8),
                      if (widget.isSubmittedIndentsSection || !isApprovalEnabled) ...[
                        _buildFilterChip('PENDING', 'Pending', currentStatus),
                        const SizedBox(width: 8),
                      ],
                      _buildFilterChip('APPROVED', 'Approved', currentStatus),
                      const SizedBox(width: 8),
                      _buildFilterChip('REJECTED', 'Rejected', currentStatus),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Source Filter Chips: Auto Refill vs Requester Indents
                requestsAsync.maybeWhen(
                  data: (allReqs) {
                    final autoCount =
                        allReqs.where((r) => r.isAutoRefill).length;
                    final reqCount =
                        allReqs.where((r) => r.isRequesterIndent).length;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildSourceChip(
                            'ALL',
                            'All Sources (${allReqs.length})',
                          ),
                          const SizedBox(width: 8),
                          _buildSourceChip(
                            'AUTO',
                            '🤖 Auto Refill ($autoCount)',
                          ),
                          const SizedBox(width: 8),
                          _buildSourceChip(
                            'REQUESTER',
                            '👤 Requester Indents ($reqCount)',
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Requests List
        Expanded(
          child: requestsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => StoreErrorView(
              error: err,
              onRetry: () => ref.invalidate(refillRequestsListProvider),
            ),
            data: (requests) {
              final filteredRequests = requests.where((r) {
                if (!widget.isSubmittedIndentsSection &&
                    isApprovalEnabled &&
                    r.status == 'PENDING') {
                  return false;
                }
                if (_sourceFilter == 'AUTO') return r.isAutoRefill;
                if (_sourceFilter == 'REQUESTER') return r.isRequesterIndent;
                return true;
              }).toList();

              if (filteredRequests.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(refillRequestsListProvider);
                    ref.invalidate(pendingRefillRequestsCountProvider);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: _ink600,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _sourceFilter == 'ALL'
                                  ? 'No indent requests found'
                                  : (_sourceFilter == 'AUTO'
                                      ? 'No automated refill requests found'
                                      : 'No requester indent requisitions found'),
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(refillRequestsListProvider);
                  ref.invalidate(pendingRefillRequestsCountProvider);
                },
                child: Scrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  interactive: true,
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filteredRequests.length,
                    itemBuilder: (context, idx) {
                      final req = filteredRequests[idx];
                      return _buildRequestCard(context, req, canApprove);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label, String current) {
    final isSelected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(refillRequestFilterStatusProvider.notifier).state = value;
      },
      selectedColor: _ink900,
      backgroundColor: _surfaceAlt.withValues(alpha: 0.5),
      labelStyle: TextStyle(
        color: isSelected ? _surface : _ink900,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      side: const BorderSide(color: _stroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildSourceChip(String value, String label) {
    final isSelected = _sourceFilter == value;
    Color activeColor;
    if (value == 'AUTO') {
      activeColor = const Color(0xFF5E35B1);
    } else if (value == 'REQUESTER') {
      activeColor = const Color(0xFF1565C0);
    } else {
      activeColor = _ink900;
    }

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        setState(() {
          _sourceFilter = value;
        });
      },
      selectedColor: activeColor,
      backgroundColor: _surfaceAlt.withValues(alpha: 0.5),
      labelStyle: TextStyle(
        color: isSelected ? _surface : _ink900,
        fontWeight: FontWeight.w700,
        fontSize: 11.5,
      ),
      side: BorderSide(color: isSelected ? activeColor : _stroke),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    StockRefillRequestModel req,
    bool canApprove,
  ) {
    Color statusBg;
    Color statusFg;
    IconData statusIcon;

    if (req.isApproved) {
      statusBg = const Color(0xFFE8F5E9);
      statusFg = const Color(0xFF2E7D32);
      statusIcon = Icons.check_circle_rounded;
    } else if (req.isRejected) {
      statusBg = const Color(0xFFFFEBEE);
      statusFg = const Color(0xFFC62828);
      statusIcon = Icons.cancel_rounded;
    } else {
      statusBg = const Color(0xFFFFF3E0);
      statusFg = const Color(0xFFE65100);
      statusIcon = Icons.hourglass_top_rounded;
    }

    final indentNum = req.indentNumber.isNotEmpty
        ? req.indentNumber
        : req.requestNo;

    return Card(
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _stroke),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Indent Number + Source Tag + Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.receipt_long_outlined,
                            size: 16,
                            color: _ink700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            indentNum,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      // Origin badge: Auto Refill vs Demand Shortage vs Store Refill
                      if (req.isAutoRefill)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEDE7F6),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD1C4E9)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.smart_toy_rounded,
                                size: 11,
                                color: Color(0xFF5E35B1),
                              ),
                              SizedBox(width: 3.5),
                              Text(
                                'AUTO REFILL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF5E35B1),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (req.isIssueShortage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFCC80)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                size: 11,
                                color: Color(0xFFE65100),
                              ),
                              SizedBox(width: 3.5),
                              Text(
                                'DEMAND SHORTAGE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFE65100),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFBBDEFB)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.storefront_rounded,
                                size: 11,
                                color: Color(0xFF1565C0),
                              ),
                              SizedBox(width: 3.5),
                              Text(
                                'STORE REFILL',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1565C0),
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (req.groupIndentNumber != null &&
                          req.groupIndentNumber!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: req.isAutoRefill
                                ? const Color(0xFFF3E5F5)
                                : const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: req.isAutoRefill
                                  ? const Color(0xFFCE93D8)
                                  : const Color(0xFFFFE082),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (req.isAutoRefill) ...[
                                const Icon(Icons.nightlight_round, size: 10, color: Color(0xFF7B1FA2)),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                req.isAutoRefill
                                    ? 'EOD Batch: ${req.groupIndentNumber}'
                                    : 'Group: ${req.groupIndentNumber}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: req.isAutoRefill
                                      ? const Color(0xFF7B1FA2)
                                      : const Color(0xFFE65100),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusFg),
                      const SizedBox(width: 4),
                      Text(
                        req.status,
                        style: TextStyle(
                          color: statusFg,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18, color: _stroke),

            // Item Name / Description & Code
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.itemDescription,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (req.itemCode.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceAlt,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: _stroke),
                              ),
                              child: Text(
                                req.itemCode,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _ink900,
                                ),
                              ),
                            ),
                          if (req.unitOfMeasure.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${req.unitOfMeasure}',
                              style: const TextStyle(
                                color: _ink600,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Indent Qty Badge
                Tooltip(
                  message: req.isPending ? 'Click to edit requested quantity' : '',
                  child: InkWell(
                    onTap: req.isPending ? () => _showEditQtyDialog(req) : null,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: req.isPending
                              ? const Color(0xFFFFB74D)
                              : const Color(0xFFFFECB3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Indent Qty',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFF57F17),
                                ),
                              ),
                              if (req.isPending) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.edit_outlined,
                                  size: 11,
                                  color: Color(0xFFE65100),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            '+${req.indentQty}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE65100),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Stock Details at request time
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: [
                  const Text(
                    'Balance Stock at Request: ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _ink600,
                    ),
                  ),
                  Text(
                    'Avail: ${req.balanceQty}  |  Total: ${req.currentTotalQty} ${req.unitOfMeasure}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _ink900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Optional Specifications Tags (Make, Spec, HSN)
            if ((req.make != null && req.make!.isNotEmpty) ||
                (req.techSpec != null && req.techSpec!.isNotEmpty) ||
                (req.hsnCode != null && req.hsnCode!.isNotEmpty)) ...[
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (req.make != null && req.make!.isNotEmpty)
                    _buildMetaTag('Make: ${req.make}'),
                  if (req.techSpec != null && req.techSpec!.isNotEmpty)
                    _buildMetaTag('Spec: ${req.techSpec}'),
                  if (req.hsnCode != null && req.hsnCode!.isNotEmpty)
                    _buildMetaTag('HSN: ${req.hsnCode}'),
                  if (req.costCenter != null && req.costCenter!.isNotEmpty)
                    _buildMetaTag('CC: ${req.costCenter}'),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Requester & Date
            Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 13,
                  color: _ink700,
                ),
                const SizedBox(width: 4),
                Text(
                  req.requestedBy.isNotEmpty ? req.requestedBy : 'Requester',
                  style: const TextStyle(
                    color: _ink700,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (req.createdAt != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 5),
                    child: Text('•', style: TextStyle(color: _ink700)),
                  ),
                  const Icon(
                    Icons.access_time_rounded,
                    size: 12,
                    color: _ink700,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatDate(req.createdAt),
                    style: const TextStyle(
                      color: _ink600,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),

            // Reason / Justification
            if (req.reason.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Reason: ${req.reason}',
                  style: const TextStyle(
                    color: _ink700,
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),

            // Origin Routing Banner
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: req.isIssueShortage
                    ? const Color(0xFFFFF8E1)
                    : const Color(0xFFF1F8E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: req.isIssueShortage
                      ? const Color(0xFFFFE082)
                      : const Color(0xFFC8E6C9),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    req.isIssueShortage
                        ? Icons.assignment_ind_rounded
                        : Icons.inventory_2_rounded,
                    size: 14,
                    color: req.isIssueShortage
                        ? const Color(0xFFE65100)
                        : const Color(0xFF2E7D32),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      req.isIssueShortage
                          ? 'Fulfills issue demand shortage: Will auto-reserve for ${req.requestedBy}'
                          : (req.isAutoRefill
                              ? 'System auto-indent: Directly credits to Available Stock on shelf'
                              : 'General store replenishment: Directly credits to Available Stock on shelf'),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: req.isIssueShortage
                            ? const Color(0xFFE65100)
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Review Details if reviewed
            if (req.reviewedBy != null && req.reviewedBy!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: req.isApproved
                      ? const Color(0xFFF1F8E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${req.status} by ${req.reviewedBy}${req.reviewedAt != null ? ' on ${_formatDate(req.reviewedAt)}' : ''}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: req.isApproved
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                    if (req.reviewRemarks != null &&
                        req.reviewRemarks!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(
                          'Note: ${req.reviewRemarks}',
                          style: TextStyle(
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                            color: req.isApproved
                                ? const Color(0xFF1B5E20)
                                : const Color(0xFFB71C1C),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Store Receiver / Approver
            if (req.isPending) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          showIndentLifecycleTimelineSheet(context, indent: req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        iconColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Timeline',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteRequest(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        iconColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFEF9A9A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC62828)),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditQtyDialog(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE65100),
                        iconColor: const Color(0xFFE65100),
                        side: const BorderSide(color: Color(0xFFFFB74D)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFFE65100)),
                      label: const Text(
                        'Edit Qty',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (canApprove) ...[
                      OutlinedButton.icon(
                        onPressed: () => _showApprovalDialog(req, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          iconColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFEF9A9A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFFC62828)),
                        label: const Text(
                          'Reject',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _showApprovalDialog(req, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          iconColor: Colors.white,
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: const Text(
                          'Approve',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ] else if (req.isApproved && !req.stockCredited) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          showIndentLifecycleTimelineSheet(context, indent: req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        iconColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.timeline_rounded, size: 16, color: Color(0xFF2563EB)),
                      label: const Text(
                        'Timeline',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditQtyDialog(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0),
                        iconColor: const Color(0xFF1565C0),
                        side: const BorderSide(color: Color(0xFF90CAF9)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF1565C0)),
                      label: const Text(
                        'Amend / Increase',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDeleteRequest(req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFC62828),
                        iconColor: const Color(0xFFC62828),
                        side: const BorderSide(color: Color(0xFFEF9A9A)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFC62828)),
                      label: const Text(
                        'Delete',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (ref.watch(storeCartConfigProvider).grnWorkflowEnabled) ...[
                      if (ref.watch(grnCartProvider).containsKey(req.id))
                        OutlinedButton.icon(
                          onPressed: () => showGrnCartSheet(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2E7D32),
                            iconColor: const Color(0xFF2E7D32),
                            side: const BorderSide(color: Color(0xFF81C784)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF2E7D32)),
                          label: const Text(
                            'In GRN Cart',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          onPressed: () {
                            ref.read(grnCartProvider.notifier).addIndent(req);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${req.itemName.isNotEmpty ? req.itemName : req.itemDescription} added to GRN Cart',
                                ),
                                action: SnackBarAction(
                                  label: 'Open Cart',
                                  onPressed: () => showGrnCartSheet(context),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            iconColor: Colors.white,
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          label: const Text(
                            'Add to GRN',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                    if (canApprove && !ref.watch(storeCartConfigProvider).grnWorkflowEnabled)
                      ElevatedButton.icon(
                        onPressed: () => _showCreditStockDialog(req),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B5E20),
                          foregroundColor: Colors.white,
                          iconColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.add_business_rounded, size: 18, color: Colors.white),
                        label: Text(
                          'Receive Stock (+${req.indentQty} ${req.unitOfMeasure})',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!req.stockCredited)
                      OutlinedButton.icon(
                        onPressed: () => _confirmDeleteRequest(req),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFC62828),
                          iconColor: const Color(0xFFC62828),
                          side: const BorderSide(color: Color(0xFFEF9A9A)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFC62828)),
                        label: const Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          showIndentLifecycleTimelineSheet(context, indent: req),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        iconColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFBFDBFE)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.timeline_rounded, size: 15, color: Color(0xFF2563EB)),
                      label: const Text(
                        'View Timeline',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (req.stockCredited) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 15, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Stock Credited into Inventory (+${req.creditedQty ?? req.indentQty} ${req.unitOfMeasure})'
                        '${req.creditedRackCode != null && req.creditedRackCode!.isNotEmpty ? ' • Rack: ${req.creditedRackCode}' : ''}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1B5E20),
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
    );
  }

  Widget _buildMetaTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3EE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _stroke),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _ink700,
        ),
      ),
    );
  }
}

