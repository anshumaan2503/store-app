// lib/views/sorting_jobs/add_bag_to_sorting_job_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../domains/models/sorting_job_model.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: _ink900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _setMode(_Mode m) {
    setState(() {
      _mode = _mode == m ? _Mode.none : m; // toggle
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

  InputDecoration _decor({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      hintStyle: const TextStyle(color: _ink600, fontWeight: FontWeight.w700),
      prefixIcon: Icon(icon, color: _ink600),
      filled: true,
      fillColor: _surfaceAlt.withValues(alpha: .55),
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

  @override
  Widget build(BuildContext context) {
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    final sortingLoading = ref.watch(sortingJobControllerProvider);
    final bagLoading = ref.watch(bagControllerProvider);
    final anyLoading = sortingLoading || bagLoading;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Bag Actions',
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
        child: SafeArea(
          child: bagsAsync.when(
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

              final List<BagModel> sameItemOtherBags =
                  bags
                      .where(
                        (b) =>
                            b.itemId == sourceBag.itemId &&
                            b.id != sourceBag.id,
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
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ======================================================
                            // BAG FULL DETAILS
                            // ======================================================
                            _Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Source Bag: ${sourceBag.bagCode}',
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),

                                    _kv('Item', sourceBag.itemName),
                                    const SizedBox(height: 4),
                                    _kv(
                                      'Transfer Type',
                                      _displayTransferType(
                                        sourceBag.transferType,
                                      ),
                                    ),
                                    const SizedBox(height: 18),

                                    // const Divider(height: 18),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _stat(
                                            'Stock',
                                            '${sourceBag.itemStock}',
                                            icon: Icons.inventory_2_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _stat(
                                            'Used',
                                            '${sourceBag.itemUsed}',
                                            icon: Icons.done_all_rounded,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _stat(
                                            'MaxQty',
                                            '${sourceBag.maxQty ?? 0}',
                                            icon: Icons.speed_rounded,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 22),
                                    // const Divider(height: 22),
                                    _kv(
                                      'Transfer Qty',
                                      '${sourceBag.transferQty}',
                                    ),
                                    const SizedBox(height: 6),
                                    // _kv(
                                    //   'Updated',
                                    //   _fmtDate(sourceBag.updatedAt),
                                    // ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // ======================================================
                            // MODE BUTTONS
                            // ======================================================
                            Row(
                              children: [
                                Expanded(
                                  child: _PrimaryBtn(
                                    icon: Icons.playlist_add_rounded,
                                    label:
                                        _mode == _Mode.addToJob
                                            ? 'Hide Add To Job'
                                            : 'Add bag to sorting job',
                                    onTap:
                                        anyLoading
                                            ? null
                                            : () => _setMode(_Mode.addToJob),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _SecondaryBtn(
                                    icon: Icons.swap_horiz_rounded,
                                    label:
                                        _mode == _Mode.transferToBag
                                            ? 'Hide Transfer'
                                            : 'Transfer to another bag',
                                    onTap:
                                        anyLoading
                                            ? null
                                            : () =>
                                                _setMode(_Mode.transferToBag),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // ======================================================
                            // SECTION 1: ADD BAG TO SORTING JOB
                            // ======================================================
                            if (_mode == _Mode.addToJob) ...[
                              _Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Add to started sorting job',
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      if (startedJobs.isEmpty)
                                        const Text(
                                          'No started sorting job found for this item.',
                                          style: TextStyle(color: _ink700),
                                        )
                                      else ...[
                                        DropdownButtonFormField<String>(
                                          initialValue: _selectedJobId,
                                          decoration: _decor(
                                            label: 'Select Started Job',
                                            icon:
                                                Icons
                                                    .precision_manufacturing_rounded,
                                          ),
                                          dropdownColor: _surface,
                                          items:
                                              startedJobs
                                                  .map(
                                                    (j) => DropdownMenuItem(
                                                      value: j.id,
                                                      child: Text(
                                                        '${j.machineName ?? "-"} • ${j.totalTransferQtyInWt}/${j.totalInputQtyInWt}',
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                          onChanged:
                                              (v) => setState(
                                                () => _selectedJobId = v,
                                              ),
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        TextFormField(
                                          keyboardType: TextInputType.number,
                                          decoration: _decor(
                                            label: 'Qty to add (wt)',
                                            icon: Icons.scale_rounded,
                                            hint: 'e.g., 25',
                                          ),
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          onChanged:
                                              (v) => setState(() {
                                                _addToJobQtyInWt =
                                                    double.tryParse(v) ?? 0;
                                              }),
                                        ),
                                        const SizedBox(height: 12),

                                        _PrimaryBtn(
                                          icon: Icons.check_circle_rounded,
                                          label:
                                              anyLoading
                                                  ? 'Please wait...'
                                                  : 'Confirm',
                                          onTap:
                                              anyLoading
                                                  ? null
                                                  : () async {
                                                    if (_selectedJobId ==
                                                        null) {
                                                      _snack(
                                                        'Select a sorting job',
                                                      );
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
                                                          jobId:
                                                              _selectedJobId!,
                                                          bagId: sourceBag.id!,
                                                          qtyInWt:
                                                              _addToJobQtyInWt,
                                                        );

                                                    if (!mounted) return;
                                                    if (ok) {
                                                      setState(() {
                                                        _addToJobQtyInWt = 0;
                                                        _selectedJobId = null;
                                                      });
                                                      _snack(
                                                        'Added to sorting job',
                                                      );
                                                    }
                                                  },
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
                              _Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      const Text(
                                        'Transfer to another bag',
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      if (sameItemOtherBags.isEmpty)
                                        const Text(
                                          'No other bags found for this item.',
                                          style: TextStyle(color: _ink700),
                                        )
                                      else ...[
                                        DropdownButtonFormField<String>(
                                          initialValue: _targetBagId,
                                          decoration: _decor(
                                            label: 'Select Target Bag',
                                            icon: Icons.swap_horiz_rounded,
                                          ),
                                          dropdownColor: _surface,
                                          items:
                                              sameItemOtherBags.map((b) {
                                                final maxQty = b.maxQty ?? 0;
                                                final stock = b.itemStock;
                                                final cap =
                                                    maxQty > 0
                                                        ? (maxQty - stock)
                                                        : 0;
                                                return DropdownMenuItem(
                                                  value: b.id,
                                                  child: Text(
                                                    '${b.bagCode} (Stock: ${b.itemStock}, Max: ${b.maxQty ?? 0}, Capacity: $cap)',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged:
                                              (v) => setState(
                                                () => _targetBagId = v,
                                              ),
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        TextFormField(
                                          keyboardType: TextInputType.number,
                                          decoration: _decor(
                                            label: 'Transfer Qty (wt)',
                                            icon: Icons.scale_rounded,
                                            hint: 'e.g., 10',
                                          ),
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w800,
                                          ),
                                          onChanged:
                                              (v) => setState(() {
                                                _transferQty =
                                                    double.tryParse(v) ?? 0;
                                              }),
                                        ),
                                        const SizedBox(height: 12),

                                        _PrimaryBtn(
                                          icon: Icons.check_circle_rounded,
                                          label:
                                              anyLoading
                                                  ? 'Please wait...'
                                                  : 'Confirm',
                                          onTap:
                                              anyLoading
                                                  ? null
                                                  : () async {
                                                    if (_targetBagId == null) {
                                                      _snack(
                                                        'Select target bag',
                                                      );
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
                                                      _snack(
                                                        'Enter transfer qty',
                                                      );
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
                                                          (b) =>
                                                              b.id ==
                                                              _targetBagId,
                                                          orElse:
                                                              () =>
                                                                  throw Exception(
                                                                    'Target bag not found',
                                                                  ),
                                                        );

                                                    final maxQty =
                                                        target.maxQty ?? 0;
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
                                                          sourceBagId:
                                                              sourceBag.id!,
                                                          targetBagId:
                                                              _targetBagId!,
                                                          qty: _transferQty,
                                                        );

                                                    if (!mounted) return;
                                                    if (ok) {
                                                      setState(() {
                                                        _targetBagId = null;
                                                        _transferQty = 0;
                                                      });
                                                      _snack(
                                                        'Transferred successfully',
                                                      );
                                                    }
                                                  },
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
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

/* ---------------- Themed UI Helpers ---------------- */

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

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _surface),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _surface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
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
            style: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

Widget _stat(String label, String value, {required IconData icon}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _surfaceAlt.withValues(alpha: .55),
      border: Border.all(color: _stroke),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _stroke),
          ),
          child: Icon(icon, color: _ink900, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
