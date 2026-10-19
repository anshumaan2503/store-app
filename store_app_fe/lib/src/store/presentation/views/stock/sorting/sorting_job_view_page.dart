import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/item_controller.dart';
import '../../../../controllers/bag_controller.dart';
import '../../../../controllers/sorting_job_controller.dart';

import '../../../../domains/models/item_model.dart';
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

enum TransferMode { sameBag, anotherBag }

class SortingJobViewPage extends ConsumerStatefulWidget {
  final String jobId;
  const SortingJobViewPage({super.key, required this.jobId});

  @override
  ConsumerState<SortingJobViewPage> createState() => _SortingJobViewPageState();
}

class _SortingJobViewPageState extends ConsumerState<SortingJobViewPage> {
  // Always pick an INPUT bag first
  String? _selectedInputBagCode;
  double _transferWt = 0.0;

  // Mode
  TransferMode _mode = TransferMode.sameBag;

  // Only for "another bag"
  String? _targetBagId;

  void _resetAnotherBagSelectionIfNeeded() {
    if (_mode == TransferMode.sameBag) {
      _targetBagId = null;
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: _ink900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submitTransfer(
    SortingJobModel job,
    List<BagModel> itemBags,
  ) async {
    final qty = _transferWt;

    if (_selectedInputBagCode == null) {
      _snack('Select an input bag');
      return;
    }

    if (qty <= 0) {
      _snack('Enter transfer weight');
      return;
    }

    // Selected input bag in the JOB (this is the source context)
    final input = job.inputBags.firstWhere(
      (b) => b.bagCode == _selectedInputBagCode,
    );

    // Remaining checks (bag-level + job-level)
    final bagTransferred = input.transferQtyInWt ?? 0;
    final bagRemaining = input.qtyInWt - bagTransferred;
    if (qty > bagRemaining) {
      _snack('Input bag remaining is $bagRemaining');
      return;
    }

    final jobTransferred = job.totalTransferQtyInWt ?? 0;
    final jobRemaining = job.totalInputQtyInWt - jobTransferred;
    if (qty > jobRemaining) {
      _snack('Job remaining is $jobRemaining');
      return;
    }

    final notifier = ref.read(sortingJobControllerProvider.notifier);

    // ---- MODE A: Same bag (transferOne) ----
    if (_mode == TransferMode.sameBag) {
      final ok = await notifier.transferOne(
        jobId: widget.jobId,
        bagCode: input.bagCode,
        transferQtyInWt: qty,
        bagId: input.bagId, // optional; send if available
      );

      // print(ok);

      if (!mounted) return;
      if (ok) {
        setState(() {
          _transferWt = 0;
        });
        ref.invalidate(sortingJobAllDataStreamProvider);
        ref.invalidate(bagAllDataStreamProvider);
        ref.invalidate(itemAllDataStreamProvider);
      }
      return;
    }

    // ---- MODE B: Another bag (transferToAnotherBag) ----
    // Need sourceBagId from selected input bag
    final sourceBagId = (input.bagId ?? '').trim();
    if (sourceBagId.isEmpty) {
      _snack('Selected input bag has no bagId');
      return;
    }

    if (_targetBagId == null || _targetBagId!.isEmpty) {
      _snack('Select a target bag');
      return;
    }

    if (_targetBagId == sourceBagId) {
      _snack('Target bag cannot be the same as input bag');
      return;
    }

    // Frontend maxQty check for better UX (backend must enforce too)
    final target = itemBags.firstWhere((b) => b.id == _targetBagId);
    final maxQty = target.maxQty ?? 0;
    if (maxQty <= 0) {
      _snack('Target bag maxQty not set');
      return;
    }

    // NOTE: If itemStock is NOT "wt", remove this check and rely on backend.
    final wouldExceed = (target.itemStock.toDouble() + qty) > maxQty.toDouble();
    if (wouldExceed) {
      _snack('Target bag will exceed maxQty ($maxQty)');
      return;
    }

    final ok = await notifier.transferToAnotherBag(
      jobId: widget.jobId,
      sourceBagId: sourceBagId,
      targetBagId: _targetBagId!,
      transferQtyInWt: qty,
    );

    if (!mounted) return;
    if (ok) {
      setState(() {
        _transferWt = 0;
        _targetBagId = null;
        _mode = TransferMode.sameBag; // optional: go back to default
      });
      ref.invalidate(sortingJobAllDataStreamProvider);
      ref.invalidate(bagAllDataStreamProvider);
      ref.invalidate(itemAllDataStreamProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(sortingJobAllDataStreamProvider);
    final bagsAsync = ref.watch(bagAllDataStreamProvider);
    final itemsAsync = ref.watch(itemAllDataStreamProvider);

    final isLoading = ref.watch(sortingJobControllerProvider); // bool

    final cs = Theme.of(context).colorScheme;

    final inputTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: _bgTop,
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _ink900,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _ink900,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        iconTheme: IconThemeData(color: _ink900),
      ),
      dividerTheme: const DividerThemeData(
        color: _stroke,
        thickness: 1,
        space: 18,
      ),
      cardTheme: CardThemeData(
        color: _surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _stroke),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        labelStyle: const TextStyle(color: _ink700),
        hintStyle: const TextStyle(color: _ink600),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _ink700, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.4),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _ink900,
          foregroundColor: _surface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _ink900,
          side: const BorderSide(color: _stroke),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _ink900;
          return _ink600;
        }),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: _ink700,
        textColor: _ink900,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
    );

