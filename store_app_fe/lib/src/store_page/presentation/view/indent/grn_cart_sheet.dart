import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../controllers/store_grn_controller.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFFA89F91);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFF9F7F5);
const _stroke = Color(0xFFDFE1D6);

void showGrnCartSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const GrnCartSheet(),
  );
}

class GrnCartSheet extends ConsumerStatefulWidget {
  const GrnCartSheet({super.key});

  @override
  ConsumerState<GrnCartSheet> createState() => _GrnCartSheetState();
}

class _GrnCartSheetState extends ConsumerState<GrnCartSheet> {
  final _remarksCtrl = TextEditingController();
  final Map<String, TextEditingController> _qtyControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};

  Uint8List? _pickedImageBytes;
  String? _pickedImageBase64;
  bool _isUploadingImage = false;

  @override
  void dispose() {
    _remarksCtrl.dispose();
    for (final c in _qtyControllers.values) {
      c.dispose();
    }
    for (final c in _priceControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickChallanImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;

    setState(() => _isUploadingImage = true);
    try {
      final bytes = await picked.readAsBytes();
      final base64Str = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      setState(() {
        _pickedImageBytes = bytes;
        _pickedImageBase64 = base64Str;
      });
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _removeChallanImage() {
    setState(() {
      _pickedImageBytes = null;
      _pickedImageBase64 = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(grnCartProvider);
    final isSubmitting = ref.watch(storeGrnControllerProvider);
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.90;

    final totalItems = cart.length;
    final totalQty = cart.values.fold(0, (sum, it) => sum + it.receivedQty);
    final totalVal = cart.values.fold(0.0, (sum, it) => sum + it.totalPrice);

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
          // Header handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: _stroke,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title & Clear All
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.assignment_turned_in_outlined,
                    color: Color(0xFF2E7D32),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'GRN Cart (Goods Receipt)',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$totalItems',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Recheck physical quantities, rates & upload invoice/challan',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: _ink600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (cart.isNotEmpty)
                  TextButton.icon(
                    onPressed: isSubmitting
                        ? null
                        : () {
                            ref.read(grnCartProvider.notifier).clear();
                          },
                    icon: Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.red.shade700),
                    label: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12.5),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      iconColor: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _stroke),

          // Content
          if (cart.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_shopping_cart_outlined,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'GRN Cart is Empty',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Select items from approved indents in the Receive section and click "Add to GRN" to inspect physical quantities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: _ink600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Item list
                  ...cart.entries.map((entry) {
                    final indentId = entry.key;
                    final item = entry.value;

                    // Initialize controllers once
                    if (!_qtyControllers.containsKey(indentId)) {
                      _qtyControllers[indentId] = TextEditingController(
                        text: item.receivedQty.toString(),
                      );
                    }
                    if (!_priceControllers.containsKey(indentId)) {
                      _priceControllers[indentId] = TextEditingController(
                        text: item.unitPrice > 0
                            ? item.unitPrice.toStringAsFixed(2)
                            : '',
                      );
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.indent.itemName.isNotEmpty
                                          ? item.indent.itemName
                                          : item.indent.itemDescription,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _ink900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Text(
                                          'Indent #${item.indent.indentNumber.isNotEmpty ? item.indent.indentNumber : item.indent.requestNo}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1565C0),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Ordered: ${item.orderedQty} ${item.indent.unitOfMeasure}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: _ink600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                color: Colors.grey.shade600,
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  ref
                                      .read(grnCartProvider.notifier)
                                      .removeIndent(indentId);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Inputs row: Received Qty & Purchase Rate
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Verified Qty',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 38,
                                      child: TextField(
                                        controller:
                                            _qtyControllers[indentId],
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _ink900,
                                        ),
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF2E7D32),
                                                width: 1.5),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final parsed =
                                              int.tryParse(val.trim()) ?? 0;
                                          ref
                                              .read(grnCartProvider.notifier)
                                              .updateReceivedQty(
                                                indentId,
                                                parsed,
                                              );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Rate (₹ / pc)',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      height: 38,
                                      child: TextField(
                                        controller:
                                            _priceControllers[indentId],
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: _ink900,
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: '₹ ',
                                          prefixStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _ink900,
                                          ),
                                          hintText: '0.00',
                                          hintStyle: const TextStyle(
                                            fontSize: 12,
                                            color: _ink500,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          filled: true,
                                          fillColor: Colors.white,
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: _stroke),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF2E7D32),
                                                width: 1.5),
                                          ),
                                        ),
                                        onChanged: (val) {
                                          final parsed =
                                              double.tryParse(val.trim()) ??
                                                  0.0;
                                          ref
                                              .read(grnCartProvider.notifier)
                                              .updateUnitPrice(
                                                indentId,
                                                parsed,
                                              );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 4,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Line Total',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: _ink600,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '₹${item.totalPrice.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 14,
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
                    );
                  }),

                  const SizedBox(height: 8),

                  // Image Upload Section (Delivery Challan / Bill)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _pickedImageBytes != null
                            ? const Color(0xFF2E7D32)
                            : _stroke,
                        width: _pickedImageBytes != null ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              size: 18,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Delivery Challan / Invoice Photo (Optional)',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ),
                            if (_pickedImageBytes != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'Attached',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Upload 1 photo of the supplier invoice, delivery challan, or parcel. Once approved, scanning QR to receive will NOT require photo upload.',
                          style: TextStyle(
                            fontSize: 11,
                            color: _ink600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_pickedImageBytes != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _pickedImageBytes!,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickChallanImage,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _ink900,
                                  iconColor: _ink900,
                                ),
                                icon: const Icon(Icons.change_circle_outlined,
                                    size: 16, color: _ink900),
                                label: const Text('Change'),
                              ),
                              const SizedBox(width: 10),
                              TextButton.icon(
                                onPressed: _removeChallanImage,
                                icon: Icon(Icons.delete_outline,
                                    size: 16, color: Colors.red.shade700),
                                label: const Text('Remove'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  iconColor: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          InkWell(
                            onTap: _isUploadingImage ? null : _pickChallanImage,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: _surfaceAlt,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _stroke,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                children: [
                                  if (_isUploadingImage)
                                    const CircularProgressIndicator(
                                        strokeWidth: 2)
                                  else ...[
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      size: 32,
                                      color: _ink600,
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Tap to upload Challan / Invoice photo',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _ink900,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Remarks
                  TextField(
                    controller: _remarksCtrl,
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _ink900,
                    ),
                    decoration: InputDecoration(
                      labelText: 'GRN Remarks / Supplier Note (Optional)',
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ink700,
                      ),
                      hintText: 'e.g. Received from ABC Logistics, bill # 8492',
                      hintStyle: const TextStyle(
                        fontSize: 11,
                        color: _ink500,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF2E7D32),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Summary Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F8E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFC8E6C9)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Total Verified Qty',
                              style: TextStyle(
                                fontSize: 11,
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalQty units',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _ink900,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Estimated Total Value',
                              style: TextStyle(
                                fontSize: 11,
                                color: _ink600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '₹${totalVal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Bottom Action
          if (cart.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final grn = await ref
                              .read(storeGrnControllerProvider.notifier)
                              .submitGrn(
                                base64Image: _pickedImageBase64,
                                remarks: _remarksCtrl.text.trim(),
                                autoApprove: true,
                              );
                          if (grn != null && mounted) {
                            nav.pop();
                          }
                        },
                  icon: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        isSubmitting
                            ? 'Approving GRN...'
                            : 'Approve GRN (${cart.length} items)',
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
