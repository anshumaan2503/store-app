import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_rack_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import 'issue_scan_create_page.dart';

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

// int _remainApprove(IssueLine l) => math.max(
//   0,
//   _i(l.requestedQty) - _i(l.approvedQty) - _i(l.approvedRejectQty),
// );

// int _remainIssue(IssueLine l) =>
//     math.max(0, _i(l.approvedQty) - _i(l.issuedQty) - _i(l.issuedRejectQty));

int _remainReturn(IssueLine l) =>
    math.max(0, _i(l.issuedQty) - (_i(l.returnQty) + _i(l.scrapQty)));

String _idOf(Map<String, dynamic> m) =>
    (m["_id"] ?? m["id"] ?? "").toString().trim();

class IssueByItemReturnActionsPage extends ConsumerStatefulWidget {
  const IssueByItemReturnActionsPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<IssueByItemReturnActionsPage> createState() =>
      _IssueByItemReturnActionsPageState();
}

class _IssueByItemReturnActionsPageState
    extends ConsumerState<IssueByItemReturnActionsPage> {
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
    if (q.isEmpty) return _issues;

    return _issues.where((issue) {
      final issMatch = issue.issNo.toLowerCase().contains(q);
      final lineMatch = issue.lines.any(
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
    final userAv = ref.watch(userFindOneDataStreamProvider);

    return userAv.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error: (e, _) => Text('User load error: $e'),
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text("User not found")));
        }

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

        final hasAccess = user.appWorks.contains("storissueadd");
        final shortest = MediaQuery.of(context).size.shortestSide;
        final isTablet = shortest >= 600;

        return Scaffold(
          floatingActionButton:
              (!hasAccess || !isTablet)
                  ? null
                  : FloatingActionButton.extended(
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
                  ),
          backgroundColor: _surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _ink900),
            title: const Text(
              'Issue Return Actions by Item',
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

class _IssueCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final filteredLines =
        issue.lines.where((l) => l.itemId == item.id).toList();

    final canReturnForThisItem = filteredLines.any((l) => _remainReturn(l) > 0);

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: _accentMint.withValues(alpha: .65),
      foregroundColor: _ink900,
      disabledBackgroundColor: _accentMint.withValues(alpha: .18),
      disabledForegroundColor: _ink700.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

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
                        issue.issNo,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        issue.reason.isEmpty ? '—' : issue.reason,
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
                (user.appWorks.contains("storissuereturn"))
                    ? FilledButton.icon(
                      onPressed:
                          canReturnForThisItem
                              ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => _ReturnSheet(
                                        issue: issue,
                                        onChanged: onChanged,
                                      ),
                                );
                              }
                              : null,
                      icon: const Icon(
                        Icons.assignment_return_rounded,
                        size: 18,
                      ),
                      label: const Text('Return'),
                      style: filledStyle,
                    )
                    : const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return const Row(
      children: [
        _TableHeaderCell('Requested Qty'),
        _TableHeaderCell('Approved Qty'),
        _TableHeaderCell('Issued Qty'),
        _TableHeaderCell('Returned Qty'),
        _TableHeaderCell('Scrap Qty'),
        _TableHeaderCell('Reject Qty'),
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
          (_i(line.issuedRejectQty) - _i(line.approvedRejectQty)).toString(),
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

/* ---------------- Return Sheet ---------------- */

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({required this.issue, required this.onChanged});

  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ReturnSheet> createState() => _ReturnSheetState();
}

class _ReturnSheetState extends ConsumerState<_ReturnSheet> {
  late List<IssueLine> _lines;

  final Map<String, TextEditingController> _goodCtrls = {};
  final Map<String, TextEditingController> _scrapCtrls = {};
  final Set<String> _busy = {};
  final bool _bulkBusy = false;

  // ✅ per-item racks
  final Map<String, Map<String, dynamic>> _goodRackByItem = {};
  final Map<String, StoreRack> _scrapRackByItem = {};

  @override
  void initState() {
    super.initState();
    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      final rr = _remainReturn(l);
      _goodCtrls[l.itemId] = TextEditingController(text: rr > 0 ? '$rr' : '0');
      _scrapCtrls[l.itemId] = TextEditingController(text: '0');
    }
  }

  @override
  void dispose() {
    for (final c in _goodCtrls.values) {
      c.dispose();
    }
    for (final c in _scrapCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  int _asInt(String s) => int.tryParse(s.trim()) ?? 0;

  Future<String> _getUid() async {
    final uid =
        await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';
    return uid.trim();
  }

  Future<bool> _ensureGoodRackSelected(IssueLine line) async {
    // normalize controller output
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

    // if one rack -> auto
    if (list.length == 1) {
      setState(() => _goodRackByItem[line.itemId] = list.first);
      return true;
    }

    final existing = _goodRackByItem[line.itemId];
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (_) => RackByItemSelectionDialog(
            itemId: line.itemId,
            initialRackId: existing == null ? null : _idOf(existing),
            racks: list, // ✅ pass list directly (no extra provider/socket)
          ),
    );

    if (selected == null) return false;
    setState(() => _goodRackByItem[line.itemId] = selected);
    return true;
  }

  Future<bool> _ensureScrapRackSelected(IssueLine line) async {
    final list = await ref
        .read(storeRackControllerProvider)
        .getScrapRacksByItem(line.itemId);

    if (list.isEmpty) {
      showSnackBar('Scrap rack data is not available');
      return false;
    }

    if (list.length == 1) {
      setState(() => _scrapRackByItem[line.itemId] = list.first);
      return true;
    }

    final selected = await showDialog<StoreRack>(
      context: context,
      builder:
          (_) => ScrapRackSelectionDialog(
            racks: list,
            initialRackId: _scrapRackByItem[line.itemId]?.id,
          ),
    );

    if (selected == null) return false;
    setState(() => _scrapRackByItem[line.itemId] = selected);
    return true;
  }

  Future<void> _returnOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final good = _asInt(_goodCtrls[line.itemId]?.text ?? '0');
    final scrap = _asInt(_scrapCtrls[line.itemId]?.text ?? '0');
    final total = good + scrap;
    final remaining = _remainReturn(line);

    if (good < 0 || scrap < 0) {
      showSnackBar('Qty cannot be negative');
      return;
    }
    if (total <= 0) {
      showSnackBar('Enter good or scrap qty');
      return;
    }
    if (total > remaining) {
      showSnackBar('Total exceeds remaining ($remaining)');
      return;
    }

    final goodRack = _goodRackByItem[line.itemId];
    if (goodRack == null) {
      showSnackBar('Select Rack');
      return;
    }

    StoreRack? scrapRack;

    if (scrap > 0) {
      scrapRack = _scrapRackByItem[line.itemId];
      if (scrapRack == null) {
        showSnackBar('Select Scrap Rack');
        return;
      }
    }

    setState(() => _busy.add(line.itemId));
    try {
      final res = await ref
          .read(issueControllerProvider)
          .returnLine(
            issueId: widget.issue.id,
            itemId: line.itemId,
            rackId: _idOf(goodRack),
            scrapRackId: scrapRack?.id ?? "",
            returnedBy: uid,
            goodQty: good,
            scrapQty: scrap,
          );

      if (res == null) return;

      final data =
          (res['data'] is Map)
              ? Map<String, dynamic>.from(res['data'] as Map)
              : <String, dynamic>{};

      final updatedLine =
          (data['updatedLine'] is Map)
              ? Map<String, dynamic>.from(data['updatedLine'] as Map)
              : <String, dynamic>{};

      final updatedItemId = (updatedLine['itemId'] ?? '').toString();

      final nextReturn =
          int.tryParse((updatedLine['returnQty'] ?? '').toString()) ??
          _i(line.returnQty);

      final nextScrap =
          int.tryParse((updatedLine['scrapQty'] ?? '').toString()) ??
          _i(line.scrapQty);

      if (updatedItemId.isNotEmpty) {
        setState(() {
          _lines =
              _lines.map((x) {
                if (x.itemId == updatedItemId) {
                  final nx = x.copyWith(
                    returnQty: nextReturn,
                    scrapQty: nextScrap,
                  );
                  final rr = _remainReturn(nx);
                  _goodCtrls[x.itemId]?.text = rr > 0 ? '$rr' : '0';
                  _scrapCtrls[x.itemId]?.text = '0';
                  return nx;
                }
                return x;
              }).toList();
        });
      }

      widget.onChanged();

      // safe multi-pop if fully returned
      final issued = _i(line.issuedQty);
      final nowReturned = nextReturn + nextScrap;

      if (nowReturned >= issued) {
        final nav = Navigator.of(context);
        for (var i = 0; i < 3; i++) {
          if (nav.canPop()) nav.pop();
        }
      } else {
        if (mounted) Navigator.pop(context); // close sheet only
      }
    } catch (e) {
      showSnackBar('Return failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
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
                        'Return Items: ${widget.issue.issNo}',
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
                      final busy = _busy.contains(l.itemId);
                      final remaining = _remainReturn(l);

                      final goodRack = _goodRackByItem[l.itemId];
                      final scrapRack = _scrapRackByItem[l.itemId];

                      final goodRackLabel =
                          goodRack == null
                              ? "No rack selected"
                              : "${goodRack["code"]} • ${goodRack["roomName"]}";
                      final scrapRackLabel =
                          scrapRack == null
                              ? "No scrap rack"
                              : "${scrapRack.code} • ${scrapRack.roomName}";

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
                            Wrap(
                              spacing: 12,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Issued: ${_i(l.issuedQty)}',
                                  style: const TextStyle(
                                    color: _ink700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Returned: ${_i(l.returnQty)}',
                                  style: const TextStyle(
                                    color: _ink700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Scrap: ${_i(l.scrapQty)}',
                                  style: const TextStyle(
                                    color: _ink700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  'Remaining: $remaining',
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Rack: $goodRackLabel',
                              style: const TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Scrap Rack: $scrapRackLabel',
                              style: const TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Good Qty',
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _goodCtrls[l.itemId],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        cursorColor: const Color(0xFF111827),
                                        style: const TextStyle(
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          hintText: '0',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF10B981),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Scrap Qty',
                                        style: TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _scrapCtrls[l.itemId],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        cursorColor: const Color(0xFF111827),
                                        style: const TextStyle(
                                          color: Color(0xFF111827),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          hintText: '0',
                                          hintStyle: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 1.5,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD1D5DB),
                                              width: 1.5,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFDC2626),
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: SizedBox(
                                height: 44,
                                width: 140,
                                child: FilledButton(
                                  onPressed:
                                      (busy || remaining <= 0)
                                          ? null
                                          : () async {
                                            final scrap = _asInt(
                                              _scrapCtrls[l.itemId]?.text ??
                                                  '0',
                                            );

                                            final good = _asInt(
                                              _goodCtrls[l.itemId]?.text ?? '0',
                                            );
                                            if (good > 0) {
                                              final okGood =
                                                  await _ensureGoodRackSelected(
                                                    l,
                                                  );
                                              if (!okGood) return;
                                            }
                                            if (scrap > 0) {
                                              final okScrap =
                                                  await _ensureScrapRackSelected(
                                                    l,
                                                  );
                                              if (!okScrap) return;
                                            }

                                            await _returnOne(l);
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
                                            'Return',
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- Dialogs ---------------- */

class ScrapRackSelectionDialog extends StatefulWidget {
  const ScrapRackSelectionDialog({
    super.key,
    required this.racks,
    this.initialRackId,
  });

  final List<StoreRack> racks;
  final String? initialRackId;

  @override
  State<ScrapRackSelectionDialog> createState() =>
      _ScrapRackSelectionDialogState();
}

class _ScrapRackSelectionDialogState extends State<ScrapRackSelectionDialog> {
  StoreRack? _rack;

  @override
  Widget build(BuildContext context) {
    final list = widget.racks;

    if (_rack == null && widget.initialRackId != null) {
      final hit = list.where((x) => x.id == widget.initialRackId).toList();
      if (hit.isNotEmpty) _rack = hit.first;
    }
    _rack ??= list.first;

    final mustSelect = list.length > 1;
    final canSubmit = !mustSelect || _rack != null;

    return AlertDialog(
      title: const Text('Select Scrap Rack'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DropdownField<StoreRack>(
              label: 'Scrap Rack *',
              hint: 'Select rack',
              icon: Icons.category_rounded,
              value: _rack,
              items: list,
              textOf: (x) => '${x.code} • ${x.roomName}',
              onChanged: (v) => setState(() => _rack = v),
            ),
            const SizedBox(height: 12),
            if (_rack != null)
              _SimpleRackDetailsCard(
                code: _rack!.code,
                roomName: _rack!.roomName,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: canSubmit ? () => Navigator.pop(context, _rack) : null,
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
    this.racks,
  });

  final String itemId;
  final String? initialRackId;
  final List<Map<String, dynamic>>? racks;

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
    final racksAv =
        widget.racks != null
            ? AsyncValue.data(widget.racks!)
            : ref.watch(rackDataByItemDataStreamProvider(widget.itemId));

    return AlertDialog(
      title: const Text('Select Rack'),
      content: SizedBox(
        width: 520,
        child: racksAv.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error: (e, _) => Text('Rack load error: $e'),
          data: (racks) {
            final list = racks ?? <Map<String, dynamic>>[];

            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text('Data is not available'),
              );
            }

            final mustSelect = list.length > 1;

            if (!_didTryPreselect) {
              _didTryPreselect = true;

              if (widget.initialRackId != null) {
                final hit =
                    list
                        .where((x) => _idOf(x) == widget.initialRackId)
                        .toList();
                if (hit.isNotEmpty) _rack = hit.first;
              }

              if (!mustSelect) _rack ??= list.first;
              if (mustSelect && _rack != null) {
                final ok = list.any((x) => _idOf(x) == _idOf(_rack!));
                if (!ok) _rack = null;
              }
            }

            // Map identity fix: safe instance from list
            Map<String, dynamic>? safeValue;
            if (_rack != null) {
              final id = _idOf(_rack!);
              final hit = list.where((x) => _idOf(x) == id).toList();
              safeValue = hit.isNotEmpty ? hit.first : null;
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
        Consumer(
          builder: (context, ref, _) {
            final list = (racksAv.asData?.value ?? <Map<String, dynamic>>[]);
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

/* ---------------- Shared dropdown + rack cards ---------------- */

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

class _SimpleRackDetailsCard extends StatelessWidget {
  const _SimpleRackDetailsCard({required this.code, required this.roomName});
  final String code;
  final String roomName;

  @override
  Widget build(BuildContext context) {
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
            code,
            style: const TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          _RackDetailRow(label: 'Code', value: code),
          _RackDetailRow(label: 'Room', value: roomName),
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
