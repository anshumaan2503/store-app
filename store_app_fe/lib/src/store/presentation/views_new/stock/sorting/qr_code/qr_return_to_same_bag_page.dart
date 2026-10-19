import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../controllers/bag_controller.dart';
import '../../../../../controllers/sorting_job_controller.dart';
import '../../../../../domains/models/bag_model.dart';
import '../../../../../domains/models/sorting_job_model.dart';

// ✅ ADD: import your transfer-to-another-bag page
import 'qr_transfer_to_another_bag_page.dart'; // <-- adjust path

class QRReturnToSameBagPage extends ConsumerStatefulWidget {
  final String bagId;
  final String jobId;
  const QRReturnToSameBagPage({
    super.key,
    required this.bagId,
    required this.jobId,
  });

  @override
  ConsumerState<QRReturnToSameBagPage> createState() =>
      _QRReturnToSameBagPageState();
}

class _QRReturnToSameBagPageState extends ConsumerState<QRReturnToSameBagPage> {
  bool _isActiveJob(String status) {
    final s = status.toLowerCase();
    return s == 'created' ||
        s == 'started' ||
        s == 'restarted' ||
        s == 'stopped';
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  bool _bagIsInJob(SortingJobModel job, BagModel bag) {
    final bagId = (bag.id ?? '').toString();
    if (bagId.isEmpty) return false;
    return job.inputBags.any((b) => (b.bagId ?? '').toString() == bagId);
  }

  Future<void> _openReturnPopup({
    required BagModel bag,
    required SortingJobModel job,
  }) async {
    final input = job.inputBags.cast<dynamic>().firstWhere(
      (b) => (b.bagId ?? '').toString() == (bag.id ?? '').toString(),
      orElse: () => null,
    );

    final alreadyInJob = input != null;

    final qtyCtrl = TextEditingController(text: '');

    final inputQtyWt = alreadyInJob ? _toDouble(input.qtyInWt) : 0.0;
    final inputTransferredWt =
        alreadyInJob ? _toDouble(input.transferQtyInWt) : 0.0;

    final bagRemainingInJob = math.max(0.0, inputQtyWt - inputTransferredWt);

    final jobTotalInputWt = _toDouble(job.totalInputQtyInWt);
    final jobTransferredWt = _toDouble(job.totalTransferQtyInWt);
    final jobRemaining = math.max(0.0, jobTotalInputWt - jobTransferredWt);

    final bagMaxQty = _toDouble(bag.maxQty);
    final bagStock = _toDouble(bag.itemStock);
    final bagCapacityRemaining =
        (bagMaxQty > 0) ? math.max(0.0, bagMaxQty - bagStock) : 0.0;

    final maxAllowed =
        alreadyInJob
            ? math.min(
              bagRemainingInJob,
              math.min(jobRemaining, bagCapacityRemaining),
            )
            : 0.0;

    void snack(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Return to Same Bag'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bag Code: ${bag.bagCode}'),
                Text('Bag ID: ${bag.id ?? "-"}'),
                Text('Item: ${bag.itemName}'),
                Text('Bag Stock: ${bag.itemStock}'),
                Text('Bag MaxQty: ${bag.maxQty ?? 0}'),
                const SizedBox(height: 10),

                Text('Job ID: ${job.id ?? "-"}'),
                Text('Status: ${job.status}'),
                const SizedBox(height: 10),

                const Divider(height: 16),

                if (!alreadyInJob)
                  const Text(
                    'This bag is NOT part of this job inputBags.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else ...[
                  Text('Input WT (job row): $inputQtyWt'),
                  Text('Already transferred (job row): $inputTransferredWt'),
                  Text('Remaining for this bag (job row): $bagRemainingInJob'),
                  const SizedBox(height: 8),
                  Text('Job remaining WT: $jobRemaining'),
                  const SizedBox(height: 8),
                  Text(
                    'Bag capacity remaining (maxQty - stock): $bagCapacityRemaining',
                  ),
                  const Divider(height: 16),
                  Text(
                    'Max allowed transfer now: $maxAllowed',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],

                const SizedBox(height: 10),

                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Return Qty (wt)',
                    border: const OutlineInputBorder(),
                    helperText:
                        alreadyInJob
                            ? 'You can return up to $maxAllowed wt'
                            : 'Bag is not part of this job',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isLoading = ref.watch(sortingJobControllerProvider);
                return ElevatedButton(
                  onPressed:
                      (!alreadyInJob || isLoading)
                          ? null
                          : () async {
                            if (!_isActiveJob(job.status)) {
                              snack('This job is not active. Cannot transfer.');
                              return;
                            }

                            final qty =
                                double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                            if (qty <= 0) {
                              snack('Enter valid qty');
                              return;
                            }

                            if (qty > maxAllowed) {
                              snack('Cannot transfer more than $maxAllowed wt');
                              return;
                            }

                            final ok = await ref
                                .read(sortingJobControllerProvider.notifier)
                                .transferOne(
                                  jobId: widget.jobId,
                                  bagCode: bag.bagCode,
                                  bagId: bag.id,
                                  transferQtyInWt: qty,
                                );

                            if (!mounted) return;
                            if (ok) Navigator.pop(context);
                          },
                  child: Text(isLoading ? 'Processing...' : 'Submit'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _goToTransferToAnotherBag() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => QRTransferToAnotherBagPage(
              jobId: widget.jobId,
              bagId:
                  widget
                      .bagId, // ✅ this bag becomes the target bag for QR transfer
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('QR Bag Route')),
      body: bagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Bags error: $e')),
        data: (bags) {
          final bag = bags.firstWhere(
            (b) => (b.id ?? '') == widget.bagId,
            orElse:
                () => BagModel(
                  id: widget.bagId,
                  itemId: '',
                  bagCode: '',
                  itemName: '',
                  itemStock: 0,
                  itemUsed: 0,
                  approvedStatus: '',
                  transferQty: 0,
                  transferType: '',
                  maxQty: 0,
                ),
          );

          if ((bag.itemId ?? '').isEmpty) {
            return const Center(child: Text('Bag not found or itemId missing'));
          }

          return jobsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Jobs error: $e')),
            data: (jobs) {
              final SortingJobModel? job = jobs
                  .where((j) => (j.id ?? '') == widget.jobId)
                  .cast<SortingJobModel?>()
                  .firstWhere((x) => x != null, orElse: () => null);

              if (job == null) {
                return const Center(
                  child: Text('Job not found (wait refresh)'),
                );
              }

              final bagItemId = (bag.itemId ?? '').toString();
              final jobItemId = (job.itemId).toString();

              final itemMatches =
                  bagItemId.isNotEmpty &&
                  jobItemId.isNotEmpty &&
                  bagItemId == jobItemId;
              print(bagItemId);
              print(jobItemId);
              print(itemMatches);

              final isBagInJob = _bagIsInJob(job, bag);

              // ✅ Route logic:
              // - If bag is in job => show return-to-same-bag work
              // - else if item matches => show transfer-to-another-bag button
              // - else show mismatch message

              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Bag summary (always visible)
                    Text(
                      'Bag: ${bag.bagCode}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Bag ID: ${bag.id ?? "-"}'),
                    Text('Item: ${bag.itemName}'),
                    Text('ItemId: ${bag.itemId}'),
                    Text(
                      'Stock: ${bag.itemStock}  Used: ${bag.itemUsed}  Max: ${bag.maxQty ?? 0}',
                    ),
                    const Divider(height: 24),

                    // Job summary
                    Text(
                      'Job: ${job.id ?? "-"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Job ItemId: ${job.itemId}'),
                    Text('Status: ${job.status}'),
                    Text('Total WT: ${job.totalInputQtyInWt}'),
                    Text('Transferred WT: ${job.totalTransferQtyInWt ?? 0}'),
                    const Divider(height: 24),

                    if (isBagInJob) ...[
                      const Text(
                        'Action available: Return to same bag',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _openReturnPopup(bag: bag, job: job),
                          child: const Text('Return to same bag'),
                        ),
                      ),
                    ] else if (itemMatches) ...[
                      const Text(
                        'Bag is not part of job inputBags.\nAction available: Transfer to another bag',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: _goToTransferToAnotherBag,
                          child: const Text('Transfer to another bag'),
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Bag is not a match for this job (itemId mismatch).',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Bag itemId: $bagItemId'),
                      Text('Job itemId: $jobItemId'),
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
