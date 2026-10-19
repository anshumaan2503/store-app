// lib/views/sorting_jobs/sorting_jobs_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/sorting_job_controller.dart';
import '../../../../domains/models/sorting_job_model.dart';
import 'qr_sorting_job_view_page.dart';
import 'sorting_job_create_page.dart';

class SortingJobsListView extends ConsumerWidget {
  const SortingJobsListView({super.key});

  String _pretty(String s) {
    switch (s) {
      case 'created':
        return 'Created';
      case 'started':
        return 'Started';
      case 'stopped':
        return 'Stopped';
      case 'restarted':
        return 'Restarted';
      case 'completed':
        return 'Completed';
      default:
        return s;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Sorting Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SortingJobCreatePage(),
                  ),
                ),
          ),
        ],
      ),
      body: jobsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error: $e')),
        data: (jobs) {
          if (jobs.isEmpty) return const Center(child: Text('No sorting jobs'));

          return ListView.separated(
            itemCount: jobs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final SortingJobModel job = jobs[i];
              return ListTile(
                title: Text('${job.itemName} (${_pretty(job.status)})'),
                subtitle: Text(
                  'Input: ${job.totalInputQtyInWt}  Transfer: ${job.totalTransferQtyInWt}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.qr_code),
                  tooltip: 'QR Code',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QRSortingJobViewPage(jobId: job.id!),
                      ),
                    );
                  },
                ),
                // onTap:
                //     () => Navigator.push(
                //       context,
                //       MaterialPageRoute(
                //         builder: (_) => SortingJobViewPage(jobId: job.id!),
                //       ),
                //     ),
              );
            },
          );
        },
      ),
    );
  }
}
