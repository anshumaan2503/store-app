// lib/views/bags/bag_form_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/item_model.dart';
import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

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

  InputDecoration _decor({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      hintStyle: const TextStyle(color: _ink600, fontWeight: FontWeight.w700),
      prefixIcon: Icon(icon, color: _ink600),
      filled: true,
      fillColor: _surfaceAlt.withValues(alpha: .55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _stroke),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _stroke),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _ink900, width: 1.2),
      ),
    );
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _createBag() async {
    if (!_formKey.currentState!.validate()) return;

    final maxQty = _int(_maxQtyCtrl.text);
    if (maxQty <= 0) {
      _snack('Max Qty must be > 0');
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
    };

    await ref.read(bagControllerProvider.notifier).createBag(bag: payload);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _updateBag(List<ItemModel> items) async {
    if (!_formKey.currentState!.validate()) return;

    final existing = widget.existingBag;
    if (existing?.id == null) return;

    final maxQty = _int(_maxQtyCtrl.text);
    if (maxQty <= 0) {
      _snack('Max Qty must be > 0');
      return;
    }

    if (_currentStock > maxQty) {
      _snack('Stock cannot exceed Max Qty ($maxQty)');
      return;
    }

    final canChangeItem = _currentStock == 0;
    if (canChangeItem) {
      final itemId = (_selectedItemId ?? '').trim();
      if (itemId.isEmpty) {
        _snack('Please select an item');
        return;
      }
    }

    String? itemName;
    final selectedId = (_selectedItemId ?? '').trim();
    if (selectedId.isNotEmpty) {
      final found = items.where(
        (e) => (e.id ?? '').toString().trim() == selectedId,
      );
      if (found.isNotEmpty) itemName = found.first.name;
    }

    final payload = <String, dynamic>{
      'id': existing!.id,
      'bagCode': _bagCodeCtrl.text.trim(),
      'maxQty': maxQty,
      'itemStock': _currentStock,
      'itemUsed': existing.itemUsed,
      'approvedStatus': existing.approvedStatus,
      'transferQty': existing.transferQty,
      'transferType': existing.transferType,
    };

    if (selectedId.isNotEmpty) {
      payload['itemId'] = selectedId;
      payload['itemName'] = itemName ?? existing.itemName;
    }

    await ref.read(bagControllerProvider.notifier).updateBag(bag: payload);

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _openAddStockPopup({required BagModel bag}) async {
    final qtyCtrl = TextEditingController(text: '');

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Add Stock To Bag',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bag: ${bag.bagCode}',
                style: const TextStyle(color: _ink700),
              ),
              Text(
                'Item: ${bag.itemName.isNotEmpty ? bag.itemName : "-"}',
                style: const TextStyle(color: _ink700),
              ),
              const SizedBox(height: 8),
              Text(
                'Current Stock: $_currentStock',
                style: const TextStyle(color: _ink700),
              ),
              Text(
                'Max Qty: ${_int(_maxQtyCtrl.text)}',
                style: const TextStyle(color: _ink700),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: _decor(
                  label: 'Add Qty',
                  icon: Icons.add_circle_outline_rounded,
                ),
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isLoading = ref.watch(bagControllerProvider);
                return FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                  ),
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            final addQty =
                                int.tryParse(qtyCtrl.text.trim()) ?? 0;
                            if (addQty <= 0) {
                              _snack('Enter valid qty');
                              return;
                            }

                            final maxQty = _int(_maxQtyCtrl.text);
                            final nextStock = _currentStock + addQty;

                            if (nextStock > maxQty) {
                              _snack('Cannot exceed Max Qty ($maxQty)');
                              return;
                            }

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
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Text(
          _isEdit ? 'Edit Bag' : 'Create Bag',
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
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
        child: SafeArea(
          child: itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error loading items: $e')),
            data: (items) {
              final itemMap = <String, ItemModel>{};
              for (final it in items) {
                final id = (it.id ?? '').toString().trim();
                if (id.isEmpty) continue;
                itemMap[id] = it;
              }

              final selectedId = (_selectedItemId ?? '').trim();
              final safeSelectedItemId =
                  itemMap.containsKey(selectedId) ? selectedId : null;

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _Card(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _isEdit ? 'Update Bag Details' : 'Bag Details',
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 14),

                            TextFormField(
                              controller: _bagCodeCtrl,
                              decoration: _decor(
                                label: 'Bag Code *',
                                icon: Icons.qr_code_2_rounded,
                                hint: 'e.g., BAG-0001',
                              ),
                              validator:
                                  (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Required'
                                          : null,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),

                            TextFormField(
                              controller: _maxQtyCtrl,
                              keyboardType: TextInputType.number,
                              decoration: _decor(
                                label: 'Max Qty *',
                                icon: Icons.speed_rounded,
                                hint: 'e.g., 1000',
                              ),
                              validator: (v) {
                                final n = int.tryParse((v ?? '').trim());
                                if (n == null) return 'Enter number';
                                if (n <= 0) return 'Max Qty must be > 0';
                                return null;
                              },
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),

                            if (_isEdit) ...[
                              TextFormField(
                                initialValue: _currentStock.toString(),
                                readOnly: true,
                                decoration: _decor(
                                  label: 'Item Stock (current)',
                                  icon: Icons.inventory_rounded,
                                ),
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),

                              DropdownButtonFormField<String>(
                                initialValue: safeSelectedItemId,
                                items:
                                    itemMap.values.map((it) {
                                      final id = it.id!.toString().trim();
                                      return DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(
                                          '${it.code} - ${it.name}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }).toList(),
                                onChanged:
                                    canChangeItem
                                        ? (v) =>
                                            setState(() => _selectedItemId = v)
                                        : null,
                                dropdownColor: _surface,
                                decoration: _decor(
                                  label:
                                      canChangeItem
                                          ? 'Select Item *'
                                          : 'Item (locked because stock > 0)',
                                  icon: Icons.category_rounded,
                                ),
                                validator: (v) {
                                  if (canChangeItem) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Required';
                                    }
                                  }
                                  return null;
                                },
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if ((widget.existingBag?.itemId ?? '')
                                  .trim()
                                  .isNotEmpty)
                                _SecondaryBtn(
                                  label: 'Add Stock to Bag',
                                  icon: Icons.add_circle_outline_rounded,
                                  onTap:
                                      isLoading
                                          ? null
                                          : () => _openAddStockPopup(
                                            bag: widget.existingBag!,
                                          ),
                                ),
                              const SizedBox(height: 14),
                            ],

                            _PrimaryBtn(
                              label:
                                  isLoading
                                      ? 'Saving...'
                                      : (_isEdit ? 'Update' : 'Create'),
                              busy: isLoading,
                              onTap:
                                  isLoading
                                      ? null
                                      : () async {
                                        if (_isEdit) {
                                          await _updateBag(items);
                                        } else {
                                          await _createBag();
                                        }
                                      },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ---------------- Shared UI ---------------- */

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onTap,
    required this.busy,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _surface,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 18, color: _surface),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _surface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
