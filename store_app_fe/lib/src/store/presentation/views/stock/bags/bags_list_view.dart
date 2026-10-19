import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../controllers/bag_controller.dart';
import '../../issue/qr_code_scanner/qr_code_scanner.dart';
import 'bag_form_view.dart';
import 'bag_qr_code/bag_qr_code_print_page.dart';

/* ---------------- Theme Tokens ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class BagsListView extends ConsumerWidget {
  const BagsListView({super.key});

  Future<void> _openForm(BuildContext context, {BagModel? bag}) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => BagFormView(existingBag: bag)));
  }

  void _confirmDelete(WidgetRef ref, BuildContext context, BagModel bag) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: _surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _stroke),
          ),
          title: const Text(
            'Delete Bag',
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
          content: Text(
            'Are you sure you want to delete ${bag.bagCode}?',
            style: const TextStyle(color: _ink700, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: _ink700,
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
              child: const Text('Cancel'),
            ),
            Consumer(
              builder: (context, ref, _) {
                final isLoading = ref.watch(bagControllerProvider);
                return FilledButton(
                  onPressed:
                      isLoading
                          ? null
                          : () async {
                            Navigator.of(context).pop();
                            if (bag.id == null) return;
                            final bagNotifier = ref.read(
                              bagControllerProvider.notifier,
                            );
                            await bagNotifier.deleteBag(id: bag.id!);
                          },
                  style: FilledButton.styleFrom(
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    disabledBackgroundColor: _ink600.withValues(alpha: .4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  child: Text(isLoading ? 'Deleting...' : 'Delete'),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openTransferDialog(
    WidgetRef ref,
    BuildContext context,
    BagModel source,
    List<BagModel> allBags,
  ) {
    final sameItemTargets =
        allBags
            .where((b) => b.itemId == source.itemId && b.id != source.id)
            .toList();

    String? targetBagId;
    double qty = 0;

    showDialog(
      context: context,
      builder:
          (_) => Consumer(
            builder: (context, ref, __) {
              final isLoading = ref.watch(bagControllerProvider);

              BagModel? target =
                  targetBagId == null
                      ? null
                      : sameItemTargets.firstWhere((b) => b.id == targetBagId);

              final targetRemainingCap =
                  target == null
                      ? null
                      : ((target.maxQty ?? 0) - (target.itemStock));

              return AlertDialog(
                backgroundColor: _surface,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: _stroke),
                ),
                title: Text(
                  'Transfer from Bag: ${source.bagCode}',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoPill(
                        text:
                            'Source Stock: ${source.itemStock} | Used: ${source.itemUsed} | Max: ${source.maxQty}',
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: targetBagId,
                        decoration: _inputDecoration(
                          label: 'Select Target Bag (same item)',
                          icon: Icons.swap_horiz_rounded,
                        ),
                        items:
                            sameItemTargets
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      '${b.bagCode} (Stock: ${b.itemStock}/${b.maxQty})',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: isLoading ? null : (v) => targetBagId = v,
                      ),

                      const SizedBox(height: 12),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(
                          label: 'Transfer Qty',
                          icon: Icons.numbers_rounded,
                        ),
                        onChanged: (v) => qty = double.tryParse(v) ?? 0,
                      ),

                      if (target != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Target remaining capacity: ${targetRemainingCap ?? "-"}',
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isLoading ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: _ink700,
                      textStyle: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        isLoading
                            ? null
                            : () async {
                              if (source.id == null) return;
                              if (targetBagId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Select target bag'),
                                  ),
                                );
                                return;
                              }
                              if (targetBagId == source.id) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Target cannot be same as source',
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (qty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter transfer qty'),
                                  ),
                                );
                                return;
                              }
                              if (qty > source.itemStock) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Source has only ${source.itemStock}',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final targetBag = sameItemTargets.firstWhere(
                                (b) => b.id == targetBagId,
                              );
                              final maxQty = targetBag.maxQty ?? 0;
                              if (maxQty <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Target maxQty is not set'),
                                  ),
                                );
                                return;
                              }

                              if ((targetBag.itemStock.toDouble() + qty) >
                                  maxQty.toDouble()) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Target bag will exceed maxQty ($maxQty)',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final notifier = ref.read(
                                bagControllerProvider.notifier,
                              );
                              final ok = await notifier.transferToOtherBag(
                                sourceBagId: source.id!,
                                targetBagId: targetBagId!,
                                qty: qty,
                              );

                              if (context.mounted && ok) {
                                Navigator.of(context).pop();
                              }
                            },
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: _surface,
                      disabledBackgroundColor: _ink600.withValues(alpha: .4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(isLoading ? 'Transferring...' : 'Transfer'),
                  ),
                ],
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncBags = ref.watch(bagAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Bags Management',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan QR',
            icon: const Icon(Icons.qr_code_scanner_rounded, color: _ink900),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrCodeScanner()),
                ),
          ),
        ],
      ),
      // floatingActionButton: FloatingActionButton(
      //   backgroundColor: _ink900,
      //   foregroundColor: _surface,
      //   elevation: 2,
      //   onPressed: () => _openForm(context),
      //   child: const Icon(Icons.add_rounded),
      // ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: asyncBags.when(
          data: (bags) {
            if (bags.isEmpty) {
              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(bagAllDataStreamProvider),
                color: _ink900,
                child: ListView(
                  children: const [
                    SizedBox(height: 200),
                    Center(
                      child: Text(
                        'No bags found. Pull to refresh.',
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(bagAllDataStreamProvider),
              color: _ink900,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                itemCount: bags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final bag = bags[index];

                  return _BagCard(
                    bag: bag,
                    onTap: () => _openForm(context, bag: bag),
                    onDelete: () => _confirmDelete(ref, context, bag),
                    onQr: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => BagQRCodePrintPage(bagModelList: [bag]),
                        ),
                      );
                    },
                    // onTransfer: () => _openTransferDialog(ref, context, bag, bags),
                  );
                },
              ),
            );
          },
          loading:
              () => const Center(
                child: CircularProgressIndicator(color: _ink900),
              ),
          error:
              (err, st) => Center(
                child: Text(
                  'Error: $err',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
        ),
      ),
    );
  }
}

/* ---------------- UI Parts ---------------- */

