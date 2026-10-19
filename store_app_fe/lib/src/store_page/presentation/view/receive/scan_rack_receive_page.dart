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
import '../../../controllers/store_cart_controller.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _accentPeach = Color(0xFFF3D7C0);

class ScanRackReceivePage extends ConsumerStatefulWidget {
  final String rackId;
  final String? initialItemId;

  const ScanRackReceivePage({
    super.key,
    required this.rackId,
    this.initialItemId,
  });

  @override
  ConsumerState<ScanRackReceivePage> createState() =>
      _ScanRackReceivePageState();
}

class _ScanRackReceivePageState extends ConsumerState<ScanRackReceivePage> {
  late StoreRack _rack;
  late StoreItemsModel _item;

  bool _busy = false;
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

    _rack = StoreRack(
      id: '',
      roomId: '',
      roomName: '',
      code: '',
      remark: '',
      itemId: [],
      isScrap: false,
    );

    _item = StoreItemsModel(
      id: "",
      itemCode: "",
      isScrap: false,
      itemName: "",
      rackId: [],
      categoryLabel: "",
      unit: "",
      description: "",
      totalStockQuantity: 0,
      stockAvailableQuantity: 0,
      stockIssueQuantity: 0,
      stockissueCompleted: 0,
      stockscrapQuantity: 0,
      imageUrl: "",
      maxCapacity: 0,
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
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
    final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
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
        return;
      }

      if (_pickedImage != null) {
        await _uploadPickedImage(receiveId);
      }

      _refresh();

      if (!mounted) return;

      qtyCtrl.clear();
      _unitPriceCtrl.clear();
      setState(() {
        _pickedImage = null;
        _pickedBytes = null;
      });

      _snack('Item received successfully');

      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _buildIndentSelector(String itemId) {
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
        if (indents.isEmpty) {
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
                  const Expanded(
                    child: Text(
                      'Against Indent Request (Optional)',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _ink900,
                      ),
                    ),
                  ),
                  if (_selectedIndentId != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: () {
                        setState(() {
                          _selectedIndentId = null;
                          _directToAvailable = true;
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
                        _rackQtyCtrl.text = '${matched.first.indentQty}';
                        // 🌟 Locked System Routing:
                        // Issue demand shortage -> Reserved for requester
                        // Store refill or Auto refill -> Available Stock
                        _directToAvailable = !matched.first.isIssueShortage;
                      }
                    } else {
                      _directToAvailable = true;
                    }
                  });
                },
              ),
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

              final rackItemsAv = ref.watch(
                rackItemListStreamProvider(widget.rackId),
              );
              final allItemsAv = ref.watch(itemAllPagedStreamProvider);

              final rackItems = rackItemsAv.value ?? <StoreItemsModel>[];
              final allItems = allItemsAv.value ?? <StoreItemsModel>[];

              if (rackItemsAv.isLoading &&
                  allItemsAv.isLoading &&
                  rackItems.isEmpty &&
                  allItems.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final rackItemIds = rackItems.map((e) => e.id).toSet();
              final seen = <String>{};
              final combinedList = <StoreItemsModel>[];

              // Items assigned to this rack first
              for (final it in rackItems) {
                if (seen.add(it.id)) combinedList.add(it);
              }
              // All other items in the store
              for (final it in allItems) {
                if (seen.add(it.id)) combinedList.add(it);
              }

              if (combinedList.isEmpty) {
                return const Center(
                  child: Text(
                    "No items found in store",
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                );
              }

              final filteredList = _itemSearchQuery.isEmpty
                  ? combinedList
                  : combinedList.where((it) {
                      final q = _itemSearchQuery.toLowerCase();
                      return it.itemName.toLowerCase().contains(q) ||
                          it.itemCode.toLowerCase().contains(q);
                    }).toList();

              final displayList = List<StoreItemsModel>.from(filteredList);
              if (_selectedItemId != null &&
                  !displayList.any((e) => e.id == _selectedItemId)) {
                final sel =
                    combinedList.where((e) => e.id == _selectedItemId).firstOrNull;
                if (sel != null) displayList.insert(0, sel);
              }

              final selectedItem = _selectedItemFrom(combinedList);
              final itemReady = selectedItem != null;

              if (selectedItem != null) {
                _item = selectedItem;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _InfoRow(label: 'Rack Code', value: _rack.code),
                  _InfoRow(label: 'Room', value: _rack.roomName),
                  _InfoRow(label: 'Remark', value: _rack.remark),
                  const SizedBox(height: 12),
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
                      hintText: 'Search items (e.g. Hack Saw, T-AA010)...',
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
                    value: _selectedItemId,
                    isExpanded: true,
                    dropdownColor: _surfaceAlt,
                    itemHeight: 52,
                    selectedItemBuilder: (ctx) {
                      return displayList.map((it) {
                        final isOnRack = rackItemIds.contains(it.id);
                        final label =
                            '${it.itemName} • ${it.itemCode}${isOnRack ? " (On Rack)" : ""}';
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
                      final isOnRack = rackItemIds.contains(it.id);
                      final label =
                          '${it.itemName} • ${it.itemCode}${isOnRack ? "  [On Rack]" : ""}';

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
                        final hit =
                            combinedList.where((x) => x.id == v).toList();
                        if (hit.isNotEmpty) _item = hit.first;
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
                          if (itemReady) ...[
                            _InfoRow(
                              label: 'Item Name',
                              value: selectedItem!.itemName,
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
                            const SizedBox(height: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Row(
                                        children: [
                                          const Text(
                                            'Receive Quantity',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
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
                                    const SizedBox(width: 8),
                                    Expanded(
                                      flex: 5,
                                      child: const Text(
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
                                            color: Color(0xFF2E7D32),
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
                                            color: Color(0xFF1B5E20),
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
                                              color: Color(0xFF2E7D32),
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
                                            color: Color(0xFF1B5E20),
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
                                              color: Color(0xFF2E7D32),
                                              width: 1.8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildImagePicker(),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed:
                                  (_busy || !itemReady)
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
                                        ),
                                      )
                                      : const Icon(Icons.check_rounded),
                              label: Text(
                                _busy
                                    ? 'Adding...'
                                    : (itemReady ? 'Add Item' : 'Select Item'),
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
