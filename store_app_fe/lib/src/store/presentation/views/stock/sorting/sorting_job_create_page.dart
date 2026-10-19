// lib/views/sorting_jobs/sorting_job_create_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/sorting_job_machine_model.dart';
import 'sorting_job_view_page.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class SortingJobCreatePage extends ConsumerStatefulWidget {
  const SortingJobCreatePage({super.key});

  @override
  ConsumerState<SortingJobCreatePage> createState() =>
      _SortingJobCreatePageState();
}

class _SortingJobCreatePageState extends ConsumerState<SortingJobCreatePage> {
  String? _selectedItemId;
  String? _selectedMachineId;

  final List<_SelectedBagInput> _rows = [];

  void _addRow() => setState(() => _rows.add(_SelectedBagInput()));
  void _removeRow(int i) => setState(() => _rows.removeAt(i));

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  T? _firstWhereOrNull<T>(Iterable<T> list, bool Function(T) test) {
    for (final x in list) {
      if (test(x)) return x;
    }
    return null;
  }

  Future<void> _submit(
    ItemModel item,
    MachineModel machine,
    List<BagModel> itemBags,
  ) async {
    if (_rows.isEmpty) {
      _snack('Select at least 1 bag');
      return;
    }

    // validate unique bag selection
    final usedBagIds = <String>{};
    final inputBags = <Map<String, dynamic>>[];
    double totalWt = 0;

    for (final r in _rows) {
      final id = (r.bagId ?? '').trim();
      if (id.isEmpty) continue;

      final qtyWt = r.qtyInWt;
      if (qtyWt <= 0) continue;

      if (usedBagIds.contains(id)) {
        _snack('Same bag cannot be selected twice');
        return;
      }
      usedBagIds.add(id);

      final bag = _firstWhereOrNull(itemBags, (b) => (b.id ?? '') == id);
      if (bag == null) {
        _snack('Selected bag not found. Please refresh and select again.');
        return;
      }

      if (bag.itemStock < qtyWt) {
        _snack('Bag ${bag.bagCode} has insufficient stock');
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
      _snack('Enter qty (wt) for selected bags');
      return;
    }

    if ((item.openingStock ?? 0) < totalWt) {
      _snack('Item openingStock is insufficient (need $totalWt)');
      return;
    }

    final payload = {
      'machineId': machine.id,
      'machineName': machine.machineName,
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

  /* ---------------- UI helpers (themed) ---------------- */

  InputDecoration _dec({
    required String label,
    required IconData icon,
    // String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      // hintText: hint,
      // hintStyle: TextStyle(color: _ink700),
      prefixIcon: Icon(icon, color: _ink600),
      filled: true,
      fillColor: _surfaceAlt.withValues(alpha: .55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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

  ButtonStyle _primaryBtnStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: _ink900,
      foregroundColor: _surface,
      iconColor: _surface,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }

  ButtonStyle _outlineBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _ink900,
      iconColor: _ink900,
      side: const BorderSide(color: _stroke),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(itemAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final machinesAsync = ref.watch(sortingJobMachineAllDataStreamProvider);
    final isLoading = ref.watch(sortingJobControllerProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Create Sorting Job',
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
        child: itemsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, st) => Center(
                child: Text(
                  'Items error: $e',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          data: (items) {
            return machinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, st) => Center(
                    child: Text(
                      'Machines error: $e',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              data: (machines) {
                return bagsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, st) => Center(
                        child: Text(
                          'Bags error: $e',
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  data: (bags) {
                    // ✅ SAFE item selection
                    final ItemModel? selectedItem =
                        (_selectedItemId == null)
                            ? null
                            : _firstWhereOrNull(
                              items,
                              (i) => i.id == _selectedItemId,
                            );

                    // ✅ de-duplicate machines by id + remove empty ids + only active
                    final machineMap = <String, MachineModel>{};
                    for (final m in machines) {
                      final id = (m.id ?? '').trim();
                      if (id.isEmpty) continue;
                      if (m.isActive != true) continue;
                      machineMap.putIfAbsent(id, () => m);
                    }
                    final filteredMachines = machineMap.values.toList();

                    // ✅ SAFE machine selection
                    final safeMachineId =
                        (_selectedMachineId != null &&
                                machineMap.containsKey(
                                  _selectedMachineId!.trim(),
                                ))
                            ? _selectedMachineId!.trim()
                            : null;

                    final MachineModel? selectedMachine =
                        safeMachineId == null
                            ? null
                            : machineMap[safeMachineId];

                    final itemBags =
                        (selectedItem == null)
                            ? <BagModel>[]
                            : bags
                                .where((b) => b.itemId == selectedItem.id)
                                .toList();

                    // ✅ safe item value
                    final safeItemId =
                        (_selectedItemId != null &&
                                items.any((it) => it.id == _selectedItemId))
                            ? _selectedItemId
                            : null;

                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: _Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Sorting Job Details',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 14),

                                  // -------- Item dropdown --------
                                  DropdownButtonFormField<String>(
                                    initialValue: safeItemId,
                                    decoration: _dec(
                                      label: 'Select Item',

                                      icon: Icons.category_rounded,
                                    ),
                                    hint: Text(
                                      'Choose item to sort',
                                      style: const TextStyle(color: _ink700),
                                    ),
                                    dropdownColor: _surface,
                                    style: TextStyle(color: _ink700),
                                    items:
                                        items
                                            .map(
                                              (it) => DropdownMenuItem(
                                                value: it.id,
                                                child: Text(
                                                  '${it.code} - ${it.name} (Stock: ${it.openingStock ?? 0})',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _ink900,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
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

                                  // -------- Machine dropdown (FIXED) --------
                                  DropdownButtonFormField<String>(
                                    initialValue: safeMachineId, // ✅ correct
                                    decoration: _dec(
                                      label: 'Select Machine',
                                      icon:
                                          Icons
                                              .precision_manufacturing_outlined,
                                    ),
                                    hint: Text(
                                      filteredMachines.isEmpty
                                          ? 'No machines available'
                                          : 'Choose machine',
                                      style: const TextStyle(color: _ink700),
                                    ),
                                    dropdownColor: _surface,
                                    items:
                                        filteredMachines
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: (m.id ?? '').trim(),
                                                child: Text(
                                                  '${m.machineCode} - ${m.machineName}',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: _ink900,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                    onChanged:
                                        filteredMachines.isEmpty
                                            ? null
                                            : (v) {
                                              setState(() {
                                                _selectedMachineId = v;
                                              });
                                            },
                                  ),

                                  const SizedBox(height: 14),

                                  if (selectedItem == null ||
                                      selectedMachine == null)
                                    const Text(
                                      'Select an item and machine first.',
                                      style: TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    )
                                  else ...[
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Item Bags (${itemBags.length})',
                                            style: const TextStyle(
                                              color: _ink900,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        OutlinedButton.icon(
                                          style: _outlineBtnStyle(),
                                          onPressed:
                                              itemBags.isEmpty ? null : _addRow,
                                          icon: const Icon(Icons.add, color: _ink900),
                                          label: const Text('Add Bag'),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    ...List.generate(_rows.length, (idx) {
                                      final row = _rows[idx];

                                      final selectedIds =
                                          _rows
                                              .where(
                                                (r) =>
                                                    r != row && r.bagId != null,
                                              )
                                              .map((r) => r.bagId!)
                                              .toSet();

                                      final dropdownBags =
                                          itemBags
                                              .where(
                                                (b) =>
                                                    !selectedIds.contains(b.id),
                                              )
                                              .toList();

                                      final safeBagId =
                                          (row.bagId != null &&
                                                  dropdownBags.any(
                                                    (b) => b.id == row.bagId,
                                                  ))
                                              ? row.bagId
                                              : null;

                                      return _Card(
                                        margin: const EdgeInsets.only(
                                          bottom: 10,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(14),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: DropdownButtonFormField<
                                                      String
                                                    >(
                                                      initialValue: safeBagId,
                                                      decoration: _dec(
                                                        label: 'Bag',
                                                        icon:
                                                            Icons
                                                                .inventory_2_rounded,
                                                      ),
                                                      hint: Text(
                                                        'Select bag',
                                                        style: const TextStyle(
                                                          color: _ink700,
                                                        ),
                                                      ),
                                                      dropdownColor: _surface,
                                                      items:
                                                          dropdownBags
                                                              .map(
                                                                (
                                                                  b,
                                                                ) => DropdownMenuItem(
                                                                  value: b.id,
                                                                  child: Text(
                                                                    '${b.bagCode} (Stock: ${b.itemStock})',
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: const TextStyle(
                                                                      color:
                                                                          _ink900,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w800,
                                                                    ),
                                                                  ),
                                                                ),
                                                              )
                                                              .toList(),
                                                      onChanged:
                                                          (v) => setState(
                                                            () => row.bagId = v,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  IconButton(
                                                    onPressed:
                                                        () => _removeRow(idx),
                                                    icon: const Icon(
                                                      Icons
                                                          .delete_outline_rounded,
                                                      color: _ink700,
                                                    ),
                                                    tooltip: 'Remove',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              TextFormField(
                                                keyboardType:
                                                    TextInputType.number,
                                                decoration: _dec(
                                                  label: 'Qty (wt)',
                                                  // hint: 'Enter weight',
                                                  icon: Icons.scale_rounded,
                                                ),
                                                style: const TextStyle(
                                                  color: _ink900,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                                onChanged:
                                                    (v) =>
                                                        row.qtyInWt =
                                                            double.tryParse(
                                                              v,
                                                            ) ??
                                                            0,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),

                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: _primaryBtnStyle(),
                                        onPressed:
                                            (isLoading || _rows.isEmpty)
                                                ? null
                                                : () => _submit(
                                                  selectedItem,
                                                  selectedMachine,
                                                  itemBags,
                                                ),
                                        child: Text(
                                          isLoading
                                              ? 'Creating...'
                                              : 'Create Sorting Job',
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- Simple themed card ---------------- */
class _Card extends StatelessWidget {
  const _Card({required this.child, this.margin});
  final Widget child;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
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
      child: child,
    );
  }
}

class _SelectedBagInput {
  String? bagId;
  double qtyInWt = 0.0;
}
