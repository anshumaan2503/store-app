// lib/views/sorting_jobs/return_to_same_bag_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../controllers/sorting_job_controller.dart';
import '../../../../../domains/models/bag_model.dart';
import '../../../../../domains/models/sorting_job_model.dart';

class ReturnToSameBagPage extends ConsumerStatefulWidget {
  final String jobId;
  final SortingJobModel job;
  final List<BagModel> itemBags;

  const ReturnToSameBagPage({
    super.key,
    required this.jobId,
    required this.job,
    required this.itemBags,
  });

  @override
  ConsumerState<ReturnToSameBagPage> createState() => _ReturnToSameBagPageState();
}

class _ReturnToSameBagPageState extends ConsumerState<ReturnToSameBagPage> {
  String? _selectedInputBagCode;
  double _qty = 0;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(sortingJobControllerProvider);

    final job = widget.job;

    final selected = _selectedInputBagCode == null
        ? null
        : job.inputBags.firstWhere((b) => b.bagCode == _selectedInputBagCode);

    final bagRemaining = selected == null
        ? 0.0
        : (selected.qtyInWt - (selected.transferQtyInWt ?? 0));

    final jobRemaining = job.totalInputQtyInWt - (job.totalTransferQtyInWt ?? 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Return to same bag')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Select input bag
            DropdownButtonFormField<String>(
              initialValue: _selectedInputBagCode,
              decoration: const InputDecoration(
                labelText: 'Select Input Bag',
                border: OutlineInputBorder(),
              ),
              items: job.inputBags.map((b) {
                final remaining = b.qtyInWt - (b.transferQtyInWt ?? 0);
                return DropdownMenuItem(
                  value: b.bagCode,
                  child: Text('${b.bagCode} (remaining: $remaining)'),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedInputBagCode = v),
            ),

            const SizedBox(height: 12),

            if (selected != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Input Bag: ${selected.bagCode}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text('Bag ID: ${selected.bagId ?? "-"}'),
                      Text('Input WT: ${selected.qtyInWt}'),
                      Text('Transferred WT: ${selected.transferQtyInWt ?? 0}'),
                      Text('Remaining WT: $bagRemaining'),
                      const Divider(),
                      Text('Job Remaining WT: $jobRemaining'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            TextFormField(
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Return Qty (wt)',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _qty = double.tryParse(v) ?? 0),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (selected == null) {
                        _snack('Select an input bag');
                        return;
                      }
                      if (_qty <= 0) {
                        _snack('Enter qty');
                        return;
                      }
                      if (_qty > bagRemaining) {
                        _snack('Bag remaining is $bagRemaining');
                        return;
                      }
                      if (_qty > jobRemaining) {
                        _snack('Job remaining is $jobRemaining');
                        return;
                      }

                      final ok = await ref
                          .read(sortingJobControllerProvider.notifier)
                          .transferOne(
                            jobId: widget.jobId,
                            bagCode: selected.bagCode,
                            transferQtyInWt: _qty,
                            bagId: selected.bagId, // optional
                          );

                      if (!mounted) return;
                      if (ok) Navigator.pop(context);
                    },
              child: Text(isLoading ? 'Processing...' : 'Return to same bag'),
            ),
          ],
        ),
      ),
    );
  }
}
