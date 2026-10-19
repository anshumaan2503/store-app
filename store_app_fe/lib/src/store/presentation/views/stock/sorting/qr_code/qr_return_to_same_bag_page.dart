import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../controllers/bag_controller.dart';
import '../../../../../controllers/sorting_job_controller.dart';
import '../../../../../domains/models/bag_model.dart';
import '../../../../../domains/models/sorting_job_model.dart';

import 'qr_transfer_to_another_bag_page.dart'; // <-- adjust path

// ---------------------- Palette (same as Login) ----------------------
const _ink900 = Color(0xFF282321); // deep charcoal (titles/icons)
const _ink700 = Color(0xFF4D4542); // deep charcoal (titles/icons)
const _ink600 = Color(0xFF867471); // warm grey (subtitles/links)

const _surface = Color(0xFFFFFFFF); // white card
const _surfaceAlt = Color(0xFFFFF4E2); // warm cream
const _stroke = Color(0xFFDFE1D6); // soft sage border

const _accentMint = Color(0xFFB6D3CC); // mint
const _accentPeach = Color(0xFFF3D7C0); // peach

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

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
  // ---------------------- helpers ----------------------

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

  ButtonStyle _primaryBtn() => ElevatedButton.styleFrom(
    backgroundColor: _ink900,
    foregroundColor: _surface,
    elevation: 0,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
  );

  ButtonStyle _outlineBtn() => OutlinedButton.styleFrom(
    foregroundColor: _ink900,
    side: const BorderSide(color: _stroke),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontWeight: FontWeight.w900),
  );

  InputDecoration _fieldDec({
    required String label,
    required IconData icon,
    String? helper,
    String? hint,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    helperText: helper,
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

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
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
    child: Padding(padding: padding ?? const EdgeInsets.all(14), child: child),
  );

  Widget _chip({
    required IconData icon,
    required String label,
    required String value,
    Color? tint,
  }) {
    final bg = (tint ?? _accentMint).withValues(alpha: .35);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _ink900),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: _ink600, fontWeight: FontWeight.w800),
          ),
          Text(
            value,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _ink900,
        content: Text(msg, style: const TextStyle(color: _surface)),
      ),
    );
  }

  // ---------------------- dialogs/actions ----------------------

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

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Return to Same Bag',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _card(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bag',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Code',
                            value: bag.bagCode,
                            tint: _accentPeach,
                          ),
                          _chip(
                            icon: Icons.inventory_2_outlined,
                            label: 'Stock',
                            value: '${bag.itemStock}',
                          ),
                          _chip(
                            icon: Icons.scale_outlined,
                            label: 'Max',
                            value: '${bag.maxQty ?? 0}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Item: ${bag.itemName}',
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Bag ID: ${bag.id ?? "-"}',
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Job',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _chip(
                            icon: Icons.qr_code_2_outlined,
                            label: 'Job ID',
                            value: job.id ?? '-',
                          ),
                          _chip(
                            icon: Icons.flag_outlined,
                            label: 'Status',
                            value: job.status,
                            tint: _accentMint,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (!alreadyInJob)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withValues(alpha: .25)),
                    ),
                    child: const Text(
                      'This bag is NOT part of this job inputBags.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  _card(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Limits',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _chip(
                              icon: Icons.input_outlined,
                              label: 'Input WT',
                              value: '$inputQtyWt',
                            ),
                            _chip(
                              icon: Icons.swap_horiz_outlined,
                              label: 'Transferred',
                              value: '$inputTransferredWt',
                            ),
                            _chip(
                              icon: Icons.timelapse_outlined,
                              label: 'Bag Remaining',
                              value: '$bagRemainingInJob',
                              tint: _accentPeach,
                            ),
                            _chip(
                              icon: Icons.timelapse_outlined,
                              label: 'Job Remaining',
                              value: '$jobRemaining',
                            ),
                            _chip(
                              icon: Icons.warehouse_outlined,
                              label: 'Bag Capacity',
                              value: '$bagCapacityRemaining',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Max allowed transfer now: $maxAllowed',
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDec(
                    label: 'Return Qty (wt)',
                    icon: Icons.edit_outlined,
                    helper:
                        alreadyInJob
                            ? 'You can return up to $maxAllowed wt'
                            : 'Bag is not part of this job',
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: _ink600),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isLoading = ref.watch(sortingJobControllerProvider);
                return ElevatedButton(
                  style: _primaryBtn(),
                  onPressed:
                      (!alreadyInJob || isLoading)
                          ? null
                          : () async {
                            if (!_isActiveJob(job.status)) {
                              _snack(
                                'This job is not active. Cannot transfer.',
                              );
                              return;
                            }

                            final qty =
                                double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                            if (qty <= 0) {
                              _snack('Enter valid qty');
                              return;
                            }
                            if (qty > maxAllowed) {
                              _snack(
                                'Cannot transfer more than $maxAllowed wt',
                              );
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
                  widget.bagId, // this bag becomes target bag for QR transfer
            ),
      ),
    );
  }

  // ---------------------- UI ----------------------

  @override
  Widget build(BuildContext context) {
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'QR Bag Route',
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
        child: bagsAsync.when(
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
              return const Center(
                child: Text(
                  'Bag not found or itemId missing',
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
                ),
              );
            }

            return jobsAsync.when(
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
                    .where((j) => (j.id ?? '') == widget.jobId)
                    .cast<SortingJobModel?>()
                    .firstWhere((x) => x != null, orElse: () => null);

                if (job == null) {
                  return const Center(
                    child: Text(
                      'Job not found (wait refresh)',
                      style: TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                final bagItemId = (bag.itemId ?? '').toString();
                final jobItemId = (job.itemId).toString();

                final itemMatches =
                    bagItemId.isNotEmpty &&
                    jobItemId.isNotEmpty &&
                    bagItemId == jobItemId;

                final isBagInJob = _bagIsInJob(job, bag);

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Bag Summary',
                                  style: TextStyle(
                                    color: _ink900,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _chip(
                                      icon: Icons.confirmation_number_outlined,
                                      label: 'Bag',
                                      value: bag.bagCode,
                                      tint: _accentPeach,
                                    ),
                                    _chip(
                                      icon: Icons.inventory_2_outlined,
                                      label: 'Stock',
                                      value: '${bag.itemStock}',
                                    ),
                                    _chip(
                                      icon: Icons.auto_graph_outlined,
                                      label: 'Used',
                                      value: '${bag.itemUsed}',
                                    ),
                                    _chip(
                                      icon: Icons.scale_outlined,
                                      label: 'Max',
                                      value: '${bag.maxQty ?? 0}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Item: ${bag.itemName}',
                                  style: const TextStyle(
                                    color: _ink600,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'ItemId: ${bag.itemId}',
                                  style: const TextStyle(
                                    color: _ink600,
                                    fontWeight: FontWeight.w800,
                                  ),
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
                                  'Job Summary',
                                  style: TextStyle(
                                    color: _ink900,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _chip(
                                      icon: Icons.qr_code_2_outlined,
                                      label: 'Job ID',
                                      value: job.id ?? '-',
                                    ),
                                    _chip(
                                      icon: Icons.flag_outlined,
                                      label: 'Status',
                                      value: job.status,
                                      tint: _accentMint,
                                    ),
                                    _chip(
                                      icon: Icons.input_outlined,
                                      label: 'Total WT',
                                      value: '${job.totalInputQtyInWt}',
                                    ),
                                    _chip(
                                      icon: Icons.swap_horiz_outlined,
                                      label: 'Transferred',
                                      value: '${job.totalTransferQtyInWt ?? 0}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Job ItemId: ${job.itemId}',
                                  style: const TextStyle(
                                    color: _ink600,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (isBagInJob) ...[
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Action',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Return to same bag',
                                    style: TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: _primaryBtn(),
                                      onPressed:
                                          () => _openReturnPopup(
                                            bag: bag,
                                            job: job,
                                          ),
                                      child: const Text('Return to same bag'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (itemMatches) ...[
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Action',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Bag is not part of job inputBags.\nTransfer to another bag',
                                    style: TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      style: _outlineBtn(),
                                      onPressed: _goToTransferToAnotherBag,
                                      child: const Text(
                                        'Transfer to another bag',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Mismatch',
                                    style: TextStyle(
                                      color: _ink900,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: .06),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: .25),
                                      ),
                                    ),
                                    child: const Text(
                                      'Bag is not a match for this job (itemId mismatch).',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Bag itemId: $bagItemId',
                                    style: const TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  Text(
                                    'Job itemId: $jobItemId',
                                    style: const TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}
