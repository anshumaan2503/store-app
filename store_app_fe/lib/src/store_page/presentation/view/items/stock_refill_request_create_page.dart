import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/stock_refill_request_model.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../widgets/store_ui_state_widgets.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);

typedef IndentRaiseCreatePage = StockRefillRequestCreatePage;

class StockRefillRequestCreatePage extends ConsumerStatefulWidget {
  const StockRefillRequestCreatePage({
    super.key,
    required this.item,
  });

  final StoreItemsModel item;

  @override
  ConsumerState<StockRefillRequestCreatePage> createState() =>
      _StockRefillRequestCreatePageState();
}

class _StockRefillRequestCreatePageState
    extends ConsumerState<StockRefillRequestCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _reasonController = TextEditingController();

  // Optional reference controllers
  final _makeController = TextEditingController();
  final _techSpecController = TextEditingController();
  final _hsnCodeController = TextEditingController();
  final _costCenterController = TextEditingController();

  bool _showOptionalFields = false;
  bool _submitting = false;

  @override
  void dispose() {
    _qtyController.dispose();
    _reasonController.dispose();
    _makeController.dispose();
    _techSpecController.dispose();
    _hsnCodeController.dispose();
    _costCenterController.dispose();
    super.dispose();
  }

  Future<void> _openEditQtyDialog(StockRefillRequestModel indent) async {
    final qtyController = TextEditingController(
      text: indent.indentQty > 0 ? indent.indentQty.toString() : '1',
    );
    final reasonController = TextEditingController(text: indent.reason);
    bool isSubmitting = false;
    final isPending = indent.isPending;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final maxQty = widget.item.maxCapacity;
            final currentAvail = widget.item.stockAvailableQuantity;
            final maxAllowed =
                maxQty > 0 ? (maxQty - currentAvail).clamp(1, maxQty) : 999999;

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
                          ? 'A refill indent is already pending. Adjust the quantity for ${widget.item.itemName} (${indent.indentNumber.isNotEmpty ? indent.indentNumber : indent.requestNo}).'
                          : 'This indent is approved and awaiting receipt. Increasing quantity will submit an amendment for approver re-approval.',
                      style: const TextStyle(
                        color: _ink700,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (maxQty > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _surfaceAlt.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Can Indent Up To:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _ink600,
                              ),
                            ),
                            Text(
                              '$maxAllowed ${widget.item.unit} (Max: $maxQty)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _ink900,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            final current =
                                num.tryParse(qtyController.text) ?? 1;
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
                            keyboardType:
                                const TextInputType.numberWithOptions(
                                    decimal: true),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink900,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                            cursorColor: _ink900,
                            decoration: InputDecoration(
                              suffixText: widget.item.unit,
                              filled: true,
                              fillColor: const Color(0xFFFAF8F0),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: _stroke),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: _ink900, width: 1.5),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          onPressed: () {
                            final current =
                                num.tryParse(qtyController.text) ?? 0;
                            if (maxQty <= 0 || current + 1 <= maxAllowed) {
                              setDialogState(() {
                                qtyController.text = (current + 1).toString();
                              });
                            }
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
                        hintText:
                            'e.g. Adjusted refill quantity based on current consumption',
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
                          borderSide: const BorderSide(
                              color: _ink900, width: 1.5),
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
                          final newQty =
                              num.tryParse(qtyController.text.trim());
                          if (newQty == null || newQty <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Please enter a valid quantity greater than 0'),
                                backgroundColor: Color(0xFFC62828),
                              ),
                            );
                            return;
                          }

                          if (maxQty > 0 && newQty > maxAllowed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Quantity cannot exceed allowable limit ($maxAllowed ${widget.item.unit}) to reach max capacity ($maxQty).'),
                                backgroundColor: const Color(0xFFC62828),
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
                                id: indent.id,
                                indentQty: newQty,
                                reason: reasonController.text.trim(),
                              );

                          if (!mounted || !dialogCtx.mounted) return;
                          Navigator.pop(dialogCtx);

                          if (res != null) {
                            ref.invalidate(
                                activeIndentForItemProvider(widget.item.id));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPending
                                      ? 'Indent quantity updated to $newQty ${widget.item.unit}'
                                      : 'Quantity amended to $newQty ${widget.item.unit}. Moved to Approver review.',
                                ),
                                backgroundColor: const Color(0xFF2E7D32),
                              ),
                            );
                            Navigator.pop(context, true);
                          } else {
                            final err = ref
                                    .read(stockRefillRequestControllerProvider)
                                    .error
                                    ?.toString() ??
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
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
                    isPending ? 'Save Quantity' : 'Request Amendment',
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

  Widget _buildActiveIndentBanner(StockRefillRequestModel activeIndent) {
    final isPending = activeIndent.isPending;
    final indentId = activeIndent.indentNumber.isNotEmpty
        ? activeIndent.indentNumber
        : activeIndent.requestNo;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPending ? const Color(0xFFFFF8E1) : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPending ? const Color(0xFFFFB300) : const Color(0xFF1976D2),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPending
                    ? Icons.warning_amber_rounded
                    : Icons.local_shipping_outlined,
                color: isPending
                    ? const Color(0xFFE65100)
                    : const Color(0xFF1565C0),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isPending
                      ? 'Indent $indentId is already Pending Approval'
                      : 'Indent $indentId is Approved & In-Transit',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: isPending
                        ? const Color(0xFFE65100)
                        : const Color(0xFF0D47A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isPending
                ? 'A refill indent for ${activeIndent.indentQty} ${widget.item.unit} has already been raised for this item. Under the One Indent Rule, you can edit the existing quantity instead of creating a duplicate request.'
                : 'An order for ${activeIndent.indentQty} ${widget.item.unit} is approved and awaiting delivery. You can amend / increase the quantity on this indent if additional units are needed.',
            style: const TextStyle(
                fontSize: 12.5, color: _ink700, height: 1.35),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openEditQtyDialog(activeIndent),
            icon: Icon(
                isPending
                    ? Icons.edit_note_rounded
                    : Icons.add_shopping_cart_rounded,
                size: 16),
            label: Text(isPending
                ? 'Edit Existing Quantity'
                : 'Amend / Increase Quantity'),
            style: FilledButton.styleFrom(
              backgroundColor: isPending
                  ? const Color(0xFFE65100)
                  : const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;

    final activeIndent =
        ref.read(activeIndentForItemProvider(widget.item.id)).valueOrNull;
    if (activeIndent != null) {
      _openEditQtyDialog(activeIndent);
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    final qty = num.tryParse(_qtyController.text.trim());
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFC62828),
          content: Text('Please enter a valid indent quantity (>= 1)'),
        ),
      );
      return;
    }

    if (widget.item.maxCapacity > 0) {
      final current = widget.item.stockAvailableQuantity;
      if (current >= widget.item.maxCapacity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              'Cannot raise indent: "${widget.item.itemName}" has reached its maximum quantity of ${widget.item.maxCapacity}.',
            ),
          ),
        );
        return;
      }
      final remaining = widget.item.maxCapacity - current;
      if (qty > remaining) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(
              'Cannot raise indent: Requested quantity ($qty) exceeds allowable limit ($remaining) to reach maximum quantity (${widget.item.maxCapacity}).',
            ),
          ),
        );
        return;
      }
    }

    setState(() => _submitting = true);

    try {
      final res = await ref
          .read(stockRefillRequestControllerProvider.notifier)
          .createIndent(
            itemId: widget.item.id,
            indentQty: qty,
            reason: _reasonController.text.trim(),
            itemDescription: widget.item.itemName,
            unitOfMeasure: widget.item.unit,
            make: _makeController.text.trim().isNotEmpty
                ? _makeController.text.trim()
                : null,
            techSpec: _techSpecController.text.trim().isNotEmpty
                ? _techSpecController.text.trim()
                : null,
            hsnCode: _hsnCodeController.text.trim().isNotEmpty
                ? _hsnCodeController.text.trim()
                : null,
            costCenter: _costCenterController.text.trim().isNotEmpty
                ? _costCenterController.text.trim()
                : null,
          );

      if (!mounted) return;
      setState(() => _submitting = false);

      if (res != null) {
        final indentIdStr = res.indentNumber.isNotEmpty
            ? res.indentNumber
            : res.requestNo;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text(
              'Indent raised successfully for ${widget.item.itemName} ($indentIdStr)',
            ),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final error = ref.read(stockRefillRequestControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFC62828),
            content: Text(error?.toString() ?? 'Failed to raise indent request'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFC62828),
          content: Text('Error: $e'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeIndentAsync =
        ref.watch(activeIndentForItemProvider(widget.item.id));
    final activeIndent = activeIndentAsync.valueOrNull;
    final hasActiveIndent = activeIndent != null;

    final item = widget.item;
    final isOut = item.stockAvailableQuantity <= 0;
    final maxQty = item.maxCapacity;
    final currentStock = item.stockAvailableQuantity;
    final hasMaxLimit = maxQty > 0;
    final isMaxReached = hasMaxLimit && currentStock >= maxQty;
    final remainingAllowed = hasMaxLimit
        ? (maxQty - currentStock).clamp(0, maxQty)
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      appBar: AppBar(
        title: const Text(
          'Indent Raise',
          style: TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        elevation: 0,
        backgroundColor: _surface,
        iconTheme: const IconThemeData(color: _ink900),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _stroke, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasActiveIndent) ...[
                      _buildActiveIndentBanner(activeIndent),
                      const SizedBox(height: 16),
                    ],

                    // Item summary card (Authoritative Read-Only Stock Information)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _stroke),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isOut
                                      ? const Color(0xFFFFEBEE)
                                      : const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isOut
                                        ? const Color(0xFFFFCDD2)
                                        : const Color(0xFFFFECB3),
                                  ),
                                ),
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: isOut
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFFF9A825),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.itemName,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _surfaceAlt,
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(color: _stroke),
                                          ),
                                          child: Text(
                                            item.itemCode,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        if (item.unit.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Text(
                                            'Unit: ${item.unit}',
                                            style: const TextStyle(
                                              color: _ink700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              StockStatusChip(
                                availableQty: item.stockAvailableQuantity,
                                compact: true,
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: _stroke),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOut
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Available Stock',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isOut
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF2E7D32),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${item.stockAvailableQuantity} ${item.unit}',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          color: isOut
                                              ? const Color(0xFFC62828)
                                              : const Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (hasMaxLimit) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMaxReached
                                          ? const Color(0xFFFFEBEE)
                                          : const Color(0xFFE8F0FE),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMaxReached
                                            ? const Color(0xFFFFCDD2)
                                            : const Color(0xFFBFDBFE),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isMaxReached ? 'Max (Reached)' : 'Max Quantity',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isMaxReached
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$maxQty ${item.unit}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: isMaxReached
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFF1E40AF),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isMaxReached
                                          ? const Color(0xFFFFEBEE)
                                          : const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isMaxReached
                                            ? const Color(0xFFFFCDD2)
                                            : const Color(0xFFFFE082),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Can Indent Up To',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isMaxReached
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFFB78103),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$remainingAllowed ${item.unit}',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: isMaxReached
                                                ? const Color(0xFFC62828)
                                                : const Color(0xFFE65100),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ] else if (item.minStockQuantity > 0) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF8E1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFFFE082)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Min Stock Alert',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFFB78103),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${item.minStockQuantity} ${item.unit}',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFFE65100),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Information note explaining authoritative nature
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFF1565C0),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Raising an indent creates a replenishment/procurement request. Stock quantities shown above are authoritative and cannot be manually overridden. Creating an indent does not alter inventory.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0D47A1),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (isMaxReached) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFCDD2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.block_rounded,
                              color: Color(0xFFC62828),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'This item has reached its Maximum Quantity ($maxQty ${item.unit}). Current stock is $currentStock. Manual indent request cannot be generated.',
                                style: const TextStyle(
                                  color: Color(0xFFC62828),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Indent Details Form Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _stroke),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A000000),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Indent Details',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Indent Quantity Field
                          const Text(
                            'Indent Quantity *',
                            style: TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _qtyController,
                            style: const TextStyle(
                              color: _ink900,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            cursorColor: _ink900,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*'),
                              ),
                            ],
                            decoration: InputDecoration(
                              hintText: hasActiveIndent
                                  ? (activeIndent.isPending
                                      ? 'Indent pending: Use button below to edit quantity'
                                      : 'Indent in-transit: Use button below to amend')
                                  : hasMaxLimit
                                      ? (isMaxReached
                                          ? 'Maximum quantity reached ($maxQty)'
                                          : 'Enter indent quantity (Max allowed: $remainingAllowed ${item.unit})')
                                      : 'Enter indent quantity needed (e.g. 50)',
                              helperText: hasActiveIndent
                                  ? 'Active indent ${activeIndent.indentNumber.isNotEmpty ? activeIndent.indentNumber : activeIndent.requestNo} already covers this item (${activeIndent.indentQty} ${item.unit}).'
                                  : hasMaxLimit && !isMaxReached
                                      ? 'Max limit: $maxQty ${item.unit}. You can indent up to $remainingAllowed ${item.unit}.'
                                      : null,
                              helperStyle: TextStyle(
                                color: hasActiveIndent
                                    ? const Color(0xFFE65100)
                                    : const Color(0xFF1D4ED8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              hintStyle: const TextStyle(
                                color: _ink600,
                                fontSize: 13,
                              ),
                              suffixText: item.unit.isNotEmpty ? item.unit : null,
                              suffixStyle: const TextStyle(
                                color: _ink700,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                              filled: true,
                              fillColor: (isMaxReached || hasActiveIndent)
                                  ? const Color(0xFFEEEEEE)
                                  : const Color(0xFFFAF8F0),
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
                                borderSide: const BorderSide(
                                  color: _ink900,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            enabled: !isMaxReached && !hasActiveIndent,
                            validator: (val) {
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Indent quantity is required';
                              }
                              final n = num.tryParse(trimmed);
                              if (n == null || n <= 0) {
                                return 'Quantity must be greater than 0';
                              }
                              if (hasMaxLimit) {
                                if (isMaxReached) {
                                  return 'Item has reached its maximum quantity of $maxQty';
                                }
                                if (remainingAllowed != null && n > remainingAllowed) {
                                  return 'Quantity exceeds maximum limit. You can only indent up to $remainingAllowed ${item.unit}';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Reason Field
                          const Text(
                            'Reason / Procurement Justification *',
                            style: TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _reasonController,
                            maxLines: 3,
                            style: const TextStyle(
                              color: _ink900,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            cursorColor: _ink900,
                            decoration: InputDecoration(
                              hintText:
                                  'Explain reason for indent (e.g. Stock exhausted, production requirement, upcoming project...)',
                              hintStyle: const TextStyle(
                                color: _ink600,
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFFAF8F0),
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
                                borderSide: const BorderSide(
                                  color: _ink900,
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            validator: (val) {
                              final trimmed = val?.trim() ?? '';
                              if (trimmed.isEmpty) {
                                return 'Reason/justification is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Optional Specifications Expander
                          InkWell(
                            onTap: () {
                              setState(() {
                                _showOptionalFields = !_showOptionalFields;
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                children: [
                                  Icon(
                                    _showOptionalFields
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 20,
                                    color: _ink700,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _showOptionalFields
                                        ? 'Hide Additional Specifications'
                                        : 'Add Specifications (Optional: Make, Spec, HSN...)',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          if (_showOptionalFields) ...[
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: _stroke),
                            const SizedBox(height: 14),

                            // Make / Brand
                            const Text(
                              'Make / Brand (Optional)',
                              style: TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _makeController,
                              style: const TextStyle(
                                color: _ink900,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                hintText: 'e.g. Bosch, Siemens, 3M',
                                hintStyle: const TextStyle(
                                  color: _ink600,
                                  fontSize: 12.5,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAF8F0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _stroke),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Technical Specification
                            const Text(
                              'Technical Specification (Optional)',
                              style: TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w600,
                                fontSize: 12.5,
                              ),
                            ),
                            const SizedBox(height: 5),
                            TextFormField(
                              controller: _techSpecController,
                              maxLines: 2,
                              style: const TextStyle(
                                color: _ink900,
                                fontSize: 13.5,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                  'e.g. Grade 304, Dimensions: 100x50mm, 24V DC',
                                hintStyle: const TextStyle(
                                  color: _ink600,
                                  fontSize: 12.5,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFFAF8F0),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: _stroke),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Row with HSN Code and Cost Center
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'HSN Code (Optional)',
                                        style: TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextFormField(
                                        controller: _hsnCodeController,
                                        style: const TextStyle(
                                          color: _ink900,
                                          fontSize: 13.5,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. 84713010',
                                          hintStyle: const TextStyle(
                                            color: _ink600,
                                            fontSize: 12.5,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFFAF8F0),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Cost Center (Optional)',
                                        style: TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      TextFormField(
                                        controller: _costCenterController,
                                        style: const TextStyle(
                                          color: _ink900,
                                          fontSize: 13.5,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'e.g. CC-STORE-01',
                                          hintStyle: const TextStyle(
                                            color: _ink600,
                                            fontSize: 12.5,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFFFAF8F0),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Submit or Edit/Amend Button
                    if (hasActiveIndent)
                      ElevatedButton(
                        onPressed: () => _openEditQtyDialog(activeIndent),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeIndent.isPending
                              ? const Color(0xFFE65100)
                              : const Color(0xFF1565C0),
                          foregroundColor: _surface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              activeIndent.isPending
                                  ? Icons.edit_note_rounded
                                  : Icons.add_shopping_cart_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                activeIndent.isPending
                                    ? 'Indent Already Pending — Edit Quantity'
                                    : 'Indent In-Transit — Amend / Increase Quantity',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ElevatedButton(
                        onPressed: (_submitting || isMaxReached) ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMaxReached ? Colors.grey : _ink900,
                          foregroundColor: _surface,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    isMaxReached
                                        ? Icons.block_rounded
                                        : Icons.send_rounded,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      isMaxReached
                                          ? 'Maximum Quantity Reached — Cannot Indent'
                                          : 'Submit Indent Request',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
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
}

