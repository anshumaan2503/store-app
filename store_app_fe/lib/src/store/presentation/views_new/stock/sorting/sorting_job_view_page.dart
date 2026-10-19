import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/sorting_job_model.dart';

enum TransferMode { sameBag, anotherBag }

class SortingJobViewPage extends ConsumerStatefulWidget {
  final String jobId;
  const SortingJobViewPage({super.key, required this.jobId});

  @override
  ConsumerState<SortingJobViewPage> createState() => _SortingJobViewPageState();
}

class _SortingJobViewPageState extends ConsumerState<SortingJobViewPage> {
  // Always pick an INPUT bag first
  String? _selectedInputBagCode;
  double _transferWt = 0.0;

  // Mode
  TransferMode _mode = TransferMode.sameBag;

  // Only for "another bag"
  String? _targetBagId;

  void _resetAnotherBagSelectionIfNeeded() {
    if (_mode == TransferMode.sameBag) {
      _targetBagId = null;
    }
  }

  Future<void> _submitTransfer(
    SortingJobModel job,
    List<BagModel> itemBags,
  ) async {
    final qty = _transferWt;

    if (_selectedInputBagCode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an input bag')));
      return;
    }

    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter transfer weight')));
      return;
    }

    // Selected input bag in the JOB (this is the source context)
    final input = job.inputBags.firstWhere(
      (b) => b.bagCode == _selectedInputBagCode,
    );

