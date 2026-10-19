import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/auth_controller.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../../domains/models/store_items_model.dart';
import 'issue_scan_create_page.dart';
import '../../../controllers/store_cart_controller.dart';

// Palette
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;
const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

// Remaining calculations
// int _remainApprove(IssueLine l) => math.max(
//   0,
//   _i(l.requestedQty) - _i(l.approvedQty) - _i(l.approvedRejectQty),
// );

int _remainIssue(IssueLine l) =>
    math.max(0, _i(l.approvedQty) - _i(l.issuedQty) - _i(l.issuedRejectQty));

// int _remainReturn(IssueLine l) =>
//     math.max(0, _i(l.issuedQty) - (_i(l.returnQty) + _i(l.scrapQty)));

class IssueByItemActionsPage extends ConsumerStatefulWidget {
  const IssueByItemActionsPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<IssueByItemActionsPage> createState() =>
      _IssueByItemActionsPageState();
}

class _IssueByItemActionsPageState
    extends ConsumerState<IssueByItemActionsPage> {
  String? _selectedIssueId;
  List<IssueModel> _issues = [];
  String _issueSearch = '';

  IssueModel? _findIssueById(String? id) {
    if (id == null) return null;
    for (final x in _issues) {
      if (x.id == id) return x;
    }
    return null;
  }

  List<IssueModel> _filteredIssues() {
    final q = _issueSearch.trim().toLowerCase();

    return _issues.where((issue) {
      // ✅ filter lines that can still be issued
      final filteredLines =
          issue.lines.where((l) => _remainIssue(l) > 0).toList();
      final canIssueForThisItem = filteredLines.isNotEmpty;

      if (!canIssueForThisItem) return false;

      // ✅ search filter
      if (q.isEmpty) return true;

      final issMatch = issue.issNo.toLowerCase().contains(q);
      final lineMatch = filteredLines.any(
        (l) => l.itemName.toLowerCase().contains(q),
      );

      return issMatch || lineMatch;
    }).toList();
  }

  void _openIssueSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _filteredIssues();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    onChanged: (v) => setModalState(() => _issueSearch = v),
                    decoration: const InputDecoration(
                      hintText: "Search by Issue No or Item Name…",
                      prefixIcon: Icon(Icons.search, color: _ink900),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _stroke),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _ink900),
                      ),
                    ),
                    style: const TextStyle(color: _ink900),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child:
                        filtered.isEmpty
                            ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                "No issues found for this item name.",
                                style: TextStyle(color: _ink700),
                              ),
                            )
                            : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder:
                                  (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final issue = filtered[index];
                                final q = _issueSearch.trim().toLowerCase();
                                final issMatch = issue.issNo
                                    .toLowerCase()
                                    .contains(q);

                                final lines =
                                    q.isEmpty
                                        ? issue.lines.take(3).toList()
                                        : (issMatch
                                            ? issue.lines.take(3).toList()
                                            : issue.lines
                                                .where(
                                                  (l) => l.itemName
                                                      .toLowerCase()
                                                      .contains(q),
                                                )
                                                .take(3)
                                                .toList());

                                return ListTile(
                                  onTap: () {
                                    setState(() {
                                      _selectedIssueId = issue.id;
                                    });
                                    Navigator.pop(context);
                                  },
                                  title: Text(
                                    issue.issNo,
                                    style: const TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...lines.map(
                                          (l) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    l.itemName,
                                                    style: const TextStyle(
                                                      color: _ink900,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Req:${l.requestedQty}  App:${l.approvedQty}  Iss:${l.issuedQty}",
                                                  style: const TextStyle(
                                                    color: _ink700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (issue.lines.length > 3)
                                          Text(
                                            "+${issue.lines.length - 3} more items",
                                            style: const TextStyle(
                                              color: _ink600,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  trailing: const Icon(
                                    Icons.chevron_right,
                                    color: _ink700,
                                  ),
                                );
                              },
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

  @override
  Widget build(BuildContext context) {
    final itemAv = ref.watch(itemFindOneStreamProvider(widget.itemId));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text("User not found")));
        }

        final hasAccess = user.appWorks.contains("storissueadd");
        final canViewAll = user.isSuperAdmin ||
            user.appWorks.isEmpty ||
            user.appWorks.contains("storeadmin") ||
            user.appWorks.contains("storissueview") ||
            user.appWorks.contains("storissueapprove") ||
            user.appWorks.contains("storissuefromstock") ||
            user.appWorks.contains("storissuereturn");

        final queryItem = IssueItemQuery(
          search: "",
          createdBy: canViewAll ? null : user.uid,
          itemId: widget.itemId,
        );
        final issuesAv = ref.watch(
          issueByIdItemAllDataStreamProvider(queryItem),
        );
        // Better tablet detection
        final shortest = MediaQuery.of(context).size.shortestSide;
        final isTablet = shortest >= 600;

        return Scaffold(
          floatingActionButton:
              (!hasAccess || !isTablet)
                  ? FloatingActionButton.extended(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => ItemPage(initialItemId: widget.itemId),
                        ),
                      );
                      if (result == true && context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    elevation: 6,
                    backgroundColor: _ink900,
                    foregroundColor: _surface,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Create Issue',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: _stroke),
                    ),
                  )
                  : null,
          backgroundColor: _surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _ink900),
            title: const Text(
              'Issue Actions by Item',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        issuesAv.when(
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error: (e, _) => Center(child: Text('Error: $e')),
                          data: (issues) {
                            _issues = issues;

                            return itemAv.when(
                              loading:
                                  () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              error: (e, _) => Center(child: Text('Error: $e')),
                              data: (item) {
                                if (item == null) {
                                  return const Center(
                                    child: Text("Item not found"),
                                  );
                                }

                                final selectedIssue = _findIssueById(
                                  _selectedIssueId,
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Item Name: ${item.itemName}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Item Code: ${item.itemCode}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Category: ${item.categoryLabel}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Stock Available: ${item.stockAvailableQuantity}',
                                      style: const TextStyle(
                                        color: _ink700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    InkWell(
                                      onTap: _openIssueSearchSheet,
                                      borderRadius: BorderRadius.circular(12),
                                      child: InputDecorator(
                                        decoration: const InputDecoration(
                                          labelText: "Issue",
                                          filled: true,
                                          fillColor: Colors.white,
                                          prefixIcon: Icon(
                                            Icons.search,
                                            color: _ink900,
                                          ),
                                          border: OutlineInputBorder(),
                                          enabledBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _stroke,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: _ink900,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          selectedIssue == null
                                              ? "Search by item name…"
                                              : selectedIssue.issNo,
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    if (selectedIssue != null) ...[
                                      const SizedBox(height: 16),
                                      _IssueCard(
                                        issue: selectedIssue,
                                        item: item,
                                        user: user,
                                        onChanged: () {
                                          // ✅ Invalidate family providers correctly
                                          ref.invalidate(
                                            issueByIdItemAllDataStreamProvider(
                                              queryItem,
                                            ),
                                          );
                                          ref.invalidate(
                                            itemFindOneStreamProvider(
                                              widget.itemId,
                                            ),
                                          );
                                        },
                                      ),
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
        );
      },
    );
  }
}

class _IssueCard extends ConsumerStatefulWidget {
  final AuthModel user;
  final IssueModel issue;
  final StoreItemsModel item;
  final VoidCallback onChanged;

  const _IssueCard({
    required this.issue,
    required this.item,
    required this.user,
    required this.onChanged,
  });

  @override
  ConsumerState<_IssueCard> createState() => __IssueCardState();
}

class __IssueCardState extends ConsumerState<_IssueCard> {
  @override
  Widget build(BuildContext context) {
    // Filter lines for this item
    final filteredLines =
        widget.issue.lines
            .where((line) => line.itemId == widget.item.id)
            .toList();
    final createdByAv = ref.watch(userByIdProvider(widget.issue.createdBy));
    final canIssueForThisItem = filteredLines.any((l) => _remainIssue(l) > 0);

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: _accentMint.withValues(alpha: .65),
      foregroundColor: _ink900,
      disabledBackgroundColor: _accentMint.withValues(alpha: .18),
      disabledForegroundColor: _ink700.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    return createdByAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        if (user == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final a =
            (widget.user.divisionIds)
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final b =
            (user.divisionIds)
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final hasCommon = a.intersection(b).isNotEmpty;

        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accentMint, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 40,
                      color: _ink900,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.issue.issNo,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.issue.reason.isEmpty
                                ? '—'
                                : widget.issue.reason,
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (filteredLines.isNotEmpty) ...[
                  _buildTableHeader(),
                  for (final line in filteredLines) ...[
                    _buildLineData(line),
                    const SizedBox(height: 8),
                  ],
                ],

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    (widget.user.appWorks.contains("storissuefromstock") &&
                            hasCommon)
                        ? FilledButton.icon(
                          onPressed:
                              canIssueForThisItem
                                  ? () async {
                                    await showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder:
                                          (_) => IssueSheet(
                                            issue: widget.issue,
                                            onChanged: widget.onChanged,
                                          ),
                                    );
                                  }
                                  : null,
                          icon: const Icon(
                            Icons.local_shipping_rounded,
                            size: 18,
                          ),
                          label: const Text('Issue'),
                          style: filledStyle,
                        )
                        : const SizedBox.shrink(),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return const Row(
      children: [
        _TableHeaderCell('Requested'),
        _TableHeaderCell('Approved'),
        _TableHeaderCell('Issued'),
        _TableHeaderCell('Returned'),
        _TableHeaderCell('Scrap'),
        _TableHeaderCell('Reject'),
        _TableHeaderCell('Issue Rate'),
      ],
    );
  }

  Widget _buildLineData(IssueLine line) {
    return Row(
      children: [
        _TableDataCell(line.requestedQty.toString()),
        _TableDataCell(line.approvedQty.toString()),
        _TableDataCell(line.issuedQty.toString()),
        _TableDataCell(line.returnQty.toString()),
        _TableDataCell(line.scrapQty.toString()),
        _TableDataCell(
          (_i(line.issuedRejectQty) + _i(line.approvedRejectQty)).toString(),
        ),
        _TableDataCell(
          line.unitPrice > 0
              ? '₹${line.unitPrice.toStringAsFixed(line.unitPrice % 1 == 0 ? 0 : 2)}'
              : '-',
        ),
      ],
    );
  }
}

class _TableHeaderCell extends StatelessWidget {
  final String text;
  const _TableHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _surfaceAlt,
          border: Border.all(color: _stroke),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: _ink900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  final String text;
  const _TableDataCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: _stroke)),
        child: Text(text, style: const TextStyle(color: _ink700)),
      ),
    );
  }
}

/* ---------------- Issue Sheet (line-by-line issue + bulk) ---------------- */

class IssueSheet extends ConsumerStatefulWidget {
  const IssueSheet({super.key, required this.issue, required this.onChanged});

  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends ConsumerState<IssueSheet> {
  late List<IssueLine> _lines;

  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _rejectQtyCtrls = {};
  final Set<String> _busyLineIds = {};
  bool _bulkBusy = false;

  // ✅ rack per itemId
  final Map<String, Map<String, dynamic>> _selectedRackByItem = {};

  @override
  void initState() {
    super.initState();
    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      final ri = _remainIssue(l);
      _qtyCtrls[l.itemId] = TextEditingController(text: ri > 0 ? '$ri' : '0');
      _rejectQtyCtrls[l.itemId] = TextEditingController(text: '0');
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadRacks();
    });
  }

  Future<void> _preloadRacks() async {
    for (final l in _lines) {
      try {
        final raw = await ref
            .read(storeRackControllerProvider)
            .getRacksByItem(l.itemId);
        final list =
            raw
                .where((e) => e != null)
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
        if (list.isNotEmpty && mounted) {
          setState(() {
            _selectedRackByItem[l.itemId] = list.first;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    for (final c in _rejectQtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _asInt(String s, int fallback) => int.tryParse(s.trim()) ?? fallback;

  Future<String> _getUid() async {
    final uid =
        await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';
    return uid.trim();
  }

  int _availOf(Map<String, dynamic> r) {
    final v = r["stockAvailableQuantity"];
    return int.tryParse((v ?? 0).toString()) ?? 0;
  }

  Map<String, dynamic>? _rackForItem(String itemId) =>
      _selectedRackByItem[itemId];

  Future<bool> _ensureRackSelected(IssueLine line) async {
    final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
    final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);
    final total = qty + rejectQty;

    if (total <= 0) {
      showSnackBar('Enter any one');
      return false;
    }

    // fetch racks
    final raw = await ref
        .read(storeRackControllerProvider)
        .getRacksByItem(line.itemId);

    final list =
        raw
            .where((e) => e != null)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

    if (list.isEmpty) {
      showSnackBar('Rack data is not available');
      return false;
    }

    // one rack -> auto select
    if (list.length == 1) {
      final r = list.first;
      if (total > _availOf(r)) {
        showSnackBar('Don`t take more than available qty.');
        return false;
      }
      setState(() => _selectedRackByItem[line.itemId] = r);
      return true;
    }

    // multiple -> keep existing if valid
    final existing = _selectedRackByItem[line.itemId];
    if (existing != null) {
      final id = existing["_id"]?.toString();
      final hit = list.where((x) => x["_id"]?.toString() == id).toList();
      if (hit.isNotEmpty) {
        final live = hit.first;
        if (total <= _availOf(live)) {
          setState(() => _selectedRackByItem[line.itemId] = live);
          return true;
        }
      }
    }

    // otherwise open dialog
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => RackByItemSelectionDialog(
            itemId: line.itemId,
            initialRackId: existing?["_id"]?.toString(),
          ),
    );

    if (selected == null) return false;

    if (total > _availOf(selected)) {
      showSnackBar('Don`t take more than available qty.');
      return false;
    }

    setState(() => _selectedRackByItem[line.itemId] = selected);
    return true;
  }

  Future<void> _issueOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
    final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);
    final remaining = _remainIssue(line);

    final total = qty + rejectQty;

    if (total <= 0) {
      showSnackBar('Enter any one');
      return;
    }
    if (qty < 0 || rejectQty < 0) {
      showSnackBar('Enter qty > 0');
      return;
    }
    // ✅ total must not exceed remaining
    if (total > remaining) {
      showSnackBar('Qty cannot exceed remaining ($remaining)');
      return;
    }

    final rack = _rackForItem(line.itemId);
    final rackId = (rack?["_id"] ?? "").toString();
    if (rackId.isEmpty) {
      showSnackBar('Please select rack first');
      return;
    }

    setState(() => _busyLineIds.add(line.itemId));
    try {
      final res = await ref
          .read(issueControllerProvider)
          .issueLine(
            issueId: widget.issue.id,
            itemId: line.itemId,
            issuedBy: uid,
            rackId: rackId,
            qty: qty,
            issuedRejectQty: rejectQty,
          );

      final data =
          (res?['data'] is Map)
              ? Map<String, dynamic>.from(res?['data'] as Map)
              : <String, dynamic>{};

      final updatedLine =
          (data['updatedLine'] is Map)
              ? Map<String, dynamic>.from(data['updatedLine'] as Map)
              : <String, dynamic>{};

      final updatedItemId = (updatedLine['itemId'] ?? '').toString();
      final nextIssued =
          int.tryParse((updatedLine['issuedQty'] ?? '').toString()) ??
          _i(line.issuedQty);

      if (updatedItemId.isNotEmpty) {
        setState(() {
          _lines =
              _lines.map((x) {
                if (x.itemId == updatedItemId) {
                  final nx = x.copyWith(issuedQty: nextIssued);
                  final ri = _remainIssue(nx);
                  _qtyCtrls[x.itemId]?.text = ri > 0 ? '$ri' : '0';
                  _rejectQtyCtrls[x.itemId]?.text = '0';
                  return nx;
                }
                return x;
              }).toList();
        });
      }

      widget.onChanged();
      ref.read(globalInCartProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Issue failed: $e');
    } finally {
      if (mounted) setState(() => _busyLineIds.remove(line.itemId));
    }
  }

  Future<void> _issueAllRemaining() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final payload =
        _lines
            .where((l) => _remainIssue(l) > 0)
            .map((l) => {'itemId': l.itemId, 'qty': _remainIssue(l)})
            .toList();

    if (payload.isEmpty) {
      showSnackBar('Nothing remaining to issue');
      return;
    }

    setState(() => _bulkBusy = true);
    try {
      await ref
          .read(issueControllerProvider)
          .issueBulk(issueId: widget.issue.id, issuedBy: uid, lines: payload);

      widget.onChanged();
      ref.read(globalInCartProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Bulk issue failed: $e');
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.78;

    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      child: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _stroke),
              boxShadow: _shadow,
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Issue Items: ${widget.issue.issNo}',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = _lines[i];
                      final busy = _busyLineIds.contains(l.itemId);
                      final remaining = _remainIssue(l);
                      final rack = _rackForItem(l.itemId);
                      final rackLabel =
                          rack == null
                              ? "No rack selected"
                              : "${rack["code"]} • ${rack["roomName"]}";

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceAlt.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.itemName,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Approved: ${_i(l.approvedQty)}   Issued: ${_i(l.issuedQty)}   Remaining: $remaining    Rejected: ${_i(l.issuedRejectQty)}',
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.history_toggle_off_rounded, size: 13, color: Color(0xFF15803D)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Store Rule: Old stock will be issued first automatically',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF166534),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final existing = _selectedRackByItem[l.itemId];
                                final selected = await showDialog<Map<String, dynamic>>(
                                  context: context,
                                  builder:
                                      (_) => RackByItemSelectionDialog(
                                        itemId: l.itemId,
                                        initialRackId: existing?["_id"]?.toString(),
                                      ),
                                );
                                if (selected != null && mounted) {
                                  setState(() => _selectedRackByItem[l.itemId] = selected);
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: rack == null ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: rack == null ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.grid_view_rounded,
                                      size: 16,
                                      color: rack == null ? const Color(0xFFB45309) : const Color(0xFF047857),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        rack == null
                                            ? 'No rack selected (Tap to choose)'
                                            : 'Rack: $rackLabel',
                                        style: TextStyle(
                                          color: rack == null ? const Color(0xFF92400E) : const Color(0xFF065F46),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      color: rack == null ? const Color(0xFFB45309) : const Color(0xFF047857),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text(
                                  "Qty - ",
                                  style: TextStyle(color: _ink900),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: _qtyCtrls[l.itemId],
                                    keyboardType: TextInputType.number,
                                    cursorColor: const Color(0xFF111827),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      prefixIcon: const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                                      hintText: 'Qty',
                                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  "Reject Qty - ",
                                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    controller: _rejectQtyCtrls[l.itemId],
                                    keyboardType: TextInputType.number,
                                    cursorColor: const Color(0xFF111827),
                                    style: const TextStyle(
                                      color: Color(0xFF111827),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                      prefixIcon: const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFDC2626)),
                                      hintText: 'Reject Qty',
                                      hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFD1D5DB), width: 1.5),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: SizedBox(
                                width: 140,
                                height: 46,
                                child: FilledButton(
                                  onPressed:
                                      (busy || remaining <= 0)
                                          ? null
                                          : () async {
                                            final ok =
                                                await _ensureRackSelected(l);
                                            if (!ok) return;
                                            await _issueOne(l);
                                          },
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _accentMint.withValues(
                                      alpha: .75,
                                    ),
                                    foregroundColor: _ink900,
                                    disabledBackgroundColor: _accentMint
                                        .withValues(alpha: .18),
                                    disabledForegroundColor: _ink700
                                        .withValues(alpha: .55),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child:
                                      busy
                                          ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text(
                                            'Issue',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // optional bulk issue button
                // SizedBox(
                //   width: double.infinity,
                //   height: 46,
                //   child: FilledButton(
                //     onPressed: _bulkBusy ? null : _issueAllRemaining,
                //     child:
                //         _bulkBusy
                //             ? const SizedBox(
                //               width: 18,
                //               height: 18,
                //               child: CircularProgressIndicator(strokeWidth: 2),
                //             )
                //             : const Text(
                //               'Issue All Remaining',
                //               style: TextStyle(fontWeight: FontWeight.w900),
                //             ),
                //   ),
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Rack selection dialogs ---------------- */

class RackSelectionDialog extends ConsumerStatefulWidget {
  const RackSelectionDialog({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<RackSelectionDialog> createState() =>
      _RackSelectionDialogState();
}

class _RackSelectionDialogState extends ConsumerState<RackSelectionDialog> {
  Map<String, dynamic>? _rack;

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(
      findRackByItemIdDataStreamProvider(widget.itemId),
    );

    return AlertDialog(
      title: const Text('Select Scrap Rack'),
      content: SizedBox(
        child: racksAv.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Rack load error: $e'),
          data: (racks) {
            final list = (racks ?? <Map<String, dynamic>>[]);

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Data is not available'),
              );
            }

            // safe value instance
            Map<String, dynamic>? safeValue;
            if (_rack != null) {
              final id = _rack!["_id"]?.toString();
              if (id != null) {
                final hit =
                    list.where((x) => x["_id"]?.toString() == id).toList();
                safeValue = hit.isNotEmpty ? hit.first : null;
              }
            }
            safeValue ??= list.first;

            _rack = safeValue;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DropdownField<Map<String, dynamic>>(
                  label: 'Rack *',
                  hint: 'Select rack',
                  icon: Icons.category_rounded,
                  value: safeValue,
                  items: list,
                  textOf: (x) => (x["code"] ?? "").toString(),
                  onChanged: (rack) => setState(() => _rack = rack),
                ),
                const SizedBox(height: 12),
                _RackDetailsCard(rack: _rack),
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
          onPressed: () => Navigator.pop(context, _rack),
          child: const Text('Select'),
        ),
      ],
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
  bool _didTryPreselect = false;

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(rackDataByItemDataStreamProvider(widget.itemId));

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

            final mustSelect = list.length > 1;

            // preselect only once
            if (!_didTryPreselect) {
              _didTryPreselect = true;

              if (widget.initialRackId != null) {
                final hit =
                    list
                        .where(
                          (x) => x["_id"]?.toString() == widget.initialRackId,
                        )
                        .toList();
                if (hit.isNotEmpty) _rack = hit.first;
              }

              if (!mustSelect) {
                _rack ??= list.first;
              }

              if (mustSelect &&
                  (_rack != null) &&
                  !list.any(
                    (x) => x["_id"]?.toString() == _rack!["_id"]?.toString(),
                  )) {
                _rack = null;
              }
            }

            // if list changed, validate selection
            if (_rack != null &&
                !list.any(
                  (x) => x["_id"]?.toString() == _rack!["_id"]?.toString(),
                )) {
              _rack = null;
            }

            // safe value instance (Map identity fix)
            Map<String, dynamic>? safeValue;
            if (_rack != null) {
              final id = _rack!["_id"]?.toString();
              if (id != null) {
                final hit =
                    list.where((x) => x["_id"]?.toString() == id).toList();
                safeValue = hit.isNotEmpty ? hit.first : null;
              }
            }

            final canSubmit = !mustSelect || _rack != null;

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _DropdownField<Map<String, dynamic>>(
                  label: 'Rack *',
                  hint: 'Select rack',
                  icon: Icons.category_rounded,
                  value: safeValue,
                  items: list,
                  textOf: (x) => '${x["code"]} • ${x["roomName"]}',
                  onChanged: (rack) => setState(() => _rack = rack),
                ),
                const SizedBox(height: 10),
                if (!canSubmit)
                  const Text(
                    'Please select a rack to continue.',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                if (_rack != null) _RackDetailsCard(rack: _rack),
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
        // ✅ correct typing and disable when required
        Consumer(
          builder: (context, ref, _) {
            final racksAv2 = ref.watch(
              rackDataByItemDataStreamProvider(widget.itemId),
            );
            final list = racksAv2.asData?.value ?? <Map<String, dynamic>>[];
            final mustSelect = list.length > 1;
            final canSubmit = !mustSelect || _rack != null;

            return TextButton(
              onPressed: canSubmit ? () => Navigator.pop(context, _rack) : null,
              child: const Text('Select'),
            );
          },
        ),
      ],
    );
  }
}

/* ---------------- Shared dropdown + rack card ---------------- */

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
    if (rack == null) {
      return const Text('No rack selected');
    }

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
            (rack!["code"] ?? "").toString(),
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _RackDetailRow(
            label: 'Code',
            value: (rack!["code"] ?? '').toString(),
          ),
          _RackDetailRow(
            label: 'Room',
            value: (rack!["roomName"] ?? '').toString(),
          ),
          _RackDetailRow(
            label: 'Total Stock',
            value: (rack!["totalStockQuantity"] ?? 0).toString(),
          ),
          _RackDetailRow(
            label: 'Aval. Stock',
            value: (rack!["stockAvailableQuantity"] ?? 0).toString(),
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
            width: 80,
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
