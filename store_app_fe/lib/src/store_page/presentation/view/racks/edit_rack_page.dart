// lib/src/store/presentation/views/racks/edit_rack_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../domains/models/store_rack_model.dart';
import 'widgets/racks_shared_widgets.dart';
import 'widgets/racks_theme.dart';

class EditRackPage extends ConsumerStatefulWidget {
  const EditRackPage({super.key, required this.rack, required this.canEdit});
  final StoreRack rack;
  final bool canEdit;
  @override
  ConsumerState<EditRackPage> createState() => _EditRackPageState();
}

class _EditRackPageState extends ConsumerState<EditRackPage> {
  Future<void> _confirmRemoveItem(String rackId, String itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm"),
            content: const Text("Do you want to remove this item?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(storeItemsControllerProvider)
                      .transferRack(itemId: itemId, toRackId: rackId);

                  if (ok == true) {
                    ref.invalidate(storeRoomPagedStreamProvider);
                    ref.invalidate(storeRackPagedStreamProvider);
                  }

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );

    if (ok == true) {
      ref.invalidate(storeRoomPagedStreamProvider);
      ref.invalidate(storeRackPagedStreamProvider);
    }
  }

  Future<void> _confirmRemoveRack(String rackId) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Confirm"),
            content: const Text("Do you want to remove this rack?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await ref
                      .read(storeItemsControllerProvider)
                      .removeRack(toRackId: rackId);

                  if (ok == true) {
                    ref.invalidate(storeRoomPagedStreamProvider);
                    ref.invalidate(storeRackPagedStreamProvider);
                  }

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );

