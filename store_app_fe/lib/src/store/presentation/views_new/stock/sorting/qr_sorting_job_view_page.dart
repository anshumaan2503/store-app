// lib/views/sorting_jobs/sorting_job_view_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/sorting_job_model.dart';

import 'qr_code/sorting_qr_code_scanner.dart';

class QRSortingJobViewPage extends ConsumerStatefulWidget {
  final String jobId;
  const QRSortingJobViewPage({super.key, required this.jobId});

  @override
  ConsumerState<QRSortingJobViewPage> createState() =>
      _QRSortingJobViewPageState();
}

class _QRSortingJobViewPageState extends ConsumerState<QRSortingJobViewPage> {
  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final itemsAsync = ref.watch(itemAllDataStreamProvider);

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
              child: Text('Job not found (wait for refresh)'),
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

                  final isCompleted = job.status == 'completed';
                  final remaining =
                      job.totalInputQtyInWt - (job.totalTransferQtyInWt ?? 0);

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
                        Text('Remaining wt: $remaining'),
                        const Divider(),

                        const Text(
                          'Input Bags (progress):',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ...job.inputBags.map((b) {
                          final t = b.transferQtyInWt ?? 0;
                          final r = b.qtyInWt - t;
                          return ListTile(
                            dense: true,
                            title: Text(b.bagCode),
                            subtitle: Text(
                              'Input: ${b.qtyInWt} | Transferred: $t | Remaining: $r',
                            ),
                          );
                        }),

                        const Divider(),

                        if (isCompleted)
                          const Text(
                            'Job is completed.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )
                        else ...[
                          // ✅ FIX: No Expanded inside scroll view
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) => SortingQrCodeScanner(
                                              jobId: widget.jobId,
                                            ),
                                      ),
                                    );
                                  },
                                  child: const Text('Return to same bag'),
                                ),
                              ),
                              // const SizedBox(width: 12),
                              // Expanded(
                              //   child: OutlinedButton(
                              //     onPressed: () {
                              //       Navigator.push(
                              //         context,
                              //         MaterialPageRoute(
                              //           builder:
                              //               (_) => TransferToAnotherBagPage(
                              //                 jobId: widget.jobId,
                              //               ),
                              //         ),
                              //       );
                              //     },
                              //     child: const Text('Transfer to another bag'),
                              //   ),
                              // ),
                            ],
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
