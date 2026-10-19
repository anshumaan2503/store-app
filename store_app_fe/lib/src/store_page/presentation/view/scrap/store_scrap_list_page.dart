import 'dart:typed_data';

import 'package:excel/excel.dart' hide Border;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_scrap_controller.dart';
import '../../../domains/models/store_scrap_model.dart';
import '../../widgets/excel_downloader.dart';
import '../../widgets/store_ui_state_widgets.dart';
import 'create_scrap_page.dart';

/* =================== Palette (reuse yours) =================== */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* =================== Scrap List Page =================== */

class StoreScrapListPage extends ConsumerStatefulWidget {
  const StoreScrapListPage({super.key});

  @override
  ConsumerState<StoreScrapListPage> createState() => _StoreScrapListPageState();
}

class _StoreScrapListPageState extends ConsumerState<StoreScrapListPage> {
  final _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final int _limit = 20;
  int _page = 1;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ScrapPagedQuery get _query => ScrapPagedQuery(
    page: _page,
    limit: _limit,
    search: _searchCtrl.text.trim(),
    sort: '-createdAt',
  );

  Future<void> _openCreate() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ScrapCreatePage()));

    // refresh after returning
    ref.invalidate(scrapPagedStreamProvider);
  }

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;

    if (v is int) {
      if (v > 1000000000000) return DateTime.fromMillisecondsSinceEpoch(v);
      return DateTime.fromMillisecondsSinceEpoch(v * 1000);
    }

    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      final asInt = int.tryParse(s);
      if (asInt != null) return _toDate(asInt);
      return DateTime.tryParse(s);
    }

    return null;
  }

  String formatDdMmYyyyHmAmPm(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');

    final day = two(d.day);
    final month = two(d.month);
    final year = d.year.toString();

    final hour12 = (d.hour % 12 == 0) ? 12 : (d.hour % 12);
    final ampm = d.hour >= 12 ? 'PM' : 'AM';

    final hh = two(hour12);
    final mm = two(d.minute);

    return '$day/$month/$year $hh:$mm $ampm';
  }

  Uint8List _buildItemsExcelBytes(List<StoreScrapModel> items) {
    final excel = Excel.createExcel();

    const sheetName = 'Scrap';

    if (excel.sheets.keys.contains('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    excel.setDefaultSheet(sheetName);

    final sheet = excel[sheetName];

    CellValue t(String v) => TextCellValue(v);
    CellValue n(double v) => DoubleCellValue(v);

    sheet.appendRow([
      t('Scraped By'),
      t('Scraped At'),
      t('Item Code'),
      t('Item Name'),
      t('Room Code'),
      t('Rack Code'),
      t('Scraped Qty'),
      t('Remark'),
    ]);

    for (final it in items) {
      final dt = _toDate((it as dynamic).createdAt);
      final createdAtText = dt == null ? '' : formatDdMmYyyyHmAmPm(dt);

      sheet.appendRow([
        t(it.createdByName),
        t(createdAtText),
        t(it.itemCode),
        t(it.itemName),
        t(it.roomCode),
        t(it.rackCode),
        n(it.itemQuantity),
        t(it.remark),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  Future<void> _exportItemsExcel({
    required List<StoreScrapModel> rowsList,
  }) async {
    if (rowsList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data loaded to export.')),
      );
      return;
    }

    final bytes = _buildItemsExcelBytes(rowsList);

    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Export failed: excel encode returned empty.'),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    final filename = 'scrap_all_$y$m$d.xlsx';

    await ExcelDownloader.saveBytes(bytes, filename);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Excel exported: $filename')));
  }

  Future<void> _showExportSheet(List<StoreScrapModel> rows) async {
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
                  title: const Text('Export All Loaded'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exportItemsExcel(rowsList: rows);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAv = ref.watch(userFindOneDataStreamProvider);
    final av = ref.watch(scrapPagedStreamProvider(_query));

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: const Text(
          'Scrap Stock',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        actions: [
          userAv.maybeWhen(
            data: (user) {
              final canAdd = user != null &&
                  (user.isSuperAdmin ||
                      user.appWorks.contains('storeadmin') ||
                      user.appWorks.contains('scrapadd'));
              if (!canAdd) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Add Scrap',
                icon: const Icon(Icons.add_rounded, color: _ink900),
                onPressed: _openCreate,
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: userAv.when(
        loading: () => const LinearProgressIndicator(minHeight: 2),
        error: (e, _) => StoreErrorView(
          error: e,
          onRetry: () => ref.invalidate(userFindOneDataStreamProvider),
        ),
        data: (user) {
          return av.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => StoreErrorView(
              error: e,
              onRetry: () => ref.invalidate(scrapPagedStreamProvider(_query)),
            ),
            data: (paged) {
              final rowsDynamic = paged.rows;

              if (rowsDynamic.isEmpty) {
                return StoreEmptyStateWidget(
                  message: 'No scrap entries found',
                  searchQuery: _searchCtrl.text,
                  onClearSearch: () => setState(() {
                    _searchCtrl.clear();
                    _page = 1;
                  }),
                );
              }

              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_bgTop, _bgBottom],
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() => _page = 1),
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search item / rack...',
                          hintStyle: const TextStyle(color: _ink600),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _ink600,
                          ),
                          suffixIcon: (user != null &&
                                  (user.isSuperAdmin ||
                                      user.appWorks.contains('storeadmin') ||
                                      user.appWorks.contains('scrapexport')))
                              ? IconButton(
                                  tooltip: 'Download',
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    color: _ink600,
                                  ),
                                  onPressed: () =>
                                      _showExportSheet(rowsDynamic),
                                )
                              : null,
                          filled: true,
                          fillColor: _surface,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: _stroke),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: _ink900,
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Scrollbar(
                        controller: _scrollController,
                        child: RefreshIndicator(
                          onRefresh: () async {
                            ref.invalidate(scrapPagedStreamProvider);
                          },
                          child: ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                            itemCount: rowsDynamic.length,
                            separatorBuilder:
                                (_, __) => const SizedBox(height: 12),
                            itemBuilder:
                                (_, i) => _ScrapCard(model: rowsDynamic[i]),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: userAv.maybeWhen(
        data: (user) {
          final canAdd = user != null &&
              (user.isSuperAdmin ||
                  user.appWorks.contains('storeadmin') ||
                  user.appWorks.contains('scrapadd'));
          final w = MediaQuery.of(context).size.width;
          final isTabletOrPhone = w <= 768;
          if (!canAdd || !isTabletOrPhone) return null;
          return FloatingActionButton.extended(
            onPressed: _openCreate,
            backgroundColor: _ink900,
            foregroundColor: _surface,
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Scrap',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          );
        },
        orElse: () => null,
      ),
    );
  }
}

/* =================== Scrap Card =================== */

class _ScrapCard extends StatelessWidget {
  const _ScrapCard({required this.model});

  final StoreScrapModel model;

  @override
  Widget build(BuildContext context) {
    final createdBy =
        model.createdByName.trim().isEmpty
            ? model.createdBy
            : model.createdByName;

    final remark = model.remark.trim();

    return StoreCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= Top row: Item + Qty =================
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item name + code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        letterSpacing: .1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        model.itemCode.isNotEmpty ? model.itemCode : '—',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // Qty badge (neutral presentation)
              StoreQtyPill(
                quantity: model.itemQuantity,
                label: 'Scrapped',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ================= Chips row: Room + Rack =================
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniChip(
                icon: Icons.meeting_room_outlined,
                label:
                    'Room: ${model.roomCode.isNotEmpty ? model.roomCode : model.roomId}',
              ),
              _MiniChip(
                icon: Icons.view_in_ar_outlined,
                label:
                    'Rack: ${model.rackCode.isNotEmpty ? model.rackCode : model.rackId}',
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ================= Footer: By + Date =================
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke.withValues(alpha: .9)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: _ink600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    createdBy,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: _ink600.withValues(alpha: .95),
                ),
                const SizedBox(width: 6),
                Text(
                  formatStoreDateTime(model.createdAt),
                  style: TextStyle(
                    color: _ink600.withValues(alpha: .95),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

            // ================= Remark =================
            if (remark.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 18, color: _ink600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remark,
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

/* ===== Small chip widget for Room/Rack ===== */

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: _ink600),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
