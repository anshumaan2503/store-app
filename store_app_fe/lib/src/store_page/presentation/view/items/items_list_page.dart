import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../controllers/store_category_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_category_model.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../../../controllers/store_cart_controller.dart';

import '../../widgets/excel_downloader_web.dart';
import '../../widgets/store_ui_state_widgets.dart';
import '../../../../components/motion_widgets.dart';
import 'find_item_page.dart';
import 'item_add_page.dart';
import 'item_edit_page.dart';
import 'item_list_card_page.dart';
import 'qr_code/qr_scanner_item_page.dart';
import '../issue/qr_code_issue/qr_scanner_item_issue_page.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color.fromARGB(255, 136, 130, 129);
const _ink500 = Color.fromARGB(255, 151, 146, 146);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

bool _canFindItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeitemfind");
}

bool _canAddItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeitemadd");
}

bool _canEditItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeitemedit");
}

bool _canDeleteItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeitemdelete");
}

bool _canExportItems(AuthModel? user) {
  if (user == null) return false;
  return user.isSuperAdmin ||
      user.appWorks.contains("storeadmin") ||
      user.appWorks.contains("storeexport");
}


class ItemsListPage extends ConsumerStatefulWidget {
  const ItemsListPage({
    super.key,
    this.goodItemsTabKey,
    this.scrapItemsTabKey,
  });

  final GlobalKey? goodItemsTabKey;
  final GlobalKey? scrapItemsTabKey;

  @override
  ConsumerState<ItemsListPage> createState() => _ItemsListPageState();
}

