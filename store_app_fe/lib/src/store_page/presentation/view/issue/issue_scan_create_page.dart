import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../cart/store_cart_page.dart';

/* ---------------- Design Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _surfaceSubtle = Color(0xFFF9F7F2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class ItemPage extends ConsumerStatefulWidget {
  final String initialItemId;
  const ItemPage({super.key, required this.initialItemId});

  @override
  ConsumerState<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends ConsumerState<ItemPage> {
  final List<Map<String, dynamic>> _lines = [];
  bool _isCategoryChecked = true; // Default to true so machine subparts appear immediately
  StoreItemsModel? _selectedItem;

  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF2563EB),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addItemToTable(StoreItemsModel item, int qty) {
    if (qty <= 0) {
      _showSnackBar('Quantity must be greater than 0', isError: true);
      return;
    }
    if (item.stockAvailableQuantity > 0 && qty > item.stockAvailableQuantity) {
      _showSnackBar(
        'Quantity cannot exceed available stock (${item.stockAvailableQuantity} ${item.unit})',
        isError: true,
      );
      return;
    }

    final existingIndex = _lines.indexWhere((l) => l["id"] == item.id);
    if (existingIndex != -1) {
      final currentRequested = _lines[existingIndex]["requestedQty"] as int;
      final newTotal = currentRequested + qty;
      if (item.stockAvailableQuantity > 0 && newTotal > item.stockAvailableQuantity) {
        _showSnackBar(
          'Total requested ($newTotal) exceeds available stock (${item.stockAvailableQuantity})',
          isError: true,
        );
        return;
      }
      setState(() {
        _lines[existingIndex]["requestedQty"] = newTotal;
      });
      _showSnackBar('Updated quantity for ${item.itemName}');
    } else {
      setState(() {
        _lines.add({
          "id": item.id,
          "itemName": item.itemName,
          "itemCode": item.itemCode,
          "rackId": item.rackId,
          "categoryId": item.categoryId,
          "categoryLabel": item.categoryLabel,
          "unit": item.unit.isEmpty ? 'PCS' : item.unit,
          "requestedQty": qty,
          "stockAvailableQuantity": item.stockAvailableQuantity,
        });
      });
      _showSnackBar('Added ${item.itemName} to issue request');
    }
  }

  void _removeItem(int index) {
    setState(() {
      _lines.removeAt(index);
    });
  }

  void _addToCartSingle(StoreItemsModel item, int qty) {
    if (qty <= 0) {
      _showSnackBar('Quantity must be greater than 0', isError: true);
      return;
    }
    final ok = ref.read(storeCartProvider.notifier).addItem(
      item,
      qty: qty,
      onStockError: (err) => _showSnackBar(err, isError: true),
    );
    if (ok) {
      _showSnackBar('Added ${item.itemName} ($qty ${item.unit}) to Requisition Cart!');
    }
  }

  void _addAllLinesToCart() {
    if (_lines.isEmpty) {
      if (_selectedItem != null) {
        final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
        _addToCartSingle(_selectedItem!, qty);
      } else {
        _showSnackBar('Select an item to add to cart', isError: true);
      }
      return;
    }

    int addedCount = 0;
    for (final l in _lines) {
      final cartItem = StoreCartItem(
        id: l["id"].toString(),
        itemName: l["itemName"].toString(),
        itemCode: l["itemCode"]?.toString() ?? '',
        unit: l["unit"]?.toString() ?? 'PCS',
        quantity: l["requestedQty"] as int,
        stockAvailableQuantity: l["stockAvailableQuantity"] as int,
        rackId: l["rackId"]?.toString(),
        categoryId: l["categoryId"]?.toString(),
        categoryLabel: l["categoryLabel"]?.toString(),
      );
      final ok = ref.read(storeCartProvider.notifier).addCartItem(
        cartItem,
        onStockError: (err) => _showSnackBar(err, isError: true),
      );
      if (ok) addedCount++;
    }

    if (addedCount > 0) {
      _showSnackBar('Added $addedCount item(s) to Cart! You can scan more items or view cart.');
      setState(() => _lines.clear());
    }
  }

  Future<void> _submitCreate() async {
    final uid = await ref.read(spRepositoryProvider).getStringValue('uid');
    if (uid.trim().isEmpty) {
      _showSnackBar('Missing user credentials. Please log in again.', isError: true);
      return;
    }
    if (_lines.isEmpty) {
      _showSnackBar('Please add at least 1 item to the request.', isError: true);
      return;
    }
    if (_reasonCtrl.text.trim().isEmpty) {
      _showSnackBar('Please provide a reason for the issue.', isError: true);
      return;
    }

    setState(() => _busy = true);
    try {
      final dto = <String, dynamic>{
        'createdBy': uid.trim(),
        'reason': _reasonCtrl.text.trim(),
        'remark': _remarkCtrl.text.trim().isEmpty ? _reasonCtrl.text.trim() : _remarkCtrl.text.trim(),
        'lines': _lines
            .map(
              (l) => {
                'itemId': l["id"],
                'requestedQty': l["requestedQty"],
              },
            )
            .toList(),
      };

      final ctrl = ref.read(issueControllerProvider);
      await ctrl.createDraft(dto);

      if (!mounted) return;
      await ref.read(storeCartProvider.notifier).clearCart();
      ref.read(globalInCartProvider.notifier).refresh();
      _showSnackBar('Issue request created successfully!');

      // Auto-direct to the item page
      ref.read(guidedTourControllerProvider).requestSection('items');

      // Close back cleanly to caller
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnackBar('Failed to create issue: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final baseItemAsync = ref.watch(oneItemAllDataStreamProvider(widget.initialItemId));
    final subItemsAsync = ref.watch(
      _isCategoryChecked
          ? parentcategoryItemAllDataStreamProvider(widget.initialItemId)
          : oneItemAllDataStreamProvider(widget.initialItemId),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: _surface,
        cardColor: _surface,
        dialogBackgroundColor: _surface,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: _surface,
          primary: const Color(0xFF2563EB),
        ),
      ),
      child: Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Create Issue Request',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(storeCartProvider);
              return Badge.count(
                count: cart.lineCount,
                isLabelVisible: cart.lineCount > 0,
                backgroundColor: _ink900,
                textColor: _surface,
                child: IconButton(
                  tooltip: 'Requisition Cart (${cart.lineCount})',
                  icon: const Icon(Icons.shopping_cart_outlined, color: _ink900),
                  onPressed: () async {
                    final cartResult = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(builder: (_) => const StoreCartPage()),
                    );
                    if (cartResult == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Scanned Machine / Base Item Summary Card
                      baseItemAsync.when(
                        data: (items) {
                          final machine = items.isNotEmpty ? items.first : null;
                          if (machine == null) return const SizedBox.shrink();
                          return _MachineHeaderCard(machine: machine);
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),

                      const SizedBox(height: 14),

                      // 2. Issue Details Card (Reason & Remark)
                      _CardSection(
                        title: 'Issue Details',
                        icon: Icons.assignment_outlined,
                        child: Column(
                          children: [
                            TextField(
                              controller: _reasonCtrl,
                              style: const TextStyle(
                                color: _ink900,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF2563EB),
                              decoration: InputDecoration(
                                labelText: 'Reason for Issue *',
                                labelStyle: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w700,
                                ),
                                hintText: 'e.g. Replacing worn parts for Hopper Machine',
                                hintStyle: TextStyle(
                                  color: _ink600.withValues(alpha: 0.55),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.edit_note_rounded, color: Color(0xFF2563EB)),
                                filled: true,
                                fillColor: _surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _stroke),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _remarkCtrl,
                              style: const TextStyle(
                                color: _ink900,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              cursorColor: const Color(0xFF2563EB),
                              decoration: InputDecoration(
                                labelText: 'Remark (Optional)',
                                labelStyle: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w700,
                                ),
                                hintText: 'e.g. Line 2 conveyor maintenance',
                                hintStyle: TextStyle(
                                  color: _ink600.withValues(alpha: 0.55),
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(Icons.comment_outlined, color: _ink700),
                                filled: true,
                                fillColor: _surface,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: _stroke),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 3. Select Item & Quantity Card
                      _CardSection(
                        title: 'Add Required Item / Part',
                        icon: Icons.add_box_outlined,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Category Filter Toggle
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _isCategoryChecked = !_isCategoryChecked;
                                  _selectedItem = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: Checkbox(
                                        value: _isCategoryChecked,
                                        activeColor: const Color(0xFF2563EB),
                                        checkColor: Colors.white,
                                        side: const BorderSide(color: _stroke, width: 1.5),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        onChanged: (v) {
                                          setState(() {
                                            _isCategoryChecked = v ?? true;
                                            _selectedItem = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Fetch Categorized Items (Machine Subparts)',
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Items Dropdown
                            subItemsAsync.when(
                              loading: () => const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              error: (e, _) => Padding(
                                padding: const EdgeInsets.all(8),
                                child: Text('Failed to load items: $e', style: const TextStyle(color: Colors.red)),
                              ),
                              data: (items) {
                                if (items.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _surfaceSubtle,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: const Text(
                                      'No parts found for this category. Uncheck "Fetch Categorized Items" to select base item.',
                                      style: TextStyle(color: _ink600, fontSize: 13),
                                    ),
                                  );
                                }

                                // If selected item is not in list, reset
                                if (_selectedItem != null && !items.any((x) => x.id == _selectedItem!.id)) {
                                  _selectedItem = null;
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<StoreItemsModel>(
                                      isExpanded: true,
                                      value: _selectedItem,
                                      dropdownColor: _surface,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      iconEnabledColor: const Color(0xFF2563EB),
                                      hint: const Text(
                                        'Select an item / spare part',
                                        style: TextStyle(color: _ink600, fontWeight: FontWeight.w600),
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down_rounded, color: _ink900),
                                      items: items.map((item) {
                                        return DropdownMenuItem<StoreItemsModel>(
                                          value: item,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.itemName,
                                                  style: const TextStyle(
                                                    color: _ink900,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: item.stockAvailableQuantity > 0
                                                      ? _accentMint.withValues(alpha: 0.35)
                                                      : Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Avl: ${item.stockAvailableQuantity} ${item.unit}',
                                                  style: TextStyle(
                                                    color: item.stockAvailableQuantity > 0
                                                        ? _ink900
                                                        : Colors.red.shade800,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedItem = val;
                                          _qtyCtrl.text = '1';
                                        });
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),

                            if (_selectedItem != null) ...[
                              const SizedBox(height: 14),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isCompact = constraints.maxWidth < 440;

                                  final stepper = Container(
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: _stroke),
                                    ),
                                    child: Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_rounded, size: 18, color: _ink900),
                                          onPressed: () {
                                            final curr = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
                                            if (curr > 1) {
                                              setState(() => _qtyCtrl.text = (curr - 1).toString());
                                            }
                                          },
                                        ),
                                        Expanded(
                                          child: TextField(
                                            controller: _qtyCtrl,
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            cursorColor: const Color(0xFF2563EB),
                                            style: const TextStyle(
                                              color: _ink900,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                            ),
                                            decoration: const InputDecoration(
                                              isDense: true,
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.zero,
                                              filled: false,
                                              fillColor: Colors.transparent,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_rounded, size: 18, color: _ink900),
                                          onPressed: () {
                                            final curr = int.tryParse(_qtyCtrl.text.trim()) ?? 1;
                                            final max = _selectedItem!.stockAvailableQuantity;
                                            if (max <= 0 || curr < max) {
                                              setState(() => _qtyCtrl.text = (curr + 1).toString());
                                            } else {
                                              _showSnackBar('Cannot exceed available stock ($max)');
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );

                                  final cartBtn = SizedBox(
                                    height: 48,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
                                        _addToCartSingle(_selectedItem!, qty);
                                      },
                                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: _ink900),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('To Cart'),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _ink900,
                                        iconColor: _ink900,
                                        side: const BorderSide(color: _stroke),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                      ),
                                    ),
                                  );

                                  final addPartBtn = SizedBox(
                                    height: 48,
                                    child: FilledButton.icon(
                                      onPressed: () {
                                        final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
                                        _addItemToTable(_selectedItem!, qty);
                                      },
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                                      label: const FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text('Add Part'),
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(0xFF2563EB),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                                      ),
                                    ),
                                  );

                                  if (isCompact) {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        stepper,
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(child: cartBtn),
                                            const SizedBox(width: 8),
                                            Expanded(child: addPartBtn),
                                          ],
                                        ),
                                      ],
                                    );
                                  }

                                  return Row(
                                    children: [
                                      Expanded(flex: 3, child: stepper),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 5,
                                        child: Row(
                                          children: [
                                            Expanded(child: cartBtn),
                                            const SizedBox(width: 6),
                                            Expanded(child: addPartBtn),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // 4. Added Items Table
                      _CardSection(
                        title: 'Requested Items (${_lines.length})',
                        icon: Icons.format_list_bulleted_rounded,
                        child: _lines.isEmpty
                            ? Container(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inventory_2_outlined,
                                      size: 40,
                                      color: _ink600.withValues(alpha: 0.4),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'No parts added to this issue yet',
                                      style: TextStyle(
                                        color: _ink600,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Select an item above and tap "Add Part"',
                                      style: TextStyle(color: _ink600, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  // Header Row
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: _surfaceSubtle,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Row(
                                      children: [
                                        Expanded(
                                          flex: 5,
                                          child: Text(
                                            'Item / Part',
                                            style: TextStyle(
                                              color: _ink700,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Center(
                                            child: Text(
                                              'Req Qty',
                                              style: TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 36),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: _lines.length,
                                    separatorBuilder: (_, __) => const Divider(height: 1, color: _stroke),
                                    itemBuilder: (context, idx) {
                                      final row = _lines[idx];
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 5,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    row["itemName"] ?? '',
                                                    style: const TextStyle(
                                                      color: _ink900,
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'Avl Stock: ${row["stockAvailableQuantity"]} ${row["unit"]}',
                                                    style: const TextStyle(
                                                      color: _ink600,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Center(
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: _surfaceAlt,
                                                    borderRadius: BorderRadius.circular(10),
                                                    border: Border.all(color: _stroke),
                                                  ),
                                                  child: Text(
                                                    '${row["requestedQty"]} ${row["unit"]}',
                                                    style: const TextStyle(
                                                      color: _ink900,
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                              tooltip: 'Remove',
                                              onPressed: () => _removeItem(idx),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Sticky Submit Bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: BoxDecoration(
                  color: _surface,
                  border: const Border(top: BorderSide(color: _stroke)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 480;

                    final countSection = Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_lines.length} Items Selected',
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _lines.isEmpty ? 'Add parts to continue' : 'Ready to create issue',
                          style: const TextStyle(color: _ink600, fontSize: 12),
                        ),
                      ],
                    );

                    final saveCartBtn = OutlinedButton.icon(
                      onPressed: _busy ? null : _addAllLinesToCart,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _ink900,
                        iconColor: _ink900,
                        side: const BorderSide(color: _stroke),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: _ink900),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Save to Cart',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                    );

                    final submitBtn = ElevatedButton(
                      onPressed: _busy || _lines.isEmpty ? null : _submitCreate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.3),
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Submit Now',
                                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                              ),
                            ),
                    );

                    if (isNarrow) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          countSection,
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              if (_lines.isNotEmpty) ...[
                                Expanded(child: saveCartBtn),
                                const SizedBox(width: 8),
                              ],
                              Expanded(child: submitBtn),
                            ],
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: countSection),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_lines.isNotEmpty) ...[
                              saveCartBtn,
                              const SizedBox(width: 8),
                            ],
                            submitBtn,
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

/* ---------------- Helper Widgets ---------------- */

class _MachineHeaderCard extends StatelessWidget {
  const _MachineHeaderCard({required this.machine});
  final StoreItemsModel machine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _surfaceAlt,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: const Icon(Icons.precision_manufacturing_rounded, color: _ink900, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  machine.itemName,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code: ${machine.itemCode} • ${machine.categoryLabel.isEmpty ? "Machine" : machine.categoryLabel}',
                  style: const TextStyle(
                    color: _ink600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
