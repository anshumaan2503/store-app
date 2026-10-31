import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../../domains/models/store_items_model.dart';
import '../../../domains/models/store_rack_model.dart';

// Palette
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;
const _brandGreen = Color(0xFF2E7D32);

int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;
int _remainIssue(IssueLine l) =>
    math.max(0, _i(l.approvedQty) - _i(l.issuedQty) - _i(l.issuedRejectQty));

/// Mobile-optimized Issue page when scanning a physical Rack / Place (`P0041.<rackId>`)
class IssueByRackActionsPage extends ConsumerStatefulWidget {
  const IssueByRackActionsPage({super.key, required this.rackId});
  final String rackId;

  @override
  ConsumerState<IssueByRackActionsPage> createState() =>
      _IssueByRackActionsPageState();
}

class _IssueByRackActionsPageState
    extends ConsumerState<IssueByRackActionsPage> {
  String? _selectedItemId;
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(findOneRackStreamProvider(widget.rackId));
    ref.invalidate(rackItemListStreamProvider(widget.rackId));
    ref.invalidate(rackItemStreamProvider(widget.rackId));
  }

  @override
  Widget build(BuildContext context) {
    final userAv = ref.watch(userFindOneDataStreamProvider);
    final rackAv = ref.watch(findOneRackStreamProvider(widget.rackId));
    final rackItemsAv = ref.watch(rackItemListStreamProvider(widget.rackId));
    final fallbackItemAv = ref.watch(rackItemStreamProvider(widget.rackId));

    final user = userAv.value;
    final canViewAll = user == null ||
        user.isSuperAdmin ||
        user.appWorks.isEmpty ||
        user.appWorks.contains("storeadmin") ||
        user.appWorks.contains("storissueview") ||
        user.appWorks.contains("storissuefromstock");

    final rackQuery = IssueRackQuery(
      rackId: widget.rackId,
      createdBy: canViewAll ? null : user.uid,
      search: "",
    );
    final issuesAv = ref.watch(issueByIdRackAllDataStreamProvider(rackQuery));

    // Combine and deduplicate rack items
    final Map<String, StoreItemsModel> itemMap = {};
    if (rackItemsAv.value != null) {
      for (final it in rackItemsAv.value!) {
        itemMap[it.id] = it;
      }
    }
    if (fallbackItemAv.value != null) {
      itemMap[fallbackItemAv.value!.id] = fallbackItemAv.value!;
    }
    final itemsList = itemMap.values.toList();
    final rackItemIds = itemMap.keys.toSet();

    final rack = rackAv.value;
    final rackTitle = rack != null
        ? '${rack.code.isNotEmpty ? rack.code : "Rack"}${rack.rackName.isNotEmpty ? " • ${rack.rackName}" : ""}'
        : 'Place / Rack';

    // Filter issues
    final allIssues = issuesAv.value ?? [];
    final filteredIssues = allIssues.where((issue) {
      if (_selectedItemId != null) {
        final hasItem = issue.lines.any(
          (l) => l.itemId == _selectedItemId && _remainIssue(l) > 0,
        );
        if (!hasItem) return false;
      }
      final q = _searchQuery.trim().toLowerCase();
      if (q.isNotEmpty) {
        final matchIss = issue.issNo.toLowerCase().contains(q);
        final matchLine = issue.lines.any(
          (l) => l.itemName.toLowerCase().contains(q),
        );
        if (!matchIss && !matchLine) return false;
      }
      return true;
    }).toList();

    final isLoading = rackAv.isLoading && rackItemsAv.isLoading && issuesAv.isLoading;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Issue by Place / Rack',
              style: TextStyle(
                color: _ink900,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              rackTitle,
              style: const TextStyle(
                color: _ink600,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: _ink700),
            onPressed: () {
              _refreshAll();
              ref.invalidate(issueByIdRackAllDataStreamProvider(rackQuery));
            },
          ),
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
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    _refreshAll();
                    ref.invalidate(issueByIdRackAllDataStreamProvider(rackQuery));
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    children: [
                      // 1. Rack details header banner
                      _buildRackHeaderBanner(rack, itemsList.length),
                      const SizedBox(height: 12),

                      // 2. Items on this rack (filter chips)
                      if (itemsList.isNotEmpty) ...[
                        _buildItemFilterChips(itemsList),
                        const SizedBox(height: 12),
                      ],

                      // 3. Search Bar
                      _buildSearchBar(),
                      const SizedBox(height: 14),

                      // 4. Pending Requisitions List or Empty States
                      if (issuesAv.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (filteredIssues.isEmpty)
                        _buildEmptyState(itemsList.isEmpty, allIssues.isEmpty)
                      else ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10, left: 4),
                          child: Text(
                            'Pending Requisitions (${filteredIssues.length})',
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        ...filteredIssues.map((issue) {
                          return _buildIssueCard(
                            context: context,
                            issue: issue,
                            rackItemIds: rackItemIds,
                            onChanged: () {
                              ref.invalidate(
                                issueByIdRackAllDataStreamProvider(rackQuery),
                              );
                              _refreshAll();
                            },
                          );
                        }),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildRackHeaderBanner(StoreRack? rack, int itemCount) {
    final rackCode = rack?.code.isNotEmpty == true ? rack!.code : 'RK-PLACE';
    final rackName = rack?.rackName.isNotEmpty == true ? rack!.rackName : 'Warehouse Rack';
    final roomName = rack?.roomName.isNotEmpty == true ? rack!.roomName : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC8E6C9)),
            ),
            child: const Icon(
              Icons.warehouse_rounded,
              color: Color(0xFF2E7D32),
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _ink900,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        rackCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (roomName.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          roomName,
                          style: const TextStyle(
                            color: _ink600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rackName,
                  style: const TextStyle(
                    color: _ink900,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$itemCount item(s) stored in this rack',
                  style: const TextStyle(
                    color: _ink600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemFilterChips(List<StoreItemsModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Items in this Rack',
            style: TextStyle(
              color: _ink700,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text('All (${items.length})'),
                  selected: _selectedItemId == null,
                  onSelected: (_) {
                    setState(() => _selectedItemId = null);
                  },
                  backgroundColor: _surface,
                  selectedColor: _ink900,
                  labelStyle: TextStyle(
                    color: _selectedItemId == null ? Colors.white : _ink700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: _selectedItemId == null ? _ink900 : _stroke,
                    ),
                  ),
                  showCheckmark: false,
                ),
              ),
              ...items.map((item) {
                final isSelected = _selectedItemId == item.id;
                final avail = item.stockAvailableQuantity;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text('${item.itemName} ($avail)'),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectedItemId = isSelected ? null : item.id;
                      });
                    },
                    backgroundColor: _surface,
                    selectedColor: const Color(0xFF2E7D32),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : _ink900,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF2E7D32) : _stroke,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchCtrl,
      onChanged: (v) => setState(() => _searchQuery = v),
      decoration: InputDecoration(
        hintText: 'Search by Issue No or Item Name…',
        hintStyle: const TextStyle(color: _ink600, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _ink700, size: 20),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchCtrl.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: _surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _ink900, width: 1.5),
        ),
      ),
      style: const TextStyle(color: _ink900, fontSize: 14),
    );
  }

  Widget _buildEmptyState(bool noItemsAssigned, bool noIssuesAtAll) {
    if (noItemsAssigned) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inventory_2_outlined, size: 48, color: _ink600),
            SizedBox(height: 12),
            Text(
              'No Items Mapped to this Place',
              style: TextStyle(
                color: _ink900,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'This rack does not have any items assigned to it yet. Please assign items to this rack or receive inventory into it first.',
              style: TextStyle(color: _ink600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (noIssuesAtAll) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _stroke),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.check_circle_outline_rounded, size: 48, color: Color(0xFF2E7D32)),
            SizedBox(height: 12),
            Text(
              'No Pending Requisitions',
              style: TextStyle(
                color: _ink900,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 6),
            Text(
              'All stock in this rack is up to date! There are currently no approved requisitions waiting to be issued from this rack.',
              style: TextStyle(color: _ink600, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.filter_list_off_rounded, size: 44, color: _ink600),
          SizedBox(height: 12),
          Text(
            'No Matching Requisitions',
            style: TextStyle(
              color: _ink900,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'No pending issues match your current filter or search criteria.',
            style: TextStyle(color: _ink600, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildIssueCard({
    required BuildContext context,
    required IssueModel issue,
    required Set<String> rackItemIds,
    required VoidCallback onChanged,
  }) {
    // Only display lines belonging to this rack that still have remaining issue qty
    final relevantLines = issue.lines.where((l) {
      if (rackItemIds.isNotEmpty && !rackItemIds.contains(l.itemId)) {
        return false;
      }
      return _remainIssue(l) > 0;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Issue No & Status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue.issNo,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (issue.reason.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          issue.reason,
                          style: const TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFA5D6A7)),
                  ),
                  child: const Text(
                    'READY FOR ISSUE',
                    style: TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: _stroke),
            const SizedBox(height: 10),

            // Line items available to issue from this rack
            ...relevantLines.map((line) {
              final rem = _remainIssue(line);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke.withValues(alpha: .8)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.itemName,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Req: ${line.requestedQty}  •  App: ${line.approvedQty}  •  Issued: ${line.issuedQty}',
                            style: const TextStyle(
                              color: _ink600,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFFCC80)),
                      ),
                      child: Text(
                        'Pending: $rem',
                        style: const TextStyle(
                          color: Color(0xFFE65100),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 4),

            // Action button: Issue (Pick Up)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _RackIssueSheet(
                      issue: issue,
                      rackId: widget.rackId,
                      rackItemIds: rackItemIds,
                      onChanged: onChanged,
                    ),
                  );
                },
                icon: const Icon(Icons.local_shipping_rounded, size: 18),
                label: const Text(
                  'Issue (Pick Up)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: _brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------- Rack Issue Sheet ---------------- */

class _RackIssueSheet extends ConsumerStatefulWidget {
  const _RackIssueSheet({
    required this.issue,
    required this.rackId,
    required this.rackItemIds,
    required this.onChanged,
  });

  final IssueModel issue;
  final String rackId;
  final Set<String> rackItemIds;
  final VoidCallback onChanged;

  @override
  ConsumerState<_RackIssueSheet> createState() => _RackIssueSheetState();
}

class _RackIssueSheetState extends ConsumerState<_RackIssueSheet> {
  late List<IssueLine> _lines;
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _rejectQtyCtrls = {};
  final Set<String> _busyLineIds = {};
  bool _bulkBusy = false;

  @override
  void initState() {
    super.initState();
    // Filter lines belonging to this rack that still need issuance
    _lines = widget.issue.lines.where((l) {
      if (widget.rackItemIds.isNotEmpty && !widget.rackItemIds.contains(l.itemId)) {
        return false;
      }
      return _remainIssue(l) > 0;
    }).toList();

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
    final uid = await ref.read(spRepositoryProvider).getStringValue('uid');
    return uid.trim();
  }

  Future<void> _issueOne(IssueLine line) async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing user session');
      return;
    }

    final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
    final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);
    final remaining = _remainIssue(line);

    if (qty <= 0 && rejectQty <= 0) {
      showSnackBar('Please enter a quantity greater than 0');
      return;
    }
    if (qty + rejectQty > remaining) {
      showSnackBar('Total quantity cannot exceed remaining ($remaining)');
      return;
    }

    setState(() => _busyLineIds.add(line.itemId));
    try {
      await ref.read(issueControllerProvider).issueLine(
            issueId: widget.issue.id,
            itemId: line.itemId,
            issuedBy: uid,
            qty: qty,
            issuedRejectQty: rejectQty,
            rackId: widget.rackId,
          );

      if (mounted) {
        showSnackBar('Successfully issued ${line.itemName}');
        widget.onChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      showSnackBar('Issue failed: $e');
    } finally {
      if (mounted) {
        setState(() => _busyLineIds.remove(line.itemId));
      }
    }
  }

  Future<void> _issueAllRemaining() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing user session');
      return;
    }

    setState(() => _bulkBusy = true);
    try {
      for (final line in _lines) {
        final qty = _asInt(_qtyCtrls[line.itemId]?.text ?? '', 0);
        final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);
        if (qty <= 0 && rejectQty <= 0) continue;

        await ref.read(issueControllerProvider).issueLine(
              issueId: widget.issue.id,
              itemId: line.itemId,
              issuedBy: uid,
              qty: qty,
              issuedRejectQty: rejectQty,
              rackId: widget.rackId,
            );
      }

      if (mounted) {
        showSnackBar('All items from this rack issued successfully');
        widget.onChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      showSnackBar('Issuance failed: $e');
    } finally {
      if (mounted) {
        setState(() => _bulkBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.82;

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
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top sheet handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Issue: ${widget.issue.issNo}',
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Confirm issuance from this scanned Place / Rack',
                            style: TextStyle(color: _ink600, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: _ink700),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(height: 1, color: _stroke),
                const SizedBox(height: 12),

                // List of items
                Expanded(
                  child: ListView.separated(
                    itemCount: _lines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      final remaining = _remainIssue(line);
                      final isBusy = _busyLineIds.contains(line.itemId);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _surfaceAlt.withValues(alpha: .5),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _stroke),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    line.itemName,
                                    style: const TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFCC80),
                                    ),
                                  ),
                                  child: Text(
                                    'Remaining: $remaining',
                                    style: const TextStyle(
                                      color: Color(0xFFE65100),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Inputs Row
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextField(
                                    controller: _qtyCtrls[line.itemId],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Issue Qty',
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        color: _brandGreen,
                                      ),
                                      isDense: true,
                                      prefixIcon: const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: _brandGreen,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: TextField(
                                    controller: _rejectQtyCtrls[line.itemId],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Reject Qty',
                                      labelStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.redAccent,
                                      ),
                                      isDense: true,
                                      prefixIcon: const Icon(
                                        Icons.cancel_outlined,
                                        size: 16,
                                        color: Colors.redAccent,
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  height: 44,
                                  child: FilledButton(
                                    onPressed: isBusy ? null : () => _issueOne(line),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _brandGreen,
                                      padding: const EdgeInsets.symmetric(horizontal: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: isBusy
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text(
                                            'Issue',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
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

                const SizedBox(height: 12),

                // Issue All button
                if (_lines.length > 1)
                  FilledButton.icon(
                    onPressed: _bulkBusy ? null : _issueAllRemaining,
                    icon: _bulkBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text(
                      'Issue All Remaining From This Rack',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _brandGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
