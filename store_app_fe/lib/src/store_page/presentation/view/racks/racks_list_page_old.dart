// lib/src/store/presentation/views/racks/racks_list_page.dart
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';

import '../../../domains/models/store_rack_model.dart';
import '../../../domains/models/store_room_model.dart';

import '../../widgets/code_gen.dart';
import '../../widgets/excel_downloader_web.dart';
import '../issue/issue_scan_by_rack_page.dart';
import '../receive/scan_rack_receive_page.dart';
import '../rooms/rooms_list_page.dart';
import 'qr_code_rack/qr_code_print_rack_page.dart';

/* ---- Theme palette ---- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color.fromARGB(255, 151, 146, 146);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _accentPeach = Color(0xFFF3D7C0);

class RacksListOldPage extends ConsumerStatefulWidget {
  const RacksListOldPage({super.key});

  @override
  ConsumerState<RacksListOldPage> createState() => _RacksListOldPageState();
}

class _RacksListOldPageState extends ConsumerState<RacksListOldPage> {
  StoreRoom? _filterRoom; // optional filter
  final String _q = '';
  int _limit = 12;

  // Rooms: for dropdown only (fetch more so user sees all)
  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  // Racks: WS pagination + search + room filter
  RackQuery get _racksQuery => RackQuery(
    page: 1,
    limit: _limit,
    search: _q,
    sort: 'createdAt',
    roomId: _filterRoom?.id,
  );

  void _refresh() {
    // Invalidate whole families (refresh all instances)
    ref.invalidate(storeRoomPagedStreamProvider(_roomsQuery));
    ref.invalidate(storeRackPagedStreamProvider(_racksQuery));

    // Also reset racks page settings
    setState(() => _limit = 12);
  }

  void _loadMore(PagedRacks paged) {
    final canLoadMore = paged.rows.length < paged.total;
    if (!canLoadMore) return;
    setState(() => _limit += 12);
  }

  Uint8List _buildRacksExcelBytes(List<Map<String, dynamic>> items) {
    final excel = Excel.createExcel();

    // delete default sheet if present
    // if (excel.sheets.keys.contains('Sheet1')) {
    //   excel.delete('Sheet1');
    // }

    // final sheet = excel['Items'];

    const sheetName = 'Racks';

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
      t('Rack Code'),
      t('Item Name'),
      t('Room Name'),
      t('Remark'),
      t('Is Scrap'),
      t('Total Stock Quantity'),
      t('Stock Available Quantity'),
      t('Stock Issue Quantity'),
      t('Stock Scrap Quantity'),
    ]);

    for (final it in items) {
      sheet.appendRow([
        // t(it.id),
        t(it["code"]),
        t(it["itemName"]),
        t(it["roomName"]),
        t(it["remark"]),
        t(it["isScrap"] ? 'YES' : 'NO'), // or BoolCellValue(it.isScrap)
        t(it["totalStockQuantity"].toString()),
        t(it["stockAvailableQuantity"].toString()),
        t(it["stockIssueQuantity"].toString()),
        t(it["stockscrapQuantity"].toString()),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  Future<void> _exportRacksExcel({
    required bool? isScrap,
    required List<Map<String, dynamic>> rowsList,
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
            : rowsList.where((e) => e["isScrap"] == isScrap).toList();
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

    final bytes = _buildRacksExcelBytes(rows);

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

  Future<void> _showExportSheet(List<Map<String, dynamic>> rows) async {
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
                  title: const Text('Export Good Racks'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportRacksExcel(isScrap: false, rowsList: rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export Scrap Racks'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportRacksExcel(isScrap: true, rowsList: rows);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export All Loaded'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportRacksExcel(isScrap: null, rowsList: rows);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openForm({StoreRack? initial}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RackFormPage(initial: initial)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openroomForm() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RoomCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreRack r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete rack?'),
            content: Text('Delete ${r.code} ?'),
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

    final ok = await ref.read(storeRackControllerProvider).deleteRack(id: r.id);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Deleted' : 'Delete failed')));
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAv = ref.watch(storeRoomPagedStreamProvider(_roomsQuery));
    final racksAv = ref.watch(storeAllRackPagedStreamProvider);
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (user) {
        return racksAv.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Room load error: $e'),
          data: (rack) {
            final rows = rack;
            return Scaffold(
              backgroundColor: _surface,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: _surface,
                surfaceTintColor: Colors.transparent,
                iconTheme: const IconThemeData(color: _ink900),
                title: const Text(
                  'Racks',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
                ),
                actions: [
                  IconButton(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  const SizedBox(width: 4),
                  (user!.appWorks.contains("storeplaceadd"))
                      ? IconButton(
                        onPressed: () => _openForm(),
                        icon: const Icon(Icons.storage),
                        tooltip: "Add Rack",
                      )
                      : SizedBox.shrink(),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: () => _showExportSheet(rows),
                    icon: const Icon(Icons.download_rounded),
                    tooltip: 'Download Excel',
                  ),
                  const SizedBox(width: 6),
                  (user.appWorks.contains("storeplaceadd"))
                      ? IconButton(
                        onPressed: () => _openroomForm(),
                        icon: const Icon(Icons.add_home),
                        tooltip: "Add Room",
                      )
                      : SizedBox.shrink(),
                  const SizedBox(width: 6),
                ],
              ),
              body: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    // Tabs
                    _Card(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: TabBar(
                        labelColor: _ink900,
                        unselectedLabelColor: _ink700,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: _ink500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tabs: const [
                          Tab(text: "Good Items"),
                          Tab(text: "Scrap Items"),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Expanded(
                      child: TabBarView(
                        children: [
                          RacksGoodQtyListPage(),
                          RacksScrapQtyListPage(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class RackFormPage extends ConsumerStatefulWidget {
  const RackFormPage({super.key, this.initial});
  final StoreRack? initial;

  @override
  ConsumerState<RackFormPage> createState() => _RackFormPageState();
}

class _RackFormPageState extends ConsumerState<RackFormPage> {
  final _formKey = GlobalKey<FormState>();

  StoreRoom? _room;
  bool _createRack = false;
  // late final TextEditingController _name = TextEditingController(
  //   text: widget.initial?.name ?? '',
  // );
  late final TextEditingController _code = TextEditingController(
    text: widget.initial?.code ?? '',
  );
  late final TextEditingController _remark = TextEditingController(
    text: widget.initial?.remark ?? '',
  );

  bool _busy = false;

  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  @override
  void initState() {
    super.initState();

    if (widget.initial == null) {
      _code.text = genCode(prefix: 'RK', name: _code.text);
    } else {
      _createRack = widget.initial!.isScrap;
    }

    // _name.addListener(() {
    //   if (widget.initial != null) return;
    //   final n = _name.text.trim();
    //   if (n.isEmpty) return;
    //   _code.text = genCode(prefix: 'RK', name: n);
    // });
  }

  @override
  void dispose() {
    // _name.dispose();
    _code.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _openQuickRoomCreate() async {
    final created = await showDialog<StoreRoom>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RoomQuickCreateDialog(isScrap: _createRack),
    );

    if (created == null) return;

    // refresh rooms list
    ref.invalidate(storeRoomPagedStreamProvider);

    // auto-select new room
    setState(() => _room = created);
  }

  Future<void> _openTransferItem() async {
    // final ok = await showDialog<bool>(
    //   context: context,
    //   barrierDismissible: false,
    //   builder:
    //       (_) => _TransferItemDialog(
    //         item: widget.initial!.itemId,
    //         rack: widget.initial!,
    //       ),
    // );

    // if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
  }

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
                  if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
    if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
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
                  if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);

                  Navigator.pop(ctx, true);
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
    if (ok == true) ref.invalidate(storeRoomPagedStreamProvider);
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_room == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select room')));
      return;
    }

    final isEdit = widget.initial != null;
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid");
    final dto = <String, dynamic>{
      'roomId': _room!.id,
      'roomName': _room!.code, // useful on BE (optional)
      'code': _code.text.trim(),
      'isScrap': _createRack,
      // 'name': _name.text.trim(),
      'remark': _remark.text.trim(),
      'createdBy': createdBy,
      if (isEdit) 'id': widget.initial!.id,
    };

    setState(() => _busy = true);
    try {
      final ok =
          isEdit
              ? await ref
                  .read(storeRackControllerProvider)
                  .updateRack(storeRack: dto)
              : await ref
                  .read(storeRackControllerProvider)
                  .createRack(storeRack: dto);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? (isEdit ? 'Updated' : 'Created')
                : (isEdit ? 'Update failed' : 'Create failed'),
          ),
        ),
      );

      if (ok) {
        ref.invalidate(storeRackPagedStreamProvider);
        ref.invalidate(storeRoomPagedStreamProvider);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    // final roomsAv = ref.watch(findOneRackStreamProvider(_roomsQuery));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (user) {
        return Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _ink900),
            title: Text(
              isEdit ? 'Edit Rack' : 'Create Rack',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w900,
              ),
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: _Card(
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Rack Details',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Room dropdown with right-side "Room create"
                            // roomsAv.when(
                            //   loading:
                            //       () => const LinearProgressIndicator(minHeight: 2),
                            //   error: (e, _) => Text('Room load error: $e'),
                            //   data: (paged) {
                            //     final rooms = paged.rows;

                            //     // Preselect in edit mode
                            //     if (isEdit && _room == null) {
                            //       final hit =
                            //           rooms
                            //               .where(
                            //                 (x) => x.id == widget.initial!.roomId,
                            //               )
                            //               .toList();
                            //       if (hit.isNotEmpty) _room = hit.first;
                            //     }

                            //     final safeValue =
                            //         (_room != null &&
                            //                 rooms.any((x) => x.id == _room!.id))
                            //             ? rooms.firstWhere((x) => x.id == _room!.id)
                            //             : null;
                            if (isEdit) ...[
                              Builder(
                                builder: (context) {
                                  final roomsAv = ref.watch(
                                    rackDataStockDataStreamProvider(
                                      widget.initial!.id,
                                    ),
                                  );
                                  return (roomsAv.value == null)
                                      ? Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [_bgTop, _bgBottom],
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            "rack Data is not available",
                                            style: TextStyle(
                                              color: _ink900,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      )
                                      : roomsAv.when(
                                        loading:
                                            () => const LinearProgressIndicator(
                                              minHeight: 2,
                                            ),
                                        error:
                                            (e, _) =>
                                                Text('rack load error: $e'),
                                        data: (rack) {
                                          return (rack == null)
                                              ? Container(
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: [_bgTop, _bgBottom],
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                  ),
                                                ),
                                                child: const Center(
                                                  child: Text(
                                                    "rack Data is not available",
                                                    style: TextStyle(
                                                      color: _ink900,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              : Column(
                                                children: [
                                                  _ReadRow(
                                                    label: 'Room Name',
                                                    value: rack["roomName"],
                                                    icon:
                                                        Icons
                                                            .text_fields_rounded,
                                                  ),
                                                  const SizedBox(height: 10),
                                                  _ReadRow(
                                                    label: 'Rack Code',
                                                    value: rack["code"],
                                                    icon:
                                                        Icons
                                                            .text_fields_rounded,
                                                  ),
                                                  if (rack["isOccupied"]) ...[
                                                    const SizedBox(height: 10),
                                                    _ReadRow(
                                                      label: 'Item Name',
                                                      value:
                                                          rack["itemName"]
                                                              .toString(),
                                                      icon:
                                                          Icons
                                                              .text_fields_rounded,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    _ReadRow(
                                                      label: 'Rack Stock',
                                                      value:
                                                          rack["stockAvailableQuantity"]
                                                              .toString(),
                                                      icon:
                                                          Icons
                                                              .text_fields_rounded,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    (double.parse(
                                                              rack["stockAvailableQuantity"]
                                                                  .toString(),
                                                            ) >
                                                            0)
                                                        ? (user!.appWorks.contains(
                                                              "storeitemtransfer",
                                                            ))
                                                            ? ElevatedButton(
                                                              onPressed:
                                                                  _openTransferItem,
                                                              child: Text(
                                                                "Transfer Qty",
                                                              ),
                                                            )
                                                            : SizedBox.shrink()
                                                        : ElevatedButton(
                                                          onPressed:
                                                              () => _confirmRemoveItem(
                                                                rack["_id"],
                                                                rack["itemId"],
                                                              ),
                                                          child: Text(
                                                            "Remove Item",
                                                          ),
                                                        ),
                                                  ] else ...[
                                                    const SizedBox(height: 10),
                                                    ElevatedButton(
                                                      onPressed:
                                                          () =>
                                                              _confirmRemoveRack(
                                                                rack["_id"],
                                                              ),
                                                      child: Text(
                                                        "Remove the Rack",
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                        },
                                      );
                                },
                              ),
                            ] else ...[
                              Row(
                                children: [
                                  Checkbox(
                                    value: _createRack,
                                    onChanged: (value) {
                                      setState(() {
                                        _createRack = value ?? false;
                                      });
                                    },
                                  ),
                                  const Text(
                                    "Create Scrap Storing Rack in this room",
                                    style: TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              (_createRack)
                                  ? _RoomDropdownWithCreateScrap(
                                    value: _room,
                                    initial: widget.initial,
                                    onChanged: (v) => setState(() => _room = v),
                                    onCreateTap: _openQuickRoomCreate,
                                    isScrap: _createRack,
                                  )
                                  : _RoomDropdownWithCreate(
                                    value: _room,
                                    initial: widget.initial,
                                    onChanged: (v) => setState(() => _room = v),
                                    onCreateTap: _openQuickRoomCreate,
                                    isScrap: _createRack,
                                  ),

                              //   },
                              // ),
                              const SizedBox(height: 12),

                              // _Field(
                              //   controller: _code,
                              //   label: 'Code (auto)',
                              //   hint: 'Auto code',
                              //   icon: Icons.qr_code_2_rounded,
                              //   enabled: false,
                              //   validator: (v) => null,
                              // ),
                              // const SizedBox(height: 12),
                              // _Field(
                              //   controller: _name,
                              //   labelColor: _ink900, // ✅
                              //   label: 'Rack Name *',
                              //   hint: 'e.g., Rack A1',
                              //   icon: Icons.view_module_rounded,
                              //   validator:
                              //       (v) =>
                              //           (v == null || v.trim().isEmpty)
                              //               ? 'Required'
                              //               : null,
                              // ),
                              const SizedBox(height: 12),

                              _Field(
                                controller: _remark,
                                labelColor: _ink900, // ✅
                                label: 'Remark',
                                hint: 'Optional note',
                                icon: Icons.notes_rounded,
                                maxLines: 3,
                                validator: (v) => null,
                              ),
                              const SizedBox(height: 18),

                              _PrimaryBtn(
                                label:
                                    _busy
                                        ? 'Saving...'
                                        : (isEdit
                                            ? 'Save Changes'
                                            : 'Create Rack'),
                                busy: _busy,
                                onTap: _busy ? null : _save,
                              ),
                            ],
                          ],
                        ),
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

/* ---------- Room dropdown with "Room create" on right ---------- */
class _RoomDropdownWithCreate extends ConsumerStatefulWidget {
  const _RoomDropdownWithCreate({
    required this.value,
    required this.onChanged,
    required this.isScrap,
    required this.onCreateTap,
    this.initial,
  });

