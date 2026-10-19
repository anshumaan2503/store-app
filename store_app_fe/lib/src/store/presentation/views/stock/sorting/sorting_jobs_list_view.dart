// lib/views/sorting_jobs/sorting_jobs_list_view.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/sorting_job_controller.dart';
import '../../../../domains/models/sorting_job_model.dart';
import 'sorting_job_create_page.dart';
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

  IconData _statusIcon(String s) {
    switch (s) {
      case 'created':
        return Icons.fiber_new_rounded;
      case 'started':
      case 'restarted':
        return Icons.play_circle_fill_rounded;
      case 'stopped':
        return Icons.pause_circle_filled_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Sorting Jobs',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: _ink900),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SortingJobCreatePage(),
                  ),
                ),
            tooltip: 'Create',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, st) => Center(
                child: Text(
                  'Error: $e',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          data: (jobs) {
            if (jobs.isEmpty) {
              return const Center(
                child: Text(
                  'No sorting jobs',
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final SortingJobModel job = jobs[i];
                final status = _pretty(job.status);

                return _Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    leading: _IconBadge(icon: _statusIcon(job.status)),
                    title: Text(
                      '${job.itemName} ($status)\nMachine: ${job.machineName}',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Input: ${job.totalInputQtyInWt}   Transfer: ${job.totalTransferQtyInWt}',
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.queue_play_next, color: _ink900),
                      tooltip: 'Sorting',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SortingJobViewPage(jobId: job.id!),
                          ),
                        );
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder:
                        //         (_) => QRSortingJobViewPage(jobId: job.id!),
                        //   ),
                        // );
                      },
                    ),
                    // If you want open details:
                    // onTap: () => Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (_) => SortingJobViewPage(jobId: job.id!),
                    //   ),
                    // ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/* ---------------- Themed Widgets ---------------- */

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _ink900),
    );
  }
}