    // Remaining checks (bag-level + job-level)
    final bagTransferred = input.transferQtyInWt ?? 0;
    final bagRemaining = input.qtyInWt - bagTransferred;
    if (qty > bagRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Input bag remaining is $bagRemaining')),
      );
      return;
    }

    final jobTransferred = job.totalTransferQtyInWt ?? 0;
    final jobRemaining = job.totalInputQtyInWt - jobTransferred;
    if (qty > jobRemaining) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Job remaining is $jobRemaining')));
      return;
    }

    final notifier = ref.read(sortingJobControllerProvider.notifier);

    // ---- MODE A: Same bag (transferOne) ----
    if (_mode == TransferMode.sameBag) {
      final ok = await notifier.transferOne(
        jobId: widget.jobId,
        bagCode: input.bagCode,
        transferQtyInWt: qty,
        bagId: input.bagId, // optional; send if available
      );

      if (!mounted) return;
      if (ok) {
        setState(() {
          _transferWt = 0;
        });
      }
      return;
    }

    // ---- MODE B: Another bag (transferToAnotherBag) ----
    // Need sourceBagId from selected input bag
    final sourceBagId = (input.bagId ?? '').trim();
    if (sourceBagId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected input bag has no bagId')),
      );
      return;
    }

    if (_targetBagId == null || _targetBagId!.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a target bag')));
      return;
    }

    if (_targetBagId == sourceBagId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target bag cannot be the same as input bag'),
        ),
      );
      return;
    }

    // Frontend maxQty check for better UX (backend must enforce too)
    final target = itemBags.firstWhere((b) => b.id == _targetBagId);
    final maxQty = target.maxQty ?? 0;
    if (maxQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target bag maxQty not set')),
      );
      return;
    }

    // NOTE: You are transferring WT, but your Bag model has itemStock (number).
    // If itemStock is actually "bags qty" and not "wt", then this check is not correct.
    // If itemStock stores "wt", then it's okay. Otherwise, keep only backend check.
    final wouldExceed = (target.itemStock.toDouble() + qty) > maxQty.toDouble();
    if (wouldExceed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target bag will exceed maxQty ($maxQty)')),
      );
      return;
    }

    final ok = await notifier.transferToAnotherBag(
      jobId: widget.jobId,
      sourceBagId: sourceBagId,
      targetBagId: _targetBagId!,
      transferQtyInWt: qty,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _transferWt = 0;
        _targetBagId = null;
        _mode = TransferMode.sameBag; // optional: go back to default
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final itemsAsync = ref.watch(itemAllDataStreamProvider);

    final isLoading = ref.watch(sortingJobControllerProvider); // bool

    return Scaffold(
      appBar: AppBar(title: const Text('Sorting Job')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Jobs error: $e')),
        data: (jobs) {
          final SortingJobModel? job = jobs
              .where((j) => j.id == widget.jobId)
              .cast<SortingJobModel?>()
              .firstWhere((x) => x != null, orElse: () => null);

          if (job == null) {
            return const Center(
              child: Text('Job not found (wait for WS refresh)'),
            );
          }

          return bagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Bags error: $e')),
            data: (bags) {
              final itemBags =
                  bags.where((b) => b.itemId == job.itemId).toList();

              return itemsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Items error: $e')),
                data: (items) {
                  final item = items.firstWhere(
                    (i) => i.id == job.itemId,
                    orElse:
                        () => ItemModel(
                          id: job.itemId,
                          code: '',
                          name: job.itemName,
                          openingStock: 0,
                        ),
                  );

                  final jobRemaining =
                      job.totalInputQtyInWt - (job.totalTransferQtyInWt ?? 0);
                  final isCompleted = job.status == 'completed';

                  // Build a set of all input bag IDs used in this job (to exclude from target selection)
                  final inputBagIds = <String>{};
                  for (final b in job.inputBags) {
                    final id = (b.bagId ?? '').trim();
                    if (id.isNotEmpty) inputBagIds.add(id);
                  }

                  // Selected input bag object (for showing remaining)
                  final selectedInput =
                      _selectedInputBagCode == null
                          ? null
                          : job.inputBags.firstWhere(
                            (b) => b.bagCode == _selectedInputBagCode,
                            orElse: () => job.inputBags.first,
                          );

                  // Allowed target bags:
                  // 1) same itemId (already filtered into itemBags)
                  // 2) NOT the selected input bag id
                  // 3) NOT any bag that is part of job.inputBags selections
                  final selectedInputId = (selectedInput?.bagId ?? '').trim();
                  final allowedTargets =
                      itemBags.where((b) {
                        final id = (b.id ?? '').trim();
                        if (id.isEmpty) return false;
                        if (id == selectedInputId) return false;
                        // if (inputBagIds.contains(id)) return false; // your rule
                        return true;
                      }).toList();

                  // If user switched mode to sameBag, remove target selection
                  _resetAnotherBagSelectionIfNeeded();

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${job.itemName} (${job.status.toUpperCase()})',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Machine: ${job.machineName ?? "-"}'),
                        Text(
                          'Item openingStock (live): ${item.openingStock ?? 0}',
                        ),
                        const SizedBox(height: 8),
                        Text('Total bags: ${job.totalInputQtyInBags}'),
                        Text('Total input wt: ${job.totalInputQtyInWt}'),
                        Text(
                          'Total transfer wt: ${job.totalTransferQtyInWt ?? 0}',
                        ),
                        Text('Remaining wt: $jobRemaining'),
                        const Divider(),

                        const Text(
                          'Input Bags (progress):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...job.inputBags.map((b) {
                          final transferred = b.transferQtyInWt ?? 0;
                          final remaining = b.qtyInWt - transferred;
                          return ListTile(
                            dense: true,
                            title: Text(b.bagCode),
                            subtitle: Text(
                              'Input: ${b.qtyInWt} | Transferred: $transferred | Remaining: $remaining',
                            ),
                          );
                        }),

                        const Divider(),

                        if (!isCompleted) ...[
                          const Text(
                            'Transfer',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),

                          // 1) Select input bag first
                          DropdownButtonFormField<String>(
                            initialValue: _selectedInputBagCode,
                            decoration: const InputDecoration(
                              labelText: 'Select Input Bag',
                              border: OutlineInputBorder(),
                            ),
                            items:
                                job.inputBags.map((b) {
                                  final remaining =
                                      b.qtyInWt - (b.transferQtyInWt ?? 0);
                                  return DropdownMenuItem(
                                    value: b.bagCode,
                                    child: Text(
                                      '${b.bagCode} (remaining: $remaining)',
                                    ),
                                  );
                                }).toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedInputBagCode = v;
                                // reset target if input changes
                                _targetBagId = null;
                              });
                            },
                          ),

                          const SizedBox(height: 12),

                          // 2) Radio button with labels
                          const Text(
                            'Transfer Mode',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          RadioListTile<TransferMode>(
                            value: TransferMode.sameBag,
                            groupValue: _mode,
                            title: const Text('Return to same bag'),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _mode = v;
                                _targetBagId = null;
                              });
                            },
                          ),
                          RadioListTile<TransferMode>(
                            value: TransferMode.anotherBag,
                            groupValue: _mode,
                            title: const Text('Transfer to another bag'),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _mode = v;
                                _targetBagId = null;
                              });
                            },
                          ),

                          const SizedBox(height: 10),

                          // 3) If mode=anotherBag show target bag dropdown
                          if (_mode == TransferMode.anotherBag) ...[
                            DropdownButtonFormField<String>(
                              initialValue: _targetBagId,
                              decoration: const InputDecoration(
                                labelText: 'Select Target Bag (same item)',
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  allowedTargets.map((b) {
                                    return DropdownMenuItem(
                                      value: b.id,
                                      child: Text(
                                        '${b.bagCode} (stock: ${b.itemStock}/${b.maxQty})',
                                      ),
                                    );
                                  }).toList(),
                              onChanged:
                                  (v) => setState(() => _targetBagId = v),
                            ),
                            const SizedBox(height: 10),
                            if (_selectedInputBagCode != null &&
                                allowedTargets.isEmpty)
                              const Text(
                                'No valid target bags (all bags are used as input bags or same as selected input bag).',
                                style: TextStyle(color: Colors.red),
                              ),
                          ],

                          const SizedBox(height: 10),

                          // 4) transfer wt
                          TextFormField(
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Transfer Qty (wt)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged:
                                (v) => setState(
                                  () => _transferWt = double.tryParse(v) ?? 0,
                                ),
                          ),

                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  isLoading
                                      ? null
                                      : () => _submitTransfer(job, itemBags),
                              child: Text(
                                isLoading ? 'Processing...' : 'Transfer',
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Job is completed.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],

                        const Divider(),
                        const Text(
                          'Live Bags List (same itemId):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...itemBags.map(
                          (b) => ListTile(
                            dense: true,
                            title: Text(b.bagCode),
                            subtitle: Text(
                              'Stock: ${b.itemStock}  Used: ${b.itemUsed}  Max: ${b.maxQty}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
