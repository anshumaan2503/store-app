import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domains/models/bag_model.dart';
import '../../../../controllers/bag_controller.dart';
import '../../issue/qr_code_scanner/qr_code_scanner.dart';
import 'bag_form_view.dart';
import 'bag_qr_code/bag_qr_code_print_page.dart';

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
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Bag'),
            content: Text('Are you sure you want to delete ${bag.bagCode}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              Consumer(
                builder: (context, ref, _) {
                  final isLoading = ref.watch(bagControllerProvider);
                  return ElevatedButton(
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
                    child: const Text('Delete'),
                  );
                },
              ),
            ],
          ),
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
                title: Text('Transfer from Bag: ${source.bagCode}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Source Stock: ${source.itemStock} | Used: ${source.itemUsed} | Max: ${source.maxQty}',
                      ),
                      const SizedBox(height: 12),

                      DropdownButtonFormField<String>(
                        initialValue: targetBagId,
                        decoration: const InputDecoration(
                          labelText: 'Select Target Bag (same item)',
                          border: OutlineInputBorder(),
                        ),
                        items:
                            sameItemTargets
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b.id,
                                    child: Text(
                                      '${b.bagCode} (Stock: ${b.itemStock}/${b.maxQty})',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: isLoading ? null : (v) => targetBagId = v,
                      ),

                      const SizedBox(height: 12),
                      TextFormField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Transfer Qty',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => qty = double.tryParse(v) ?? 0,
                      ),

                      if (target != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Target remaining capacity: ${targetRemainingCap ?? "-"}',
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
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

                              // FRONTEND maxQty check
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Bags Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed:
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QrCodeScanner()),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add),
      ),
      body: asyncBags.when(
        data: (bags) {
          if (bags.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(bagAllDataStreamProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No bags found. Pull to refresh.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bagAllDataStreamProvider),
            child: ListView.separated(
              itemCount: bags.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final bag = bags[index];

                return ListTile(
                  title: Text(
                    '${bag.bagCode} – ${bag.itemName}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Stock: ${bag.itemStock}   Used: ${bag.itemUsed}\n'
                    'MaxQty: ${bag.maxQty}\n'
                    'TransferType: ${bag.transferType}',
                  ),
                  isThreeLine: true,
                  onTap: () => _openForm(context, bag: bag),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      // IconButton(
                      //   icon: const Icon(Icons.swap_horiz),
                      //   tooltip: 'Transfer to other bag',
                      //   onPressed:
                      //       () => _openTransferDialog(ref, context, bag, bags),
                      // ),
                      IconButton(
                        icon: const Icon(Icons.qr_code),
                        tooltip: 'QR Code',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) =>
                                      BagQRCodePrintPage(bagModelList: [bag]),
                            ),
                          );
                        },
                      ),
                      // IconButton(
                      //   icon: const Icon(Icons.check),
                      //   onPressed: () {
                      //     Navigator.push(
                      //       context,
                      //       MaterialPageRoute(
                      //         builder:
                      //             (_) => AddBagToSortingJobPage(bagId: bag.id!),
                      //       ),
                      //     );
                      //   },
                      // ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(ref, context, bag),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
