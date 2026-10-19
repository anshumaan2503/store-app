import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../../controllers/bag_controller.dart';
import '../../../../../controllers/sorting_job_controller.dart';
import '../../../../../domains/models/bag_model.dart';
import '../../../../../domains/models/sorting_job_model.dart';


class QRTransferToAnotherBagPage extends ConsumerStatefulWidget {
  final String jobId;
  final String bagId; // target bag id (QR scanned)
  const QRTransferToAnotherBagPage({
    super.key,
    required this.jobId,
    required this.bagId,
  });

  @override
  ConsumerState<QRTransferToAnotherBagPage> createState() =>
      _QRTransferToAnotherBagPageState();
}

class _QRTransferToAnotherBagPageState
    extends ConsumerState<QRTransferToAnotherBagPage> {
  final TextEditingController _qtyCtrl = TextEditingController();
  double _qty = 0.0;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<void> _submit({
    required SortingJobModel job,
    required BagModel targetBag,
    required double jobRemainingWt,
    required double bagCapacityRemaining,
  }) async {
    final qty = _qty;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid transfer quantity')),
      );
      return;
    }

    // ✅ job remaining check
    if (qty > jobRemainingWt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Qty exceeds job remaining ($jobRemainingWt).',
          ),
        ),
      );
      return;
    }

    // ✅ bag maxQty capacity check
    if (qty > bagCapacityRemaining) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Qty exceeds target bag capacity ($bagCapacityRemaining).',
          ),
        ),
      );
      return;
    }

    // ✅ itemId must match
    if ((job.itemId).toString() != (targetBag.itemId ?? '').toString()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job itemId and Bag itemId mismatch')),
      );
      return;
    }

    // createdBy from local storage
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final notifier = ref.read(sortingJobControllerProvider.notifier);
    final ok = await notifier.transferToAnotherBagTwo(
      jobId: job.id ?? widget.jobId,
      // new backend: only targetBagId
      targetBagId: targetBag.id ?? widget.bagId,
      transferQtyInWt: qty,
      createdBy: createdBy,
    );

    if (!mounted) return;

    if (ok) {
      setState(() {
        _qtyCtrl.text = '';
        _qty = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transferred to target bag')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final isLoading = ref.watch(sortingJobControllerProvider); // bool loading

    return Scaffold(
      appBar: AppBar(title: const Text('Transfer to Another Bag')),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Jobs error: $e')),
        data: (jobs) {
          final SortingJobModel? job = jobs
              .where((j) => (j.id ?? '') == widget.jobId)
              .cast<SortingJobModel?>()
              .firstWhere((x) => x != null, orElse: () => null);

          if (job == null) {
            return const Center(child: Text('Job not found'));
          }

          return bagsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Bags error: $e')),
            data: (bags) {
              final BagModel? targetBag = bags
                  .where((b) => (b.id ?? '') == widget.bagId)
                  .cast<BagModel?>()
                  .firstWhere((x) => x != null, orElse: () => null);

              if (targetBag == null) {
                return const Center(child: Text('Target bag not found'));
              }

              final jobItemId = job.itemId.toString();
              final bagItemId = (targetBag.itemId ?? '').toString();

              // ✅ 1) job.itemId == bag.itemId
              final itemMatches = jobItemId.isNotEmpty &&
                  bagItemId.isNotEmpty &&
                  jobItemId == bagItemId;

              // ✅ 2) maxQty check
              final maxQty = _toDouble(targetBag.maxQty);
              final bagStock = _toDouble(targetBag.itemStock);

              final bagCapacityRemaining = maxQty - bagStock;

              // ✅ job remaining check
              final totalInputWt = _toDouble(job.totalInputQtyInWt);
              final totalTransferredWt = _toDouble(job.totalTransferQtyInWt);
              final jobRemainingWt = totalInputWt - totalTransferredWt;

              final jobRemainingOk = jobRemainingWt > 0;
              final maxQtyOk = maxQty > 0;

              final disableSubmit =
                  !itemMatches || !jobRemainingOk || !maxQtyOk || isLoading;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // -------- Job summary --------
                    Text(
                      'Job: ${job.id ?? "-"}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Item: ${job.itemName}'),
                    Text('Status: ${job.status}'),
                    const SizedBox(height: 8),
                    Text('Total Input WT: $totalInputWt'),
                    Text('Total Transferred WT: $totalTransferredWt'),
                    Text(
                      'Job Remaining WT: $jobRemainingWt',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: jobRemainingWt > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const Divider(height: 28),

                    // -------- Target bag summary --------
                    Text(
                      'Target Bag (QR): ${targetBag.bagCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Bag ID: ${targetBag.id ?? "-"}'),
                    Text('Item: ${targetBag.itemName}'),
                    Text('Bag ItemId: ${targetBag.itemId ?? "-"}'),
                    Text('Job ItemId: ${job.itemId}'),
                    const SizedBox(height: 8),
                    Text('Stock: $bagStock'),
                    Text('MaxQty: $maxQty'),
                    Text(
                      'Capacity Remaining: $bagCapacityRemaining',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            bagCapacityRemaining > 0 ? Colors.green : Colors.red,
                      ),
                    ),
                    const Divider(height: 28),

                    // -------- Validations --------
                    if (!itemMatches)
                      const Text(
                        'Item mismatch: job.itemId and bag.itemId are different.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    if (!maxQtyOk)
                      const Text(
                        'Target bag maxQty is not set (must be > 0).',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    if (!jobRemainingOk)
                      const Text(
                        'No remaining quantity in this job (already fully transferred).',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                    const SizedBox(height: 12),

                    // -------- Input + submit --------
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Transfer Qty (wt)',
                        border: const OutlineInputBorder(),
                        helperText: itemMatches
                            ? 'Max allowed: min(job remaining=$jobRemainingWt, bag capacity=$bagCapacityRemaining)'
                            : 'Fix item mismatch first',
                      ),
                      onChanged: (v) {
                        setState(() {
                          _qty = double.tryParse(v.trim()) ?? 0.0;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: disableSubmit
                            ? null
                            : () => _submit(
                                  job: job,
                                  targetBag: targetBag,
                                  jobRemainingWt: jobRemainingWt,
                                  bagCapacityRemaining: bagCapacityRemaining,
                                ),
                        child: Text(
                          isLoading ? 'Processing...' : 'Transfer to this bag',
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