    if (ok == true) {
      ref.invalidate(storeRoomPagedStreamProvider);
      ref.invalidate(storeRackPagedStreamProvider);
    }
  }

  Future<void> _openTransferItem({
    required String itemId,
    required StoreRack rack,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferItemDialog(item: itemId, rack: rack),
    );

    if (ok == true) {
      // refresh
      ref.invalidate(storeRoomPagedStreamProvider);
      ref.invalidate(storeRackPagedStreamProvider);
    }
  }

  int _asInt(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        final canTransfer =
            user?.appWorks.contains("storeitemtransfer") ?? false;

        return Scaffold(
          backgroundColor: surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: ink900),
            title: const Text(
              'Edit Rack',
              style: TextStyle(color: ink900, fontWeight: FontWeight.w900),
            ),
          ),
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [bgTop, bgBottom],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: AppCard(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Rack Details',
                            style: TextStyle(
                              color: ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 14),

                          Builder(
                            builder: (context) {
                              final rackAv = ref.watch(
                                rackDataStockDataStreamProvider(widget.rack.id),
                              );

                              return rackAv.when(
                                loading:
                                    () => const LinearProgressIndicator(
                                      minHeight: 2,
                                    ),
                                error: (e, _) => Text('Rack load error: $e'),
                                data: (rack) {
                                  if (rack == null) {
                                    return const Center(
                                      child: Text(
                                        "Rack data is not available",
                                        style: TextStyle(
                                          color: ink900,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    );
                                  }

                                  final rackId =
                                      (rack["_id"] ??
                                              rack["id"] ??
                                              widget.rack.id)
                                          .toString();

                                  final roomName =
                                      (rack["roomName"] ?? '').toString();
                                  final code = (rack["code"] ?? '').toString();
                                  final remark =
                                      (rack["remark"] ?? '').toString();
                                  final isScrap = rack["isScrap"] == true;

                                  final itemList = _asMapList(rack["itemlist"]);
                                  final hasItems = itemList.isNotEmpty;

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ReadRow(
                                        label: 'Room Name',
                                        value: roomName,
                                        icon: Icons.meeting_room_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      ReadRow(
                                        label: 'Rack Code',
                                        value: code,
                                        icon: Icons.qr_code_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      ReadRow(
                                        label: 'Remark',
                                        value: remark.isEmpty ? '—' : remark,
                                        icon: Icons.notes_rounded,
                                      ),
                                      const SizedBox(height: 10),
                                      ReadRow(
                                        label: 'Rack Type',
                                        value: isScrap ? 'Scrap' : 'Good',
                                        icon: Icons.category_rounded,
                                      ),
                                      const SizedBox(height: 14),

                                      if (!hasItems) ...[
                                        const Text(
                                          "No item assigned to this rack.",
                                          style: TextStyle(
                                            color: ink700,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        (user!.isSuperAdmin)
                                            ? ElevatedButton(
                                              onPressed:
                                                  () => _confirmRemoveRack(
                                                    rackId,
                                                  ),
                                              child: const Text(
                                                "Remove the Rack",
                                              ),
                                            )
                                            : SizedBox.shrink(),
                                      ] else ...[
                                        const Text(
                                          "Items in this rack",
                                          style: TextStyle(
                                            color: ink900,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        const SizedBox(height: 10),

                                        ...itemList.map((it) {
                                          final itemId =
                                              (it["itemId"] ?? '').toString();
                                          final itemCode =
                                              (it["itemCode"] ?? '').toString();
                                          final itemName =
                                              (it["itemName"] ?? '').toString();

                                          final total = _asInt(
                                            it["totalStockQuantity"],
                                          );
                                          final avail = _asInt(
                                            it["stockAvailableQuantity"],
                                          );
                                          final issued = _asInt(
                                            it["stockIssueQuantity"],
                                          );
                                          final scrap = _asInt(
                                            it["stockscrapQuantity"],
                                          );

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 12,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: surfaceAlt.withValues(
                                                alpha: .55,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(color: stroke),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  '$itemName ($itemCode)',
                                                  style: const TextStyle(
                                                    color: ink900,
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 6,
                                                  children: [
                                                    _MiniStat(
                                                      label: 'Total',
                                                      value: '$total',
                                                    ),
                                                    _MiniStat(
                                                      label: 'Avail',
                                                      value: '$avail',
                                                    ),
                                                    _MiniStat(
                                                      label: 'Issued',
                                                      value: '$issued',
                                                    ),
                                                    _MiniStat(
                                                      label: 'Scrap',
                                                      value: '$scrap',
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 10),

                                                if (avail > 0 &&
                                                    canTransfer &&
                                                    widget.canEdit)
                                                  ElevatedButton(
                                                    onPressed:
                                                        () => _openTransferItem(
                                                          itemId: itemId,
                                                          rack: widget.rack,
                                                        ),
                                                    child: const Text(
                                                      "Transfer Qty",
                                                    ),
                                                  )
                                                else if (widget.canEdit)
                                                  ElevatedButton(
                                                    onPressed:
                                                        () =>
                                                            _confirmRemoveItem(
                                                              rackId,
                                                              itemId,
                                                            ),
                                                    child: const Text(
                                                      "Remove Item",
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        }),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: stroke),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: ink700,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

/* ---------- Transfer Item Dialog (same as your existing) ---------- */
class _TransferItemDialog extends ConsumerStatefulWidget {
  const _TransferItemDialog({required this.item, required this.rack});
  final String item;
  final StoreRack rack;

  @override
  ConsumerState<_TransferItemDialog> createState() =>
      _TransferItemDialogState();
}

class _TransferItemDialogState extends ConsumerState<_TransferItemDialog> {
  String _q = '';
  StoreRack? _toRack;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  late final Map<String, dynamic> query;

  @override
  void initState() {
    query = {"itemId": widget.item, "rackId": widget.rack.id};
    super.initState();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  int? _parseQty() {
    final s = _qtyCtrl.text.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(
      sameItemRacksWithItemAndRackDataStreamProvider(query),
    );

    final rackstockAv = ref.watch(rackByItemDataStockDataStreamProvider(query));

    final itemAv = ref.watch(itemFindOneStreamProvider(widget.item));

    return itemAv.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Item load error: $e')),
      data: (item) {
        final int maxQty = item?.stockAvailableQuantity ?? 0;

        return rackstockAv.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Rack load error: $e')),
          data: (paged) {
            final rackStock = paged;
            final rackAvail =
                int.tryParse(
                  (rackStock?["stockAvailableQuantity"] ?? "0").toString(),
                ) ??
                0;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Transfer Item'),
              content: SizedBox(
                width: 560,
                height: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HintBar(
                      text:
                          'Move quantity from this rack to another rack. Quantity must be ≤ Available.',
                    ),
                    const SizedBox(height: 10),
                    InfoRow(
                      label: 'Item',
                      value:
                          '${item?.itemName ?? ''} (${item?.itemCode ?? ''})',
                    ),
                    InfoRow(label: 'Available', value: '$maxQty'),
                    InfoRow(
                      label: 'Rack',
                      value: '${(rackStock?["code"] ?? '')}',
                    ),
                    InfoRow(label: 'Rack Available', value: '$rackAvail'),
                    const SizedBox(height: 10),

                    TextField(
                      onChanged: (v) => setState(() => _q = v.trim()),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search destination rack...',
                      ),
                    ),
                    const SizedBox(height: 10),

                    Expanded(
                      child: racksAv.when(
                        loading:
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (e, _) =>
                                Center(child: Text('Rack load error: $e')),
                        data: (paged) {
                          final list = paged;
                          final q = _q.trim().toLowerCase();
                          final filteredList =
                              q.isEmpty
                                  ? list
                                  : list.where((r) {
                                    final s = (r.code).toLowerCase();
                                    return s.contains(q);
                                  }).toList();

                          if (filteredList.isEmpty) {
                            return const Center(
                              child: Text('No destination racks found.'),
                            );
                          }

                          return ListView.separated(
                            itemCount: filteredList.length,
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final r = filteredList[i];
                              final sel = _toRack?.id == r.id;
                              return ListTile(
                                onTap: () => setState(() => _toRack = r),
                                leading: Icon(
                                  sel
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: sel ? surface : ink600,
                                ),
                                title: Text(
                                  r.code,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(r.code),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                    TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.swap_horiz_rounded),
                        hintText: 'Enter quantity (max $rackAvail)',
                        helperText: 'Quantity must be between 1 and $rackAvail',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed:
                      _busy
                          ? null
                          : () async {
                            final qty = _parseQty();
                            if (_toRack == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Select destination rack'),
                                ),
                              );
                              return;
                            }

                            if (qty == null || qty <= 0 || qty > rackAvail) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter valid quantity (1..$rackAvail)',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _busy = true);
                            try {
                              final ok = await ref
                                  .read(storeItemsControllerProvider)
                                  .transferItem(
                                    itemId: widget.item,
                                    fromRackId: widget.rack.id,
                                    toRackId: _toRack!.id,
                                    qty: qty,
                                  );

                              if (!mounted) return;

                              if (ok) {
                                Navigator.pop(context, true);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Transfer failed'),
                                  ),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                  child: Text(_busy ? 'Transferring...' : 'Confirm'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
