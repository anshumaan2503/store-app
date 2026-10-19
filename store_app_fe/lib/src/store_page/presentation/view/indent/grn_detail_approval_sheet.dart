import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_grn_controller.dart';
import '../../../domains/models/store_grn_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF9F7F5);
const _stroke = Color(0xFFDFE1D6);

void showGrnDetailApprovalSheet(
  BuildContext context, {
  required StoreGrnModel grn,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => GrnDetailApprovalSheet(grn: grn),
  );
}

class GrnDetailApprovalSheet extends ConsumerStatefulWidget {
  final StoreGrnModel grn;
  const GrnDetailApprovalSheet({super.key, required this.grn});

  @override
  ConsumerState<GrnDetailApprovalSheet> createState() =>
      _GrnDetailApprovalSheetState();
}

class _GrnDetailApprovalSheetState
    extends ConsumerState<GrnDetailApprovalSheet> {
  bool _isProcessing = false;

  Color _statusColor(String status) {
    switch (status) {
      case 'APPROVED':
        return const Color(0xFF2E7D32);
      case 'REJECTED':
        return const Color(0xFFC62828);
      case 'RECEIVED':
        return const Color(0xFF1565C0);
      case 'PENDING_APPROVAL':
      default:
        return const Color(0xFFE65100);
    }
  }

  Future<void> _approve() async {
    setState(() => _isProcessing = true);
    try {
      final ok = await ref
          .read(storeGrnControllerProvider.notifier)
          .approveGrn(widget.grn.id);
      if (ok && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _reject() async {
    final reasonCtrl = TextEditingController();
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject GRN', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject GRN ${widget.grn.grnNumber}?',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason',
                hintText: 'e.g. Broken package, rate discrepancy',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );

    if (shouldReject == true) {
      setState(() => _isProcessing = true);
      try {
        final ok = await ref
            .read(storeGrnControllerProvider.notifier)
            .rejectGrn(widget.grn.id, reasonCtrl.text.trim());
        if (ok && mounted) {
          Navigator.of(context).pop();
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grn = widget.grn;
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.90;
    final isPending = grn.status == 'PENDING_APPROVAL';

    final user = ref.watch(userFindOneDataStreamProvider).asData?.value;
    final isSuperAdmin = user?.isSuperAdmin ?? false;
    final isStoreAdmin = user?.appWorks.contains('storeadmin') ?? false;
    final canApprove = isSuperAdmin ||
        isStoreAdmin ||
        (user?.appWorks.contains('storreceiveapprove') ?? false);
    final canReject = isSuperAdmin ||
        isStoreAdmin ||
        (user?.appWorks.contains('storreceivereject') ?? false) ||
        (user?.appWorks.contains('storreceiveapprove') ?? false);

    return Container(
      constraints: BoxConstraints(maxHeight: maxH),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: mediaQuery.viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: _stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              grn.grnNumber,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor(grn.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              grn.status.replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: _statusColor(grn.status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Submitted by ${grn.submittedByName.isNotEmpty ? grn.submittedByName : "Store Operator"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _ink600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: _ink900),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _stroke),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Challan Image Preview if available
                if (grn.imageUrl.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.photo_outlined, size: 18, color: _ink700),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Verified Challan / Invoice Document',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            grn.imageUrl,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Document image preview unavailable'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Items Table
                const Text(
                  'Physical Verification & Rates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _ink900,
                  ),
                ),
                const SizedBox(height: 8),

                ...grn.items.map((it) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                it.itemName,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ),
                            Text(
                              '₹${it.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              'Ordered: ${it.orderedQty}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: _ink600,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Verified: ${it.receivedQty} ${it.unit}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _ink900,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '@ ₹${it.unitPrice.toStringAsFixed(2)}/pc',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),

                // Summary
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F8E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC8E6C9)),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        'Total: ${grn.totalQuantity} items',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _ink900,
                        ),
                      ),
                      Text(
                        'Total Value: ₹${grn.totalValue.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                        ),
                      ),
                    ],
                  ),
                ),

                if (grn.remarks.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Remarks: ${grn.remarks}',
                    style: const TextStyle(fontSize: 12, color: _ink600),
                  ),
                ],

                if (grn.rejectionReason.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(
                      'Rejection Reason: ${grn.rejectionReason}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Actions for pending approval
          if (isPending && (canApprove || canReject))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  if (canReject)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isProcessing ? null : _reject,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Reject GRN'),
                      ),
                    ),
                  if (canReject && canApprove) const SizedBox(width: 12),
                  if (canApprove)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _approve,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Approve GRN (Unlock Putaway)',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          if (isPending && !canApprove && !canReject)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Colors.amber.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Approval permission required to approve or reject this GRN.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
