import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../auth/shared/providers/auth_model_provider.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_receive_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../../domains/models/stock_refill_request_model.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/store_rack_controller.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class ScanRackReceivePage extends ConsumerStatefulWidget {
  final String rackId;
  final String? initialItemId;
  final String? initialIndentId;
  final num? initialIndentQty;
  final String? initialIndentNumber;

  const ScanRackReceivePage({
    super.key,
    required this.rackId,
    this.initialItemId,
    this.initialIndentId,
    this.initialIndentQty,
    this.initialIndentNumber,
  });

  @override
  ConsumerState<ScanRackReceivePage> createState() =>
      _ScanRackReceivePageState();
}

class _ScanRackReceivePageState extends ConsumerState<ScanRackReceivePage> {
  late StoreRack _rack;

  bool _busy = false;
  bool _hasSubmitted = false;
  StockRefillRequestModel? _cachedBoundIndent;
  final TextEditingController _rackQtyCtrl = TextEditingController();
  final TextEditingController _unitPriceCtrl = TextEditingController();
  final TextEditingController _imageUrlCtrl = TextEditingController();

  String? _selectedItemId;
  String? _selectedIndentId;
  bool _directToAvailable = true;
  String? _uploadedUrl;
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  String _itemSearchQuery = '';

  @override
  void initState() {
    super.initState();

    if (widget.initialItemId != null && widget.initialItemId!.isNotEmpty) {
      _selectedItemId = widget.initialItemId;
    }
    if (widget.initialIndentId != null && widget.initialIndentId!.isNotEmpty) {
      _selectedIndentId = widget.initialIndentId;
    }
    if (widget.initialIndentQty != null && widget.initialIndentQty! > 0) {
      final q = widget.initialIndentQty!;
      _rackQtyCtrl.text = q is int ? '$q' : (q % 1 == 0 ? '${q.toInt()}' : '$q');
    }

    _rack = StoreRack(
      id: '',
      roomId: '',
      roomName: '',
      code: '',
      remark: '',
      itemId: [],
      isScrap: false,
    );

  }

