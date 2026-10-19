// lib/src/store/presentation/views/racks/racks_list_page.dart
import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../controllers/store_room_controller.dart';

import '../../widgets/excel_downloader_web.dart';
import '../../../../components/motion_widgets.dart';
import '../rooms/rooms_list_page.dart';
import 'add_rack_page.dart';
import 'lists/racks_good_qty_item_list_page.dart';
import 'lists/racks_good_qty_machine_list_page.dart';
import 'lists/racks_scrap_qty_item_list_page.dart';
import 'lists/rakes_scrap_qty_machine_list_page.dart';
import 'widgets/racks_shared_widgets.dart';
import 'widgets/racks_theme.dart';
import '../../../controllers/guided_tour_controller.dart';

class RacksListPage extends ConsumerStatefulWidget {
  const RacksListPage({
    super.key,
    this.goodItemRacksTabKey,
    this.scrapItemRacksTabKey,
    this.goodMachineRoomsTabKey,
    this.scrapMachineRoomsTabKey,
  });

  final GlobalKey? goodItemRacksTabKey;
  final GlobalKey? scrapItemRacksTabKey;
  final GlobalKey? goodMachineRoomsTabKey;
  final GlobalKey? scrapMachineRoomsTabKey;

  @override
  ConsumerState<RacksListPage> createState() => _RacksListPageState();
}

class _RacksListPageState extends ConsumerState<RacksListPage> {
  int _selectedTabIndex = 0;
  RoomQuery get _roomsQuery =>
      const RoomQuery(page: 1, limit: 300, search: '', sort: 'name');

  void _refresh() {
    ref.invalidate(storeRoomPagedStreamProvider(_roomsQuery));
    ref.invalidate(storeAllRackPagedStreamProvider);
  }

  Uint8List _buildRacksExcelBytes(List<Map<String, dynamic>> items) {
    final excel = Excel.createExcel();
    const sheetName = 'Racks';

    if (excel.sheets.keys.contains('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    excel.setDefaultSheet(sheetName);

    final sheet = excel[sheetName];

    CellValue t(String v) => TextCellValue(v);

    sheet.appendRow([
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
        t(it["code"]),
        t(it["itemName"]),
        t(it["roomName"]),
        t(it["remark"]),
        t(it["isScrap"] ? 'YES' : 'NO'),
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
    if (rowsList.isEmpty) {
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
            ? 'racks_all_$y$m$d.xlsx'
            : (isScrap ? 'racks_scrap_$y$m$d.xlsx' : 'racks_good_$y$m$d.xlsx');

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

  Future<void> _openAddRack() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddRackPage()),
    );
    if (ok == true) _refresh();
  }

  Future<void> _openRoomForm() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => RoomCreatePage()),
    );
    if (ok == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final racksAllAv = ref.watch(storeAllRackPagedStreamProvider);
    final userAv = ref.watch(userFindOneDataStreamProvider);

    return userAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        return racksAllAv.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Racks load error: $e'),
          data: (rows) {
            return Scaffold(
              backgroundColor: surface,
              appBar: AppBar(
                elevation: 0,
                backgroundColor: surface,
                surfaceTintColor: Colors.transparent,
                iconTheme: const IconThemeData(color: ink900),
                title: const Text(
                  'Racks',
                  style: TextStyle(color: ink900, fontWeight: FontWeight.w900),
                ),
                actions: [
                  _HeaderActionButton(
                    icon: Icons.refresh_rounded,
                    tooltip: 'Refresh',
                    onPressed: _refresh,
                  ),
                  if (user != null &&
                      (user.isSuperAdmin ||
                          user.appWorks.contains("storeadmin") ||
                          user.appWorks.contains("storeexport"))) ...[
                    const SizedBox(width: 6),
                    _HeaderActionButton(
                      icon: Icons.file_download_rounded,
                      tooltip: 'Download Excel',
                      onPressed: () => _showExportSheet(rows),
                    ),
                  ],
                  if (user != null &&
                      (user.isSuperAdmin ||
                          user.appWorks.contains("storeadmin") ||
                          user.appWorks.contains("storeplaceadd"))) ...[
                    const SizedBox(width: 6),
                    _HeaderActionButton(
                      icon: Icons.storage_rounded,
                      tooltip: "Add Rack",
                      isPrimary: true,
                      onPressed: _openAddRack,
                    ),
                    const SizedBox(width: 6),
                    _HeaderActionButton(
                      icon: Icons.add_home_rounded,
                      tooltip: "Add Room",
                      isPrimary: true,
                      onPressed: _openRoomForm,
                    ),
                  ],
                  const SizedBox(width: 12),
                ],
              ),
              body: DefaultTabController(
                length: 4,
                child: Column(
                  children: [
                    AppCard(
                      key: GuidedTourController.placesZoneTabsKey,
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: TabBar(
                        onTap: (index) => setState(() => _selectedTabIndex = index),
                        labelColor: ink900,
                        unselectedLabelColor: ink700,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: ink500,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        tabs: [
                          Tab(
                            key: widget.goodItemRacksTabKey ??
                                GuidedTourController.goodItemRacksTabKey,
                            text: "Good Items Racks",
                          ),
                          Tab(
                            key: widget.scrapItemRacksTabKey ??
                                GuidedTourController.scrapItemRacksTabKey,
                            text: "Scrap Items Racks",
                          ),
                          Tab(
                            key: widget.goodMachineRoomsTabKey ??
                                GuidedTourController.goodMachineRoomsTabKey,
                            text: "Good Machine Rooms",
                          ),
                          Tab(
                            key: widget.scrapMachineRoomsTabKey ??
                                GuidedTourController.scrapMachineRoomsTabKey,
                            text: "Scrap Machine Rooms",
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AppAnimatedTabView(
                        currentTabIndex: _selectedTabIndex,
                        tabs: const [
                          RacksGoodQtyItemListPage(),
                          RacksScrapQtyItemListPage(),
                          RacksGoodQtyMachineListPage(),
                          RacksScrapQtyMachineListPage(),
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

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _HeaderActionButton({
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
            color: isPrimary ? ink900 : surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isPrimary ? ink900 : stroke),
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
            color: isPrimary ? Colors.white : ink900,
          ),
        ),
      ),
    );
  }
}
