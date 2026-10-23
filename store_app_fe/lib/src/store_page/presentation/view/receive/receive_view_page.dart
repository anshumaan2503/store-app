
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_receive_controller.dart';
import '../../widgets/excel_downloader.dart';
import '../../widgets/store_ui_state_widgets.dart';
import 'qr_code_receive.dart/qr_scanner_receive_page.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../../controllers/store_cart_controller.dart';
import 'stock_refill_requests_list_view.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../items/qr_code/qr_code_print_item_page.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);

class ReceivePagedListPage extends ConsumerStatefulWidget {
  const ReceivePagedListPage({super.key});

  @override
  ConsumerState<ReceivePagedListPage> createState() =>
      _ReceivePagedListPageState();
}

class _ReceivePagedListPageState extends ConsumerState<ReceivePagedListPage> {
  int _selectedTab = 0; // 0: Stock Receipts, 1: Indents & GRN
  String _q = '';
  int _limit = 12;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ReceivePagedQuery get _query =>
      ReceivePagedQuery(page: 1, limit: _limit, search: _q, sort: '-createdAt');

  void _loadMore(ReceivePagedResult paged) {
    setState(() {
      _limit += 12;
    });
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

  DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;

    if (v is int) {
      if (v > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(v);
      }
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

  String _fmtDt(DateTime? dt) {
    if (dt == null) return '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  Uint8List _buildItemsExcelBytes(List<Map<String, dynamic>> items) {
    final excel = Excel.createExcel();

    const sheetName = 'Receive';

    if (excel.sheets.keys.contains('Sheet1')) {
      excel.rename('Sheet1', sheetName);
    }
    excel.setDefaultSheet(sheetName);

    final sheet = excel[sheetName];

    CellValue t(String v) => TextCellValue(v);
    CellValue n(int v) => IntCellValue(v);

    sheet.appendRow([
      t('Received By'),
      t('Received At'),
      t('Age'),
      t('Item Code'),
      t('Item Name'),
      t('Room Code'),
      t('Rack Code'),
      t('Receive Qty'),
      t('Remark'),
    ]);

    for (final it in items) {
      final dt = _toDate(it["createdAt"]);
      final createdAtText = dt == null ? '' : formatDdMmYyyyHmAmPm(dt);
      final ageText = dt == null ? '' : _formatItemAge(dt);

      sheet.appendRow([
        t((it["receivedBy"] ?? '').toString()),
        t(createdAtText),
        t(ageText),
        t((it["itemCode"] ?? '').toString()),
        t((it["itemName"] ?? '').toString()),
        t((it["roomName"] ?? '').toString()),
        t((it["rackCode"] ?? '').toString()),
        n(((it["qty"] as num?)?.toInt()) ?? 0),
        t((it["remark"] ?? '').toString()),
      ]);
    }

    final encoded = excel.encode();
    return Uint8List.fromList(encoded ?? <int>[]);
  }

  String _formatItemAge(DateTime receivedAt) {
    final now = DateTime.now();

    if (receivedAt.isAfter(now)) {
      return '00D - 00H - 00M - 00S';
    }

    DateTime cursor = receivedAt;

    int years = 0;
    while (true) {
      final next = _addYearsSafe(cursor, 1);
      if (next.isAfter(now)) break;
      cursor = next;
      years++;
    }

    int months = 0;
    while (true) {
      final next = _addMonthsSafe(cursor, 1);
      if (next.isAfter(now)) break;
      cursor = next;
      months++;
    }

    final remaining = now.difference(cursor);

    final days = remaining.inDays;
    final hours = remaining.inHours.remainder(24);
    final minutes = remaining.inMinutes.remainder(60);
    final seconds = remaining.inSeconds.remainder(60);

    final parts = <String>[];

    if (years > 0) parts.add('${years}Y');
    if (months > 0) parts.add('${months}M');

    parts.add('${days}D');
    parts.add('${hours.toString().padLeft(2, '0')}H');
    parts.add('${minutes.toString().padLeft(2, '0')}M');
    parts.add('${seconds.toString().padLeft(2, '0')}S');

    return parts.join(' - ');
  }

  DateTime _addYearsSafe(DateTime date, int yearsToAdd) {
    final newYear = date.year + yearsToAdd;
    final maxDay = _daysInMonth(newYear, date.month);
    final safeDay = date.day > maxDay ? maxDay : date.day;

    return DateTime(
      newYear,
      date.month,
      safeDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
    final totalMonths = (date.year * 12 + (date.month - 1)) + monthsToAdd;
    final newYear = totalMonths ~/ 12;
    final newMonth = (totalMonths % 12) + 1;

    final maxDay = _daysInMonth(newYear, newMonth);
    final safeDay = date.day > maxDay ? maxDay : date.day;

    return DateTime(
      newYear,
      newMonth,
      safeDay,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  int _daysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  Future<void> _exportItemsExcel({
    required List<Map<String, dynamic>> rowsList,
  }) async {
    if (rowsList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data loaded to export.')),
      );
      return;
    }

    final bytes = _buildItemsExcelBytes(rowsList);

    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    final filename = 'receive_all_$y$m$d.xlsx';

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

  String _receiveImageUrl(Map<String, dynamic> r) {
    final candidates = <dynamic>[
      r["imageUrl"],
      r["receiveImageUrl"],
      r["attachmentUrl"],
      r["entity"] is Map<String, dynamic>
          ? (r["entity"] as Map<String, dynamic>)["imageUrl"]
          : null,
    ];

    for (final value in candidates) {
      final url = (value ?? '').toString().trim();
      if (url.isNotEmpty) {
        // _debugReceiveRow(r, resolved: url);
        return url;
      }
    }

    // _debugReceiveRow(r, resolved: '');
    return '';
  }

  int _sumQty(Map<String, dynamic> r) {
    return (r['qty'] as num?)?.toInt() ?? 0;
  }

  Widget _buildQtyBadge(dynamic qty) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFA5D6A7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_circle_outline_rounded,
            size: 13,
            color: Color(0xFF2E7D32),
          ),
          const SizedBox(width: 4),
          Text(
            '+${qty ?? 0}',
            style: const TextStyle(
              color: Color(0xFF1B5E20),
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiveImagePreview(
    BuildContext context,
    String imageUrl, {
    String? title,
  }) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = size.width * 0.92;
    final dialogHeight = size.height * 0.88;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 20,
          ),
          child: Container(
            width: dialogWidth,
            height: dialogHeight,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title ?? 'Receive Image Preview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink900,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),

                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Container(
                      width: double.infinity,
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: SizedBox.expand(
                          child: Image.network(
                            Uri.encodeFull(imageUrl),
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, error, stackTrace) {
                              debugPrint('preview image error => $error');
                              debugPrint('preview image stack => $stackTrace');
                              return Container(
                                alignment: Alignment.center,
                                color: _surfaceAlt,
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      size: 42,
                                      color: _ink600,
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Unable to load image',
                                      style: TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiveCard(BuildContext context, Map<String, dynamic> r, {bool isFirst = false}) {
    final imageUrl = _receiveImageUrl(r);
    final createdAt = _toDate(r["createdAt"]);
    final itemName = (r["itemName"] ?? "").toString().trim();
    final itemCode = (r["itemCode"] ?? "").toString().trim();
    final itemId = (r["itemId"] ?? "").toString().trim();
    final rackId = (r["rackId"] ?? "").toString().trim();
    final rackCode = (r["rackCode"] ?? "").toString().trim();
    final roomName = (r["roomName"] ?? "").toString().trim();
    final receivedBy = (r["receivedBy"] ?? "-").toString().trim();
    final remark = (r["remark"] ?? "").toString().trim();
    final hasImage = imageUrl.isNotEmpty;
    final qty = _sumQty(r);

    final displayName = itemName.isNotEmpty
        ? itemName
        : (itemCode.isNotEmpty ? itemCode : 'Unknown Item');

    return Card(
      key: isFirst ? GuidedTourController.firstReceiveRecordKey : null,
      color: _surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: _stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          iconColor: _ink700,
          collapsedIconColor: _ink700,
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: SizedBox(
            width: 48,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                color: _accentMint.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _stroke),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? InkWell(
                      onTap: () => _showReceiveImagePreview(
                        context,
                        imageUrl,
                        title: 'Receive Image • $itemCode',
                      ),
                      child: Image.network(
                        Uri.encodeFull(imageUrl),
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          color: _ink900,
                          size: 22,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_outlined,
                      color: _ink900,
                      size: 22,
                    ),
            ),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Full Item Name + Quantity Badge + Print QR Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildQtyBadge(qty),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Print Item QR Stickers',
                    child: InkWell(
                      key: isFirst
                          ? GuidedTourController.firstReceivePrintQrKey
                          : null,
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QRCodePrintItemPage(
                              storeItemList: [
                                StoreItemsModel(
                                  id: itemId.isNotEmpty ? itemId : 'unknown',
                                  itemCode: itemCode,
                                  isScrap: false,
                                  itemName: displayName,
                                  rackId: rackId.isNotEmpty ? [rackId] : [],
                                  categoryLabel: '',
                                  unit: '',
                                  description: '',
                                  maxCapacity: 0,
                                  totalStockQuantity: qty,
                                  stockAvailableQuantity: qty,
                                  stockIssueQuantity: 0,
                                  stockissueCompleted: 0,
                                  stockscrapQuantity: 0,
                                  imageUrl: imageUrl,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4.5),
                        decoration: BoxDecoration(
                          color: _surfaceAlt.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _stroke),
                        ),
                        child: const Icon(
                          Icons.qr_code_2_rounded,
                          size: 17,
                          color: _ink900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 2: Item Code & Rack Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (itemCode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        itemCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                    ),
                  if (rackCode.isNotEmpty)
                    Container(
                      key: isFirst
                          ? GuidedTourController.firstReceiveRackLocationKey
                          : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.shelves,
                            size: 12,
                            color: _ink700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            rackCode,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: _ink700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (roomName.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        roomName,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _ink600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Row 3: Received by & Timestamp
              Row(
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 13,
                    color: _ink600,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      receivedBy,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink700,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (createdAt != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 5),
                      child: Text(
                        '•',
                        style: TextStyle(color: _ink600, fontSize: 11),
                      ),
                    ),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 12,
                      color: _ink600,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _fmtDt(createdAt),
                      style: const TextStyle(
                        color: _ink600,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),

              if (remark.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.notes_rounded,
                      size: 13,
                      color: _ink600,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        remark,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink700,
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceAlt.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Receipt Details',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow('Item Name', displayName),
                  if (itemCode.isNotEmpty) _buildDetailRow('Item Code', itemCode),
                  _buildDetailRow('Received Qty', '$qty units'),
                  if (rackCode.isNotEmpty) _buildDetailRow('Rack Location', rackCode),
                  if (roomName.isNotEmpty) _buildDetailRow('Room Name', roomName),
                  _buildDetailRow('Received By', receivedBy),
                  if (createdAt != null) _buildDetailRow('Received At', formatDdMmYyyyHmAmPm(createdAt)),
                  if (remark.isNotEmpty) _buildDetailRow('Remark', remark),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stroke),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: _ink900,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Receive Attachment',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (imageUrl.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed:
                              () => _showReceiveImagePreview(
                                context,
                                imageUrl,
                                title: 'Receive Image • $itemCode',
                              ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _ink900,
                            iconColor: _ink900,
                            side: const BorderSide(color: _stroke),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 18, color: _ink900),
                          label: const Text('Preview'),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Text(
                            'No Image',
                            style: TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (imageUrl.isNotEmpty)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap:
                          () => _showReceiveImagePreview(
                            context,
                            imageUrl,
                            title: 'Receive Image • $itemCode',
                          ),
                      child: Container(
                        width: double.infinity,
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _stroke),
                          color: Colors.white,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            Uri.encodeFull(imageUrl),
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, error, stack) {
                              return Container(
                                alignment: Alignment.center,
                                color: _surface,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.broken_image_outlined,
                                      color: _ink600,
                                      size: 34,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _stroke),
                      ),
                      child: const Column(
                        children: [
                          Icon(
                            Icons.image_not_supported_outlined,
                            color: _ink600,
                            size: 34,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No receive image uploaded',
                            style: TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: const TextStyle(
                color: _ink600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink900,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final av = ref.watch(receivePagedStreamProvider(_query));
    final avAll = ref.watch(findAllReceiveDataStreamProvider);
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Center(child: Text('Room load error: $e')),
      data: (user) {
        return avAll.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (rec) {
            final receive = rec;

            return av.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => StoreErrorView(
                    error: e,
                    onRetry:
                        () => ref.invalidate(
                          receivePagedStreamProvider(_query),
                        ),
                  ),
              data: (paged) {
                final rows = paged.rows;
                final canLoadMore = rows.length < paged.total;

                final pendingRefillCount =
                    ref.watch(pendingRefillRequestsCountProvider).value ?? 0;

                return Scaffold(
                  floatingActionButton: () {
                    if (_selectedTab != 0) return null;

                    final hasAccess = user?.isSuperAdmin == true ||
                        (user?.appWorks.contains("storreceiveadd") ?? false) ||
                        (user?.appWorks.any((w) => w.startsWith("storreceive")) ?? false) ||
                        (user?.appWorks.isEmpty ?? true);

                    final w = MediaQuery.of(context).size.width;
                    final isTabletOrPhone = w <= 768;

                    if (!hasAccess || !isTabletOrPhone) return null;

                    return FloatingActionButton.extended(
                      key: GuidedTourController.receiveStockActionKey,
                      onPressed: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const QRCodeScannerRackPage(),
                          ),
                        );
                        if (res == true || mounted) {
                          ref.invalidate(receivePagedStreamProvider(_query));
                          ref.invalidate(findAllReceiveDataStreamProvider);
                        }
                      },
                      elevation: 6,
                      backgroundColor: _ink900,
                      foregroundColor: _surface,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text(
                        'QR Receive',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: _stroke),
                      ),
                    );
                  }(),
                  body: Container(
                    color: Colors.white,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Column(
                              children: [
                                // Top Tab Switcher: Receipts vs Store Consolidation vs Refill Requests
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: _surfaceAlt.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Row(
                                    children: [
                                      // Tab 0: Stock Receipts
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () =>
                                              setState(() => _selectedTab = 0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _selectedTab == 0
                                                  ? _surface
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: _selectedTab == 0
                                                  ? const [
                                                      BoxShadow(
                                                        color:
                                                            Color(0x0A000000),
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.inbox_rounded,
                                                  size: 16,
                                                  color: _selectedTab == 0
                                                      ? _ink900
                                                      : _ink600,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Stock Receipts',
                                                  style: TextStyle(
                                                    color: _selectedTab == 0
                                                        ? _ink900
                                                        : _ink600,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      // Tab 1: Indent Requests & GRN
                                      Expanded(
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          onTap: () {
                                            setState(() => _selectedTab = 1);
                                            ref.invalidate(refillRequestsListProvider);
                                            ref.invalidate(pendingRefillRequestsCountProvider);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: _selectedTab == 1
                                                  ? _surface
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              boxShadow: _selectedTab == 1
                                                  ? const [
                                                      BoxShadow(
                                                        color:
                                                            Color(0x0A000000),
                                                        blurRadius: 4,
                                                        offset: Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.assignment_outlined,
                                                  size: 16,
                                                  color: _selectedTab == 1
                                                      ? _ink900
                                                      : _ink600,
                                                ),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Indents & GRN',
                                                  style: TextStyle(
                                                    color: _selectedTab == 1
                                                        ? _ink900
                                                        : _ink600,
                                                    fontWeight:
                                                        FontWeight.w800,
                                                    fontSize: 12.5,
                                                  ),
                                                ),
                                                if (pendingRefillCount > 0) ...[
                                                  const SizedBox(width: 5),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets
                                                            .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xFFE65100),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    child: Text(
                                                      '$pendingRefillCount',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w900,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_selectedTab == 1)
                                  Expanded(
                                    child: StockRefillRequestsListView(
                                      initialStatusFilter: ref.watch(storeCartConfigProvider).indentApprovalRequired
                                          ? 'APPROVED'
                                          : 'ALL',
                                    ),
                                  )
                                else ...[
                                Card(
                                  color: _surface,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      14,
                                      10,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            onChanged: (v) {
                                              setState(() {
                                                _q = v.trim();
                                                _limit = 12;
                                              });
                                            },
                                            decoration: const InputDecoration(
                                              hintText: 'Search receive...',
                                              prefixIcon: Icon(
                                                Icons.search_rounded,
                                              ),
                                              border: InputBorder.none,
                                            ),
                                            style: const TextStyle(
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        IconButton(
                                          tooltip: "Refresh",
                                          onPressed: () {
                                            ref.invalidate(receivePagedStreamProvider(_query));
                                            ref.invalidate(findAllReceiveDataStreamProvider);
                                          },
                                          icon: const Icon(
                                            Icons.refresh_rounded,
                                          ),
                                          color: _ink900,
                                        ),
                                        IconButton(
                                          tooltip: "Download",
                                          onPressed:
                                              () => _showExportSheet(receive),
                                          icon: const Icon(
                                            Icons.download_rounded,
                                          ),
                                          color: _ink900,
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          style: FilledButton.styleFrom(
                                            backgroundColor: _ink900,
                                            foregroundColor: _surface,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 10,
                                            ),
                                          ),
                                          onPressed: () async {
                                            final res =
                                                await Navigator.push<bool>(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const QRCodeScannerRackPage(),
                                              ),
                                            );
                                            if (res == true || mounted) {
                                              ref.invalidate(
                                                  receivePagedStreamProvider(
                                                      _query));
                                              ref.invalidate(
                                                  findAllReceiveDataStreamProvider);
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.qr_code_scanner,
                                            size: 16,
                                          ),
                                          key: GuidedTourController.receiveStockActionKey,
                                          label: const Text(
                                            'Receive Stock',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      ref.invalidate(receivePagedStreamProvider(_query));
                                      ref.invalidate(findAllReceiveDataStreamProvider);
                                    },
                                    child: rows.isEmpty
                                        ? ListView(
                                            physics: const AlwaysScrollableScrollPhysics(),
                                            children: [
                                              SizedBox(
                                                height: 350,
                                                child: StoreEmptyStateWidget(
                                                  message: 'No receive records found',
                                                  searchQuery: _q,
                                                  onClearSearch: () => setState(() {
                                                    _q = '';
                                                    _limit = 12;
                                                  }),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Column(
                                            children: [
                                              Expanded(
                                                child: Scrollbar(
                                                  controller: _scrollController,
                                                  thumbVisibility: true,
                                                  trackVisibility: true,
                                                  interactive: true,
                                                  child: ListView.separated(
                                                    controller: _scrollController,
                                                  physics: const AlwaysScrollableScrollPhysics(),
                                                  itemCount: rows.length,
                                                  separatorBuilder:
                                                      (_, __) => const SizedBox(
                                                        height: 10,
                                                      ),
                                                  itemBuilder: (_, i) {
                                                    final r = rows[i];
                                                    return _buildReceiveCard(
                                                      context,
                                                      r,
                                                      isFirst: i == 0,
                                                    );
                                                  },
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 10),
                                              if (canLoadMore)
                                                _Card(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Text(
                                                        'Showing ${rows.length} of ${paged.total}',
                                                        style: const TextStyle(
                                                          color: _ink700,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      FilledButton.icon(
                                                                                                   onPressed:
                                                            () => _loadMore(
                                                              paged,
                                                            ),
                                                        icon: const Icon(
                                                          Icons
                                                              .expand_more_rounded,
                                                        ),
                                                        label: const Text(
                                                          'Load more',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                              else
                                                _Card(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  child: Text(
                                                    'Showing ${rows.length} of ${paged.total}',
                                                    style: const TextStyle(
                                                      color: _ink700,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
            );
          },
        );
      },
    );
  }
}

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
