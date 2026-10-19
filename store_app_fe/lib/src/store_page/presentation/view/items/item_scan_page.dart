import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../components/constants.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import 'item_edit_page.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _accentSoft = Color(0xFFE8F1EE);

class ItemScanPage extends ConsumerStatefulWidget {
  const ItemScanPage({super.key, this.initialItemId, this.canEdit});
  final bool? canEdit;
  final String? initialItemId;

  @override
  ConsumerState<ItemScanPage> createState() => _ItemScanPageState();
}

class _ItemScanPageState extends ConsumerState<ItemScanPage> {
  String? _itemId;
  String? _scanError;
  Map<String, dynamic>? _selectedRack;
  bool _scannerPaused = false;

  final Map<String, String> _overrideImageUrlByItemId = {};
  final Map<String, String> _imageVersionByItemId = {};

  final _manualCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _itemId = widget.initialItemId;
    if (_itemId != null) _manualCtrl.text = _itemId!;
  }

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  bool _hasAnyQty(StoreItemsModel it) {
    return (it.totalStockQuantity > 0) ||
        (it.stockAvailableQuantity > 0) ||
        (it.stockIssueQuantity > 0) ||
        (it.stockissueCompleted > 0) ||
        (it.stockscrapQuantity > 0);
  }

  String? _extractObjectId(String raw) {
    final m = RegExp(r'([a-fA-F0-9]{24})').firstMatch(raw);
    return m?.group(1);
  }

  void _setItemId(String? id) {
    setState(() {
      _scanError = null;
      _itemId = id;
      if (id != null) _manualCtrl.text = id;
    });
  }

  void _refreshItem() {
    final id = _itemId;
    if (id == null) return;

    ref.invalidate(itemFindOneStreamProvider(id));
    ref.invalidate(itemPagedStreamProvider);
    ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
    ref.invalidate(allRackByItemDataStockDataStreamProvider(id));
    ref.invalidate(rackDataByItemNonZeroDataStreamProvider(id));
  }

  Future<void> _openEdit(StoreItemsModel it) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ItemEditPage(initial: it)),
    );
    if (ok == true) _refreshItem();
  }

  Future<void> _confirmDelete(StoreItemsModel item) async {
    final hasQty = _hasAnyQty(item);
    if (hasQty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delete is allowed only when quantity is 0.'),
        ),
      );
      return;
    }

    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('Delete "${item.itemName}" (${item.itemCode})?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (yes != true) return;

    final ok = await ref
        .read(storeItemsControllerProvider)
        .deleteItems(item.id);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Deleted' : 'Delete failed')));

    if (ok) {
      _setItemId(null);
    } else {
      _refreshItem();
    }
  }

  Future<void> _openSelectRackDialog(String itemId) async {
    try {
      final raw = await ref
          .read(storeRackControllerProvider)
          .getRacksByItem(itemId);
      final list = raw.whereType<Map<String, dynamic>>().toList();

      if (list.isEmpty) {
        showSnackBar('Rack data is not available');
        return;
      }

      if (list.length == 1) {
        setState(() => _selectedRack = list.first);
        return;
      }

      final selectedRack = await showDialog<Map<String, dynamic>>(
        context: context,
        builder:
            (_) => RackByItemSelectionDialog(
              itemId: itemId,
              initialRackId: _selectedRack?["_id"]?.toString(),
            ),
      );

      if (selectedRack != null) {
        setState(() => _selectedRack = selectedRack);
      }
    } finally {}
  }

  Future<void> _openTransferItem(StoreItemsModel it) async {
    final maxQty = it.stockAvailableQuantity;
    if (maxQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available quantity to transfer.')),
      );
      return;
    }

    if (_selectedRack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a rack first to transfer item.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferItemDialog(item: it, rack: _selectedRack!),
    );

    if (ok == true) _refreshItem();
  }

  Future<void> _openUpdateImage(StoreItemsModel it) async {
    final newUrl = await showDialog<String?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UpdateItemImageDialog(itemId: it.id),
    );

    if (!mounted) return;
    if (newUrl == null || newUrl.trim().isEmpty) return;

    setState(() {
      _overrideImageUrlByItemId[it.id] = newUrl.trim();
      _imageVersionByItemId[it.id] =
          DateTime.now().millisecondsSinceEpoch.toString();
    });

    _refreshItem();
  }

  PopupMenuButton<ItemCardAction> _buildActionsMenu(StoreItemsModel it) {
    final hasQty = _hasAnyQty(it);

    return PopupMenuButton<ItemCardAction>(
      icon: const Icon(Icons.more_vert_rounded, color: _ink700),
      onSelected: (a) async {
        switch (a) {
          case ItemCardAction.edit:
            await _openEdit(it);
            break;
          case ItemCardAction.updateImage:
            await _openUpdateImage(it);
            break;
          case ItemCardAction.transferRack:
            break;
          case ItemCardAction.transferItem:
            await _openSelectRackDialog(it.id);
            await _openTransferItem(it);
            break;
          case ItemCardAction.delete:
            await _confirmDelete(it);
            break;
        }
      },
      itemBuilder: (_) {
        final items = <PopupMenuEntry<ItemCardAction>>[
          const PopupMenuItem(value: ItemCardAction.edit, child: Text('Edit')),
          const PopupMenuItem(
            value: ItemCardAction.updateImage,
            child: Text('Update Image'),
          ),
        ];

        if (hasQty) {
          items.add(
            const PopupMenuItem(
              value: ItemCardAction.transferItem,
              child: Text('Transfer Item'),
            ),
          );
        }

        items.add(const PopupMenuDivider());
        return items;
      },
    );
  }

  Widget _scannerCard() {
    return _Card(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _HintBar(
            text:
                'Scan item QR. The code can contain raw itemId, URL, or JSON; we will extract ObjectId.',
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: 1.15,
              child: MobileScanner(
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                ),
                onDetect: (capture) {
                  if (_scannerPaused) return;

                  final codes = capture.barcodes;
                  final raw =
                      codes.isNotEmpty ? (codes.first.rawValue ?? '') : '';
                  final id = _extractObjectId(raw);

                  if (id == null) {
                    setState(() {
                      _scanError =
                          'Scanned value does not contain a valid item id.';
                    });
                    return;
                  }

                  setState(() {
                    _scannerPaused = true;
                    _scanError = null;
                  });

                  _setItemId(id);
                },
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  _scannerPaused
                      ? 'Scanner paused (item selected).'
                      : 'Scanning...',
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _scannerPaused = false;
                    _scanError = null;
                    _selectedRack = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Rescan'),
              ),
            ],
          ),
          if (_scanError != null) ...[
            const SizedBox(height: 6),
            Text(
              _scanError!,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _itemView(String itemId) {
    final av = ref.watch(itemFindOneStreamProvider(itemId));
    final racksD = ref.watch(allRackByItemDataStockDataStreamProvider(itemId));

    return av.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (e, _) => _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Error: $e',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _refreshItem,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
      data: (it) {
        if (it == null) {
          return const _EmptyState(
            title: 'Item not found',
            subtitle: 'Verify item id and try again.',
          );
        }

        final imgUrl = (_overrideImageUrlByItemId[it.id] ?? it.imageUrl).trim();
        final versionKey = _imageVersionByItemId[it.id];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  _ItemThumb(url: imgUrl, versionKey: versionKey, size: 58),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          it.itemName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          it.itemCode,
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MiniStatPill(
                              label: 'Available',
                              value: '${it.stockAvailableQuantity}',
                            ),
                            _MiniStatPill(
                              label: 'Total',
                              value: '${it.totalStockQuantity}',
                            ),
                            _MiniStatPill(
                              label: 'Issued',
                              value: '${it.stockIssueQuantity}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.canEdit ?? false) ...[
                    IconButton(
                      tooltip: 'Edit Item',
                      onPressed: () => _openEdit(it),
                      icon: const Icon(Icons.edit_outlined, color: _ink900),
                    ),
                    _buildActionsMenu(it),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ReadRow(
              label: 'Item Code',
              value: it.itemCode,
              icon: Icons.text_fields_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Item Name',
              value: it.itemName,
              icon: Icons.text_fields_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Category',
              value: it.categoryLabel,
              icon: Icons.category_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Unit',
              value: it.unit,
              icon: Icons.straighten_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Description',
              value: it.description,
              icon: Icons.notes_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Total Stock',
              value: it.totalStockQuantity.toString(),
              icon: Icons.numbers_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Available Stock',
              value: it.stockAvailableQuantity.toString(),
              icon: Icons.numbers_rounded,
            ),
            const SizedBox(height: 4),
            _ReadRow(
              label: 'Issued Stock',
              value: it.stockIssueQuantity.toString(),
              icon: Icons.numbers_rounded,
            ),
            const SizedBox(height: 14),
            racksD.when(
              loading:
                  () => const _Card(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              error:
                  (e, _) => _Card(
                    child: Text(
                      'Rack stock load error: $e',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              data: (racks) {
                if (racks.isEmpty) {
                  return const _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(
                          title: 'Rack Stock Overview',
                          subtitle:
                              'No rack stock data available for this item.',
                          icon: Icons.warehouse_rounded,
                        ),
                      ],
                    ),
                  );
                }

                final totalRackAvailable = racks.fold<int>(
                  0,
                  (sum, r) =>
                      sum +
                      ((r["stockAvailableQuantity"] as num?)?.toInt() ??
                          int.tryParse('${r["stockAvailableQuantity"]}') ??
                          0),
                );

                return _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(
                        title: 'Rack Stock Overview',
                        subtitle:
                            '${racks.length} rack(s) mapped • $totalRackAvailable total available in racks',
                        icon: Icons.warehouse_rounded,
                      ),
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: racks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final rack = racks[i];
                          final isSelected =
                              (_selectedRack?["_id"]?.toString() ?? '') ==
                              (rack["_id"]?.toString() ?? '');

                          return _RackStockCard(
                            rack: rack,
                            isSelected: isSelected,
                            onSelect: () {
                              setState(() {
                                _selectedRack = rack;
                              });
                            },
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final id = _itemId;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: const Text(
          'Scan Item',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          if (id != null && (widget.canEdit ?? false))
            IconButton(
              tooltip: 'Edit Item',
              onPressed: () async {
                final it = ref.read(itemFindOneStreamProvider(id)).value;
                if (it != null) await _openEdit(it);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            onPressed: () {
              if (id != null) _refreshItem();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView(
                        children: [
                          if (id == null) _scannerCard() else _itemView(id),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum ItemCardAction { edit, updateImage, transferRack, transferItem, delete }

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsets padding;

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
      child: Padding(padding: padding, child: child),
    );
  }
}

class _HintBar extends StatelessWidget {
  const _HintBar({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(10),
      child: Text(
        text,
        style: const TextStyle(color: _ink700, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_rounded, size: 40, color: _ink600),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: _ink700, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _surfaceAlt.withValues(alpha: .65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _stroke),
          ),
          child: Icon(icon, color: _ink900),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatPill extends StatelessWidget {
  const _MiniStatPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: _ink900,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RackStockCard extends StatelessWidget {
  const _RackStockCard({
    required this.rack,
    required this.isSelected,
    required this.onSelect,
  });

  final Map<String, dynamic> rack;
  final bool isSelected;
  final VoidCallback onSelect;

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final code = (rack["code"] ?? "").toString();
    final room = (rack["roomName"] ?? "").toString();
    final remark = (rack["remark"] ?? "").toString().trim();

    final total = _toInt(rack["totalStockQuantity"]);
    final available = _toInt(rack["stockAvailableQuantity"]);
    final issued = _toInt(rack["stockIssueQuantity"]);
    final scrap = _toInt(rack["stockscrapQuantity"]);

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? _accentSoft : _surfaceAlt.withValues(alpha: .45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _ink700 : _stroke,
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    code.isEmpty ? 'Rack' : code,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Text(
                      'Selected',
                      style: TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              room.isEmpty ? 'Room not available' : room,
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RackMetricChip(label: 'Available', value: '$available'),
                _RackMetricChip(label: 'Total', value: '$total'),
                _RackMetricChip(label: 'Issued', value: '$issued'),
                _RackMetricChip(label: 'Scrap', value: '$scrap'),
              ],
            ),
            if (remark.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Remark: $remark',
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Align(
            //   alignment: Alignment.centerRight,
            //   child: OutlinedButton.icon(
            //     onPressed: onSelect,
            //     icon: Icon(
            //       isSelected
            //           ? Icons.check_circle_rounded
            //           : Icons.radio_button_unchecked_rounded,
            //       size: 18,
            //     ),
            //     label: Text(
            //       isSelected ? 'Selected for Transfer' : 'Use for Transfer',
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

class _RackMetricChip extends StatelessWidget {
  const _RackMetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: _ink900,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: _surface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _surface,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransferItemDialog extends ConsumerStatefulWidget {
  const _TransferItemDialog({required this.item, required this.rack});
  final StoreItemsModel item;
  final Map<String, dynamic> rack;

  @override
  ConsumerState<_TransferItemDialog> createState() =>
      _TransferItemDialogState();
}

class _TransferItemDialogState extends ConsumerState<_TransferItemDialog> {
  String _q = '';
  StoreRack? _toRack;
  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  int get _maxQty => widget.item.stockAvailableQuantity;

  Map<String, dynamic> query = {};

  @override
  void initState() {
    query = {"itemId": widget.item.id, "rackId": widget.rack["_id"]};
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
    final rackstockAv = ref.watch(
      rackDataByItemNonZeroDataStreamProvider(widget.item.id),
    );

    return rackstockAv.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Rack load error: $e')),
      data: (paged) {
        final fromRack = paged.firstWhere(
          (r) => r["_id"] == widget.rack["_id"],
        );

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
                const _HintBar(
                  text:
                      'Move quantity from this rack to another rack. Quantity must be ≤ Available.',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  label: 'Item',
                  value: '${widget.item.itemName} (${widget.item.itemCode})',
                ),
                _InfoRow(label: 'Available', value: '$_maxQty'),
                _InfoRow(label: 'Rack', value: '${fromRack["code"]}'),
                _InfoRow(
                  label: 'Rack Available',
                  value: '${fromRack["stockAvailableQuantity"]}',
                ),
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
                        () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Rack load error: $e')),
                    data: (list) {
                      final q = _q.trim().toLowerCase();
                      final filtered =
                          q.isEmpty
                              ? list
                              : list
                                  .where(
                                    (r) => (r.code).toLowerCase().contains(q),
                                  )
                                  .toList();

                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text('No destination racks found.'),
                        );
                      }

                      return ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final r = filtered[i];
                          final sel = _toRack?.id == r.id;
                          return ListTile(
                            onTap: () => setState(() => _toRack = r),
                            leading: Icon(
                              sel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: sel ? _surface : _ink600,
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
                    hintText:
                        'Enter quantity (max ${fromRack["stockAvailableQuantity"]})',
                    helperText:
                        'Quantity must be between 1 and ${fromRack["stockAvailableQuantity"]}',
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

                        final maxFromRack =
                            int.tryParse(
                              fromRack["stockAvailableQuantity"].toString(),
                            ) ??
                            0;

                        if (qty == null || qty <= 0 || qty > maxFromRack) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Enter valid quantity (1..$maxFromRack)',
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
                                itemId: widget.item.id,
                                fromRackId: widget.rack["_id"],
                                toRackId: _toRack!.id,
                                qty: qty,
                              );

                          if (!mounted) return;
                          if (ok) {
                            Navigator.pop(context, true);
                            Navigator.pop(context, true);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Transfer failed')),
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
  }
}

class RackByItemSelectionDialog extends ConsumerStatefulWidget {
  const RackByItemSelectionDialog({
    super.key,
    required this.itemId,
    this.initialRackId,
  });

  final String itemId;
  final String? initialRackId;

  @override
  ConsumerState<RackByItemSelectionDialog> createState() =>
      _RackByItemSelectionDialogState();
}

class _RackByItemSelectionDialogState
    extends ConsumerState<RackByItemSelectionDialog> {
  Map<String, dynamic>? _rack;
  bool _didInit = false;

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(
      rackDataByItemNonZeroDataStreamProvider(widget.itemId),
    );

    return AlertDialog(
      title: const Text('Select Rack'),
      content: SizedBox(
        width: 520,
        child: racksAv.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Rack load error: $e'),
          data: (racks) {
            final list = racks;

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Data is not available'),
              );
            }

            final mustPick = list.length > 1;

            if (!_didInit) {
              _didInit = true;

              if (widget.initialRackId != null) {
                final hit =
                    list
                        .where(
                          (x) =>
                              (x["_id"] ?? "").toString() ==
                              widget.initialRackId,
                        )
                        .toList();
                if (hit.isNotEmpty) _rack = hit.first;
              }

              if (!mustPick) {
                _rack ??= list.first;
              }

              if (mustPick && _rack != null) {
                final exists = list.any(
                  (x) =>
                      (x["_id"] ?? "").toString() ==
                      (_rack!["_id"] ?? "").toString(),
                );
                if (!exists) _rack = null;
              }
            }

            if (_rack != null) {
              final exists = list.any(
                (x) =>
                    (x["_id"] ?? "").toString() ==
                    (_rack!["_id"] ?? "").toString(),
              );
              if (!exists) _rack = null;
            }

            final canSubmit = !mustPick || _rack != null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DropdownField<Map<String, dynamic>>(
                  label: 'Rack *',
                  hint: 'Select rack',
                  icon: Icons.category_rounded,
                  value: _rack,
                  items: list,
                  textOf:
                      (x) =>
                          '${x["itemName"]} (${x["code"]}) • ${x["roomName"]}',
                  onChanged: (rack) => setState(() => _rack = rack),
                  allowNull: mustPick,
                  nullLabel: 'Select rack...',
                ),
                const SizedBox(height: 10),
                if (!canSubmit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Please select a rack to continue.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_rack != null) ...[
                  const SizedBox(height: 12),
                  _RackDetailsCard(rack: _rack),
                ],
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            final list =
                racksAv.asData?.value ?? const <Map<String, dynamic>>[];
            final mustPick = list.length > 1;
            final canSubmit = !mustPick || _rack != null;
            if (!canSubmit) return;

            Navigator.pop(context, {
              "_id": (_rack!["_id"] ?? "").toString(),
              "roomId": (_rack!["roomId"] ?? "").toString(),
              "roomName": (_rack!["roomName"] ?? "").toString(),
              "itemId": _rack!["itemId"],
              "code": (_rack!["code"] ?? "").toString(),
              "remark": (_rack!["remark"] ?? "").toString(),
              "isScrap": _rack!["isScrap"] == true,
            });
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.items,
    required this.textOf,
    required this.onChanged,
    this.allowNull = false,
    this.nullLabel = 'None',
  });

  final String label;
  final String hint;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T) textOf;
  final ValueChanged<T?> onChanged;
  final bool allowNull;
  final String nullLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T?>(
          initialValue: value,
          isExpanded: true,
          items: [
            if (allowNull)
              DropdownMenuItem<T?>(
                value: null,
                child: Text(
                  nullLabel,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            for (final it in items)
              DropdownMenuItem<T?>(
                value: it,
                child: Text(textOf(it), overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
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
          ),
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
          dropdownColor: _surface,
          iconEnabledColor: _ink600,
        ),
      ],
    );
  }
}

class _RackDetailsCard extends StatelessWidget {
  const _RackDetailsCard({required this.rack});
  final Map<String, dynamic>? rack;

  @override
  Widget build(BuildContext context) {
    if (rack == null) return const Text('No rack selected');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (rack!["itemName"] ?? "").toString(),
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _RackDetailRow(
            label: 'Code',
            value: (rack!["code"] ?? "").toString(),
          ),
          _RackDetailRow(
            label: 'Room',
            value: (rack!["roomName"] ?? "").toString(),
          ),
          _RackDetailRow(
            label: 'Available Quantity',
            value: (rack!["stockAvailableQuantity"] ?? "").toString(),
          ),
          if (((rack!["remark"] ?? "").toString()).trim().isNotEmpty)
            _RackDetailRow(
              label: 'Remark',
              value: (rack!["remark"] ?? "").toString(),
            ),
        ],
      ),
    );
  }
}

class _RackDetailRow extends StatelessWidget {
  const _RackDetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadRow extends StatelessWidget {
  const _ReadRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ink600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemThumb extends StatelessWidget {
  const _ItemThumb({
    required this.url,
    this.versionKey,
    this.size = 46,
  }) : radius = 12;

  final String url;
  final String? versionKey;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _stroke),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.image_rounded, color: _ink600),
    );

    if (url.trim().isEmpty) return fallback();

    final bust =
        (versionKey == null || versionKey!.isEmpty)
            ? url
            : (url.contains('?') ? '$url&v=$versionKey' : '$url?v=$versionKey');

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _stroke),
        ),
        child: Image.network(
          bust,
          key: ValueKey(bust),
          fit: BoxFit.cover,
          width: size,
          height: size,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              alignment: Alignment.center,
              color: _surfaceAlt.withValues(alpha: .35),
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
          errorBuilder: (_, __, ___) => fallback(),
        ),
      ),
    );
  }
}

class _UpdateItemImageDialog extends StatefulWidget {
  const _UpdateItemImageDialog({required this.itemId});
  final String itemId;

  @override
  State<_UpdateItemImageDialog> createState() => _UpdateItemImageDialogState();
}

class _UpdateItemImageDialogState extends State<_UpdateItemImageDialog> {
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedImage;
  Uint8List? _pickedBytes;
  bool _busy = false;

  Future<void> _pickFromGallery() async {
    final x = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = x;
      _pickedBytes = bytes;
    });
  }

  Future<void> _pickFromCamera() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (x == null) return;
    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = x;
      _pickedBytes = bytes;
    });
  }

  Future<String?> _uploadBase64() async {
    if (_pickedImage == null) return null;

    final bytes = _pickedBytes ?? await _pickedImage!.readAsBytes();

    String mime = 'image/png';
    final lower = _pickedImage!.name.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      mime = 'image/jpeg';
    } else if (lower.endsWith('.webp')) {
      mime = 'image/webp';
    }

    final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';

    final uri = Uri.parse(
      '${Constants.socketUrl}/api/store/storeitems/${widget.itemId}/image/base64',
    );

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'base64': dataUrl}),
    );

    final body = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg =
          (body is Map ? (body['msg'] ?? body['error']) : null)?.toString() ??
          '';
      throw Exception(msg.isEmpty ? 'Upload failed' : msg);
    }

    final imageUrl =
        (body is Map ? (body['imageUrl'] ?? body['entity']?['imageUrl']) : null)
            ?.toString();

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      throw Exception('Uploaded but no URL returned');
    }

    return imageUrl.trim();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Update Item Image'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              alignment: Alignment.center,
              child:
                  (_pickedBytes == null)
                      ? const Text('No image selected')
                      : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          _pickedBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 180,
                        ),
                      ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFromGallery,
                    icon: const Icon(Icons.photo_library_rounded, size: 18, color: _ink900),
                    label: const Text('Gallery'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink900,
                      iconColor: _ink900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : _pickFromCamera,
                    icon: const Icon(Icons.photo_camera_rounded, size: 18, color: _ink900),
                    label: const Text('Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink900,
                      iconColor: _ink900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed:
              (_busy || _pickedImage == null)
                  ? null
                  : () async {
                    setState(() => _busy = true);
                    try {
                      final url = await _uploadBase64();
                      if (!mounted) return;
                      Navigator.pop(context, url);
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Image upload failed: $e')),
                      );
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          child:
              _busy
                  ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('Upload'),
        ),
      ],
    );
  }
}