class _BagCard extends StatelessWidget {
  const _BagCard({
    required this.bag,
    required this.onTap,
    required this.onDelete,
    required this.onQr,
    // required this.onTransfer,
  });

  final BagModel bag;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onQr;
  // final VoidCallback onTransfer;

  @override
  Widget build(BuildContext context) {
    final title = '${bag.bagCode} – ${bag.itemName}';

    final subtitle =
        'Stock: ${bag.itemStock}   Used: ${bag.itemUsed}\n'
        'Bag Max Capacity: ${bag.maxQty}\n';
    // 'Transfer Type: ${bag.transferType}';

    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        // onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _stroke),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 14,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BadgeIcon(icon: Icons.inventory_2_rounded, text: bag.bagCode),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _IconChipButton(
                    icon: Icons.qr_code_rounded,
                    tooltip: 'QR Code',
                    onTap: onQr,
                  ),
                  const SizedBox(height: 8),
                  _IconChipButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    onTap: onDelete,
                  ),

                  // _IconChipButton(
                  //   icon: Icons.add,
                  //   tooltip: 'add bag',
                  //   onTap: () {
                  //     Navigator.push(
                  //       context,
                  //       MaterialPageRoute(
                  //         builder:
                  //             (_) => AddBagToSortingJobPage(bagId: bag.id!),
                  //       ),
                  //     );
                  //   },
                  // ),
                  _IconChipButton(
                    icon: Icons.edit,
                    tooltip: 'edit bag',
                    onTap: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _ink900, size: 22),
    );
  }
}

class _IconChipButton extends StatelessWidget {
  const _IconChipButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _surfaceAlt.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Icon(icon, color: _ink900, size: 20),
          ),
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
      ),
    );
  }
}

InputDecoration _inputDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
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
