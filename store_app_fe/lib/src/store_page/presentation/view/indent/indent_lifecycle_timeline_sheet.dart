import 'package:flutter/material.dart';
import '../../../domains/models/stock_refill_request_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF8F9FA);
const _stroke = Color(0xFFDFE1D6);
const _brandPrimary = Color(0xFF2563EB);

void showIndentLifecycleTimelineSheet(
  BuildContext context, {
  required StockRefillRequestModel indent,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    constraints: BoxConstraints(
      maxWidth: screenWidth >= 900
          ? 700
          : (screenWidth >= 600 ? screenWidth * 0.92 : double.infinity),
    ),
    builder: (_) => IndentLifecycleTimelineSheet(indent: indent),
  );
}

class IndentLifecycleTimelineSheet extends StatelessWidget {
  final StockRefillRequestModel indent;

  const IndentLifecycleTimelineSheet({super.key, required this.indent});

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'RECEIVED':
        return const Color(0xFF2563EB);
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _statusBgColor(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return const Color(0xFFDCFCE7);
      case 'REJECTED':
        return const Color(0xFFFEE2E2);
      case 'RECEIVED':
        return const Color(0xFFDBEAFE);
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  IconData _actionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return Icons.note_add_rounded;
      case 'APPROVED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      case 'QTY_EDITED':
        return Icons.edit_note_rounded;
      case 'GRN_CREATED':
      case 'GRN_INSPECTED':
        return Icons.local_shipping_rounded;
      case 'RECEIVED':
        return Icons.inventory_2_rounded;
      default:
        return Icons.radio_button_checked_rounded;
    }
  }

  Color _actionColor(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return const Color(0xFF2563EB);
      case 'APPROVED':
        return const Color(0xFF16A34A);
      case 'REJECTED':
        return const Color(0xFFDC2626);
      case 'QTY_EDITED':
        return const Color(0xFFEA580C);
      case 'GRN_CREATED':
      case 'GRN_INSPECTED':
        return const Color(0xFF7C3AED);
      case 'RECEIVED':
        return const Color(0xFF0D9488);
      default:
        return _brandPrimary;
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = (dt.hour % 12 == 0 ? 12 : dt.hour % 12).toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$d/$m/$y at $hh:$mm $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;
    final timelineEvents = indent.timeline.isNotEmpty
        ? indent.timeline
        : [
            IndentTimelineModel(
              action: 'CREATED',
              title: 'Indent Raised',
              description: indent.reason.isNotEmpty
                  ? 'Requested: ${indent.reason}'
                  : 'Requisition created for ${indent.indentQty} ${indent.unitOfMeasure}',
              actorName: indent.requestedBy,
              timestamp: indent.createdOn ?? indent.createdAt ?? DateTime.now(),
            ),
            if (indent.status.toUpperCase() == 'APPROVED' || indent.reviewedAt != null)
              IndentTimelineModel(
                action: 'APPROVED',
                title: 'Indent Approved',
                description: indent.reviewRemarks ?? 'Approved for receiving',
                actorName: indent.reviewedBy ?? 'Approver',
                timestamp: indent.reviewedAt ?? indent.lastChangedOn ?? DateTime.now(),
              ),
            if (indent.status.toUpperCase() == 'REJECTED')
              IndentTimelineModel(
                action: 'REJECTED',
                title: 'Indent Rejected',
                description: indent.reviewRemarks ?? 'Indent rejected',
                actorName: indent.reviewedBy ?? 'Approver',
                timestamp: indent.reviewedAt ?? indent.lastChangedOn ?? DateTime.now(),
              ),
            if (indent.stockCredited || (indent.receiveDocId != null && indent.receiveDocId!.isNotEmpty))
              IndentTimelineModel(
                action: 'RECEIVED',
                title: 'Stock Received & Putaway',
                description:
                    'Credited ${indent.creditedQty ?? indent.indentQty} into rack ${indent.creditedRackCode ?? "Assigned Rack"}',
                actorName: 'Store Operator',
                timestamp: indent.stockCreditedAt ?? indent.lastChangedOn ?? DateTime.now(),
              ),
          ];

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _stroke,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: const Icon(
                    Icons.timeline_rounded,
                    color: _brandPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              indent.indentNumber.isNotEmpty
                                  ? indent.indentNumber
                                  : indent.requestNo,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _statusBgColor(indent.status),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _statusColor(indent.status)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              indent.status,
                              style: TextStyle(
                                color: _statusColor(indent.status),
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        indent.itemDescription.isNotEmpty
                            ? indent.itemDescription
                            : indent.itemName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _ink700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Requested: ${indent.indentQty} ${indent.unitOfMeasure}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _brandPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '•  By: ${indent.requestedBy.isNotEmpty ? indent.requestedBy : "Store User"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _ink600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: _ink600),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _stroke),

          // Lifecycle Stepper / Timeline List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              itemCount: timelineEvents.length,
              itemBuilder: (context, idx) {
                final ev = timelineEvents[idx];
                final isLast = idx == timelineEvents.length - 1;
                final color = _actionColor(ev.action);
                final icon = _actionIcon(ev.action);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Node icon & vertical line
                      Column(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                              border: Border.all(color: color, width: 2),
                            ),
                            child: Icon(icon, color: color, size: 16),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Container(
                                width: 2,
                                color: _stroke,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Card Content
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 8 : 22),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _surfaceAlt,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _stroke),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      ev.title,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(ev.timestamp),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: _ink600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (ev.description.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    ev.description,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: _ink700,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                                if (ev.actorName.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person_outline_rounded,
                                        size: 13,
                                        color: _ink600,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        ev.actorName,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
                                          color: _ink600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom Action
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              height: 44,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _ink900,
                  side: const BorderSide(color: _stroke),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