class _ItemsListPageState extends ConsumerState<ItemsListPage> {
  final String _q = '';
  int _limit = 12;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalInCartProvider.notifier).refresh();
    });
  }

  ItemPagedQuery get _query =>
      ItemPagedQuery(page: 1, limit: _limit, search: _q, sort: '-createdAt');

  bool _hasAnyQty(StoreItemsModel it) {
    return (it.totalStockQuantity > 0) ||
        (it.stockAvailableQuantity > 0) ||
        (it.stockRequestedQuantity > 0) ||
        (it.stockIssueQuantity > 0) ||
        (it.stockissueCompleted > 0) ||
        (it.stockscrapQuantity > 0);
  }

  Uint8List _buildItemsExcelBytes(List<StoreItemsModel> items) {
    final excel = Excel.createExcel();

    // delete default sheet if present
    // if (excel.sheets.keys.contains('Sheet1')) {
    //   excel.delete('Sheet1');
    // }

    // final sheet = excel['Items'];

    const sheetName = 'Items';

    // ✅ Make sure the FIRST sheet is our target sheet
    if (excel.sheets.keys.contains('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    excel.setDefaultSheet(sheetName);

    final sheet = excel[sheetName];

    CellValue t(String v) => TextCellValue(v);
    CellValue n(int v) => IntCellValue(v);

    sheet.appendRow([
      // t('ID'),
      t('Item Code'),
      t('Item Name'),
      // t('Item Name Code'),
      t('Category'),
      t('Unit'),
      t('Description'),
      t('Total Qty'),
      t('Available Qty'),
      t('Issue Qty'),
      t('Issue Completed'),
      t('Scrap Qty'),
      t('Is Scrap'),
    ]);

    for (final it in items) {
      sheet.appendRow([
        // t(it.id),
        t(it.itemCode),
        t(it.itemName),
        // t(it.itemNameCode),
        t(it.categoryLabel),
        t(it.unit),
        t(it.description),
        n(it.totalStockQuantity),
        n(it.stockAvailableQuantity),
        n(it.stockRequestedQuantity),
        n(it.stockIssueQuantity),
        n(it.stockissueCompleted),
        n(it.stockscrapQuantity),
        t(it.isScrap ? 'YES' : 'NO'), // or BoolCellValue(it.isScrap)
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  Future<void> _exportItemsExcel({
    required bool? isScrap,
    required List<StoreItemsModel> rowsList,
  }) async {
    // final state = ref.read(
    //   itemPagedStreamProvider(_query),
    // ); // AsyncValue<ItemPagedResult>
    final paged = rowsList;

    if (paged.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data loaded to export.')),
      );
      return;
    }

    final rows =
        isScrap == null
            ? rowsList
            : rowsList.where((e) => e.isScrap == isScrap).toList();
    // isScrap == null
    //     ? paged.rows
    //     : paged.rows.where((e) => e.isScrap == isScrap).toList();

    if (rows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No rows in this tab to export.')),
      );
      return;
    }

    final bytes = _buildItemsExcelBytes(rows);

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    final filename =
        isScrap == null
            ? 'items_all_$y$m$d.xlsx'
            : (isScrap ? 'items_scrap_$y$m$d.xlsx' : 'items_good_$y$m$d.xlsx');

    await ExcelDownloader.saveBytes(bytes, filename);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Excel exported: $filename')));
  }

  Future<void> _showExportSheet(List<StoreItemsModel> rows) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text('Export Excel'),
                  subtitle: Text(
                    'Exports currently loaded rows (limit-based).',
                  ),
                ),
                const SizedBox(height: 6),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export Good Items'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportItemsExcel(isScrap: false, rowsList: rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export Scrap Items'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportItemsExcel(isScrap: true, rowsList: rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export All Loaded'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportItemsExcel(isScrap: null, rowsList: rows);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _refresh() {
    setState(() => _limit = 12);
    // refresh list + rack availability queries
    ref.invalidate(itemPagedStreamProvider);
    ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
    ref.read(globalInCartProvider.notifier).refresh();
  }

  void _loadMore(ItemPagedResult paged) {
    if (paged.rows.length >= paged.total) return;
    setState(() => _limit += 12);
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ItemCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(StoreItemsModel it) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ItemEditPage(initial: it)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreItemsModel item) async {
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
    if (ok) _refresh();
  }

  // Future<void> _openTransferRack(StoreItemsModel it) async {
  //   // Only allowed when qty == 0 (your rule)
  //   if (_hasAnyQty(it)) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(
  //         content: Text('Rack transfer is allowed only when quantity is 0.'),
  //       ),
  //     );
  //     return;
  //   }

  //   final ok = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => _TransferRackDialog(item: it),
  //   );

  //   if (ok == true) _refresh();
  // }

  // Future<void> _openTransferItem(StoreItemsModel it) async {
  //   // Only allowed when qty > 0
  //   final maxQty = it.stockAvailableQuantity;
  //   if (maxQty <= 0) {
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       const SnackBar(content: Text('No available quantity to transfer.')),
  //     );
  //     return;
  //   }

  //   final ok = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (_) => _TransferItemDialog(item: it),
  //   );

  //   if (ok == true) _refresh();
  // }

  @override
  Widget build(BuildContext context) {
    final av = ref.watch(itemAllPagedStreamProvider);
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (user) {
        return av.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Room load error: $e'),
          data: (item) {
            final rows = item;
            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Unified Tabs & Quick Actions Toolbar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Row(
                      children: [
                        // Segmented Pill TabBar
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: _surfaceAlt.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: _stroke),
                            ),
                            child: TabBar(
                              dividerColor: Colors.transparent,
                              indicatorSize: TabBarIndicatorSize.tab,
                              indicatorPadding: const EdgeInsets.all(3),
                              indicator: BoxDecoration(
                                color: _ink900,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              labelColor: Colors.white,
                              unselectedLabelColor: _ink700,
                              labelStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              splashFactory: NoSplash.splashFactory,
                              overlayColor:
                                  WidgetStateProperty.all(Colors.transparent),
                              tabs: [
                                Tab(
                                  key: widget.goodItemsTabKey ??
                                      GuidedTourController.goodItemsTabKey,
                                  text: "Good Items",
                                ),
                                Tab(
                                  key: widget.scrapItemsTabKey ??
                                      GuidedTourController.scrapItemsTabKey,
                                  text: "Scrap Items",
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Action Buttons (Refresh, Export, Add)
                        _HeaderActionButton(
                          icon: Icons.refresh_rounded,
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                        ),
                        if (_canFindItems(user)) ...[
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: Icons.location_searching_rounded,
                            tooltip: 'Find Item',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const FindItemPage(isStandalone: true),
                                ),
                              );
                            },
                          ),
                        ],
                        if (_canExportItems(user)) ...[
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            icon: Icons.file_download_rounded,
                            tooltip: 'Download Excel',
                            onPressed: () => _showExportSheet(rows),
                          ),
                        ],
                        if (_canAddItems(user)) ...[
                          const SizedBox(width: 6),
                          _HeaderActionButton(
                            key: GuidedTourController.addItemButtonKey,
                            icon: Icons.add_rounded,
                            tooltip: "Add Item",
                            isPrimary: true,
                            onPressed: () => _openCreate(),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Content Views
                  const Expanded(
                    child: TabBarView(
                      physics: ClampingScrollPhysics(),
                      children: [
                        ItemsGoodQtyListPage(),
                        ItemsScrapListPage(),
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
  }
}

/* ---------------- dialogs ---------------- */

class _TransferRackDialog extends ConsumerStatefulWidget {
  const _TransferRackDialog({required this.item});
  final StoreItemsModel item;

  @override
  ConsumerState<_TransferRackDialog> createState() =>
      _TransferRackDialogState();
}

class _TransferRackDialogState extends ConsumerState<_TransferRackDialog> {
  String _q = '';
  StoreRack? _picked;
  bool _busy = false;

  RackQuery get _rackQuery => RackQuery(
    page: 1,
    limit: 200,
    search: _q,
    sort: 'name',
    roomId: null,
    allowItemId: widget.item.id, // include current rack if backend allows
  );

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(
      storeNotOccupiecRackPagedStreamProvider(_rackQuery),
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Transfer Rack'),
      content: SizedBox(
        width: 560,
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HintBar(
              text:
                  'Allowed only when quantity is 0. Select a free rack to move this item.',
            ),
            const SizedBox(height: 10),
            TextField(
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Search rack by name/code...',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: racksAv.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Rack load error: $e')),
                data: (paged) {
                  // remove current rack from options (no-op)
                  final list =
                      paged.rows
                          .where((r) => r.id != widget.item.rackId)
                          .toList();

                  if (list.isEmpty) {
                    return const Center(
                      child: Text('No available racks found.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final r = list[i];
                      final sel = _picked?.id == r.id;
                      return ListTile(
                        onTap: () => setState(() => _picked = r),
                        leading: Icon(
                          sel
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: sel ? _ink900 : _ink600,
                        ),
                        title: Text(
                          r.code,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(r.code),
                      );
                    },
                  );
                },
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
              (_picked == null || _busy)
                  ? null
                  : () async {
                    setState(() => _busy = true);
                    try {
                      final ok = await ref
                          .read(storeItemsControllerProvider)
                          .transferRack(
                            itemId: widget.item.id,
                            toRackId: _picked!.id,
                          );

                      if (!mounted) return;
                      if (ok) {
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
  }
}

class _TransferItemDialog extends ConsumerStatefulWidget {
  const _TransferItemDialog({required this.item});
  final StoreItemsModel item;

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

  RackQuery get _rackQuery => RackQuery(
    page: 1,
    limit: 200,
    search: _q,
    sort: 'name',
    roomId: null,
    // if your backend supports "allowItemId" to include same-item racks, pass item.id
    allowItemId: widget.item.id,
  );

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
    final racksAv = ref.watch(sameItemRacksStreamProvider(widget.item.id));

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Transfer Item'),
      content: SizedBox(
        width: 560,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HintBar(
              text:
                  'Move quantity from this rack to another rack. Quantity must be ≤ Available.',
            ),
            const SizedBox(height: 10),
            _InfoRow(
              label: 'Item',
              value: '${widget.item.itemName} (${widget.item.itemCode})',
            ),
            // _InfoRow(label: 'From Rack', value: widget.item.rackName),
            _InfoRow(label: 'Available', value: '$_maxQty'),
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
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Rack load error: $e')),
                data: (paged) {
                  // destination cannot be same rack
                  final list = paged;
                  final q = _q.trim().toLowerCase();
                  final filtered =
                      q.isEmpty
                          ? list
                          : list.where((r) {
                            final s = (r.code).toLowerCase();
                            return s.contains(q);
                          }).toList();
                  // .rows
                  //     .where((r) => r.id != widget.item.rackId)
                  //     .toList();

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
                          color: sel ? _ink900 : _ink600,
                        ),
                        title: Text(
                          r.code,
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
                hintText: 'Enter quantity (max $_maxQty)',
                helperText: 'Quantity must be between 1 and $_maxQty',
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
                    if (qty == null || qty <= 0 || qty > _maxQty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enter valid quantity (1..$_maxQty)'),
                        ),
                      );
                      return;
                    }

                    setState(() => _busy = true);
                    try {
                      // final ok = await ref
                      //     .read(storeItemsControllerProvider)
                      //     .transferItem(
                      //       itemId: widget.item.id,
                      //       fromRackId: widget.item.rackId,
                      //       toRackId: _toRack!.id,
                      //       qty: qty,
                      //     );

                      // if (!mounted) return;
                      // if (ok) {
                      //   Navigator.pop(context, true);
                      // } else {
                      //   ScaffoldMessenger.of(context).showSnackBar(
                      //     const SnackBar(content: Text('Transfer failed')),
                      //   );
                      // }
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
          child: Text(_busy ? 'Transferring...' : 'Confirm'),
        ),
      ],
    );
  }
}

/* ---------------- small UI ---------------- */

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
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AbovePaginationFloatingActionButtonLocation
    extends FloatingActionButtonLocation {
  const _AbovePaginationFloatingActionButtonLocation({this.offsetY = 56.0});

  final double offsetY;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final standardOffset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(standardOffset.dx, standardOffset.dy - offsetY);
  }
}

class ItemsGoodQtyListPage extends ConsumerStatefulWidget {
  const ItemsGoodQtyListPage({super.key});

  @override
  ConsumerState<ItemsGoodQtyListPage> createState() =>
      _ItemsGoodQtyListPageState();
}

class _ItemsGoodQtyListPageState extends ConsumerState<ItemsGoodQtyListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _q = '';
  int _limit = 12;
  StoreCategory? _filterCategory;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _q);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasAnyQty(StoreItemsModel it) {
    return (it.totalStockQuantity > 0) ||
        (it.stockAvailableQuantity > 0) ||
        (it.stockRequestedQuantity > 0) ||
        (it.stockIssueQuantity > 0) ||
        (it.stockissueCompleted > 0) ||
        (it.stockscrapQuantity > 0);
  }

  void _refresh() {
    setState(() => _limit = 12);
    // refresh list + rack availability queries
    ref.invalidate(itemPagedStreamProvider);
    ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
  }

  void _loadMore(ItemPagedResult paged) {
    if (paged.rows.length >= paged.total) return;
    setState(() => _limit += 12);
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ItemCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(StoreItemsModel it) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ItemEditPage(initial: it)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreItemsModel item) async {
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
    if (ok) _refresh();
  }

  Future<void> _openTransferRack(StoreItemsModel it) async {
    // Only allowed when qty == 0 (your rule)
    if (_hasAnyQty(it)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rack transfer is allowed only when quantity is 0.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferRackDialog(item: it),
    );

    if (ok == true) _refresh();
  }

  Future<void> _openTransferItem(StoreItemsModel it) async {
    // Only allowed when qty > 0
    final maxQty = it.stockAvailableQuantity;
    if (maxQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available quantity to transfer.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferItemDialog(item: it),
    );

    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final query = ItemPagedQuery(
      page: 1,
      limit: _limit,
      search: _q,
      sort: '-createdAt',
      categoryId: _filterCategory?.id, // ✅ no bang operator
    );
    final av = ref.watch(itemPagedStreamProvider(query));

    final catAv = ref.watch(parentcategoryAllDataStreamProvider);
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        return Scaffold(
          floatingActionButtonLocation:
              const _AbovePaginationFloatingActionButtonLocation(),
          floatingActionButton: () {
            final hasAccess = _canEditItems(user);

            // iPad / tablet detection (logical pixels)
            final w = MediaQuery.of(context).size.width;
            final isIPadSize = w <= 768; // common iPad portrait breakpoint

            if (!hasAccess || !isIPadSize) return null;

            if (user?.isSuperAdmin == true) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'super_admin_items_good_scan_item_qr',
                    tooltip: 'Scan Item QR',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QRCodeScannerItemPage(),
                        ),
                      );
                    },
                    elevation: 6,
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Scan Item QR',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'super_admin_items_good_scan_issue_qr',
                    tooltip: 'Scan for Issue Request',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QRCodeScannerIssuePage(),
                        ),
                      );
                    },
                    elevation: 6,
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Scan for Issue Request',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                  ),
                ],
              );
            }

            return FloatingActionButton.extended(
              heroTag: 'items_good_scan_item_qr',
              tooltip: 'Scan Item QR',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QRCodeScannerItemPage(),
                  ),
                );
              },
              elevation: 6,
              backgroundColor: _ink900,
              foregroundColor: _surface,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Scan Item QR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _stroke),
              ),
            );
          }(),
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                // Search & Category Filter Card
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Container(
                      key: GuidedTourController.itemSearchBarKey,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _stroke.withValues(alpha: 0.9),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search Input Field
                          _StoreSearchBar(
                            controller: _searchController,
                            hintText: 'Search item by name or code...',
                            onChanged: (v) => setState(() {
                              _q = v.trim();
                              _limit = 12;
                            }),
                            onClear: () => setState(() {
                              _q = '';
                              _limit = 12;
                            }),
                          ),
                          const SizedBox(height: 8),

                          // Category Dropdown Row
                          Row(
                            children: [
                              Expanded(
                                child: catAv.when(
                                  loading: () => const LinearProgressIndicator(
                                    minHeight: 2,
                                  ),
                                  error: (e, _) =>
                                      Text('Category load error: $e'),
                                  data: (cats) {
                                    return DropdownButtonFormField<
                                        StoreCategory?>(
                                      isExpanded: true,
                                      isDense: true,
                                      initialValue: (_filterCategory != null &&
                                              cats.any((x) =>
                                                  x.id ==
                                                  _filterCategory!.id))
                                          ? cats.firstWhere((x) =>
                                              x.id == _filterCategory!.id)
                                          : null,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                      dropdownColor: _surface,
                                      iconEnabledColor: _ink700,
                                      items: [
                                        const DropdownMenuItem<
                                            StoreCategory?>(
                                          value: null,
                                          child: Text(
                                            'All Categories',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        for (final r in cats)
                                          DropdownMenuItem<StoreCategory?>(
                                            value: r,
                                            child: Text(
                                              r.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _filterCategory = v;
                                          _limit = 12;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Filter by category',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.category_outlined,
                                          color: _ink600,
                                          size: 18,
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                          minWidth: 30,
                                          minHeight: 30,
                                        ),
                                        filled: true,
                                        fillColor: _surfaceAlt.withValues(
                                          alpha: .35,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_filterCategory != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() {
                                    _filterCategory = null;
                                    _limit = 12;
                                  }),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFCDD2),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Color(0xFFC62828),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFC62828),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Items List
                Expanded(
                  child: av.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => StoreErrorView(
                      error: e,
                      onRetry: _refresh,
                    ),
                    data: (paged) {
                      final rows = paged.rows;
                      if (rows.isEmpty) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: StoreEmptyStateWidget(
                              message:
                                  'No items found. Create an item and map Item Name + Rack + Category.',
                              searchQuery: _q,
                              onClearSearch: () => setState(() {
                                _q = '';
                                _limit = 12;
                              }),
                            ),
                          ),
                        );
                      }

                      final canLoadMore = rows.length < paged.total;

                      return Column(
                        children: [
                          Expanded(
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              child: ListView.separated(
                                controller: _scrollController,
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final it = rows[i];
                                  final hasQty = _hasAnyQty(it);

                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 980),
                                      child: ItemListCard(
                                        key: i == 0 ? GuidedTourController.firstItemCardKey : null,
                                        stockMetricsKey: i == 0 ? GuidedTourController.firstItemStockMetricsKey : null,
                                        editButtonKey: i == 0 ? GuidedTourController.firstItemEditButtonKey : null,
                                        detailsKey: i == 0 ? GuidedTourController.firstItemDetailsKey : null,
                                        actionsKey: i == 0 ? GuidedTourController.firstItemActionsKey : null,
                                        addToCartKey: i == 0 ? GuidedTourController.firstItemAddToCartKey : null,
                                        index: i,
                                        item: it,
                                        hasQty: hasQty,
                                        onEdit: () => _openEdit(it),
                                        onTransferRack: (!hasQty &&
                                                (user?.isSuperAdmin == true ||
                                                    (user?.appWorks.contains("storeadmin") ?? false) ||
                                                    (user?.appWorks.contains("storeitemtransfer") ?? false)))
                                            ? () => _openTransferRack(it)
                                            : null,
                                        onTransferItem: (hasQty &&
                                                (user?.isSuperAdmin == true ||
                                                    (user?.appWorks.contains("storeadmin") ?? false) ||
                                                    (user?.appWorks.contains("storeitemtransfer") ?? false)))
                                            ? () => _openTransferItem(it)
                                            : null,
                                        onDelete: () => _confirmDelete(it),
                                        canEdit: _canEditItems(user),
                                        canDelete: _canDeleteItems(user),
                                        canFind: _canFindItems(user),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sleek Pagination Status Bar
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _stroke),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Showing ${rows.length} of ${paged.total} items',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (canLoadMore)
                                      InkWell(
                                        onTap: () => _loadMore(paged),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _ink900,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.expand_more_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Load more',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ItemsScrapListPage extends ConsumerStatefulWidget {
  const ItemsScrapListPage({super.key});

  @override
  ConsumerState<ItemsScrapListPage> createState() => _ItemsScrapListPageState();
}

class _ItemsScrapListPageState extends ConsumerState<ItemsScrapListPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _q = '';
  int _limit = 12;
  StoreCategory? _filterCategory;
  late final TextEditingController _searchController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: _q);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ItemPagedQuery get _query =>
      ItemPagedQuery(page: 1, limit: _limit, search: _q, sort: '-createdAt');

  bool _hasAnyQty(StoreItemsModel it) {
    return (it.totalStockQuantity > 0) ||
        (it.stockAvailableQuantity > 0) ||
        (it.stockRequestedQuantity > 0) ||
        (it.stockIssueQuantity > 0) ||
        (it.stockissueCompleted > 0) ||
        (it.stockscrapQuantity > 0);
  }

  void _refresh() {
    setState(() => _limit = 12);
    // refresh list + rack availability queries
    ref.invalidate(itemScrapPagedStreamProvider);
    ref.invalidate(storeNotOccupiecRackPagedStreamProvider);
  }

  void _loadMore(ItemPagedResult paged) {
    if (paged.rows.length >= paged.total) return;
    setState(() => _limit += 12);
  }

  Future<void> _openCreate() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ItemCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openEdit(StoreItemsModel it) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ItemEditPage(initial: it)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreItemsModel item) async {
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
    if (ok) _refresh();
  }

  Future<void> _openTransferRack(StoreItemsModel it) async {
    // Only allowed when qty == 0 (your rule)
    if (_hasAnyQty(it)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rack transfer is allowed only when quantity is 0.'),
        ),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferRackDialog(item: it),
    );

    if (ok == true) _refresh();
  }

  Future<void> _openTransferItem(StoreItemsModel it) async {
    // Only allowed when qty > 0
    final maxQty = it.stockAvailableQuantity;
    if (maxQty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available quantity to transfer.')),
      );
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TransferItemDialog(item: it),
    );

    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final query = ItemPagedQuery(
      page: 1,
      limit: _limit,
      search: _q,
      sort: '-createdAt',
      categoryId: _filterCategory?.id, // ✅ no bang operator
    );
    final av = ref.watch(itemScrapPagedStreamProvider(query));
    final catAv = ref.watch(parentcategoryAllDataStreamProvider);
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (user) {
        return Scaffold(
          floatingActionButtonLocation:
              const _AbovePaginationFloatingActionButtonLocation(),
          floatingActionButton: () {
            final isSuperAdmin = user?.isSuperAdmin ?? false;
            final hasAccess = isSuperAdmin || (user?.appWorks.contains("storeitemedit") ?? false);

            // iPad / tablet detection (logical pixels)
            final w = MediaQuery.of(context).size.width;
            final isIPadSize = w <= 768; // common iPad portrait breakpoint

            if (!hasAccess || !isIPadSize) return null;

            if (isSuperAdmin) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.extended(
                    heroTag: 'super_admin_items_scrap_scan_item_qr',
                    tooltip: 'Scan Item QR',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QRCodeScannerItemPage(),
                        ),
                      );
                    },
                    elevation: 6,
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Scan Item QR',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FloatingActionButton.extended(
                    heroTag: 'super_admin_items_scrap_scan_issue_qr',
                    tooltip: 'Scan for Issue Request',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QRCodeScannerIssuePage(),
                        ),
                      );
                    },
                    elevation: 6,
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Scan for Issue Request',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                  ),
                ],
              );
            }

            return FloatingActionButton.extended(
              heroTag: 'items_scrap_scan_item_qr',
              tooltip: 'Scan Item QR',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const QRCodeScannerItemPage(),
                  ),
                );
              },
              elevation: 6,
              backgroundColor: _ink900,
              foregroundColor: _surface,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text(
                'Scan Item QR',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _stroke),
              ),
            );
          }(),
          backgroundColor: Colors.transparent,
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Column(
              children: [
                // Search & Category Filter Card
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _stroke.withValues(alpha: 0.9),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search Input Field
                          _StoreSearchBar(
                            controller: _searchController,
                            hintText: 'Search scrap item by name or code...',
                            onChanged: (v) => setState(() {
                              _q = v.trim();
                              _limit = 12;
                            }),
                            onClear: () => setState(() {
                              _q = '';
                              _limit = 12;
                            }),
                          ),
                          const SizedBox(height: 8),

                          // Category Dropdown Row
                          Row(
                            children: [
                              Expanded(
                                child: catAv.when(
                                  loading: () => const LinearProgressIndicator(
                                    minHeight: 2,
                                  ),
                                  error: (e, _) =>
                                      Text('Category load error: $e'),
                                  data: (cats) {
                                    return DropdownButtonFormField<
                                        StoreCategory?>(
                                      isExpanded: true,
                                      isDense: true,
                                      initialValue: (_filterCategory != null &&
                                              cats.any((x) =>
                                                  x.id ==
                                                  _filterCategory!.id))
                                          ? cats.firstWhere((x) =>
                                              x.id == _filterCategory!.id)
                                          : null,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                      dropdownColor: _surface,
                                      iconEnabledColor: _ink700,
                                      items: [
                                        const DropdownMenuItem<
                                            StoreCategory?>(
                                          value: null,
                                          child: Text(
                                            'All Categories',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        for (final r in cats)
                                          DropdownMenuItem<StoreCategory?>(
                                            value: r,
                                            child: Text(
                                              r.name,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _filterCategory = v;
                                          _limit = 12;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Filter by category',
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.category_outlined,
                                          color: _ink600,
                                          size: 18,
                                        ),
                                        prefixIconConstraints:
                                            const BoxConstraints(
                                          minWidth: 30,
                                          minHeight: 30,
                                        ),
                                        filled: true,
                                        fillColor: _surfaceAlt.withValues(
                                          alpha: .35,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (_filterCategory != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () => setState(() {
                                    _filterCategory = null;
                                    _limit = 12;
                                  }),
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFFFCDD2),
                                      ),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Color(0xFFC62828),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Clear',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFC62828),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Items List
                Expanded(
                  child: av.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(),
                    ),
                    error: (e, _) => StoreErrorView(
                      error: e,
                      onRetry: _refresh,
                    ),
                    data: (paged) {
                      final rows = paged.rows;
                      if (rows.isEmpty) {
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: StoreEmptyStateWidget(
                              message: 'No scrap items found.',
                              searchQuery: _q,
                              onClearSearch: () => setState(() {
                                _q = '';
                                _limit = 12;
                              }),
                            ),
                          ),
                        );
                      }

                      final canLoadMore = rows.length < paged.total;

                      return Column(
                        children: [
                          Expanded(
                            child: Scrollbar(
                              controller: _scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              interactive: true,
                              child: ListView.separated(
                                controller: _scrollController,
                                itemCount: rows.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (_, i) {
                                  final it = rows[i];
                                  final hasQty = _hasAnyQty(it);

                                  return Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 980),
                                      child: ItemListCard(
                                        index: i,
                                        item: it,
                                        hasQty: hasQty,
                                        onEdit: () => _openEdit(it),
                                        onTransferRack: (!hasQty &&
                                                (user?.isSuperAdmin == true ||
                                                    (user?.appWorks.contains("storeadmin") ?? false) ||
                                                    (user?.appWorks.contains("storeitemtransfer") ?? false)))
                                            ? () => _openTransferRack(it)
                                            : null,
                                        onTransferItem: (hasQty &&
                                                (user?.isSuperAdmin == true ||
                                                    (user?.appWorks.contains("storeadmin") ?? false) ||
                                                    (user?.appWorks.contains("storeitemtransfer") ?? false)))
                                            ? () => _openTransferItem(it)
                                            : null,
                                        onDelete: () => _confirmDelete(it),
                                        canEdit: _canEditItems(user),
                                        canDelete: _canDeleteItems(user),
                                        canFind: _canFindItems(user),
                                        addToCartKey: null,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Sleek Pagination Status Bar
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 980),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _stroke),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x06000000),
                                      blurRadius: 8,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Showing ${rows.length} of ${paged.total} items',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (canLoadMore)
                                      InkWell(
                                        onTap: () => _loadMore(paged),
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _ink900,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withValues(alpha: 0.12),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.expand_more_rounded,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Load more',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _HeaderActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: AppButtonMotion(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isPrimary ? _ink900 : _surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isPrimary ? _ink900 : _stroke),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? Colors.black.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 19,
            color: isPrimary ? Colors.white : _ink900,
          ),
        ),
      ),
    );
  }
}

class _StoreSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _StoreSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  State<_StoreSearchBar> createState() => _StoreSearchBarState();
}

class _StoreSearchBarState extends State<_StoreSearchBar> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (mounted) setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 44,
      decoration: BoxDecoration(
        color: _isFocused ? Colors.white : const Color(0xFFF7F8F4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: _isFocused ? _ink900 : const Color(0xFFDFE2D6),
          width: _isFocused ? 1.5 : 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: _isFocused
                ? _ink900.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: _isFocused ? 8 : 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, right: 10),
            child: Icon(
              Icons.search_rounded,
              size: 20,
              color: _isFocused ? _ink900 : _ink600,
            ),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: (val) {
                setState(() {});
                widget.onChanged(val);
              },
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
              cursorColor: _ink900,
              cursorWidth: 1.8,
              cursorRadius: const Radius.circular(2),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: true,
                fillColor: Colors.transparent,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  color: Color(0xFF9E9A93),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          if (hasText)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InkWell(
                onTap: () {
                  widget.controller.clear();
                  widget.onClear();
                  setState(() {});
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _ink900.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _ink900,
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _stroke.withValues(alpha: 0.8),
                  ),
                ),
                child: const Text(
                  'SEARCH',
                  style: TextStyle(
                    color: _ink600,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
