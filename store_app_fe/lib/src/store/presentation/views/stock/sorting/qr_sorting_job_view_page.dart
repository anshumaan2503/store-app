// lib/views/sorting_jobs/sorting_job_view_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
import '../../../../domains/models/sorting_job_model.dart';

import 'qr_code/sorting_qr_code_scanner.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class QRSortingJobViewPage extends ConsumerStatefulWidget {
  final String jobId;
  const QRSortingJobViewPage({super.key, required this.jobId});

  @override
  ConsumerState<QRSortingJobViewPage> createState() =>
      _QRSortingJobViewPageState();
}

class _QRSortingJobViewPageState extends ConsumerState<QRSortingJobViewPage> {
  /* ---------------- UI helpers (themed) ---------------- */

  InputDecoration _dec({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
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
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }

  ButtonStyle _outlineBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _ink900,
      side: const BorderSide(color: _stroke),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w900),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _ink700),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
          ),
          Text(
            value,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsets? padding,
    EdgeInsets? margin,
  }) {
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
      child: Padding(
        padding: padding ?? const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final itemsAsync = ref.watch(itemAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Sorting Job',
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
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, st) => Center(
                child: Text(
                  'Jobs error: $e',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          data: (jobs) {
            final SortingJobModel? job = jobs
                .where((j) => j.id == widget.jobId)
                .cast<SortingJobModel?>()
                .firstWhere((x) => x != null, orElse: () => null);

            if (job == null) {
              return const Center(
                child: Text(
                  'Job not found (wait for refresh)',
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
                ),
              );
            }

            return bagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                final itemBags =
                    bags.where((b) => b.itemId == job.itemId).toList();

                return itemsAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
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
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${job.itemName} (${job.status.toUpperCase()})',
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Machine: ${job.machineName ?? "-"}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        _chip(
                                          icon: Icons.inventory_2_rounded,
                                          label: 'Opening Stock',
                                          value: '${item.openingStock ?? 0}',
                                        ),
                                        _chip(
                                          icon: Icons.shopping_bag_rounded,
                                          label: 'Total Bags',
                                          value: '${job.totalInputQtyInBags}',
                                        ),
                                        _chip(
                                          icon: Icons.input_rounded,
                                          label: 'Input wt',
                                          value: '${job.totalInputQtyInWt}',
                                        ),
                                        _chip(
                                          icon: Icons.swap_horiz_rounded,
                                          label: 'Transfer wt',
                                          value:
                                              '${job.totalTransferQtyInWt ?? 0}',
                                        ),
                                        _chip(
                                          icon: Icons.timelapse_rounded,
                                          label: 'Remaining',
                                          value: '$remaining',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              _card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Input Bags (progress)',
                                      style: TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (job.inputBags.isEmpty)
                                      const Text(
                                        'No input bags.',
                                        style: TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    else
                                      ...job.inputBags.map((b) {
                                        final t = b.transferQtyInWt ?? 0;
                                        final r = b.qtyInWt - t;

                                        return Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _surfaceAlt.withValues(alpha: .45),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(color: _stroke),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            title: Text(
                                              b.bagCode,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Input: ${b.qtyInWt} | Transferred: $t | Remaining: $r',
                                              style: const TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              _card(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Actions',
                                      style: TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    if (isCompleted)
                                      const Text(
                                        'Job is completed.',
                                        style: TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    else
                                      Row(
                                        children: [
                                          Expanded(
                                            child: ElevatedButton(
                                              style: _primaryBtnStyle(),
                                              onPressed: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder:
                                                        (_) =>
                                                            SortingQrCodeScanner(
                                                              jobId:
                                                                  widget.jobId,
                                                            ),
                                                  ),
                                                );
                                              },
                                              child: const Text(
                                                'Return to same bag',
                                              ),
                                            ),
                                          ),
                                          // If you enable transfer later, it will match theme
                                          // const SizedBox(width: 12),
                                          // Expanded(
                                          //   child: OutlinedButton(
                                          //     style: _outlineBtnStyle(),
                                          //     onPressed: () {
                                          //       Navigator.push(
                                          //         context,
                                          //         MaterialPageRoute(
                                          //           builder: (_) =>
                                          //               TransferToAnotherBagPage(
                                          //             jobId: widget.jobId,
                                          //           ),
                                          //         ),
                                          //       );
                                          //     },
                                          //     child: const Text('Transfer to another bag'),
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),

                              _card(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Live Bags List (same itemId)',
                                      style: TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (itemBags.isEmpty)
                                      const Text(
                                        'No bags found for this item.',
                                        style: TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    else
                                      ...itemBags.map(
                                        (b) => Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _surfaceAlt.withValues(alpha: .45),
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(color: _stroke),
                                          ),
                                          child: ListTile(
                                            dense: true,
                                            title: Text(
                                              b.bagCode,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: Text(
                                              'Stock: ${b.itemStock}  Used: ${b.itemUsed}  Max: ${b.maxQty}',
                                              style: const TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
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
