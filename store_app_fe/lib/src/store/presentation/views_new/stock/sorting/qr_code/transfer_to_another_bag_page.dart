import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../controllers/bag_controller.dart';
import '../../../../../controllers/sorting_job_controller.dart';
import '../../../../../domains/models/bag_model.dart';
import '../../../../../domains/models/sorting_job_model.dart';

class TransferToAnotherBagPage extends ConsumerStatefulWidget {
  final String jobId;

  const TransferToAnotherBagPage({super.key, required this.jobId});

  @override
  ConsumerState<TransferToAnotherBagPage> createState() =>
      _TransferToAnotherBagPageState();
}

class _TransferToAnotherBagPageState
    extends ConsumerState<TransferToAnotherBagPage> {
  String? _selectedInputBagCode;
  String? _targetBagId;
  double _transferWt = 0.0;

  SortingJobInputBagRow? _findSelectedInput(SortingJobModel job) {
    if (_selectedInputBagCode == null) return null;
    try {
      return job.inputBags.firstWhere(
        (b) => b.bagCode == _selectedInputBagCode,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _submitTransfer(
    SortingJobModel job,
    List<BagModel> itemBags,
    SortingJobInputBagRow selectedInput,
  ) async {
    final qty = _transferWt;

    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter transfer weight')));
      return;
    }

    final sourceBagId = (selectedInput.bagId ?? '').trim();
    if (sourceBagId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected input bag has no bagId')),
      );
      return;
    }

    if (_targetBagId == null || _targetBagId!.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a target bag')));
      return;
    }

    if (_targetBagId!.trim() == sourceBagId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Target bag cannot be the same as input bag'),
        ),
      );
      return;
    }

    // -------- Remaining validation (job + input bag) --------
    final bagTransferred = selectedInput.transferQtyInWt ?? 0;
    final bagRemaining = selectedInput.qtyInWt - bagTransferred;

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

    // -------- Frontend maxQty check (backend MUST enforce too) --------
    final target = itemBags.firstWhere((b) => b.id == _targetBagId);
    final maxQty = target.maxQty ?? 0;

    if (maxQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target bag ${target.bagCode} maxQty not set')),
      );
      return;
    }

    // NOTE:
    // If your `itemStock` represents WT, this is correct.
    // If `itemStock` is NOT WT, then keep backend check only.
    final targetCurrent = (target.itemStock ?? 0).toDouble();
    if (targetCurrent + qty > maxQty.toDouble()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Target bag will exceed maxQty ($maxQty)')),
      );
      return;
    }

    final notifier = ref.read(sortingJobControllerProvider.notifier);

    final ok = await notifier.transferToAnotherBag(
      jobId: widget.jobId,
      sourceBagId: sourceBagId,
      targetBagId: _targetBagId!.trim(),
      transferQtyInWt: qty,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _transferWt = 0;
        _targetBagId = null;
      });
    }
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final isLoading = ref.watch(sortingJobControllerProvider); // bool

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer to Another Bag')),
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

              final selected = _findSelectedInput(job);

              final jobTransferred = job.totalTransferQtyInWt ?? 0;
              final jobRemaining = job.totalInputQtyInWt - jobTransferred;

              // Allowed targets:
              // ✅ Only block the SAME selected input bag
              final selectedInputId = (selected?.bagId ?? '').trim();
              final allowedTargets =
                  itemBags.where((b) {
                    final id = (b.id ?? '').trim();
                    if (id.isEmpty) return false;
                    if (id == selectedInputId) {
                      return false; // ONLY this exclusion
                    }
                    return true;
                  }).toList();

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
                    const SizedBox(height: 8),
                    _infoRow(
                      'Total Input WT',
                      job.totalInputQtyInWt.toString(),
                    ),
                    _infoRow('Total Transferred WT', jobTransferred.toString()),
                    _infoRow('Job Remaining WT', jobRemaining.toString()),
                    const Divider(height: 24),

                    // INPUT BAG
                    DropdownButtonFormField<String>(
                      initialValue: _selectedInputBagCode,
                      decoration: const InputDecoration(
                        labelText: 'Select Input Bag',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          job.inputBags.map((b) {
                            final rem = b.qtyInWt - (b.transferQtyInWt ?? 0);
                            return DropdownMenuItem(
                              value: b.bagCode,
                              child: Text('${b.bagCode} (remaining: $rem)'),
                            );
                          }).toList(),
                      onChanged: (v) {
                        setState(() {
                          _selectedInputBagCode = v;
                          _targetBagId = null;
                        });
                      },
                    ),

                    const SizedBox(height: 12),

                    if (selected != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Input Bag: ${selected.bagCode}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Bag ID: ${selected.bagId ?? "-"}'),
                            Text('Input WT: ${selected.qtyInWt}'),
                            Text(
                              'Transferred WT: ${selected.transferQtyInWt ?? 0}',
                            ),
                            Text(
                              'Remaining WT: ${selected.qtyInWt - (selected.transferQtyInWt ?? 0)}',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // TARGET BAG
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
                                '${b.bagCode} (stock: ${b.itemStock} / max: ${b.maxQty ?? 0})',
                              ),
                            );
                          }).toList(),
                      onChanged: (v) => setState(() => _targetBagId = v),
                    ),

                    if (selected != null && allowedTargets.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'No valid target bags available (only the selected input bag exists).',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),

                    const SizedBox(height: 12),

                    TextFormField(
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Transfer Qty (wt)',
                        border: OutlineInputBorder(),
                      ),
                      onChanged:
                          (v) => setState(() {
                            _transferWt = double.tryParse(v) ?? 0;
                          }),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            (isLoading || selected == null)
                                ? null
                                : () =>
                                    _submitTransfer(job, itemBags, selected),
                        child: Text(
                          isLoading
                              ? 'Processing...'
                              : 'Transfer to another bag',
                        ),
                      ),
                    ),

                    const Divider(height: 24),

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
      ),
    );
  }
}

/// If your model class name is different, update this alias.
/// This matches your earlier usage: job.inputBags list items contain:
/// bagId, bagCode, qtyInWt, transferQtyInWt
typedef SortingJobInputBagRow = dynamic;