  @override
  void dispose() {
    _imageUrlCtrl.dispose();
    _rackQtyCtrl.dispose();
    _unitPriceCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(findOneRackStreamProvider(widget.rackId));
    ref.invalidate(rackItemListStreamProvider(widget.rackId));
    ref.invalidate(refillRequestsListProvider);
    ref.invalidate(pendingRefillRequestsCountProvider);
    if (_selectedItemId != null && _selectedItemId!.isNotEmpty) {
      ref.invalidate(uncreditedApprovedIndentsProvider(_selectedItemId!));
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  StoreItemsModel? _selectedItemFrom(List<StoreItemsModel> items) {
    if (items.isEmpty) return null;

    if (_selectedItemId != null) {
      for (final it in items) {
        if (it.id == _selectedItemId) return it;
      }
    }

    return null;
  }

  Future<void> _pickImage([ImageSource? source]) async {
    if (source == null) {
      _showImageSourceSheet();
      return;
    }
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (file == null) return;

    final bytes = await file.readAsBytes();

    if (!mounted) return;
    setState(() {
      _pickedImage = file;
      _pickedBytes = bytes;
      _uploadedUrl = null;
      _imageUrlCtrl.clear();
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      elevation: 8,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Select Photo Source',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink900,
                  ),
                ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _stroke, width: 1),
                ),
                tileColor: _surfaceAlt.withValues(alpha: 0.6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: _ink900, size: 22),
                ),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Capture using camera',
                  style: TextStyle(color: _ink600, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: _ink600),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: _stroke, width: 1),
                ),
                tileColor: _surfaceAlt.withValues(alpha: 0.6),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: _ink900, size: 22),
                ),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Select from photos',
                  style: TextStyle(color: _ink600, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: _ink600),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _removePickedImage() {
    setState(() {
      _pickedImage = null;
      _pickedBytes = null;
      _uploadedUrl = null;
      _imageUrlCtrl.clear();
    });
  }

  String _mimeFromFileName(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/png';
  }

  Future<void> _uploadPickedImage(String receiveId) async {
    if (_pickedImage == null) return;

    final bytes = _pickedBytes ?? await _pickedImage!.readAsBytes();
    final mime = _mimeFromFileName(_pickedImage!.name);
    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    final upload = await ref
        .read(storeReceiveControllerProvider)
        .uploadReceiveImageBase64(receiveId: receiveId, dataUrl: dataUrl);

    if (upload["ok"] == true) {
      final imageUrl = (upload["imageUrl"] ?? '').toString();
      if (mounted) {
        setState(() {
          _uploadedUrl = imageUrl;
          _imageUrlCtrl.text = imageUrl;
        });
      }
    } else {
      throw Exception('Image upload failed');
    }
  }

  Future<void> _confirmReceiveItem({
    required String itemId,
    required TextEditingController qtyCtrl,
  }) async {
    if (_busy || _hasSubmitted) return;
    final isGrnEnabled = ref.read(storeCartConfigProvider).grnWorkflowEnabled;
    int qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0 && widget.initialIndentQty != null && widget.initialIndentQty! > 0) {
      qty = widget.initialIndentQty!.toInt();
      qtyCtrl.text = '$qty';
    } else if (!isGrnEnabled && qty <= 0) {
      qty = 1;
    }
    if (qty <= 0) {
      _snack('Enter valid quantity (>0)');
      return;
    }

    setState(() => _busy = true);

    try {
      String receivedBy =
          await ref.read(spRepositoryProvider).getStringValue('uid');
      if (receivedBy.isEmpty) {
        receivedBy = ref.read(authModelProvider)?.uid ?? '';
      }

      if (receivedBy.isEmpty) {
        _snack('User session expired. Please log in again.');
        setState(() => _busy = false);
        return;
      }

      final unitPrice = double.tryParse(_unitPriceCtrl.text.trim());

      if (_selectedIndentId != null && _selectedIndentId!.isNotEmpty) {
        try {
          final assignedRacks = await ref
              .read(storeRackControllerProvider)
              .getRacksByItem(itemId);
          if (assignedRacks.isNotEmpty) {
            final isMatch = assignedRacks.any((r) =>
                (r['_id'] ?? r['id'])?.toString() == widget.rackId ||
                (r['code'] ?? '')?.toString().toUpperCase() == widget.rackId.toUpperCase() ||
                (r['rackName'] ?? '')?.toString().toUpperCase() == widget.rackId.toUpperCase());
            if (!isMatch) {
              final assignedCodes = assignedRacks
                  .map((r) =>
                      r['code']?.toString() ?? r['rackName']?.toString() ?? '')
                  .where((s) => s.isNotEmpty)
                  .join(', ');
              _snack('Wrong Rack! This item is assigned in some other rack ($assignedCodes). Newly received stock must be placed in the same rack.');
              setState(() => _busy = false);
              return;
            }
          }
        } catch (_) {}
      }

      final success = await ref
          .read(storeReceiveControllerProvider)
          .receiveItem(
            itemId: itemId,
            qty: qty,
            receivedBy: receivedBy,
            rackId: widget.rackId,
            indentId: _selectedIndentId,
            autoIssue: !_directToAvailable,
            unitPrice: unitPrice != null && unitPrice > 0 ? unitPrice : null,
          );

      final ok = success["ok"] == true;
      final receiveId = (success["id"] ?? '').toString();

      if (!ok || receiveId.isEmpty) {
        setState(() => _busy = false);
        return;
      }

      _hasSubmitted = true;

      bool imageUploaded = true;
      if (_pickedImage != null) {
        try {
          await _uploadPickedImage(receiveId);
        } catch (_) {
          imageUploaded = false;
        }
      }

      _refresh();

      if (!mounted) return;

      qtyCtrl.clear();
      _unitPriceCtrl.clear();
      setState(() {
        _pickedImage = null;
        _pickedBytes = null;
      });

      if (imageUploaded) {
        _snack('Item received successfully');
      } else {
        _snack('Item received successfully (picture not uploaded)');
      }

      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildIndentSelector(String itemId) {
    final isInitialIndentBound = widget.initialIndentId != null && widget.initialIndentId!.isNotEmpty;
    final indentsAv = ref.watch(uncreditedApprovedIndentsProvider(itemId));

    return indentsAv.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text(
                'Checking pending indent requests...',
                style: TextStyle(fontSize: 11.5, color: _ink600),
              ),
            ],
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (indents) {
        if (_selectedIndentId != null) {
          final matched = indents.where((x) => x.id == _selectedIndentId).toList();
          if (matched.isNotEmpty) {
            _cachedBoundIndent = matched.first;
            if (_rackQtyCtrl.text.isEmpty || _rackQtyCtrl.text == '0') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && (_rackQtyCtrl.text.isEmpty || _rackQtyCtrl.text == '0')) {
                  setState(() {
                    _rackQtyCtrl.text = '${matched.first.indentQty}';
                    _directToAvailable = !matched.first.isIssueShortage;
                  });
                }
              });
            }
          }
        }
        if (indents.isEmpty && !isInitialIndentBound) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F9F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _stroke),
            ),
            child: const Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 15, color: _ink600),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'No pending approved indents for this item (Direct Stock In)',
                    style: TextStyle(
                      fontSize: 11,
                      color: _ink600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _selectedIndentId != null
                ? const Color(0xFFE8F5E9).withValues(alpha: 0.6)
                : const Color(0xFFFAF8F0),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selectedIndentId != null
                  ? const Color(0xFF81C784)
                  : _stroke,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    size: 18,
                    color: _selectedIndentId != null
                        ? const Color(0xFF2E7D32)
                        : _ink700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isInitialIndentBound ? 'Approved Indent Request' : 'Against Indent Request (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _ink900,
                      ),
                    ),
                  ),
                  if (_selectedIndentId != null && !isInitialIndentBound)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedIndentId = null;
                          _directToAvailable = true;
                          _rackQtyCtrl.clear();
                        });
                      },
                      child: const Text(
                        'Clear',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFC62828),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (isInitialIndentBound) ...[
                Builder(
                  builder: (_) {
                    final matched = indents.where((x) => x.id == _selectedIndentId).toList();
                    if (matched.isNotEmpty) {
                      _cachedBoundIndent = matched.first;
                    }
                    final selectedIndent = matched.isNotEmpty ? matched.first : _cachedBoundIndent;
                    final reqName = (selectedIndent?.requestedBy.isNotEmpty == true)
                        ? selectedIndent!.requestedBy
                        : 'Requester';
                    final numStr = selectedIndent != null
                        ? (selectedIndent.indentNumber.isNotEmpty
                            ? selectedIndent.indentNumber
                            : (selectedIndent.requestNo.isNotEmpty
                                ? selectedIndent.requestNo
                                : (widget.initialIndentNumber?.isNotEmpty == true
                                    ? widget.initialIndentNumber!
                                    : 'Indent Refill')))
                        : (widget.initialIndentNumber?.isNotEmpty == true
                            ? widget.initialIndentNumber!
                            : 'Indent Refill');
                    final originTag = selectedIndent != null
                        ? (selectedIndent.isIssueShortage
                            ? 'SHORTAGE ($reqName) ➔ Reserved'
                            : (selectedIndent.isAutoRefill
                                ? 'AUTO REFILL ➔ Available'
                                : 'STORE REFILL ➔ Available'))
                        : 'STORE REFILL ➔ Available';
                    final qVal = selectedIndent?.indentQty ?? widget.initialIndentQty;
                    final qLabel = qVal != null
                        ? (qVal is int ? '$qVal' : (qVal % 1 == 0 ? '${qVal.toInt()}' : '$qVal'))
                        : '';

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _stroke),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  numStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _ink900,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  originTag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _ink700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (qLabel.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFA5D6A7)),
                              ),
                              child: Text(
                                'Qty: $qLabel',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  key: ValueKey(_selectedIndentId),
                  isExpanded: true,
                  initialValue: _selectedIndentId,
                  dropdownColor: Colors.white,
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                  hint: const Text(
                    'Select approved indent (Origin determines destination)',
                    style: TextStyle(fontSize: 11.5, color: _ink600),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        'None (General Direct In ➔ Available Stock)',
                        style: TextStyle(fontSize: 12, color: _ink600),
                      ),
                    ),
                    ...indents.map((ind) {
                      final reqName =
                          ind.requestedBy.isNotEmpty ? ind.requestedBy : 'Requester';
                      final numStr = ind.indentNumber.isNotEmpty
                          ? ind.indentNumber
                          : ind.requestNo;
                      final originTag = ind.isIssueShortage
                          ? '🟠 SHORTAGE ($reqName) ➔ Reserved'
                          : (ind.isAutoRefill
                              ? '🟣 AUTO REFILL ➔ Available'
                              : '🟢 STORE REFILL ➔ Available');
                      return DropdownMenuItem<String>(
                        value: ind.id,
                        child: Text(
                          '$numStr • Qty: ${ind.indentQty} • $originTag',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _ink900,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedIndentId = val;
                      if (val != null) {
                        final matched =
                            indents.where((x) => x.id == val).toList();
                        if (matched.isNotEmpty) {
                          final q = matched.first.indentQty;
                          _rackQtyCtrl.text = q is int ? '$q' : (q % 1 == 0 ? '${q.toInt()}' : '$q');
                          // 🌟 Locked System Routing:
                          // Issue demand shortage -> Reserved for requester
                          // Store refill or Auto refill -> Available Stock
                          _directToAvailable = !matched.first.isIssueShortage;
                        }
                      } else {
                        _directToAvailable = true;
                        _rackQtyCtrl.clear();
                      }
                    });
                  },
                ),
              ],
              if (_selectedIndentId != null) ...[
                Builder(
                  builder: (_) {
                    final matched =
                        indents.where((x) => x.id == _selectedIndentId).toList();
                    final selectedIndent =
                        matched.isNotEmpty ? matched.first : null;
                    final isShortage = selectedIndent?.isIssueShortage == true;
                    final isAvailable = !isShortage;

                    return Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isAvailable
                              ? const Color(0xFFA5D6A7)
                              : const Color(0xFFFFE082),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isAvailable
                                ? Icons.inventory_2_rounded
                                : Icons.assignment_ind_rounded,
                            size: 24,
                            color: isAvailable
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 3,
                                  children: [
                                    Text(
                                      isAvailable
                                          ? 'Destination: Available Stock'
                                          : 'Destination: Reserved for Requester',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: isAvailable
                                            ? const Color(0xFF1B5E20)
                                            : const Color(0xFFE65100),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isShortage
                                            ? const Color(0xFFFFE0B2)
                                            : const Color(0xFFC8E6C9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isShortage
                                            ? 'Shortage Deficit'
                                            : (selectedIndent?.isAutoRefill == true
                                                ? 'Auto Refill'
                                                : 'Store Refill'),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: isShortage
                                              ? const Color(0xFFE65100)
                                              : const Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isAvailable
                                      ? 'General store refill: Directly credited to Available Stock on this rack for all.'
                                      : 'Worker shortage: Stock will be locked & reserved for ${selectedIndent?.requestedBy ?? 'requester'}.',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: Color(0xFF555555),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Locked System Badge (Zero operator tampering)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isAvailable
                                    ? const Color(0xFFA5D6A7)
                                    : const Color(0xFFFFE082),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 11,
                                  color: isAvailable
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: isAvailable
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFE65100),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildImagePicker() {
    final isGrnEnabled = ref.watch(storeCartConfigProvider).grnWorkflowEnabled;
    if (isGrnEnabled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFA5D6A7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2E7D32),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'GRN Challan Photo Verified',
                  style: TextStyle(
                    color: Color(0xFF1B5E20),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Supplier challan / invoice photo was already uploaded in the approved GRN. Photo upload is NOT required here.',
              style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11.5),
            ),
            if (_pickedBytes != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _pickedBytes!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _busy ? null : _removePickedImage,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC62828),
                  iconColor: const Color(0xFFC62828),
                ),
                icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC62828)),
                label: const Text('Remove extra photo'),
              ),
            ] else ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: _busy ? null : _pickImage,
                style: TextButton.styleFrom(
                  foregroundColor: _ink900,
                  iconColor: _ink900,
                ),
                icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _ink900),
                label: const Text('Attach extra photo (optional)'),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Receive Image',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_pickedBytes != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                _pickedBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickImage,
                    icon: const Icon(Icons.edit_outlined, size: 16, color: _ink900),
                    label: const Text('Change Image'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink900,
                      iconColor: _ink900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _removePickedImage,
                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFC62828)),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFC62828),
                      iconColor: const Color(0xFFC62828),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            InkWell(
              onTap: _busy ? null : _pickImage,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 34, color: _ink700),
                    SizedBox(height: 8),
                    Text(
                      'Tap to add receive image',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'JPG, JPEG, PNG, WEBP',
                      style: TextStyle(color: _ink600, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if ((_uploadedUrl ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Uploaded: $_uploadedUrl',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink600, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rackAv = ref.watch(findOneRackStreamProvider(widget.rackId));

    if (rackAv.value == null) {
      return Scaffold(
        backgroundColor: _surface,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          iconTheme: const IconThemeData(color: _ink900),
          title: const Text(
            'Rack Receive',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_bgTop, _bgBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: const Center(
            child: Text(
              "Item Data is not available",
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surfaceAlt,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Rack Receive',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: rackAv.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading rack data: $e')),
            data: (rackData) {
              _rack = rackData!;
              final isGrnEnabled = ref.watch(storeCartConfigProvider).grnWorkflowEnabled;

              final rackItemsAv = ref.watch(
                rackItemListStreamProvider(widget.rackId),
              );

              final isItemFixed = widget.initialItemId != null && widget.initialItemId!.isNotEmpty;
              final rackItems = rackItemsAv.value ?? <StoreItemsModel>[];

              if (rackItemsAv.isLoading && rackItems.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (rackItems.isEmpty && !isItemFixed) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InfoRow(label: 'Rack Code', value: _rack.code),
                    _InfoRow(label: 'Room', value: _rack.roomName),
                    _InfoRow(label: 'Remark', value: _rack.remark),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _stroke),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFEBEE),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_off_rounded,
                              size: 32,
                              color: Color(0xFFD32F2F),
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'No Items Mapped to this Location',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Only items mapped to rack ${_rack.code} (${_rack.roomName}) can be received here. Please map items to this rack in Item Settings first.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _ink600,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              final filteredList = _itemSearchQuery.isEmpty
                  ? rackItems
                  : rackItems.where((it) {
                      final q = _itemSearchQuery.toLowerCase();
                      return it.itemName.toLowerCase().contains(q) ||
                          it.itemCode.toLowerCase().contains(q);
                    }).toList();

              final displayList = List<StoreItemsModel>.from(filteredList);
              if (_selectedItemId != null &&
                  !displayList.any((e) => e.id == _selectedItemId)) {
                final sel =
                    rackItems.where((e) => e.id == _selectedItemId).firstOrNull;
                if (sel != null) displayList.insert(0, sel);
              }

              final fallbackItem = isItemFixed
                  ? ref.watch(itemFindOneStreamProvider(widget.initialItemId!)).asData?.value
                  : null;
              final selectedItem = _selectedItemFrom(rackItems) ?? fallbackItem;
              final itemReady = selectedItem != null;

              if (selectedItem != null) {
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(label: 'Rack Code', value: _rack.code),
                  _InfoRow(label: 'Room', value: _rack.roomName),
                  _InfoRow(label: 'Remark', value: _rack.remark),
                  const SizedBox(height: 12),
                  if (!isItemFixed) ...[
                    // Search box for quick filtering
                    TextField(
                    style: const TextStyle(
                      color: _ink900,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    cursorColor: _ink900,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search items mapped to this rack...',
                      hintStyle: const TextStyle(
                        color: _ink600,
                        fontSize: 12.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: _ink600,
                      ),
                      suffixIcon: _itemSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: _ink700),
                              onPressed: () =>
                                  setState(() => _itemSearchQuery = ''),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                    onChanged: (v) =>
                        setState(() => _itemSearchQuery = v.trim().toLowerCase()),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedItemId,
                    isExpanded: true,
                    dropdownColor: _surfaceAlt,
                    itemHeight: 52,
                    selectedItemBuilder: (ctx) {
                      return displayList.map((it) {
                        final label = '${it.itemName} • ${it.itemCode}';
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      }).toList();
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      constraints: const BoxConstraints(
                        minHeight: 44,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      prefixIcon: const Icon(
                        Icons.inventory_2_rounded,
                        color: _ink600,
                        size: 20,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      filled: true,
                      fillColor: _surface,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _ink900,
                          width: 1.2,
                        ),
                      ),
                    ),
                    hint: const Text(
                      'Select Item',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _ink600,
                      size: 22,
                    ),
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                    ),
                    items: displayList.map((it) {
                      final isSel =
                          (_selectedItemId != null && _selectedItemId == it.id);
                      final label = '${it.itemName} • ${it.itemCode}';

                      return DropdownMenuItem<String>(
                        value: it.id,
                        child: Container(
                          height: 44,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSel
                                ? _accentMint.withValues(alpha: .35)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _ink900,
                              fontWeight:
                                  isSel ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedItemId = v;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  if (!itemReady)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Please select an item to continue.",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (itemReady) ...[
                            _InfoRow(
                              label: 'Item Name',
                              value: selectedItem.itemName,
                            ),
                            _InfoRow(
                              label: 'Item Code',
                              value: selectedItem.itemCode,
                            ),
                            _InfoRow(
                              label: 'Available Stock',
                              value: '${selectedItem.stockAvailableQuantity}',
                            ),
                            _InfoRow(
                              label: 'Total Stock',
                              value: '${selectedItem.totalStockQuantity}',
                            ),
                            const SizedBox(height: 12),
                            _buildIndentSelector(selectedItem.id),
                            if (isGrnEnabled) ...[
                              const SizedBox(height: 8),
                              Builder(
                                builder: (context) {
                                  final isQuantityLocked = (_selectedIndentId != null && _selectedIndentId!.isNotEmpty) ||
                                      (widget.initialIndentId != null && widget.initialIndentId!.isNotEmpty);

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Row(
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: Row(
                                              children: [
                                                Text(
                                                  'Receive Quantity',
                                                  style: TextStyle(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: _ink900,
                                                  ),
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  '*',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w900,
                                                    color: Color(0xFFC62828),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            flex: 5,
                                            child: Text(
                                              'Purchase Rate',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: _ink900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Expanded(
                                            flex: 6,
                                            child: TextField(
                                              controller: _rackQtyCtrl,
                                              readOnly: isQuantityLocked,
                                              showCursor: !isQuantityLocked,
                                              enableInteractiveSelection: !isQuantityLocked,
                                              keyboardType: TextInputType.number,
                                              cursorColor: _ink900,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                                prefixIcon: const Icon(
                                                  Icons.add_shopping_cart_rounded,
                                                  color: _ink900,
                                                  size: 19,
                                                ),
                                                prefixIconConstraints: const BoxConstraints(
                                                  minWidth: 38,
                                                  minHeight: 38,
                                                ),
                                                hintText: 'Qty (e.g. 10)',
                                                hintStyle: const TextStyle(
                                                  color: _ink600,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                labelText: 'Quantity',
                                                labelStyle: const TextStyle(
                                                  color: _ink700,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                floatingLabelStyle: const TextStyle(
                                                  color: _ink900,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                    color: _ink900,
                                                    width: 1.8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 5,
                                            child: TextField(
                                              controller: _unitPriceCtrl,
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              cursorColor: _ink900,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14.5,
                                              ),
                                              decoration: InputDecoration(
                                                isDense: true,
                                                contentPadding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 12,
                                                ),
                                                prefixText: '₹ ',
                                                prefixStyle: const TextStyle(
                                                  color: _ink900,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                                hintText: 'Rate / pc',
                                                hintStyle: const TextStyle(
                                                  color: _ink600,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                labelText: 'Purchase Rate',
                                                labelStyle: const TextStyle(
                                                  color: _ink700,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                floatingLabelStyle: const TextStyle(
                                                  color: _ink900,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(color: _stroke, width: 1.2),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(10),
                                                  borderSide: const BorderSide(
                                                    color: _ink900,
                                                    width: 1.8,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            _buildImagePicker(),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _ink900,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: _ink900.withValues(alpha: 0.35),
                                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  elevation: 1,
                                ),
                                onPressed:
                                    (_busy || _hasSubmitted || !itemReady)
                                        ? null
                                        : () => _confirmReceiveItem(
                                          itemId: selectedItem.id,
                                          qtyCtrl: _rackQtyCtrl,
                                        ),
                                icon:
                                    _busy
                                        ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                        : const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                                label: Text(
                                  _busy
                                      ? 'Adding...'
                                      : (itemReady ? 'Add Item' : 'Select Item'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    ),
  ),
);
}
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _ink900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: _ink700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
