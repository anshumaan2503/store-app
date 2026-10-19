// lib/views/bags/bag_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/item_model.dart';
import '../../../../controllers/item_controller.dart'; // itemAllDataStreamProvider
import '../../../../controllers/bag_controller.dart'; // bagControllerProvider

class BagFormView extends ConsumerStatefulWidget {
  final BagModel? existingBag;

  const BagFormView({super.key, this.existingBag});

  @override
  ConsumerState<BagFormView> createState() => _BagFormViewState();
}

class _BagFormViewState extends ConsumerState<BagFormView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _bagCodeCtrl;
  late TextEditingController _maxQtyCtrl;

  // NOTE:
  // - Create: itemStock is always 0 (not shown as editable field)
  // - Edit: itemStock shown (read-only) and Add Stock button modifies it
  int _currentStock = 0;

  String? _selectedItemId;

  bool get _isEdit => widget.existingBag != null;

  @override
  void initState() {
    super.initState();
    final bag = widget.existingBag;

    _bagCodeCtrl = TextEditingController(text: bag?.bagCode ?? '');
    _maxQtyCtrl = TextEditingController(text: ((bag?.maxQty ?? 0)).toString());

    _currentStock = bag?.itemStock ?? 0;

    // IMPORTANT: never store '' as dropdown value
    final initialItemId = (bag?.itemId ?? '').trim();
    _selectedItemId = initialItemId.isEmpty ? null : initialItemId;
  }

  @override
  void dispose() {
    _bagCodeCtrl.dispose();
    _maxQtyCtrl.dispose();
    super.dispose();
  }

  int _int(String v) => int.tryParse(v.trim()) ?? 0;

  // Create: no item selection, stock=0
  Future<void> _createBag() async {
    if (!_formKey.currentState!.validate()) return;

    final maxQty = _int(_maxQtyCtrl.text);
    if (maxQty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max Qty must be > 0')));
      return;
    }

    final payload = <String, dynamic>{
      'bagCode': _bagCodeCtrl.text.trim(),
      'maxQty': maxQty,
      'itemStock': 0,
      'itemUsed': 0,
      'approvedStatus': 'pending',
      'transferQty': 0,
      'transferType': 'inStock',
      // DO NOT send itemId / itemName in create
    };

    await ref.read(bagControllerProvider.notifier).createBag(bag: payload);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  // Edit:
  // - item can be set/changed only if stock == 0
  // - itemStock cannot exceed maxQty (also enforced by backend)
  Future<void> _updateBag(List<ItemModel> items) async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existingBag;
    if (existing?.id == null) return;

    final maxQty = _int(_maxQtyCtrl.text);
    if (maxQty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max Qty must be > 0')));
      return;
    }

    if (_currentStock > maxQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stock cannot exceed Max Qty ($maxQty)')),
      );
      return;
    }

    // If item is changeable, it must be selected
    final canChangeItem = _currentStock == 0;
    if (canChangeItem) {
      final itemId = (_selectedItemId ?? '').trim();
      if (itemId.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Please select an item')));
        return;
      }
    }

    // Resolve item name if itemId exists
    String? itemName;
    final selectedId = (_selectedItemId ?? '').trim();
    if (selectedId.isNotEmpty) {
      final found = items.where(
        (e) => (e.id ?? '').toString().trim() == selectedId,
      );
      if (found.isNotEmpty) {
        itemName = found.first.name;
      }
    }

    final payload = <String, dynamic>{
      'id': existing!.id,
      'bagCode': _bagCodeCtrl.text.trim(),
      'maxQty': maxQty,
      'itemStock': _currentStock,
      // keep your existing fields as you do
      'itemUsed': existing.itemUsed,
      'approvedStatus': existing.approvedStatus,
      'transferQty': existing.transferQty,
      'transferType': existing.transferType,
    };

    // Only send item fields if selected (and allowed)
    if (selectedId.isNotEmpty) {
      payload['itemId'] = selectedId;
      payload['itemName'] = itemName ?? (existing.itemName);
    }

    await ref.read(bagControllerProvider.notifier).updateBag(bag: payload);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openAddStockPopup({required BagModel bag}) async {
    final qtyCtrl = TextEditingController(text: '');

    void snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Add Stock To Bag'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bag: ${bag.bagCode}'),
              Text('Item: ${bag.itemName.isNotEmpty ? bag.itemName : "-"}'),
              const SizedBox(height: 8),
              Text('Current Stock: $_currentStock'),
              Text('Max Qty: ${_int(_maxQtyCtrl.text)}'),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Add Qty',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isLoading = ref.watch(bagControllerProvider);
                return ElevatedButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final addQty =
                                int.tryParse(qtyCtrl.text.trim()) ?? 0;
                            if (addQty <= 0) {
                              snack('Enter valid qty');
                              return;
                            }

                            final maxQty = _int(_maxQtyCtrl.text);
                            final nextStock = _currentStock + addQty;

                            if (nextStock > maxQty) {
                              snack('Cannot exceed Max Qty ($maxQty)');
                              return;
                            }

                            // Update bag stock by updating the whole bag (simple approach)
                            final payload = <String, dynamic>{
                              'id': bag.id,
                              'bagCode': _bagCodeCtrl.text.trim(),
                              'maxQty': maxQty,
                              'itemStock': nextStock,
                              'itemId': (bag.itemId ?? '').trim(),
                              'itemName': bag.itemName,
                              'itemUsed': bag.itemUsed,
                              'approvedStatus': bag.approvedStatus,
                              'transferQty': bag.transferQty,
                              'transferType': bag.transferType,
                            };

                            await ref
                                .read(bagControllerProvider.notifier)
                                .updateBag(bag: payload);

                            if (!mounted) return;

                            setState(() => _currentStock = nextStock);
                            Navigator.pop(context);
                          },
                  child: Text(isLoading ? 'Saving...' : 'Add'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(bagControllerProvider);
    final itemsAsync = ref.watch(itemAllDataStreamProvider);

    final canChangeItem = _isEdit && _currentStock == 0;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Bag' : 'Create Bag')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading items: $e')),
        data: (items) {
          // ✅ Build de-duplicated map of items, exclude empty IDs
          final itemMap = <String, ItemModel>{};
          for (final it in items) {
            final id = (it.id ?? '').toString().trim();
            if (id.isEmpty) continue;
            itemMap[id] = it;
          }

          // ✅ Never pass '' to dropdown value
          final selectedId = (_selectedItemId ?? '').trim();
          final safeSelectedItemId =
              itemMap.containsKey(selectedId) ? selectedId : null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _bagCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Bag Code',
                      border: OutlineInputBorder(),
                    ),
                    validator:
                        (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // MaxQty always available
                  TextFormField(
                    controller: _maxQtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Max Qty',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null) return 'Enter number';
                      if (n <= 0) return 'Max Qty must be > 0';
                      return null;
                    },
                  ),

                  const SizedBox(height: 12),

                  if (_isEdit) ...[
                    // Show current stock read-only
                    TextFormField(
                      initialValue: _currentStock.toString(),
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Item Stock (current)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Item dropdown only in EDIT, and only changeable if stock == 0
                    DropdownButtonFormField<String>(
                      initialValue: safeSelectedItemId,
                      items:
                          itemMap.values.map((it) {
                            final id = it.id!.toString().trim();
                            return DropdownMenuItem<String>(
                              value: id,
                              child: Text('${it.code} - ${it.name}'),
                            );
                          }).toList(),
                      onChanged:
                          canChangeItem
                              ? (v) => setState(() => _selectedItemId = v)
                              : null,
                      decoration: InputDecoration(
                        labelText:
                            canChangeItem
                                ? 'Select Item'
                                : 'Item (locked because stock > 0)',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (canChangeItem) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Add Stock button only when itemId is present
                    if ((widget.existingBag?.itemId ?? '').trim().isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              isLoading
                                  ? null
                                  : () => _openAddStockPopup(
                                    bag: widget.existingBag!,
                                  ),
                          child: const Text('Add Stock to Bag'),
                        ),
                      ),

                    const SizedBox(height: 18),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          isLoading
                              ? null
                              : () async {
                                if (_isEdit) {
                                  await _updateBag(items);
                                } else {
                                  await _createBag();
                                }
                              },
                      child: Text(
                        isLoading
                            ? 'Saving...'
                            : (_isEdit ? 'Update' : 'Create'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