  final StoreRack? initial;
  final StoreRoom? value;
  final bool isScrap;
  final ValueChanged<StoreRoom?> onChanged;
  final VoidCallback onCreateTap; // Using the fetched data

  @override
  ConsumerState<_RoomDropdownWithCreate> createState() =>
      __RoomDropdownWithCreateState();
}

class __RoomDropdownWithCreateState
    extends ConsumerState<_RoomDropdownWithCreate> {
  StoreRoom? _room;
  // RoomQuery get _roomsQuery => RoomQuery(
  //   page: 1,
  //   limit: 300,
  //   search: '',
  //   sort: 'name',
  //   isScrap: widget.isScrap,
  // );
  // @override
  // void initState() {
  //    _roomsQuery = RoomQuery(
  //     page: 1,
  //     limit: 300,
  //     search: '',
  //     sort: 'name',
  //     isScrap: widget.isScrap,
  //   );

  //   super.initState();
  // }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final roomsAv = ref.watch(findAllRoomDataByGoodStreamProvider);
    return roomsAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (paged) {
        // (Optional but recommended) De-duplicate by id to avoid duplicate-value problems
        final rooms = {for (final r in paged) r.id: r}.values.toList();

        // Determine selected id:
        // 1) parent-controlled value
        // 2) local state (updates immediately on select)
        // 3) edit mode initial (rack.roomId)
        final selectedId =
            widget.value?.id ?? _room?.id ?? (widget.initial?.roomId);

        StoreRoom? byId(String? id) {
          if (id == null) return null;
          for (final r in rooms) {
            if (r.id == id) return r;
          }
          return null;
        }

        final safeValue = byId(selectedId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room *',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              padding: const EdgeInsets.only(left: 6, right: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.meeting_room_rounded, color: _ink600),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StoreRoom>(
                        value: safeValue,
                        isExpanded: true,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        dropdownColor: _surface,
                        iconEnabledColor: _ink600,
                        hint: const Text(
                          'Select room',
                          style: TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        // IMPORTANT: build from SAME rooms list
                        selectedItemBuilder: (context) {
                          return rooms.map((r) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList();
                        },

                        items: [
                          for (final r in rooms)
                            DropdownMenuItem<StoreRoom>(
                              value: r,
                              child: Text(
                                r.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ),
                        ],

                        onChanged: (v) {
                          setState(
                            () => _room = v,
                          ); // ✅ this makes selection visible immediately
                          widget.onChanged(v); // ✅ notify parent
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onCreateTap,
                    child: const Text(
                      'Room create',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RoomDropdownWithCreateScrap extends ConsumerStatefulWidget {
  const _RoomDropdownWithCreateScrap({
    required this.value,
    required this.onChanged,
    required this.isScrap,
    required this.onCreateTap,
    this.initial,
  });

  final StoreRack? initial;
  final StoreRoom? value;
  final bool isScrap;
  final ValueChanged<StoreRoom?> onChanged;
  final VoidCallback onCreateTap; // Using the fetched data

  @override
  ConsumerState<_RoomDropdownWithCreateScrap> createState() =>
      __RoomDropdownWithCreateScrapState();
}

class __RoomDropdownWithCreateScrapState
    extends ConsumerState<_RoomDropdownWithCreateScrap> {
  StoreRoom? _room;
  // RoomQuery get _roomsQuery => RoomQuery(
  //   page: 1,
  //   limit: 300,
  //   search: '',
  //   sort: 'name',
  //   isScrap: widget.isScrap,
  // );
  // @override
  // void initState() {
  //    _roomsQuery = RoomQuery(
  //     page: 1,
  //     limit: 300,
  //     search: '',
  //     sort: 'name',
  //     isScrap: widget.isScrap,
  //   );

  //   super.initState();
  // }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    final roomsAv = ref.watch(findAllRoomDataByScrapStreamProvider);
    return roomsAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('Room load error: $e'),
      data: (paged) {
        // (Optional but recommended) De-duplicate by id to avoid duplicate-value problems
        final rooms = {for (final r in paged) r.id: r}.values.toList();

        // Determine selected id:
        // 1) parent-controlled value
        // 2) local state (updates immediately on select)
        // 3) edit mode initial (rack.roomId)
        final selectedId =
            widget.value?.id ?? _room?.id ?? (widget.initial?.roomId);

        StoreRoom? byId(String? id) {
          if (id == null) return null;
          for (final r in rooms) {
            if (r.id == id) return r;
          }
          return null;
        }

        final safeValue = byId(selectedId);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Room *',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              padding: const EdgeInsets.only(left: 6, right: 6),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.meeting_room_rounded, color: _ink600),
                  ),
                  Expanded(
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StoreRoom>(
                        value: safeValue,
                        isExpanded: true,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                        dropdownColor: _surface,
                        iconEnabledColor: _ink600,
                        hint: const Text(
                          'Select room',
                          style: TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        // IMPORTANT: build from SAME rooms list
                        selectedItemBuilder: (context) {
                          return rooms.map((r) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                r.code,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          }).toList();
                        },

                        items: [
                          for (final r in rooms)
                            DropdownMenuItem<StoreRoom>(
                              value: r,
                              child: Text(
                                r.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _ink900,
                                ),
                              ),
                            ),
                        ],

                        onChanged: (v) {
                          setState(
                            () => _room = v,
                          ); // ✅ this makes selection visible immediately
                          widget.onChanged(v); // ✅ notify parent
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: widget.onCreateTap,
                    child: const Text(
                      'Room create',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/* ---------- Quick create room dialog (REST create) ---------- */

class _RoomQuickCreateDialog extends ConsumerStatefulWidget {
  const _RoomQuickCreateDialog({required this.isScrap});
  final bool isScrap;
  @override
  ConsumerState<_RoomQuickCreateDialog> createState() =>
      _RoomQuickCreateDialogState();
}

class _RoomQuickCreateDialogState
    extends ConsumerState<_RoomQuickCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _remark = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _code.text = genCode(prefix: 'RM', name: '');
    _name.addListener(() {
      final n = _name.text.trim();
      if (n.isEmpty) return;
      _code.text = genCode(prefix: 'RM', name: n);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    _remark.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid");

    final dto = <String, dynamic>{
      'name': _name.text.trim(),
      'remark': _remark.text.trim(),
      'isScrap': widget.isScrap,
      'createdBy': createdBy,
    };

    setState(() => _busy = true);

    try {
      final created = await ref
          .read(storeRoomControllerProvider)
          .createRoom(storeRoom: dto);

      if (!mounted) return;

      if (created == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Create failed')));
        return;
      }

      Navigator.of(context, rootNavigator: true).pop<StoreRoom>(created);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed room: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Room'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // _Field(
              //   controller: _code,
              //   label: 'Code (auto)',
              //   hint: 'Auto code',
              //   icon: Icons.qr_code_2_rounded,
              //   enabled: false,
              //   validator: (v) => null,
              // ),
              const SizedBox(height: 10),
              _Field(
                controller: _name,
                label: 'Name *',
                labelColor: _surfaceAlt, // ✅
                hint: 'e.g., Room 1',
                icon: Icons.meeting_room_rounded,
                validator:
                    (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _remark,
                label: 'Remark',
                labelColor: _surfaceAlt, // ✅
                hint: 'Optional',
                icon: Icons.notes_rounded,
                maxLines: 2,
                validator: (v) => null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _create,
          child: Text(_busy ? 'Creating...' : 'Create'),
        ),
      ],
    );
  }
}

/* ---------- Shared styled widgets ---------- */

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
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.validator,
    this.maxLines = 1,
    this.labelColor,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final String? Function(String?) validator;
  final int maxLines;

  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final lc = labelColor ?? _ink900; // ✅ default dark label for light pages

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: lc, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.55),
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
          ),
        ),
      ],
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.label,
    required this.onTap,
    required this.busy,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _surface,
                  ),
                )
              else
                const Icon(Icons.save_rounded, size: 18, color: _surface),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _surface,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
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

  // int get _maxQty => widget.item.stockAvailableQuantity;

  RackQuery get _rackQuery => RackQuery(
    page: 1,
    limit: 200,
    search: _q,
    sort: 'name',
    roomId: null,
    // if your backend supports "allowItemId" to include same-item racks, pass item.id
    // allowItemId: widget.item.id,
  );

  Map<String, dynamic> query = {};
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

    final rackstockAv = ref.watch(
      rackDataStockDataStreamProvider(widget.rack.id),
    );

    final itemAv = ref.watch(itemFindOneStreamProvider(widget.item));
    return itemAv.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Item load error: $e')),
      data: (item) {
        int maxQty = item!.stockAvailableQuantity;
        return rackstockAv.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Rack load error: $e')),
          data: (paged) {
            final filtered = paged;
            // .firstWhere(
            //   (r) => r["_id"] == widget.rack.id,
            // );
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
                    _HintBar(
                      text:
                          'Move quantity from this rack to another rack. Quantity must be ≤ Available.',
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: 'Item',
                      value: '${item.itemName} (${item.itemCode})',
                    ),
                    _InfoRow(label: 'Available', value: '$maxQty'),
                    _InfoRow(
                      label: 'Rack',
                      value: '${filtered!["code"]} (${filtered["name"]})',
                    ),
                    // _InfoRow(label: 'From Rack', value: widget.item.rackName),
                    _InfoRow(
                      label: 'Rack Available',
                      value: '${filtered["stockAvailableQuantity"]}',
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
                            () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                        error:
                            (e, _) =>
                                Center(child: Text('Rack load error: $e')),
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
                            separatorBuilder:
                                (_, __) => const Divider(height: 1),
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
                            'Enter quantity (max ${filtered["stockAvailableQuantity"]})',
                        helperText:
                            'Quantity must be between 1 and ${filtered["stockAvailableQuantity"]}',
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
                            if (qty == null ||
                                qty <= 0 ||
                                qty >
                                    int.parse(
                                      filtered["stockAvailableQuantity"]
                                          .toString(),
                                    )) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Enter valid quantity (1..${filtered["stockAvailableQuantity"]})',
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

class RacksGoodQtyListPage extends ConsumerStatefulWidget {
  const RacksGoodQtyListPage({super.key});

  @override
  ConsumerState<RacksGoodQtyListPage> createState() =>
      _RacksGoodQtyListPageState();
}

class _RacksGoodQtyListPageState extends ConsumerState<RacksGoodQtyListPage> {
  StoreRoom? _filterRoom; // optional filter
  String _q = '';
  int _limit = 12;

  // Rooms: for dropdown only (fetch more so user sees all)
  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  // Racks: WS pagination + search + room filter
  RackQuery get _racksQuery => RackQuery(
    page: 1,
    limit: _limit,
    search: _q,
    sort: 'createdAt',
    roomId: _filterRoom?.id,
  );

  void _refresh() {
    // Invalidate whole families (refresh all instances)
    ref.invalidate(storeRoomPagedStreamProvider(_roomsQuery));
    ref.invalidate(storeRackPagedStreamProvider(_racksQuery));

    // Also reset racks page settings
    setState(() => _limit = 12);
  }

  void _loadMore(PagedRacks paged) {
    final canLoadMore = paged.rows.length < paged.total;
    if (!canLoadMore) return;
    setState(() => _limit += 12);
  }

  Future<void> _openForm({StoreRack? initial}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RackFormPage(initial: initial)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openroomForm() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RoomCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreRack r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete rack?'),
            content: Text('Delete  ${r.code} ?'),
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

    final ok = await ref.read(storeRackControllerProvider).deleteRack(id: r.id);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Deleted' : 'Delete failed')));
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAv = ref.watch(storeRoomPagedStreamProvider(_roomsQuery));
    final racksAv = ref.watch(storeRackPagedStreamProvider(_racksQuery));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    return Scaffold(
      backgroundColor: _surface,

      body: pagedUser.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text('Room load error: $e'),
        data: (user) {
          return Container(
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
                        // Filter row: room filter + search
                        _Card(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: roomsAv.when(
                                  loading:
                                      () => const LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                  error: (e, _) => Text('Room load error: $e'),
                                  data: (paged) {
                                    final rooms = paged.rows;

                                    return DropdownButtonFormField<StoreRoom?>(
                                      initialValue:
                                          (_filterRoom != null &&
                                                  rooms.any(
                                                    (x) =>
                                                        x.id == _filterRoom!.id,
                                                  ))
                                              ? rooms.firstWhere(
                                                (x) => x.id == _filterRoom!.id,
                                              )
                                              : null,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                      dropdownColor: _surface,
                                      iconEnabledColor: _ink600,
                                      items: [
                                        const DropdownMenuItem<StoreRoom?>(
                                          value: null,
                                          child: Text(
                                            'All rooms',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        for (final r in rooms)
                                          DropdownMenuItem<StoreRoom?>(
                                            value: r,
                                            child: Text(
                                              r.code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _filterRoom = v;
                                          _limit = 12;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Filter by room',
                                        prefixIcon: const Icon(
                                          Icons.meeting_room_rounded,
                                          color: _ink600,
                                        ),
                                        filled: true,
                                        fillColor: _surfaceAlt.withValues(alpha: .55),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  onChanged: (v) {
                                    setState(() {
                                      _q = v.trim();
                                      _limit = 12;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search rack...',
                                    hintStyle: const TextStyle(color: _ink600),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _ink600,
                                    ),
                                    filled: true,
                                    fillColor: _surfaceAlt.withValues(alpha: .55),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _stroke,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _stroke,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: racksAv.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error: (e, _) => Center(child: Text('Error: $e')),
                            data: (paged) {
                              final rows = paged.rows;

                              if (rows.isEmpty) {
                                return const _EmptyState(
                                  title: 'No racks found',
                                  subtitle:
                                      'Create a rack and assign it to a room.',
                                );
                              }

                              final canLoadMore = rows.length < paged.total;

                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: rows.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, i) {
                                        final r = rows[i];
                                        return _Card(
                                          child: ListTile(
                                            leading: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _accentPeach.withValues(
                                                  alpha: .55,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: _stroke,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.view_module_rounded,
                                                color: _ink900,
                                              ),
                                            ),
                                            title: Text(
                                              r.code,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: Text(
                                              // '${r.roomName} • ${(r.itemName)}'
                                              r.remark.isNotEmpty ? " • ${r.remark}" : "",
                                              style: const TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            trailing: Wrap(
                                              spacing: 6,
                                              children: [
                                                (user!.appWorks.contains(
                                                      "storeplaceedit",
                                                    ))
                                                    ? IconButton(
                                                      tooltip: 'Edit',
                                                      onPressed:
                                                          () => _openForm(
                                                            initial: r,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.edit_rounded,
                                                        color: _ink700,
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                                // IconButton(
                                                //   tooltip: 'Scan Receive',
                                                //   onPressed:
                                                //       () => Navigator.push(
                                                //         context,
                                                //         MaterialPageRoute(
                                                //           builder:
                                                //               (_) =>
                                                //                   ScanRackReceivePage(
                                                //                     rackId:
                                                //                         r.id,
                                                //                   ),
                                                //         ),
                                                //       ),
                                                //   icon: const Icon(
                                                //     Icons.macro_off,
                                                //     color: _ink700,
                                                //   ),
                                                // ),
                                                // IconButton(
                                                //   tooltip: 'Scan Issue',
                                                //   onPressed:
                                                //       () => Navigator.push(
                                                //         context,
                                                //         MaterialPageRoute(
                                                //           builder:
                                                //               (_) =>
                                                //                   IssueByRackActionsPage(
                                                //                     rackId:
                                                //                         r.id,
                                                //                   ),
                                                //         ),
                                                //       ),
                                                //   icon: const Icon(
                                                //     Icons.ice_skating,
                                                //     color: _ink700,
                                                //   ),
                                                // ),
                                                IconButton(
                                                  tooltip: 'QR Code',
                                                  onPressed:
                                                      () => Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                _,
                                                              ) => QRCodePrintRackPage(
                                                                storeRackList: [
                                                                  r,
                                                                ],
                                                              ),
                                                        ),
                                                      ),
                                                  icon: const Icon(
                                                    Icons.qr_code,
                                                    color: _ink700,
                                                  ),
                                                ),
                                                // IconButton(
                                                //   tooltip: 'Delete',
                                                //   onPressed:
                                                //       () => _confirmDelete(r),
                                                //   icon: const Icon(
                                                //     Icons.delete_outline_rounded,
                                                //     color: Colors.redAccent,
                                                //   ),
                                                // ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (canLoadMore)
                                    _Card(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Showing ${rows.length} of ${paged.total}',
                                            style: const TextStyle(
                                              color: _ink700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () => _loadMore(paged),
                                            icon: const Icon(
                                              Icons.expand_more_rounded,
                                            ),
                                            label: const Text('Load more'),
                                          ),
                                          SizedBox(width: 20),
                                        ],
                                      ),
                                    )
                                  else
                                    _Card(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                        'Showing ${rows.length} of ${paged.total}',
                                        style: const TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w700,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class RacksScrapQtyListPage extends ConsumerStatefulWidget {
  const RacksScrapQtyListPage({super.key});

  @override
  ConsumerState<RacksScrapQtyListPage> createState() =>
      _RacksScrapQtyListPageState();
}

class _RacksScrapQtyListPageState extends ConsumerState<RacksScrapQtyListPage> {
  StoreRoom? _filterRoom; // optional filter
  String _q = '';
  int _limit = 12;

  // Rooms: for dropdown only (fetch more so user sees all)
  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  // Racks: WS pagination + search + room filter
  RackQuery get _racksQuery => RackQuery(
    page: 1,
    limit: _limit,
    search: _q,
    sort: 'createdAt',
    roomId: _filterRoom?.id,
  );

  void _refresh() {
    // Invalidate whole families (refresh all instances)
    ref.invalidate(storeSrcapRoomPagedStreamProvider(_roomsQuery));
    ref.invalidate(storeScrapRackPagedStreamProvider(_racksQuery));

    // Also reset racks page settings
    setState(() => _limit = 12);
  }

  void _loadMore(PagedRacks paged) {
    final canLoadMore = paged.rows.length < paged.total;
    if (!canLoadMore) return;
    setState(() => _limit += 12);
  }

  Future<void> _openForm({StoreRack? initial}) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RackFormPage(initial: initial)),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openroomForm() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RoomCreatePage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _confirmDelete(StoreRack r) async {
    final yes = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete rack?'),
            content: Text('Delete (${r.code} ?'),
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

    final ok = await ref.read(storeRackControllerProvider).deleteRack(id: r.id);
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(ok ? 'Deleted' : 'Delete failed')));
    if (ok) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAv = ref.watch(storeSrcapRoomPagedStreamProvider(_roomsQuery));
    final racksAv = ref.watch(storeScrapRackPagedStreamProvider(_racksQuery));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    return Scaffold(
      backgroundColor: _surface,

      body: pagedUser.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => Text('Room load error: $e'),
        data: (user) {
          return Container(
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
                        // Filter row: room filter + search
                        _Card(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: roomsAv.when(
                                  loading:
                                      () => const LinearProgressIndicator(
                                        minHeight: 2,
                                      ),
                                  error: (e, _) => Text('Room load error: $e'),
                                  data: (paged) {
                                    final rooms = paged.rows;

                                    return DropdownButtonFormField<StoreRoom?>(
                                      initialValue:
                                          (_filterRoom != null &&
                                                  rooms.any(
                                                    (x) =>
                                                        x.id == _filterRoom!.id,
                                                  ))
                                              ? rooms.firstWhere(
                                                (x) => x.id == _filterRoom!.id,
                                              )
                                              : null,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                      dropdownColor: _surface,
                                      iconEnabledColor: _ink600,
                                      items: [
                                        const DropdownMenuItem<StoreRoom?>(
                                          value: null,
                                          child: Text(
                                            'All rooms',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        for (final r in rooms)
                                          DropdownMenuItem<StoreRoom?>(
                                            value: r,
                                            child: Text(
                                              r.code,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _filterRoom = v;
                                          _limit = 12;
                                        });
                                      },
                                      decoration: InputDecoration(
                                        hintText: 'Filter by room',
                                        prefixIcon: const Icon(
                                          Icons.meeting_room_rounded,
                                          color: _ink600,
                                        ),
                                        filled: true,
                                        fillColor: _surfaceAlt.withValues(alpha: .55),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          borderSide: const BorderSide(
                                            color: _stroke,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  onChanged: (v) {
                                    setState(() {
                                      _q = v.trim();
                                      _limit = 12;
                                    });
                                  },
                                  decoration: InputDecoration(
                                    hintText: 'Search rack...',
                                    hintStyle: const TextStyle(color: _ink600),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: _ink600,
                                    ),
                                    filled: true,
                                    fillColor: _surfaceAlt.withValues(alpha: .55),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _stroke,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: _stroke,
                                      ),
                                    ),
                                  ),
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        Expanded(
                          child: racksAv.when(
                            loading:
                                () => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                            error: (e, _) => Center(child: Text('Error: $e')),
                            data: (paged) {
                              final rows = paged.rows;

                              if (rows.isEmpty) {
                                return const _EmptyState(
                                  title: 'No racks found',
                                  subtitle:
                                      'Create a rack and assign it to a room.',
                                );
                              }

                              final canLoadMore = rows.length < paged.total;

                              return Column(
                                children: [
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: rows.length,
                                      separatorBuilder:
                                          (_, __) => const SizedBox(height: 10),
                                      itemBuilder: (context, i) {
                                        final r = rows[i];
                                        return _Card(
                                          child: ListTile(
                                            leading: Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: _accentPeach.withValues(
                                                  alpha: .55,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                border: Border.all(
                                                  color: _stroke,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.view_module_rounded,
                                                color: _ink900,
                                              ),
                                            ),
                                            title: Text(
                                              r.code,
                                              style: const TextStyle(
                                                color: _ink900,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            subtitle: Text(
                                              // '${r.roomName} • ${(r.itemName)}'
                                              r.remark.isNotEmpty ? " • ${r.remark}" : "",
                                              style: const TextStyle(
                                                color: _ink700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            trailing: Wrap(
                                              spacing: 6,
                                              children: [
                                                (user!.appWorks.contains(
                                                      "storeplaceedit",
                                                    ))
                                                    ? IconButton(
                                                      tooltip: 'Edit',
                                                      onPressed:
                                                          () => _openForm(
                                                            initial: r,
                                                          ),
                                                      icon: const Icon(
                                                        Icons.edit_rounded,
                                                        color: _ink700,
                                                      ),
                                                    )
                                                    : SizedBox.shrink(),
                                                // IconButton(
                                                //   tooltip: 'Scan Receive',
                                                //   onPressed:
                                                //       () => Navigator.push(
                                                //         context,
                                                //         MaterialPageRoute(
                                                //           builder:
                                                //               (_) =>
                                                //                   ScanRackReceivePage(
                                                //                     rackId:
                                                //                         r.id,
                                                //                   ),
                                                //         ),
                                                //       ),
                                                //   icon: const Icon(
                                                //     Icons.macro_off,
                                                //     color: _ink700,
                                                //   ),
                                                // ),
                                                // IconButton(
                                                //   tooltip: 'Scan Issue',
                                                //   onPressed:
                                                //       () => Navigator.push(
                                                //         context,
                                                //         MaterialPageRoute(
                                                //           builder:
                                                //               (_) =>
                                                //                   IssueByRackActionsPage(
                                                //                     rackId:
                                                //                         r.id,
                                                //                   ),
                                                //         ),
                                                //       ),
                                                //   icon: const Icon(
                                                //     Icons.ice_skating,
                                                //     color: _ink700,
                                                //   ),
                                                // ),
                                                IconButton(
                                                  tooltip: 'QR Code',
                                                  onPressed:
                                                      () => Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder:
                                                              (
                                                                _,
                                                              ) => QRCodePrintRackPage(
                                                                storeRackList: [
                                                                  r,
                                                                ],
                                                              ),
                                                        ),
                                                      ),
                                                  icon: const Icon(
                                                    Icons.qr_code,
                                                    color: _ink700,
                                                  ),
                                                ),
                                                // IconButton(
                                                //   tooltip: 'Delete',
                                                //   onPressed:
                                                //       () => _confirmDelete(r),
                                                //   icon: const Icon(
                                                //     Icons.delete_outline_rounded,
                                                //     color: Colors.redAccent,
                                                //   ),
                                                // ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (canLoadMore)
                                    _Card(
                                      padding: const EdgeInsets.all(10),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Showing ${rows.length} of ${paged.total}',
                                            style: const TextStyle(
                                              color: _ink700,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          FilledButton.icon(
                                            onPressed: () => _loadMore(paged),
                                            icon: const Icon(
                                              Icons.expand_more_rounded,
                                            ),
                                            label: const Text('Load more'),
                                          ),
                                          SizedBox(width: 20),
                                        ],
                                      ),
                                    )
                                  else
                                    _Card(
                                      padding: const EdgeInsets.all(10),
                                      child: Text(
                                        'Showing ${rows.length} of ${paged.total}',
                                        style: const TextStyle(
                                          color: _ink700,
                                          fontWeight: FontWeight.w700,
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
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
