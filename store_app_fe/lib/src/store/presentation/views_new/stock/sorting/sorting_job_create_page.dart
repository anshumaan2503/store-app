// lib/views/sorting_jobs/sorting_job_create_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/bag_model.dart';
import 'sorting_job_view_page.dart';

class SortingJobCreatePage extends ConsumerStatefulWidget {
  const SortingJobCreatePage({super.key});

  @override
  ConsumerState<SortingJobCreatePage> createState() => _SortingJobCreatePageState();
}

class _SortingJobCreatePageState extends ConsumerState<SortingJobCreatePage> {
  String? _selectedItemId;
  final _machineCtrl = TextEditingController();

  final List<_SelectedBagInput> _rows = [];

  @override
  void dispose() {
    _machineCtrl.dispose();
    super.dispose();
  }

  void _addRow() => setState(() => _rows.add(_SelectedBagInput()));
  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  Future<void> _submit(ItemModel item, List<BagModel> itemBags) async {
    final machineName = _machineCtrl.text.trim();
    if (machineName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Machine name is required')),
      );
      return;
    }

    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least 1 bag')),
      );
      return;
    }

    // validate unique bag selection
    final usedBagIds = <String>{};
    final inputBags = <Map<String, dynamic>>[];
    double totalWt = 0;

    for (final r in _rows) {
      if (r.bagId == null) continue;
      final qtyWt = r.qtyInWt;
      if (qtyWt <= 0) continue;

      if (usedBagIds.contains(r.bagId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Same bag cannot be selected twice')),
        );
        return;
      }
      usedBagIds.add(r.bagId!);

      final bag = itemBags.firstWhere((b) => b.id == r.bagId);

      if ((bag.itemStock) < qtyWt) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bag ${bag.bagCode} has insufficient stock')),
        );
        return;
      }

      inputBags.add({
        'bagId': bag.id,
        'bagCode': bag.bagCode,
        'qtyInWt': qtyWt,
      });
      totalWt += qtyWt;
    }

    if (inputBags.isEmpty || totalWt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter qty (wt) for selected bags')),
      );
      return;
    }

    if ((item.openingStock ?? 0) < totalWt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Item openingStock is insufficient (need $totalWt)')),
      );
      return;
    }

    final payload = {
      'machineName': machineName,
      'itemId': item.id,
      'itemName': item.name,
      'inputBags': inputBags,
    };

    final notifier = ref.read(sortingJobControllerProvider.notifier);
    final createdId = await notifier.createJob(payload: payload);

    if (!mounted) return;
    if (createdId != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => SortingJobViewPage(jobId: createdId)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final isLoading = ref.watch(sortingJobControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Sorting Job')),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Items error: $e')),
        data: (items) {
          return bagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Bags error: $e')),
            data: (bags) {
              final selectedItem = _selectedItemId == null
                  ? null
                  : items.firstWhere((i) => i.id == _selectedItemId);

              final itemBags = selectedItem == null
                  ? <BagModel>[]
                  : bags.where((b) => b.itemId == selectedItem.id).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: _selectedItemId,
                      decoration: const InputDecoration(
                        labelText: 'Select Item',
                        border: OutlineInputBorder(),
                      ),
                      items: items
                          .map(
                            (it) => DropdownMenuItem(
                              value: it.id,
                              child: Text('${it.code} - ${it.name} (Stock: ${it.openingStock ?? 0})'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedItemId = v;
                          _rows.clear();
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _machineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Machine Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (selectedItem == null)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Select an item first.'),
                      )
                    else ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Item Bags (${itemBags.length})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Select Bags', style: TextStyle(fontWeight: FontWeight.bold)),
                          const Spacer(),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF282321),
                              iconColor: const Color(0xFF282321),
                            ),
                            onPressed: itemBags.isEmpty ? null : _addRow,
                            icon: const Icon(Icons.add, color: Color(0xFF282321)),
                            label: const Text('Add Bag'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      ...List.generate(_rows.length, (idx) {
                        final row = _rows[idx];

                        // prevent already selected bags in dropdown
                        final selectedIds = _rows
                            .where((r) => r != row && r.bagId != null)
                            .map((r) => r.bagId!)
                            .toSet();

                        final dropdownBags = itemBags.where((b) => !selectedIds.contains(b.id)).toList();

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: row.bagId,
                                        decoration: const InputDecoration(
                                          labelText: 'Bag',
                                          border: OutlineInputBorder(),
                                        ),
                                        items: dropdownBags
                                            .map(
                                              (b) => DropdownMenuItem(
                                                value: b.id,
                                                child: Text('${b.bagCode} (Stock: ${b.itemStock})'),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(() => row.bagId = v),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () => _removeRow(idx),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty (wt)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged: (v) => row.qtyInWt = double.tryParse(v) ?? 0,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (isLoading)
                              ? null
                              : () => _submit(selectedItem, itemBags),
                          child: Text(isLoading ? 'Creating...' : 'Create Sorting Job'),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _SelectedBagInput {
  String? bagId;
  double qtyInWt = 0.0;
}
