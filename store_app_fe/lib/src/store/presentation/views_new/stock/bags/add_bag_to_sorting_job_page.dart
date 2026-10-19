// lib/views/sorting_jobs/add_bag_to_sorting_job_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/sorting_job_model.dart';

enum _Mode { none, addToJob, transferToBag }

class AddBagToSortingJobPage extends ConsumerStatefulWidget {
  final String bagId;
  const AddBagToSortingJobPage({super.key, required this.bagId});

  @override
  ConsumerState<AddBagToSortingJobPage> createState() =>
      _AddBagToSortingJobPageState();
}

class _AddBagToSortingJobPageState
    extends ConsumerState<AddBagToSortingJobPage> {
  _Mode _mode = _Mode.none;

  // -------- Add-to-job state --------
  String? _selectedJobId;
  double _addToJobQtyInWt = 0;

  // -------- Transfer-to-bag state --------
  String? _targetBagId;
  double _transferQty = 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _setMode(_Mode m) {
    setState(() {
      _mode = _mode == m ? _Mode.none : m; // toggle
      // reset fields when switching
      _selectedJobId = null;
      _addToJobQtyInWt = 0;
      _targetBagId = null;
      _transferQty = 0;
    });
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '-';
    return '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _displayTransferType(String? value) {
    if (value == 'other_bag') return 'Other Bag';
    if (value == 'sorting_machine') return 'Sorting Machine';
    if (value == 'inStock') return 'In Stock';
    return value ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    final sortingLoading = ref.watch(sortingJobControllerProvider);
    final bagLoading = ref.watch(bagControllerProvider);
    final anyLoading = sortingLoading || bagLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Bag Actions')),
      body: bagsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Bags error: $e')),
        data: (bags) {
          final BagModel? sourceBag = bags
              .where((b) => b.id == widget.bagId)
              .cast<BagModel?>()
              .firstWhere((x) => x != null, orElse: () => null);

          if (sourceBag == null) {
            return const Center(
              child: Text('Bag not found (wait for refresh)'),
            );
          }

          // candidate target bags: same item, exclude source bag itself
          final List<BagModel> sameItemOtherBags =
              bags
                  .where(
                    (b) => b.itemId == sourceBag.itemId && b.id != sourceBag.id,
                  )
                  .toList();

          return jobsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Jobs error: $e')),
            data: (jobs) {
              final startedJobs =
                  jobs.where((SortingJobModel j) {
                    final sameItem = j.itemId == sourceBag.itemId;
                    final started =
                        j.status == 'started' || j.status == 'restarted';
                    return sameItem && started;
                  }).toList();

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ======================================================
                    // BAG FULL DETAILS (ABOVE BUTTONS)
                    // ======================================================
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Source Bag: ${sourceBag.bagCode}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // _kv('Bag ID', sourceBag.id ?? '-'),
                            _kv('Item', sourceBag.itemName),
                            // _kv('Item ID', sourceBag.itemId),
                            const Divider(),

                            Row(
                              children: [
                                Expanded(
                                  child: _stat(
                                    'Stock',
                                    '${sourceBag.itemStock}',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _stat('Used', '${sourceBag.itemUsed}'),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _stat(
                                    'MaxQty',
                                    '${sourceBag.maxQty ?? 0}',
                                  ),
                                ),
                              ],
                            ),

                            const Divider(),
                            // _kv(
                            //   'Approved Status',
                            //   sourceBag.approvedStatus ?? '-',
                            // ),
                            _kv(
                              'Transfer Qty',
                              '${sourceBag.transferQty ?? 0}',
                            ),
                            // _kv(
                            //   'Transfer Type',
                            //   _displayTransferType(sourceBag.transferType),
                            // ),
                            const Divider(),
                            // _kv('Created', _fmtDate(sourceBag.createdAt)),
                            // _kv('Updated', _fmtDate(sourceBag.updatedAt)),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ======================================================
                    // ONLY TWO BUTTONS INITIALLY
                    // ======================================================
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF282321),
                              foregroundColor: Colors.white,
                              iconColor: Colors.white,
                            ),
                            onPressed: () => _setMode(_Mode.addToJob),
                            icon: const Icon(Icons.playlist_add, color: Colors.white),
                            label: Text(
                              _mode == _Mode.addToJob
                                  ? 'Hide Add To Job'
                                  : 'Add bag to sorting job',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF282321),
                              iconColor: const Color(0xFF282321),
                            ),
                            onPressed: () => _setMode(_Mode.transferToBag),
                            icon: const Icon(Icons.swap_horiz, color: Color(0xFF282321)),
                            label: Text(
                              _mode == _Mode.transferToBag
                                  ? 'Hide Transfer'
                                  : 'Transfer to another bag',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // ======================================================
                    // SECTION 1: ADD BAG TO SORTING JOB
                    // ======================================================
                    if (_mode == _Mode.addToJob) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Add to started sorting job',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              if (startedJobs.isEmpty)
                                const Text(
                                  'No started sorting job found for this item.',
                                )
                              else ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _selectedJobId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Started Job',
                                    border: OutlineInputBorder(),
                                  ),
                                  items:
                                      startedJobs
                                          .map(
                                            (j) => DropdownMenuItem(
                                              value: j.id,
                                              child: Text(
                                                '${j.machineName ?? "-"} • ${j.totalTransferQtyInWt}/${j.totalInputQtyInWt}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(() => _selectedJobId = v),
                                ),
                                const SizedBox(height: 10),

                                TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty to add (wt)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged:
                                      (v) => setState(() {
                                        _addToJobQtyInWt =
                                            double.tryParse(v) ?? 0;
                                      }),
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        anyLoading
                                            ? null
                                            : () async {
                                              if (_selectedJobId == null) {
                                                _snack('Select a sorting job');
                                                return;
                                              }
                                              if (_addToJobQtyInWt <= 0) {
                                                _snack('Enter qty');
                                                return;
                                              }

                                              if (sourceBag.itemStock <
                                                  _addToJobQtyInWt) {
                                                _snack(
                                                  'Bag stock is only ${sourceBag.itemStock}',
                                                );
                                                return;
                                              }

                                              final ok = await ref
                                                  .read(
                                                    sortingJobControllerProvider
                                                        .notifier,
                                                  )
                                                  .addBagToJob(
                                                    jobId: _selectedJobId!,
                                                    bagId: sourceBag.id!,
                                                    qtyInWt: _addToJobQtyInWt,
                                                  );

                                              if (!mounted) return;
                                              if (ok) {
                                                setState(() {
                                                  _addToJobQtyInWt = 0;
                                                  _selectedJobId = null;
                                                });
                                              }
                                            },
                                    child: Text(
                                      anyLoading ? 'Please wait...' : 'Confirm',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ======================================================
                    // SECTION 2: TRANSFER TO ANOTHER BAG
                    // ======================================================
                    if (_mode == _Mode.transferToBag) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Transfer to another bag',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 10),

                              if (sameItemOtherBags.isEmpty)
                                const Text('No other bags found for this item.')
                              else ...[
                                DropdownButtonFormField<String>(
                                  initialValue: _targetBagId,
                                  decoration: const InputDecoration(
                                    labelText: 'Select Target Bag',
                                    border: OutlineInputBorder(),
                                  ),
                                  items:
                                      sameItemOtherBags.map((b) {
                                        final maxQty = b.maxQty ?? 0;
                                        final stock = b.itemStock;
                                        final cap =
                                            maxQty > 0 ? (maxQty - stock) : 0;
                                        return DropdownMenuItem(
                                          value: b.id,
                                          child: Text(
                                            '${b.bagCode} (Stock: ${b.itemStock}, Max: ${b.maxQty ?? 0}, Capacity: $cap)',
                                          ),
                                        );
                                      }).toList(),
                                  onChanged:
                                      (v) => setState(() => _targetBagId = v),
                                ),
                                const SizedBox(height: 10),

                                TextFormField(
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Transfer Qty (wt)',
                                    border: OutlineInputBorder(),
                                  ),
                                  onChanged:
                                      (v) => setState(() {
                                        _transferQty = double.tryParse(v) ?? 0;
                                      }),
                                ),
                                const SizedBox(height: 12),

                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        anyLoading
                                            ? null
                                            : () async {
                                              if (_targetBagId == null) {
                                                _snack('Select target bag');
                                                return;
                                              }
                                              if (_targetBagId ==
                                                  sourceBag.id) {
                                                _snack(
                                                  'Target bag cannot be same as source bag',
                                                );
                                                return;
                                              }
                                              if (_transferQty <= 0) {
                                                _snack('Enter transfer qty');
                                                return;
                                              }

                                              if (sourceBag.itemStock <
                                                  _transferQty) {
                                                _snack(
                                                  'Source bag stock is only ${sourceBag.itemStock}',
                                                );
                                                return;
                                              }

                                              final target = sameItemOtherBags
                                                  .firstWhere(
                                                    (b) => b.id == _targetBagId,
                                                    orElse:
                                                        () =>
                                                            throw Exception(
                                                              'Target bag not found',
                                                            ),
                                                  );

                                              final maxQty = target.maxQty ?? 0;
                                              if (maxQty <= 0) {
                                                _snack(
                                                  'Target bag maxQty not set',
                                                );
                                                return;
                                              }

                                              if (target.itemStock +
                                                      _transferQty >
                                                  maxQty) {
                                                _snack(
                                                  'Target exceeds maxQty. Current=${target.itemStock}, Add=$_transferQty, Max=$maxQty',
                                                );
                                                return;
                                              }

                                              final ok = await ref
                                                  .read(
                                                    bagControllerProvider
                                                        .notifier,
                                                  )
                                                  .transferToOtherBag(
                                                    sourceBagId: sourceBag.id!,
                                                    targetBagId: _targetBagId!,
                                                    qty: _transferQty,
                                                  );

                                              if (!mounted) return;
                                              if (ok) {
                                                setState(() {
                                                  _targetBagId = null;
                                                  _transferQty = 0;
                                                });
                                              }
                                            },
                                    child: Text(
                                      anyLoading ? 'Please wait...' : 'Confirm',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
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

Widget _kv(String k, String v) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$k:',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(v)),
      ],
    ),
  );
}

Widget _stat(String label, String value) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    ),
  );
}