    return Theme(
      data: inputTheme,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: Scaffold(
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
                  child: Text('Job not found (wait for WS refresh)'),
                );
              }

              return bagsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Bags error: $e')),
                data: (bags) {
                  final itemBags =
                      bags.where((b) => b.itemId == job.itemId).toList();

                  return itemsAsync.when(
                    loading:
                        () => const Center(child: CircularProgressIndicator()),
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

                      final jobRemaining =
                          job.totalInputQtyInWt -
                          (job.totalTransferQtyInWt ?? 0);
                      final isCompleted = job.status == 'completed';

                      // Selected input bag object (for showing remaining)
                      final selectedInput =
                          _selectedInputBagCode == null
                              ? null
                              : job.inputBags.firstWhere(
                                (b) => b.bagCode == _selectedInputBagCode,
                                orElse: () => job.inputBags.first,
                              );

                      final selectedInputId =
                          (selectedInput?.bagId ?? '').trim();

                      final allowedTargets =
                          itemBags.where((b) {
                            final id = (b.id ?? '').trim();
                            if (id.isEmpty) return false;
                            if (id == selectedInputId) return false;
                            return true;
                          }).toList();

                      _resetAnotherBagSelectionIfNeeded();

                      Widget infoRow(String k, String v) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 150,
                              child: Text(
                                '$k:',
                                style: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                v,
                                style: const TextStyle(color: _ink900),
                              ),
                            ),
                          ],
                        ),
                      );

                      Widget pill(String text) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceAlt,
                          border: Border.all(color: _stroke),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          text,
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      );

                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header card
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            job.itemName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        pill(job.status.toUpperCase()),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    infoRow('Machine', job.machineName ?? '-'),
                                    infoRow(
                                      'Opening Stock (live)',
                                      '${item.openingStock ?? 0}',
                                    ),
                                    const Divider(),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Total Bags',
                                            value: '${job.totalInputQtyInBags}',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Input WT',
                                            value: '${job.totalInputQtyInWt}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Transferred WT',
                                            value:
                                                '${job.totalTransferQtyInWt ?? 0}',
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _StatCard(
                                            label: 'Remaining WT',
                                            value: '$jobRemaining',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Input bags
                            const Text(
                              'Input Bags (progress)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _ink900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Column(
                                children: [
                                  ...job.inputBags.map((b) {
                                    final transferred = b.transferQtyInWt ?? 0;
                                    final remaining = b.qtyInWt - transferred;
                                    return Column(
                                      children: [
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            b.bagCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Input: ${b.qtyInWt}  •  Transferred: $transferred  •  Remaining: $remaining',
                                            style: const TextStyle(
                                              color: _ink600,
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Transfer section
                            if (!isCompleted) ...[
                              const Text(
                                'Transfer',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _ink900,
                                ),
                              ),
                              const SizedBox(height: 8),

                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedInputBagCode,
                                        decoration: const InputDecoration(
                                          labelText: 'Select Input Bag',
                                          border: OutlineInputBorder(),
                                        ),
                                        items:
                                            job.inputBags.map((b) {
                                              final remaining =
                                                  b.qtyInWt -
                                                  (b.transferQtyInWt ?? 0);
                                              return DropdownMenuItem(
                                                value: b.bagCode,
                                                child: Text(
                                                  '${b.bagCode} (remaining: $remaining)',
                                                  style: TextStyle(
                                                    color: _ink600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                        onChanged: (v) {
                                          setState(() {
                                            _selectedInputBagCode = v;
                                            _targetBagId = null;
                                          });
                                        },
                                      ),

                                      const SizedBox(height: 12),

                                      const Text(
                                        'Transfer Mode',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: _ink700,
                                        ),
                                      ),
                                      const SizedBox(height: 6),

                                      RadioListTile<TransferMode>(
                                        value: TransferMode.sameBag,
                                        groupValue: _mode,
                                        title: const Text('Return to same bag'),
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() {
                                            _mode = v;
                                            _targetBagId = null;
                                          });
                                        },
                                      ),
                                      RadioListTile<TransferMode>(
                                        value: TransferMode.anotherBag,
                                        groupValue: _mode,
                                        title: const Text(
                                          'Transfer to another bag',
                                        ),
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() {
                                            _mode = v;
                                            _targetBagId = null;
                                          });
                                        },
                                      ),

                                      const SizedBox(height: 10),

                                      if (_mode == TransferMode.anotherBag) ...[
                                        DropdownButtonFormField<String>(
                                          initialValue: _targetBagId,
                                          decoration: const InputDecoration(
                                            labelText:
                                                'Select Target Bag (same item)',
                                            border: OutlineInputBorder(),
                                          ),
                                          items:
                                              allowedTargets.map((b) {
                                                return DropdownMenuItem(
                                                  value: b.id,
                                                  child: Text(
                                                    '${b.bagCode} (stock: ${b.itemStock}/${b.maxQty})',
                                                    style: TextStyle(
                                                      color: _ink600,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                          onChanged:
                                              (v) => setState(
                                                () => _targetBagId = v,
                                              ),
                                        ),
                                        const SizedBox(height: 10),
                                        if (_selectedInputBagCode != null &&
                                            allowedTargets.isEmpty)
                                          const Text(
                                            'No valid target bags.',
                                            style: TextStyle(
                                              color: Colors.red,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                      ],

                                      const SizedBox(height: 10),

                                      TextFormField(
                                        keyboardType: TextInputType.number,
                                        decoration: const InputDecoration(
                                          labelText: 'Transfer Qty (wt)',
                                          border: OutlineInputBorder(),
                                        ),
                                        onChanged:
                                            (v) => setState(
                                              () =>
                                                  _transferWt =
                                                      double.tryParse(v) ?? 0,
                                            ),
                                        style: TextStyle(color: _ink700),
                                      ),

                                      const SizedBox(height: 12),

                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          onPressed:
                                              isLoading
                                                  ? null
                                                  : () => _submitTransfer(
                                                    job,
                                                    itemBags,
                                                  ),
                                          child: Text(
                                            isLoading
                                                ? 'Processing...'
                                                : 'Transfer',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else ...[
                              const Text(
                                'Job is completed.',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: _ink900,
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Live bags list
                            const Text(
                              'Live Bags List (same itemId)',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _ink900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Card(
                              child: Column(
                                children: [
                                  ...itemBags.map((b) {
                                    return Column(
                                      children: [
                                        ListTile(
                                          dense: true,
                                          title: Text(
                                            b.bagCode,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'Stock: ${b.itemStock}  •  Used: ${b.itemUsed}  •  Max: ${b.maxQty}',
                                            style: const TextStyle(
                                              color: _ink600,
                                            ),
                                          ),
                                        ),
                                        const Divider(height: 1),
                                      ],
                                    );
                                  }),
                                ],
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
        ),
      ),
    );
  }
}

/* ---------------- Small themed stat card ---------------- */
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        border: Border.all(color: _stroke),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
