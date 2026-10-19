import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../controllers/store_room_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';
import '../../../domains/models/store_room_model.dart';

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

// Method to calculate remaining quantities
int _remainApprove(IssueLine l) => math.max(
  0,
  _i(l.requestedQty) - _i(l.approvedQty) - _i(l.approvedRejectQty),
);
int _remainIssue(IssueLine l) =>
    math.max(0, _i(l.approvedQty) - _i(l.issuedQty) - _i(l.issuedRejectQty));
int _remainReturn(IssueLine l) =>
    math.max(0, _i(l.issuedQty) - (_i(l.returnQty) + _i(l.scrapQty)));

class IssueByRackActionsPage extends ConsumerStatefulWidget {
  const IssueByRackActionsPage({super.key, required this.rackId});
  final String rackId;

  @override
  ConsumerState<IssueByRackActionsPage> createState() =>
      _IssueByRackActionsPageState();
}

class _IssueByRackActionsPageState
    extends ConsumerState<IssueByRackActionsPage> {
  String? _selectedIssueId; // Store the selected issue ID
  late List<IssueModel> _issues = []; // Store the list of issues
  String _issueSearch = '';

  List<IssueModel> _filteredIssues() {
    final q = _issueSearch.trim().toLowerCase();
    if (q.isEmpty) return _issues;

    return _issues.where((issue) {
      final issMatch = issue.issNo.toLowerCase().contains(q);

      final lineMatch = issue.lines.any((l) {
        return l.itemName.toLowerCase().contains(q);
      });

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
                  // Top handle
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Search
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

                  // Result list
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

                                // show only matching lines (optional)
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
    // Fetch issue and item data

    final itemAv = ref.watch(rackItemStreamProvider(widget.rackId));
    final pagedUser = ref.watch(userFindOneDataStreamProvider);
    if (itemAv.value == null) {
      return Scaffold(
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
          child: const Center(
            child: Text(
              "Item Data is not available",
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      );
    }
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
                        itemAv.when(
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error: (e, _) => Center(child: Text('Error: $e')),
                          data: (item) {
                            final canViewAll = user!.isSuperAdmin ||
                                user.appWorks.isEmpty ||
                                user.appWorks.contains("storeadmin") ||
                                user.appWorks.contains("storissueview") ||
                                user.appWorks.contains("storissueapprove") ||
                                user.appWorks.contains("storissuefromstock") ||
                                user.appWorks.contains("storissuereturn");

                            final queryItem = IssueItemQuery(
                              search: "",
                              createdBy: canViewAll ? null : user.uid,
                              itemId: item!.id,
                            );
                            final issuesAv = ref.watch(
                              issueByIdItemAllDataStreamProvider(queryItem),
                            );
                            return issuesAv.when(
                              loading:
                                  () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                              error: (e, _) => Center(child: Text('Error: $e')),
                              data: (issues) {
                                _issues = issues; // Save the fetched issues
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Display item details
                                    Text(
                                      'Item Name: ${item.itemName}',
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

                                    // Dropdown to select an issue
                                    InkWell(
                                      onTap: () => _openIssueSearchSheet(),
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
                                          _selectedIssueId == null
                                              ? "Search by item name…"
                                              : (_issues
                                                  .firstWhere(
                                                    (x) =>
                                                        x.id ==
                                                        _selectedIssueId,
                                                  )
                                                  .issNo),
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),

                                    if (_selectedIssueId != null) ...[
                                      SizedBox(height: 50),
                                      // Display issue data once selected
                                      _IssueCard(
                                        issue: _issues.firstWhere(
                                          (issue) =>
                                              issue.id == _selectedIssueId,
                                        ),
                                        item: item,
                                        onChanged: () {
                                          ref.invalidate(
                                            issueByIdItemAllDataStreamProvider(
                                              queryItem,
                                            ),
                                          );
                                          ref.invalidate(
                                            itemFindOneStreamProvider(item.id),
                                          );
                                        },
                                        rackId: widget.rackId,
                                        user: user, // Pass item data here
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

class _IssueCard extends StatefulWidget {
  final IssueModel issue;
  final AuthModel user;
  final StoreItemsModel item;
  const _IssueCard({
    required this.issue,
    required this.item,
    required this.user,
    required this.onChanged,
    required this.rackId,
  });
  final String rackId;
  final VoidCallback onChanged;

  @override
  State<_IssueCard> createState() => _IssueCardState();
}

class _IssueCardState extends State<_IssueCard> {
  @override
  Widget build(BuildContext context) {
    final canApprove = widget.issue.lines.any((l) => _remainApprove(l) > 0);
    final canIssue = widget.issue.lines.any((l) => _remainIssue(l) > 0);
    final canReturn = widget.issue.lines.any((l) => _remainReturn(l) > 0);

    final filledStyle = FilledButton.styleFrom(
      backgroundColor: _accentMint.withValues(alpha: .65),
      foregroundColor: _ink900,
      disabledBackgroundColor: _accentMint.withValues(alpha: .18),
      disabledForegroundColor: _ink700.withValues(alpha: .55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );

    // Filter lines that match the itemId
    final filteredLines =
        widget.issue.lines
            .where((line) => line.itemId == widget.item.id)
            .toList();

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
                        widget.issue.reason.isEmpty ? '—' : widget.issue.reason,
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

            // Table-like layout for the lines
            if (filteredLines.isNotEmpty) ...[
              _buildTableHeader(),
              for (var line in filteredLines) ...[
                _buildLineData(line),
                const SizedBox(height: 8),
              ],
            ],

            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                // Approve button
                // FilledButton.icon(
                //   onPressed:
                //       canApprove
                //           ? () async {
                //             await showModalBottomSheet(
                //               context: context,
                //               isScrollControlled: true,
                //               backgroundColor: Colors.transparent,
                //               builder:
                //                   (_) => _ApproveSheet(
                //                     issue: widget.issue,
                //                     onChanged: widget.onChanged,
                //                   ),
                //             );
                //           }
                //           : null,
                //   icon: const Icon(Icons.check_circle_rounded, size: 18),
                //   label: const Text('Approve'),
                //   style: filledStyle,
                // ),
                // Issue button
                (widget.user.appWorks.contains("storissuefromstock"))
                    ? FilledButton.icon(
                      onPressed:
                          canIssue
                              ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => _IssueSheet(
                                        issue: widget.issue,
                                        onChanged: widget.onChanged,
                                        rackId: widget.rackId,
                                      ),
                                );
                              }
                              : null,
                      icon: const Icon(Icons.local_shipping_rounded, size: 18),
                      label: const Text('Issue'),
                      style: filledStyle,
                    )
                    : SizedBox.shrink(),
                // Return button
                (widget.user.appWorks.contains("storissuereturn"))
                    ? FilledButton.icon(
                      onPressed:
                          canReturn
                              ? () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => _ReturnSheet(
                                        issue: widget.issue,
                                        onChanged: widget.onChanged,
                                        rackId: widget.rackId,
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
                    : SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Row(
      children: const [
        _TableHeaderCell('Item'),
        _TableHeaderCell('Requested Qty'),
        _TableHeaderCell('Approved Qty'),
        _TableHeaderCell('Issued Qty'),
        _TableHeaderCell('Returned Qty'),
        _TableHeaderCell('Scrap Qty'),
        _TableHeaderCell('Rejected Qty'),
        _TableHeaderCell('Issue Rate'),
      ],
    );
  }

  Widget _buildLineData(IssueLine line) {
    return Row(
      children: [
        _TableDataCell(line.itemName),
        _TableDataCell(line.requestedQty.toString()),
        _TableDataCell(line.approvedQty.toString()),
        _TableDataCell(line.issuedQty.toString()),
        _TableDataCell(line.returnQty.toString()),
        _TableDataCell(line.scrapQty.toString()),
        _TableDataCell(
          (line.issuedRejectQty - line.approvedRejectQty).toString(),
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

class _ApproveSheet extends ConsumerStatefulWidget {
  const _ApproveSheet({required this.issue, required this.onChanged});

  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends ConsumerState<_ApproveSheet> {
  late List<IssueLine> _lines;

  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _rejectQtyCtrls = {};
  final Map<String, String> _modes = {}; // add|set
  final Set<String> _busyLineIds = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      _modes[l.itemId] = 'add';
      final ra = _remainApprove(l);
      _qtyCtrls[l.itemId] = TextEditingController(text: ra > 0 ? '$ra' : '0');
      _rejectQtyCtrls[l.itemId] = TextEditingController(text: '0');
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

  Future<void> _approveOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final mode = (_modes[line.itemId] ?? 'add').toLowerCase();
    final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
    final rejectqty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);

    final remaining = _remainApprove(line);

    if (mode == 'add' && qty <= 0) {
      showSnackBar('Enter qty > 0');
      return;
    }
    if (mode == 'add' && rejectqty < 0) {
      showSnackBar('Enter rejectqty > 0');
      return;
    }
    if (mode == 'set' && qty < 0) {
      showSnackBar('Qty cannot be negative');
      return;
    }
    if (mode == 'add' && qty > remaining) {
      showSnackBar('Qty cannot exceed remaining ($remaining)');
      return;
    }
    if (mode == 'add' && rejectqty > remaining) {
      showSnackBar('rejectqty cannot exceed remaining ($remaining)');
      return;
    }
    if (mode == 'set' && qty > _i(line.requestedQty)) {
      showSnackBar(
        'Set qty cannot exceed requested (${_i(line.requestedQty)})',
      );
      return;
    }

    setState(() => _busyLineIds.add(line.itemId));
    try {
      final res = await ref
          .read(issueControllerProvider)
          .approveLine(
            issueId: widget.issue.id,
            itemId: line.itemId,
            approvedBy: uid,
            approvedQty: qty,
            approvedRejectQty: rejectqty,
            mode: 'add',
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
      final nextApproved =
          int.tryParse((updatedLine['approvedQty'] ?? '').toString()) ??
          _i(line.approvedQty);

      if (updatedItemId.isNotEmpty) {
        setState(() {
          _lines =
              _lines.map((x) {
                if (x.itemId == updatedItemId) {
                  final nx = x.copyWith(approvedQty: nextApproved);
                  final ra = _remainApprove(nx);
                  _qtyCtrls[x.itemId]?.text = ra > 0 ? '$ra' : '0';
                  _rejectQtyCtrls[x.itemId]?.text = '0';
                  return nx;
                }
                return x;
              }).toList();
        });
      }

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Approve failed: $e');
    } finally {
      if (mounted) setState(() => _busyLineIds.remove(line.itemId));
    }
  }

  Future<void> _approveAllRemaining() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final linesPayload =
        _lines
            .where((l) => _remainApprove(l) > 0)
            .map(
              (l) => {
                'itemId': l.itemId,
                'approvedQty': _remainApprove(l),
                'mode': 'add',
              },
            )
            .toList();

    if (linesPayload.isEmpty) {
      showSnackBar('Nothing remaining to approve');
      return;
    }

    setState(() => _bulkBusy = true);
    try {
      await ref
          .read(issueControllerProvider)
          .approveBulk(
            issueId: widget.issue.id,
            approvedBy: uid,
            lines: linesPayload,
          );

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Bulk approve failed: $e');
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
                        'Approve Issue: ${widget.issue.issNo}',
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
                const SizedBox(height: 8),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: FilledButton.icon(
                //     onPressed: _bulkBusy ? null : _approveAllRemaining,
                //     style: FilledButton.styleFrom(
                //       backgroundColor: _accentMint.withOpacity(.75),
                //       foregroundColor: _ink900,
                //       disabledBackgroundColor: _accentMint.withOpacity(.18),
                //       disabledForegroundColor: _ink700.withOpacity(.55),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(14),
                //       ),
                //     ),
                //     icon:
                //         _bulkBusy
                //             ? const SizedBox(
                //               width: 18,
                //               height: 18,
                //               child: CircularProgressIndicator(strokeWidth: 2),
                //             )
                //             : const Icon(Icons.done_all_rounded),
                //     label: const Text(
                //       'Approve all remaining',
                //       style: TextStyle(fontWeight: FontWeight.w900),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = _lines[i];
                      final busy = _busyLineIds.contains(l.itemId);
                      final remaining = _remainApprove(l);

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
                              'Requested: ${_i(l.requestedQty)}   Approved: ${_i(l.approvedQty)}   Remaining: $remaining',
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                // Expanded(
                                //   flex: 4,
                                //   child: DropdownButtonFormField<String>(
                                //     value: _modes[l.itemId] ?? 'add',
                                //     decoration: const InputDecoration(
                                //       prefixIcon: Icon(Icons.tune_rounded),
                                //       hintText: 'Mode',
                                //     ),
                                //     style: const TextStyle(
                                //       color:
                                //           _ink900, // Change this to your desired color
                                //     ),
                                //     items: const [
                                //       DropdownMenuItem(
                                //         value: 'add',
                                //         child: Text('Add'),
                                //       ),
                                //       DropdownMenuItem(
                                //         value: 'set',
                                //         child: Text('Set'),
                                //       ),
                                //     ],
                                //     onChanged:
                                //         busy
                                //             ? null
                                //             : (v) => setState(
                                //               () =>
                                //                   _modes[l.itemId] =
                                //                       (v ?? 'add'),
                                //             ),
                                //   ),
                                // ),
                                Expanded(
                                  flex: 4,
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
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 46,
                                    child: FilledButton(
                                      onPressed:
                                          (busy || remaining <= 0)
                                              ? null
                                              : () => _approveOne(l),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _accentMint
                                            .withValues(alpha: .75),
                                        foregroundColor: _ink900,
                                        disabledBackgroundColor: _accentMint
                                            .withValues(alpha: .18),
                                        disabledForegroundColor: _ink700
                                            .withValues(alpha: .55),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child:
                                          busy
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Text(
                                                'Approve',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                    ),
                                  ),
                                ),
                              ],
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

/* ---------------- Issue Sheet (line-by-line issue + bulk) ---------------- */

class _IssueSheet extends ConsumerStatefulWidget {
  const _IssueSheet({
    required this.issue,
    required this.onChanged,
    required this.rackId,
  });
  final String rackId;

  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_IssueSheet> createState() => _IssueSheetState();
}

class _IssueSheetState extends ConsumerState<_IssueSheet> {
  late List<IssueLine> _lines;
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _rejectQtyCtrls = {};
  final Set<String> _busyLineIds = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      final ri = _remainIssue(l);
      _qtyCtrls[l.itemId] = TextEditingController(text: ri > 0 ? '$ri' : '0');
      _rejectQtyCtrls[l.itemId] = TextEditingController(text: '0');
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

  Future<void> _issueOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
    final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);
    final remaining = _remainIssue(line);

    if (qty <= 0) {
      showSnackBar('Enter qty > 0');
      return;
    }
    if (qty > remaining) {
      showSnackBar('Qty cannot exceed remaining ($remaining)');
      return;
    }

    if (rejectQty < 0) {
      showSnackBar('Enter qty > 0');
      return;
    }
    if (rejectQty > remaining) {
      showSnackBar('Qty cannot exceed remaining ($remaining)');
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
            qty: qty,
            issuedRejectQty: rejectQty,
            rackId: widget.rackId,
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
                const SizedBox(height: 8),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: FilledButton.icon(
                //     onPressed: _bulkBusy ? null : _issueAllRemaining,
                //     style: FilledButton.styleFrom(
                //       backgroundColor: _accentMint.withOpacity(.75),
                //       foregroundColor: _ink900,
                //       disabledBackgroundColor: _accentMint.withOpacity(.18),
                //       disabledForegroundColor: _ink700.withOpacity(.55),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(14),
                //       ),
                //     ),
                //     icon:
                //         _bulkBusy
                //             ? const SizedBox(
                //               width: 18,
                //               height: 18,
                //               child: CircularProgressIndicator(strokeWidth: 2),
                //             )
                //             : const Icon(Icons.done_all_rounded),
                //     label: const Text(
                //       'Issue all remaining',
                //       style: TextStyle(fontWeight: FontWeight.w900),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = _lines[i];
                      final busy = _busyLineIds.contains(l.itemId);
                      final remaining = _remainIssue(l);

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
                              'Approved: ${_i(l.approvedQty)}   Issued: ${_i(l.issuedQty)}   Remaining: $remaining   Rejected: ${_i(l.issuedRejectQty)}',
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
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
                                const SizedBox(width: 10),
                                Expanded(
                                  flex: 4,
                                  child: SizedBox(
                                    height: 46,
                                    child: FilledButton(
                                      onPressed:
                                          (busy || remaining <= 0)
                                              ? null
                                              : () => _issueOne(l),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _accentMint
                                            .withValues(alpha: .75),
                                        foregroundColor: _ink900,
                                        disabledBackgroundColor: _accentMint
                                            .withValues(alpha: .18),
                                        disabledForegroundColor: _ink700
                                            .withValues(alpha: .55),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                      ),
                                      child:
                                          busy
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
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

/* ---------------- Return Sheet (good + scrap; line-by-line + bulk) ---------------- */

class _ReturnSheet extends ConsumerStatefulWidget {
  const _ReturnSheet({
    required this.issue,
    required this.onChanged,
    required this.rackId,
  });
  final String rackId;
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
  bool _bulkBusy = false;
  StoreRack? _scrapRack;
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

  Future<void> _openScrapRackDialog() async {
    // Show the dialog and wait for the selected rack (StoreRack) to be returned
    final selectedRack = await showDialog<StoreRack>(
      context: context,
      builder: (_) => RoomSelectionDialog(issue: widget.issue),
    );

    if (selectedRack != null) {
      setState(() {
        _scrapRack = selectedRack; // Assign the selected rack to _scrapRack
      });
    }
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
    if (scrap > 0) {
      if (_scrapRack == null) {
        showSnackBar('Select Sracp Rack');
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
            scrapRackId: (_scrapRack != null) ? _scrapRack!.id : "",
            returnedBy: uid,
            goodQty: good,
            scrapQty: scrap,
            rackId: widget.rackId,
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
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Return failed: $e');
    } finally {
      if (mounted) setState(() => _busy.remove(line.itemId));
    }
  }

  Future<void> _returnAllRemainingAsGood() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final payload =
        _lines
            .where((l) => _remainReturn(l) > 0)
            .map(
              (l) => {
                'itemId': l.itemId,
                'rackId': widget.rackId,
                'goodQty': _remainReturn(l),
                'scrapQty': 0,
              },
            )
            .toList();

    if (payload.isEmpty) {
      showSnackBar('Nothing remaining to return');
      return;
    }

    setState(() => _bulkBusy = true);
    try {
      await ref
          .read(issueControllerProvider)
          .returnBulk(
            issueId: widget.issue.id,
            returnedBy: uid,
            lines: payload,
          );

      widget.onChanged();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Bulk return failed: $e');
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
                const SizedBox(height: 8),
                // Align(
                //   alignment: Alignment.centerRight,
                //   child: FilledButton.icon(
                //     onPressed: _bulkBusy ? null : _returnAllRemainingAsGood,
                //     style: FilledButton.styleFrom(
                //       backgroundColor: _accentMint.withOpacity(.75),
                //       foregroundColor: _ink900,
                //       disabledBackgroundColor: _accentMint.withOpacity(.18),
                //       disabledForegroundColor: _ink700.withOpacity(.55),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(14),
                //       ),
                //     ),
                //     icon:
                //         _bulkBusy
                //             ? const SizedBox(
                //               width: 18,
                //               height: 18,
                //               child: CircularProgressIndicator(strokeWidth: 2),
                //             )
                //             : const Icon(Icons.done_all_rounded),
                //     label: const Text(
                //       'Return all remaining (Good)',
                //       style: TextStyle(fontWeight: FontWeight.w900),
                //     ),
                //   ),
                // ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final l = _lines[i];
                      final busy = _busy.contains(l.itemId);
                      final remaining = _remainReturn(l);

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
                                           contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                           hintText: '0',
                                           hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
                                           contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                           hintText: '0',
                                           hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
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
                                             var scrap = _asInt(
                                               _scrapCtrls[l.itemId]?.text ??
                                                   '0',
                                             );
                                             if (scrap > 0) {
                                               await _openScrapRackDialog();
                                               _returnOne(l);
                                             } else {
                                               _returnOne(l);
                                             }
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

class RoomSelectionDialog extends ConsumerStatefulWidget {
  const RoomSelectionDialog({super.key, required this.issue});
  final IssueModel issue;

  @override
  ConsumerState<RoomSelectionDialog> createState() =>
      _RoomSelectionDialogState();
}

class _RoomSelectionDialogState extends ConsumerState<RoomSelectionDialog> {
  StoreRoom? _roomNode;

  @override
  Widget build(BuildContext context) {
    final roomAv = ref.watch(roomAllDataStreamProvider);

    return AlertDialog(
      title: const Text('Select Room'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          roomAv.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text('Room load error: $e'),
            data: (rooms) {
              final list = rooms;

              return _DropdownField<StoreRoom>(
                label: 'Room *',
                hint: 'Select room',
                icon: Icons.view_module_rounded,
                value: _roomNode,
                items: list,
                textOf: (x) => x.code,
                onChanged: (room) {
                  setState(() {
                    _roomNode = room;
                  });

                  if (_roomNode != null) {
                    // Open the next step: Rack selection
                    _openRackSelectionDialog();
                  }
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  // Function to open the next step for rack selection
  void _openRackSelectionDialog() async {
    if (_roomNode != null) {
      final selectedRack = await showDialog<StoreRack>(
        context: context,
        builder: (BuildContext context) {
          return RackSelectionDialog(room: _roomNode!, issue: widget.issue);
        },
      );
      if (selectedRack != null) {
        Navigator.pop(context, selectedRack); // Return selected rack
      } else {
        Navigator.pop(context); // Close dialog without returning any data
      }
    }
  }
}

class RackSelectionDialog extends ConsumerStatefulWidget {
  const RackSelectionDialog({
    super.key,
    required this.room,
    required this.issue,
  });

  final IssueModel issue;
  final StoreRoom room;

  @override
  ConsumerState<RackSelectionDialog> createState() =>
      _RackSelectionDialogState();
}

class _RackSelectionDialogState extends ConsumerState<RackSelectionDialog> {
  StoreRack? _rack;

  // List<StoreRack>? _racks = []; // Track racks
  Map<String, dynamic> query = {};
  @override
  void initState() {
    query = {
      'roomId': widget.room.id,
      'itemId': widget.issue.lines.first.itemId, // Add your itemId here
    };
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final racksAv = ref.watch(scrapItemAllDataStreamProvider(query));
    return AlertDialog(
      title: const Text('Select Scrap Rack'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show racks dropdown
          racksAv.when(
            loading: () => const LinearProgressIndicator(minHeight: 2),
            error: (e, _) => Text('Room load error: $e'),
            data: (rooms) {
              final list = rooms;
              return _DropdownField<StoreRack>(
                label: 'Rack *',
                hint: 'Select rack',
                icon: Icons.category_rounded,
                value: _rack,
                items: list,
                textOf: (x) => x.code,
                onChanged: (rack) {
                  setState(() {
                    _rack = rack;
                  });
                },
              );
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_rack != null) {
              Navigator.pop(context, _rack); // Return selected rack
            } else {
              Navigator.pop(
                context,
                null,
              ); // Close dialog without returning any data
            }
          },
          child: const Text('Select'),
        ),
      ],
    );
  }

  // Fetch racks based on selected room
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
