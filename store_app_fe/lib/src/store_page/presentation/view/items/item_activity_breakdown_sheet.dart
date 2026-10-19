import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/providers/auth_model_provider.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../domains/models/store_items_model.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFFA89F91);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

enum ItemBreakdownTab {
  all,
  inCart,
  requested,
  readyForIssue,
  pickedUp,
  rejected,
  history,
}

void showItemActivityBreakdownSheet(
  BuildContext context, {
  required StoreItemsModel item,
  ItemBreakdownTab initialTab = ItemBreakdownTab.inCart,
}) {
  final screenWidth = MediaQuery.of(context).size.width;
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    constraints: BoxConstraints(
      maxWidth: screenWidth >= 900
          ? 860
          : (screenWidth >= 600 ? screenWidth * 0.94 : double.infinity),
    ),
    builder: (_) => ItemActivityBreakdownSheet(
      item: item,
      initialTab: initialTab,
    ),
  );
}

class ItemActivityBreakdownSheet extends ConsumerStatefulWidget {
  const ItemActivityBreakdownSheet({
    super.key,
    required this.item,
    this.initialTab = ItemBreakdownTab.inCart,
  });

  final StoreItemsModel item;
  final ItemBreakdownTab initialTab;

  @override
  ConsumerState<ItemActivityBreakdownSheet> createState() =>
      _ItemActivityBreakdownSheetState();
}

class _ItemActivityBreakdownSheetState
    extends ConsumerState<ItemActivityBreakdownSheet> {
  late Set<ItemBreakdownTab> _selectedTabs;
  static const int _pageSize = 8;
  int _currentPage = 1;

  final _searchCtrl = TextEditingController();
  String _searchFilter = '';

  // Track expanded cards by unique key
  final Set<String> _expandedKeys = {};
  late ScrollController _tabScrollCtrl;
  late ScrollController _listScrollCtrl;

  @override
  void initState() {
    super.initState();
    final startTab = widget.initialTab == ItemBreakdownTab.all
        ? ItemBreakdownTab.inCart
        : widget.initialTab;
    _selectedTabs = {startTab};
    _tabScrollCtrl = ScrollController();
    _listScrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTab(startTab);
    });
  }

  @override
  void dispose() {
    _tabScrollCtrl.dispose();
    _listScrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scrollToTab(ItemBreakdownTab tab) {
    if (!_tabScrollCtrl.hasClients) return;
    double offset = 0;
    switch (tab) {
      case ItemBreakdownTab.inCart:
        offset = 0;
        break;
      case ItemBreakdownTab.requested:
        offset = 65;
        break;
      case ItemBreakdownTab.readyForIssue:
        offset = 145;
        break;
      case ItemBreakdownTab.pickedUp:
        offset = 245;
        break;
      case ItemBreakdownTab.rejected:
        offset = 360;
        break;
      default:
        offset = 0;
    }
    _tabScrollCtrl.animateTo(
      offset.clamp(0.0, _tabScrollCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleTab(ItemBreakdownTab tab, bool isDesktop) {
    setState(() {
      if (_selectedTabs.contains(tab)) {
        if (_selectedTabs.length > 1) {
          _selectedTabs.remove(tab);
        }
      } else {
        _selectedTabs.add(tab);
      }
      _currentPage = 1;
    });
    if (_listScrollCtrl.hasClients) {
      _listScrollCtrl.jumpTo(0);
    }
    if (!isDesktop) {
      _scrollToTab(tab);
    }
  }

  void _goToPage(int page) {
    setState(() {
      _currentPage = page;
    });
    if (_listScrollCtrl.hasClients) {
      _listScrollCtrl.jumpTo(0);
    }
  }

  String _getSelectedTabsSummary() {
    final names = <String>[];
    if (_selectedTabs.contains(ItemBreakdownTab.inCart)) names.add('In Cart');
    if (_selectedTabs.contains(ItemBreakdownTab.requested)) names.add('Requested');
    if (_selectedTabs.contains(ItemBreakdownTab.readyForIssue)) names.add('Ready for Issue');
    if (_selectedTabs.contains(ItemBreakdownTab.pickedUp)) names.add('Picked Up');
    if (_selectedTabs.contains(ItemBreakdownTab.rejected)) names.add('Rejected');
    return names.join(', ');
  }

  void _refresh() {
    ref.invalidate(itemCartBreakdownProvider(widget.item.id));
    ref.invalidate(itemIssueBreakdownProvider(widget.item.id));
    ref.read(globalInCartProvider.notifier).refresh();
  }

  void _toggleExpanded(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  String _formatTimeAgo(dynamic raw) {
    if (raw == null) return '';
    DateTime dt;
    if (raw is DateTime) {
      dt = raw;
    } else {
      dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatDateTime(dynamic raw) {
    if (raw == null) return '';
    DateTime dt;
    if (raw is DateTime) {
      dt = raw;
    } else {
      dt = DateTime.tryParse(raw.toString()) ?? DateTime.now();
    }
    final local = dt.toLocal();
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final min = local.minute.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$min $period';
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxH = mediaQuery.size.height * 0.88;
    final isDesktop = mediaQuery.size.width >= 600;

    final globalInCart = ref.watch(globalInCartProvider);
    final cartBreakdownAsync =
        ref.watch(itemCartBreakdownProvider(widget.item.id));
    final issueBreakdownAsync =
        ref.watch(itemIssueBreakdownProvider(widget.item.id));

    final currentUid = ref.watch(authModelProvider)?.uid ?? '';

    // Compute stage counts dynamically from breakdown data
    int inCartCount = globalInCart[widget.item.id] ?? 0;
    int requestedCount = widget.item.stockRequestedQuantity;
    int readyCount = widget.item.stockIssueQuantity;
    int pickedUpCount = 0;
    int rejectedCount = 0;

    final cartListVal = cartBreakdownAsync.valueOrNull ?? [];
    final issueMapVal = issueBreakdownAsync.valueOrNull ?? {};
    final reqListVal = (issueMapVal['requested'] is List)
        ? issueMapVal['requested'] as List
        : [];
    final rdyListVal = (issueMapVal['readyForIssue'] is List)
        ? issueMapVal['readyForIssue'] as List
        : [];
    final hListVal = (issueMapVal['history'] is List)
        ? issueMapVal['history'] as List
        : [];

    if (cartBreakdownAsync.hasValue || issueBreakdownAsync.hasValue) {
      // 1. In Cart: cart records + synthesized transitions
      final existingIds = cartListVal
          .map((c) => c is Map ? c['issueId']?.toString() : null)
          .where((id) => id != null && id.isNotEmpty)
          .toSet();
      int transCount = 0;
      for (final r in reqListVal) {
        if (r is Map) {
          final id = r['issueId']?.toString() ?? '';
          if (id.isEmpty || !existingIds.contains(id)) transCount++;
        }
      }
      inCartCount = cartListVal.length + transCount;

      // 2. Requested: Pending approval requisitions ONLY (exclude rejected & closed)
      requestedCount = reqListVal.where((e) {
        if (e is! Map) return false;
        final st = (e['status'] ?? '').toString().toUpperCase();
        final isPending = e['isPending'] == true;
        return (isPending || st == 'DRAFT' || st == 'REQUESTED') &&
            st != 'REJECTED' &&
            st != 'CLOSED' &&
            st != 'PICKED UP' &&
            st != 'EXPIRED_WEEKLY';
      }).length;

      // 3. Ready for Issue: Waiting at counter ONLY (exclude closed & picked up)
      readyCount = rdyListVal.where((e) {
        if (e is! Map) return false;
        final st = (e['status'] ?? '').toString().toUpperCase();
        return (e['isPending'] == true || st == 'APPROVED') &&
            st != 'CLOSED' &&
            st != 'PICKED UP' &&
            st != 'REVERTED_APPROVAL' &&
            st != 'EXPIRED_MONTH_END';
      }).length;

      // 4. Picked Up: Completed issues (deduplicated)
      final pIds = <String>{};
      for (final list in [hListVal, rdyListVal, reqListVal]) {
        for (final e in list) {
          if (e is Map) {
            final st = (e['status'] ?? '').toString().toUpperCase();
            if (st == 'CLOSED' || st == 'PICKED UP' || st == 'ISSUED') {
              final id = (e['issueId'] ?? e['issNo'] ?? e['id'] ?? '').toString();
              if (id.isEmpty || pIds.add(id)) {
                pickedUpCount++;
              }
            }
          }
        }
      }

      // 5. Rejected: Rejected or expired requisitions (deduplicated)
      final rIds = <String>{};
      for (final list in [hListVal, reqListVal]) {
        for (final e in list) {
          if (e is Map) {
            final st = (e['status'] ?? '').toString().toUpperCase();
            if (st == 'REJECTED' ||
                st == 'EXPIRED' ||
                st == 'EXPIRED_WEEKLY' ||
                st == 'EXPIRED_MONTH_END' ||
                st == 'REVERTED_APPROVAL') {
              final id = (e['issueId'] ?? e['issNo'] ?? e['id'] ?? '').toString();
              if (id.isEmpty || rIds.add(id)) {
                rejectedCount++;
              }
            }
          }
        }
      }
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 860 : double.infinity,
          maxHeight: maxH,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(22)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: _stroke,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 8),

              // Header bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? 18 : 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Item thumbnail or icon
                    Container(
                      width: isDesktop ? 46 : 40,
                      height: isDesktop ? 46 : 40,
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _stroke),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: widget.item.imageUrl.isNotEmpty
                          ? Image.network(
                              widget.item.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.inventory_2_outlined,
                                color: _ink600,
                                size: isDesktop ? 24 : 20,
                              ),
                            )
                          : Icon(
                              Icons.inventory_2_outlined,
                              color: _ink600,
                              size: isDesktop ? 24 : 20,
                            ),
                    ),
                    SizedBox(width: isDesktop ? 12 : 10),

                    // Item details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.itemName.isNotEmpty
                                ? widget.item.itemName
                                : 'Store Item Details',
                            style: TextStyle(
                              fontSize: isDesktop ? 16 : 14.5,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              if (widget.item.itemCode.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5.5,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _surfaceAlt,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: _stroke),
                                  ),
                                  child: Text(
                                    widget.item.itemCode,
                                    style: TextStyle(
                                      fontSize: isDesktop ? 10.5 : 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: _ink900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                              ],
                              Flexible(
                                child: Text(
                                  widget.item.unit.isNotEmpty
                                      ? 'Unit: ${widget.item.unit} • Activity'
                                      : 'Activity & History',
                                  style: TextStyle(
                                    fontSize: isDesktop ? 11 : 10,
                                    color: _ink600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (((issueMapVal['latestPurchasePrice'] as num?)?.toDouble() ?? widget.item.latestPurchasePrice) > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: Text(
                                    'Rate: ₹${(((issueMapVal['latestPurchasePrice'] as num?)?.toDouble() ?? widget.item.latestPurchasePrice)).toStringAsFixed(2)}/pc',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 10 : 9,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                              if (issueMapVal['stockLots'] is List && (issueMapVal['stockLots'] as List).isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFF86EFAC)),
                                  ),
                                  child: Text(
                                    '${(issueMapVal['stockLots'] as List).length} Lots',
                                    style: TextStyle(
                                      fontSize: isDesktop ? 10 : 9,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF15803D),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Refresh Button
                    IconButton(
                      tooltip: 'Refresh data',
                      icon: Icon(Icons.refresh_rounded, size: isDesktop ? 21 : 19, color: _ink700),
                      onPressed: _refresh,
                      splashRadius: 18,
                    ),

                    // Close Button
                    IconButton(
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, size: isDesktop ? 22 : 20, color: _ink700),
                      onPressed: () => Navigator.of(context).pop(),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1, color: _stroke),

              // Filter & Search Row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _stroke),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          style: const TextStyle(fontSize: 12, color: _ink900),
                          decoration: InputDecoration(
                            hintText: 'Filter by department, user, or requisition #...',
                            hintStyle: const TextStyle(fontSize: 11.5, color: _ink500),
                            prefixIcon: const Icon(Icons.search_rounded, size: 16, color: _ink500),
                            suffixIcon: _searchFilter.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 14, color: _ink600),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {
                                        _searchFilter = '';
                                        _currentPage = 1;
                                      });
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 9),
                          ),
                          onChanged: (val) {
                            setState(() {
                              _searchFilter = val.trim().toLowerCase();
                              _currentPage = 1;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Interactive Segment Tabs (In Cart | Requested | Ready | Picked Up | Rejected Requests)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Container(
                  padding: const EdgeInsets.all(3.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke),
                  ),
                  child: isDesktop
                      ? Row(
                          children: [
                            // Tab 1: In Cart
                            _buildTabButton(
                              tab: ItemBreakdownTab.inCart,
                              icon: Icons.shopping_cart_outlined,
                              label: 'In Cart',
                              count: inCartCount,
                              activeColor: const Color(0xFF1565C0),
                              activeBgColor: const Color(0xFFE3F2FD),
                              expand: true,
                            ),
                            const SizedBox(width: 3),

                            // Tab 2: Requested
                            _buildTabButton(
                              tab: ItemBreakdownTab.requested,
                              icon: Icons.hourglass_top_rounded,
                              label: 'Requested',
                              count: requestedCount,
                              activeColor: const Color(0xFFE65100),
                              activeBgColor: const Color(0xFFFFF3E0),
                              expand: true,
                            ),
                            const SizedBox(width: 3),

                            // Tab 3: Ready for Issue
                            _buildTabButton(
                              tab: ItemBreakdownTab.readyForIssue,
                              icon: Icons.outbox_rounded,
                              label: 'Ready for Issue',
                              count: readyCount,
                              activeColor: const Color(0xFF5E35B1),
                              activeBgColor: const Color(0xFFEDE7F6),
                              expand: true,
                            ),
                            const SizedBox(width: 3),

                            // Tab 4: Picked Up
                            _buildTabButton(
                              tab: ItemBreakdownTab.pickedUp,
                              icon: Icons.check_circle_outline_rounded,
                              label: 'Picked Up',
                              count: pickedUpCount,
                              activeColor: const Color(0xFF2E7D32),
                              activeBgColor: const Color(0xFFE8F5E9),
                              expand: true,
                            ),
                            const SizedBox(width: 3),

                            // Tab 5: Rejected Requests
                            _buildTabButton(
                              tab: ItemBreakdownTab.rejected,
                              icon: Icons.cancel_outlined,
                              label: 'Rejected Requests',
                              count: rejectedCount,
                              activeColor: const Color(0xFFC62828),
                              activeBgColor: const Color(0xFFFFEBEE),
                              expand: true,
                            ),
                          ],
                        )
                      : ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                            },
                          ),
                          child: SingleChildScrollView(
                            controller: _tabScrollCtrl,
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildTabButton(
                                  tab: ItemBreakdownTab.inCart,
                                  icon: Icons.shopping_cart_outlined,
                                  label: 'In Cart',
                                  count: inCartCount,
                                  activeColor: const Color(0xFF1565C0),
                                  activeBgColor: const Color(0xFFE3F2FD),
                                ),
                                const SizedBox(width: 3.5),
                                _buildTabButton(
                                  tab: ItemBreakdownTab.requested,
                                  icon: Icons.hourglass_top_rounded,
                                  label: 'Requested',
                                  count: requestedCount,
                                  activeColor: const Color(0xFFE65100),
                                  activeBgColor: const Color(0xFFFFF3E0),
                                ),
                                const SizedBox(width: 3.5),
                                _buildTabButton(
                                  tab: ItemBreakdownTab.readyForIssue,
                                  icon: Icons.outbox_rounded,
                                  label: 'Ready for Issue',
                                  count: readyCount,
                                  activeColor: const Color(0xFF5E35B1),
                                  activeBgColor: const Color(0xFFEDE7F6),
                                ),
                                const SizedBox(width: 3.5),
                                _buildTabButton(
                                  tab: ItemBreakdownTab.pickedUp,
                                  icon: Icons.check_circle_outline_rounded,
                                  label: 'Picked Up',
                                  count: pickedUpCount,
                                  activeColor: const Color(0xFF2E7D32),
                                  activeBgColor: const Color(0xFFE8F5E9),
                                ),
                                const SizedBox(width: 3.5),
                                _buildTabButton(
                                  tab: ItemBreakdownTab.rejected,
                                  icon: Icons.cancel_outlined,
                                  label: 'Rejected',
                                  count: rejectedCount,
                                  activeColor: const Color(0xFFC62828),
                                  activeBgColor: const Color(0xFFFFEBEE),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),

              // Tab Description banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      _selectedTabs.length == 1
                          ? (_selectedTabs.contains(ItemBreakdownTab.inCart)
                              ? Icons.shopping_cart_outlined
                              : _selectedTabs.contains(ItemBreakdownTab.requested)
                                  ? Icons.hourglass_top_rounded
                                  : _selectedTabs.contains(ItemBreakdownTab.readyForIssue)
                                      ? Icons.outbox_rounded
                                      : _selectedTabs.contains(ItemBreakdownTab.pickedUp)
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.cancel_outlined)
                          : Icons.tune_rounded,
                      size: 13,
                      color: _ink600,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        _selectedTabs.length == 1
                            ? (_selectedTabs.contains(ItemBreakdownTab.inCart)
                                ? 'Users who currently hold this item in their cart with active reservation timers.'
                                : _selectedTabs.contains(ItemBreakdownTab.requested)
                                    ? 'Active department requisitions awaiting manager/store approval.'
                                    : _selectedTabs.contains(ItemBreakdownTab.readyForIssue)
                                        ? 'Approved items currently waiting at the store counter for recipient pickup.'
                                        : _selectedTabs.contains(ItemBreakdownTab.pickedUp)
                                            ? 'Items successfully handed over and physically collected by departments.'
                                            : 'Requisitions rejected by authority or automatically expired without approval.')
                            : 'Multi-filter active (${_selectedTabs.length} stages): ${_getSelectedTabsSummary()}.',
                        style: const TextStyle(
                          fontSize: 11,
                          color: _ink600,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (_selectedTabs.length == 5) {
                            _selectedTabs = {ItemBreakdownTab.inCart};
                          } else {
                            _selectedTabs = {
                              ItemBreakdownTab.inCart,
                              ItemBreakdownTab.requested,
                              ItemBreakdownTab.readyForIssue,
                              ItemBreakdownTab.pickedUp,
                              ItemBreakdownTab.rejected,
                            };
                          }
                          _currentPage = 1;
                        });
                        if (_listScrollCtrl.hasClients) {
                          _listScrollCtrl.jumpTo(0);
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        child: Text(
                          _selectedTabs.length == 5 ? 'Reset' : 'Select All',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Content Area
              Expanded(
                child: _buildTabContent(
                  cartAsync: cartBreakdownAsync,
                  issueAsync: issueBreakdownAsync,
                  currentUid: currentUid,
                  inCartCount: inCartCount,
                  requestedCount: requestedCount,
                  readyCount: readyCount,
                  pickedUpCount: pickedUpCount,
                  rejectedCount: rejectedCount,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required ItemBreakdownTab tab,
    required IconData icon,
    required String label,
    required int count,
    required Color activeColor,
    required Color activeBgColor,
    bool expand = false,
  }) {
    final isSelected = _selectedTabs.contains(tab);
    final isDesktop = MediaQuery.of(context).size.width >= 600;

    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: () => _toggleTab(tab, isDesktop),
        onLongPress: () {
          setState(() {
            _selectedTabs = {tab};
            _currentPage = 1;
          });
          if (_listScrollCtrl.hasClients) {
            _listScrollCtrl.jumpTo(0);
          }
          if (!isDesktop) {
            _scrollToTab(tab);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: isDesktop ? 6.5 : 7,
            horizontal: isDesktop ? 8 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.28)
                  : Colors.transparent,
              width: 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: isDesktop ? 12 : 11,
                  color: activeColor,
                ),
                const SizedBox(width: 3),
              ],
              Icon(
                icon,
                size: isDesktop ? 13 : 13.5,
                color: isSelected ? activeColor : _ink600,
              ),
              const SizedBox(width: 4.5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isDesktop ? 11 : 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? activeColor : _ink700,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeBgColor
                      : Colors.black.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: isDesktop ? 10 : 10.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? activeColor : _ink700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (expand) {
      return Expanded(child: btn);
    }
    return btn;
  }

  Widget _buildTabContent({
    required AsyncValue<List<Map<String, dynamic>>> cartAsync,
    required AsyncValue<Map<String, dynamic>> issueAsync,
    required String currentUid,
    required int inCartCount,
    required int requestedCount,
    required int readyCount,
    int pickedUpCount = 0,
    int rejectedCount = 0,
  }) {
    // When both are loading
    if (cartAsync.isLoading && issueAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    final cartList = cartAsync.valueOrNull ?? [];
    final issueMap = issueAsync.valueOrNull ?? {};

    final rawRequested = issueMap['requested'];
    final requestedList = (rawRequested is List)
        ? rawRequested
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final rawReady = issueMap['readyForIssue'];
    final readyList = (rawReady is List)
        ? rawReady
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final rawHistory = issueMap['history'];
    final historyList = (rawHistory is List)
        ? rawHistory
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    // Filter helper
    bool matchesFilter(Map<String, dynamic> item) {
      if (_searchFilter.isEmpty) return true;
      final dept = (item['department'] ?? '').toString().toLowerCase();
      final user = (item['userName'] ?? '').toString().toLowerCase();
      final issNo = (item['issNo'] ?? '').toString().toLowerCase();
      final reason = (item['reason'] ?? '').toString().toLowerCase();
      return dept.contains(_searchFilter) ||
          user.contains(_searchFilter) ||
          issNo.contains(_searchFilter) ||
          reason.contains(_searchFilter);
    }

    // Build comprehensive cart entries (active + auto-reverts + removals + requisitions moved from cart)
    final allCartEntries = <Map<String, dynamic>>[];
    for (final c in cartList) {
      final isExp = c['isExpired'] == true;
      final isTrans = c['status'] == 'CART_REQUESTED' ||
          c['revertType'] == 'TRANSFERRED_TO_REQUESTED';
      final isRem = c['status'] == 'CART_REMOVED' ||
          c['revertType'] == 'MANUAL_REMOVED';
      String subType = 'inCart';
      if (isTrans) {
        subType = 'cartRequested';
      } else if (isExp) {
        subType = isRem ? 'cartRemoved' : 'cartExpired';
      }
      allCartEntries.add({...c, '_type': subType});
    }

    final existingIssueIds = allCartEntries
        .map((c) => c['issueId']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet();

    for (final r in requestedList) {
      final iId = r['issueId']?.toString() ?? '';
      if (iId.isNotEmpty && existingIssueIds.contains(iId)) continue;
      allCartEntries.add({
        'issueId': r['issueId'],
        'issNo': r['issNo'],
        'userId': r['userId'],
        'userName': r['userName'],
        'department': r['department'],
        'quantity': r['quantity'],
        'addedAt': r['addedAt'] ?? r['createdAt'],
        'revertedAt': r['createdAt'],
        'createdAt': r['createdAt'],
        'status': 'CART_REQUESTED',
        '_type': 'cartRequested',
        'remark': 'Transferred from Cart to Requisition #${r['issNo'] ?? ''}',
        'reason': r['reason'],
      });
    }

    final combined = <Map<String, dynamic>>[];
    final seenKeys = <String>{};

    void addRecords(List<Map<String, dynamic>> records) {
      for (final r in records) {
        final type = r['_type']?.toString() ?? '';
        final id = (r['issueId'] ?? r['issNo'] ?? r['id'] ?? r['userId'] ?? '').toString();
        final time = (r['revertedAt'] ?? r['rejectedAt'] ?? r['issuedAt'] ?? r['createdAt'] ?? r['addedAt'] ?? '').toString();
        final key = '${type}_${id}_$time';
        if (seenKeys.add(key)) {
          combined.add(r);
        }
      }
    }

    // 1. In Cart
    if (_selectedTabs.contains(ItemBreakdownTab.inCart)) {
      if (_selectedTabs.contains(ItemBreakdownTab.requested)) {
        addRecords(allCartEntries.where((c) {
          final type = c['_type']?.toString() ?? 'inCart';
          return type == 'inCart' || type == 'cartExpired' || type == 'cartRemoved';
        }).toList());
      } else {
        addRecords(allCartEntries);
      }
    }

    // 2. Requested
    if (_selectedTabs.contains(ItemBreakdownTab.requested)) {
      final pendingReq = requestedList.where((r) {
        final st = (r['status'] ?? '').toString().toUpperCase();
        final isPending = r['isPending'] == true;
        return (isPending || st == 'DRAFT' || st == 'REQUESTED') &&
            st != 'REJECTED' &&
            st != 'CLOSED' &&
            st != 'PICKED UP' &&
            st != 'EXPIRED_WEEKLY';
      }).map((r) => {...r, '_type': 'requested'}).toList();
      addRecords(pendingReq);
    }

    // 3. Ready for Issue
    if (_selectedTabs.contains(ItemBreakdownTab.readyForIssue)) {
      final activeReady = readyList.where((rd) {
        final st = (rd['status'] ?? '').toString().toUpperCase();
        return (rd['isPending'] == true || st == 'APPROVED') &&
            st != 'CLOSED' &&
            st != 'PICKED UP' &&
            st != 'REVERTED_APPROVAL' &&
            st != 'EXPIRED_MONTH_END';
      }).map((rd) => {...rd, '_type': 'readyForIssue'}).toList();
      addRecords(activeReady);
    }

    // 4. Picked Up
    if (_selectedTabs.contains(ItemBreakdownTab.pickedUp)) {
      final pickedUpMap = <String, Map<String, dynamic>>{};
      for (final list in [historyList, readyList, requestedList]) {
        for (final e in list) {
          final st = (e['status'] ?? '').toString().toUpperCase();
          if (st == 'CLOSED' || st == 'PICKED UP' || st == 'ISSUED') {
            final key = (e['issueId'] ?? e['issNo'] ?? e['id'] ?? UniqueKey().toString()).toString();
            pickedUpMap.putIfAbsent(key, () => {...e, '_type': 'issued'});
          }
        }
      }
      addRecords(pickedUpMap.values.toList());
    }

    // 5. Rejected
    if (_selectedTabs.contains(ItemBreakdownTab.rejected)) {
      final rejectedMap = <String, Map<String, dynamic>>{};
      for (final list in [historyList, requestedList]) {
        for (final e in list) {
          final st = (e['status'] ?? '').toString().toUpperCase();
          if (st == 'REJECTED' ||
              st == 'EXPIRED' ||
              st == 'EXPIRED_WEEKLY' ||
              st == 'EXPIRED_MONTH_END' ||
              st == 'REVERTED_APPROVAL') {
            final key = (e['issueId'] ?? e['issNo'] ?? e['id'] ?? UniqueKey().toString()).toString();
            String subType = 'rejected';
            if (st == 'EXPIRED_WEEKLY' || st == 'EXPIRED') {
              subType = 'expiredWeekly';
            } else if (st == 'EXPIRED_MONTH_END') {
              subType = 'expiredMonthEnd';
            } else if (st == 'REVERTED_APPROVAL') {
              subType = 'revertedApproval';
            }
            rejectedMap.putIfAbsent(key, () => {...e, '_type': subType});
          }
        }
      }
      addRecords(rejectedMap.values.toList());
    }

    // Fallback for History tab if ever invoked
    if (_selectedTabs.contains(ItemBreakdownTab.history)) {
      final historyMap = <String, Map<String, dynamic>>{};
      for (final h in historyList) {
        final st = (h['status'] ?? '').toString().toUpperCase();
        String subType = 'issued';
        if (st == 'REJECTED') {
          subType = 'rejected';
        } else if (st == 'EXPIRED_WEEKLY') {
          subType = 'expiredWeekly';
        } else if (st == 'EXPIRED_MONTH_END') {
          subType = 'expiredMonthEnd';
        } else if (st == 'REVERTED_APPROVAL') {
          subType = 'revertedApproval';
        }
        final key = (h['issueId'] ?? h['issNo'] ?? h['id'] ?? UniqueKey().toString()).toString();
        historyMap.putIfAbsent(key, () => {...h, '_type': subType});
      }
      addRecords(historyMap.values.toList());
    }

    DateTime parseRecordDate(Map<String, dynamic> item) {
      final raw = item['revertedAt'] ??
          item['rejectedAt'] ??
          item['issuedAt'] ??
          item['approvedAt'] ??
          item['createdAt'] ??
          item['addedAt'];
      if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }

    combined.sort((a, b) => parseRecordDate(b).compareTo(parseRecordDate(a)));

    final filtered = combined.where(matchesFilter).toList();

    if (filtered.isEmpty) {
      if (_searchFilter.isNotEmpty) {
        return _buildEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No Matching Activity',
          subtitle: 'No records match "$_searchFilter" in the selected stages.',
        );
      }
      if (_selectedTabs.length == 1) {
        final single = _selectedTabs.first;
        switch (single) {
          case ItemBreakdownTab.inCart:
            return _buildEmptyState(
              icon: Icons.remove_shopping_cart_outlined,
              title: 'No Items Currently In Cart',
              subtitle: 'None of the departments currently hold this item in their cart or have cart history.',
            );
          case ItemBreakdownTab.requested:
            return _buildEmptyState(
              icon: Icons.hourglass_empty_rounded,
              title: 'No Pending Requisitions',
              subtitle: 'There are currently no active requisitions waiting for approval for this item.',
            );
          case ItemBreakdownTab.readyForIssue:
            return _buildEmptyState(
              icon: Icons.outbox_outlined,
              title: 'No Items Ready for Issue',
              subtitle: 'There are no approved items waiting at the store counter for recipient pickup.',
            );
          case ItemBreakdownTab.pickedUp:
            return _buildEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'No Items Picked Up Yet',
              subtitle: 'No requisitions for this item have been physically collected or issued yet.',
            );
          case ItemBreakdownTab.rejected:
            return _buildEmptyState(
              icon: Icons.cancel_outlined,
              title: 'No Rejected Requisitions',
              subtitle: 'No requisitions have been rejected by managers or expired.',
            );
          default:
            return _buildEmptyState(
              icon: Icons.history_rounded,
              title: 'No Past Requests or Decisions',
              subtitle: 'No requisitions for this item have been completed, issued, reverted, or rejected yet.',
            );
        }
      }
      return _buildEmptyState(
        icon: Icons.filter_list_off_rounded,
        title: 'No Records for Selected Stages',
        subtitle: 'No activity found matching the selected stages: ${_getSelectedTabsSummary()}.',
      );
    }

    final totalRecords = filtered.length;
    final totalPages = (totalRecords / _pageSize).ceil().clamp(1, 9999);
    final safeCurrentPage = _currentPage.clamp(1, totalPages);
    final startIndex = (safeCurrentPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize).clamp(0, totalRecords);
    final pageItems = filtered.sublist(startIndex, endIndex);

    final isDesktop = MediaQuery.of(context).size.width >= 600;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            controller: _listScrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            itemCount: pageItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final itemData = pageItems[i];
              final type = itemData['_type']?.toString() ?? 'inCart';
              return _buildProgressiveItemCard(itemData, currentUid, type);
            },
          ),
        ),
        _buildPaginationBar(
          totalRecords: totalRecords,
          totalPages: totalPages,
          currentPage: safeCurrentPage,
          startIndex: startIndex,
          endIndex: endIndex,
          isDesktop: isDesktop,
        ),
      ],
    );
  }

  Widget _buildPaginationBar({
    required int totalRecords,
    required int totalPages,
    required int currentPage,
    required int startIndex,
    required int endIndex,
    required bool isDesktop,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 18 : 12,
        vertical: 8,
      ),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(
          top: BorderSide(color: _stroke, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              isDesktop
                  ? 'Showing ${startIndex + 1}–$endIndex of $totalRecords records'
                  : '${startIndex + 1}–$endIndex of $totalRecords',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: _ink600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prev Button
              InkWell(
                onTap: currentPage > 1 ? () => _goToPage(currentPage - 1) : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentPage > 1
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: currentPage > 1
                          ? _stroke
                          : _stroke.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        size: 16,
                        color: currentPage > 1
                            ? _ink900
                            : _ink500.withValues(alpha: 0.5),
                      ),
                      if (isDesktop) ...[
                        const SizedBox(width: 2),
                        Text(
                          'Prev',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: currentPage > 1
                                ? _ink900
                                : _ink500.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Page chips or indicator
              if (isDesktop && totalPages <= 6)
                ...List.generate(totalPages, (index) {
                  final pageNum = index + 1;
                  final isCurrent = pageNum == currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: InkWell(
                      onTap: () => _goToPage(pageNum),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent ? _ink900 : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isCurrent ? _ink900 : _stroke,
                          ),
                        ),
                        child: Text(
                          '$pageNum',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            color: isCurrent ? Colors.white : _ink700,
                          ),
                        ),
                      ),
                    ),
                  );
                })
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _stroke),
                  ),
                  child: Text(
                    isDesktop
                        ? 'Page $currentPage of $totalPages'
                        : 'P. $currentPage/$totalPages',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _ink900,
                    ),
                  ),
                ),
              const SizedBox(width: 6),

              // Next Button
              InkWell(
                onTap: currentPage < totalPages
                    ? () => _goToPage(currentPage + 1)
                    : null,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: currentPage < totalPages
                        ? const Color(0xFFF3F4F6)
                        : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: currentPage < totalPages
                          ? _stroke
                          : _stroke.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDesktop) ...[
                        const SizedBox(width: 2),
                        Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: currentPage < totalPages
                                ? _ink900
                                : _ink500.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(width: 2),
                      ],
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: currentPage < totalPages
                            ? _ink900
                            : _ink500.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Progressive Disclosure Card:
  /// Level 1: Minimal, clean, clutter-free summary row.
  /// Level 2: Expanded vertical event timeline on tap.
  Widget _buildProgressiveItemCard(
    Map<String, dynamic> data,
    String currentUid,
    String type,
  ) {
    final isDesktop = MediaQuery.of(context).size.width >= 600;
    final cardId =
        '${type}_${data['issueId'] ?? data['userId']}_${data['revertedAt'] ?? data['rejectedAt'] ?? data['issuedAt'] ?? data['createdAt'] ?? data['addedAt']}';
    final isExpanded = _expandedKeys.contains(cardId);

    final userId = (data['userId'] ?? '').toString();
    final userName = (data['userName'] ?? 'User').toString();
    final rawDept =
        (data['department'] ?? 'General Operations').toString().trim();
    final dept =
        (rawDept.isEmpty || RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawDept))
            ? 'General Operations'
            : rawDept;
    final qty = data['quantity'] ?? 1;
    final issNo = (data['issNo'] ?? '').toString();
    final isMe = userId.isNotEmpty && userId == currentUid;

    // Theme colors and labels by type
    Color primaryColor;
    Color bgColor;
    Color borderColor;
    String statusLabel;
    IconData statusIcon;

    switch (type) {
      case 'inCart':
        primaryColor = const Color(0xFF1565C0);
        bgColor = const Color(0xFFE3F2FD);
        borderColor = const Color(0xFF90CAF9);
        statusLabel = 'IN CART';
        statusIcon = Icons.shopping_cart_outlined;
        break;
      case 'cartRequested':
        primaryColor = const Color(0xFF0277BD);
        bgColor = const Color(0xFFE1F5FE);
        borderColor = const Color(0xFF81D4FA);
        statusLabel = 'MOVED TO REQUESTED';
        statusIcon = Icons.send_rounded;
        break;
      case 'cartExpired':
        primaryColor = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFB74D);
        statusLabel = 'TIME LIMIT EXCEEDED (5m)';
        statusIcon = Icons.timer_off_outlined;
        break;
      case 'cartRemoved':
        primaryColor = const Color(0xFF546E7A);
        bgColor = const Color(0xFFECEFF1);
        borderColor = const Color(0xFFCFD8DC);
        statusLabel = 'MANUALLY REMOVED';
        statusIcon = Icons.remove_shopping_cart_outlined;
        break;
      case 'requested':
        final isPending = data['isPending'] != false;
        primaryColor = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFFB74D);
        statusLabel = isPending ? 'PENDING APPROVAL' : 'REQUISITION RAISED';
        statusIcon = Icons.hourglass_top_rounded;
        break;
      case 'readyForIssue':
        final isPending = data['isPending'] != false;
        primaryColor = const Color(0xFF5E35B1);
        bgColor = const Color(0xFFEDE7F6);
        borderColor = const Color(0xFFB39DDB);
        statusLabel = isPending ? 'READY FOR ISSUE' : 'COUNTER QUEUE';
        statusIcon = Icons.outbox_rounded;
        break;
      case 'rejected':
        primaryColor = const Color(0xFFC62828);
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFFFCDD2);
        statusLabel = 'REJECTED';
        statusIcon = Icons.cancel_outlined;
        break;
      case 'expiredWeekly':
        primaryColor = const Color(0xFFD84315);
        bgColor = const Color(0xFFFBE9E7);
        borderColor = const Color(0xFFFFCCBC);
        statusLabel = 'AUTO-REVERT (WEEKLY 7D)';
        statusIcon = Icons.history_toggle_off_rounded;
        break;
      case 'expiredMonthEnd':
        primaryColor = const Color(0xFFC2185B);
        bgColor = const Color(0xFFFCE4EC);
        borderColor = const Color(0xFFF8BBD0);
        statusLabel = 'AUTO-REVERT (MONTHLY)';
        statusIcon = Icons.event_busy_rounded;
        break;
      case 'revertedApproval':
        primaryColor = const Color(0xFF6A1B9A);
        bgColor = const Color(0xFFF3E5F5);
        borderColor = const Color(0xFFE1BEE7);
        statusLabel = 'APPROVAL REVERTED';
        statusIcon = Icons.replay_rounded;
        break;
      case 'issued':
      default:
        primaryColor = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFFA5D6A7);
        statusLabel = 'ISSUED';
        statusIcon = Icons.check_circle_outline_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded
              ? primaryColor.withValues(alpha: 0.6)
              : (isMe ? primaryColor : _stroke),
          width: isExpanded || isMe ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1.5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleExpanded(cardId),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 12 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEVEL 1: Clean summary row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Requester / Department Avatar
                    CircleAvatar(
                      radius: isDesktop ? 19 : 16.5,
                      backgroundColor: bgColor,
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          fontSize: isDesktop ? 14 : 12,
                        ),
                      ),
                    ),
                    SizedBox(width: isDesktop ? 10 : 8),

                    // User name, Department & Status
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  userName,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 13 : 12,
                                    fontWeight: FontWeight.w800,
                                    color: _ink900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4.5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'YOU',
                                    style: TextStyle(
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(width: 6),
                              // Status Chip
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(statusIcon,
                                        size: 9.5, color: primaryColor),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        statusLabel,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              // Department Pill
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: _stroke),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.business_center_outlined,
                                      size: 9.5,
                                      color: _ink700,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      dept,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: _ink700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (issNo.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text(
                                  '#$issNo',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink600,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Time / Relative
                              Text(
                                _formatTimeAgo(data['revertedAt'] ??
                                    data['rejectedAt'] ??
                                    data['issuedAt'] ??
                                    data['approvedAt'] ??
                                    data['createdAt'] ??
                                    data['addedAt']),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: _ink600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: isDesktop ? 8 : 6),

                    // Quantity Badge
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 8 : 6.5,
                          vertical: isDesktop ? 5 : 4),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$qty',
                            style: TextStyle(
                              fontSize: isDesktop ? 14 : 12.5,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            widget.item.unit.isNotEmpty
                                ? widget.item.unit
                                : 'PCS',
                            style: TextStyle(
                              fontSize: isDesktop ? 9 : 8.5,
                              fontWeight: FontWeight.w700,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (data['unitPrice'] != null &&
                        (data['unitPrice'] as num) > 0) ...[
                      SizedBox(width: isDesktop ? 6 : 4),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 7 : 5.5,
                            vertical: isDesktop ? 4 : 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF86EFAC)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '₹${(data['unitPrice'] as num).toDouble().toStringAsFixed((data['unitPrice'] as num).toDouble() % 1 == 0 ? 0 : 2)}/pc',
                              style: TextStyle(
                                fontSize: isDesktop ? 12 : 10.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF166534),
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'OLD STOCK RATE',
                              style: TextStyle(
                                fontSize: isDesktop ? 8 : 7.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    SizedBox(width: isDesktop ? 6 : 4),

                    // Expand / Collapse Chevron
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: isDesktop ? 18 : 16,
                      color: _ink600,
                    ),
                  ],
                ),

                // Sub-hint when collapsed
                if (!isExpanded) ...[
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        'Tap to view event lifecycle timeline',
                        style: TextStyle(
                          fontSize: 9.5,
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          size: 12, color: primaryColor),
                    ],
                  ),
                ],

                // LEVEL 2: Expanded Chronological Event Timeline
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: _stroke),
                  const SizedBox(height: 10),

                  // Header of timeline
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded,
                          size: 14, color: _ink700),
                      const SizedBox(width: 5),
                      const Text(
                        'Request Lifecycle Timeline',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Dept: $dept',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _ink600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Event Steps
                  _buildTimelineStepper(data, type),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Visual vertical event stepper with complete auto-revert, approval, rejection, and issue history
  Widget _buildTimelineStepper(Map<String, dynamic> data, String type) {
    final issNo = (data['issNo'] ?? '').toString();
    final reason = (data['reason'] ?? '').toString();
    final remark = (data['remark'] ?? '').toString();
    final userName = (data['userName'] ?? 'User').toString();
    final rawDept =
        (data['department'] ?? 'General Operations').toString().trim();
    final dept =
        (rawDept.isEmpty || RegExp(r'^[0-9a-fA-F]{24}$').hasMatch(rawDept))
            ? 'General Operations'
            : rawDept;
    final approvedByName = (data['approvedByName'] ?? '').toString();
    final rejectedByName = (data['rejectedByName'] ?? '').toString();
    final reverterName = (data['revertedByName'] ?? '').toString();
    final issuedByName = (data['issuedByName'] ?? '').toString();

    final addedAt = data['addedAt'];
    final createdAt = data['createdAt'];
    final approvedAt = data['approvedAt'];
    final rejectedAt = data['rejectedAt'];
    final revertedAt = data['revertedAt'];
    final issuedAt = data['issuedAt'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          // =================== CASE: CART REQUESTED ===================
          if (type == 'cartRequested') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
              note: 'Item reserved in cart by requester',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.send_rounded,
              iconColor: const Color(0xFF0277BD),
              title: issNo.isNotEmpty
                  ? 'Transferred to Requisition #$issNo'
                  : 'Transferred to Requisition',
              actorText: 'Submitted by $userName ($dept)',
              dateTimeText: revertedAt != null
                  ? _formatDateTime(revertedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Submitted'),
              note:
                  'Item moved from Cart to Requisition #${issNo.isNotEmpty ? issNo : ""}. Soft-locked in pending approval state.',
            ),
          ]

          // ======================= CASE 1: IN CART =======================
          else if (type == 'inCart') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Initial cart hold'),
              note: data['remainingSeconds'] != null &&
                      (data['remainingSeconds'] as int) > 0
                  ? 'Cart hold active (~${((data['remainingSeconds'] as int) / 60).ceil()}m remaining)'
                  : 'Currently held in cart with 5-minute auto-release policy',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: false,
              icon: Icons.pending_actions_rounded,
              iconColor: _ink500,
              title: 'Awaiting Requisition Checkout',
              actorText:
                  'Requester $userName must submit requisition before 5-minute timeout',
              dateTimeText: 'In Progress',
              note: 'Unsubmitted holds auto-revert to stock after 5 minutes',
            ),
          ]

          // =================== CASE 2: CART EXPIRED (5m) ===================
          else if (type == 'cartExpired') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : 'Cart reservation initiated',
              note: '5-minute cart hold policy applied',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.timer_off_outlined,
              iconColor: const Color(0xFFE65100),
              title: 'Auto-Revert: 5 Minutes Time Limit Exceeded',
              actorText: 'System Cart Retention Engine',
              dateTimeText: revertedAt != null
                  ? _formatDateTime(revertedAt)
                  : '5m Time Limit Exceeded',
              note: remark.isNotEmpty
                  ? remark
                  : 'Auto-revert: 5 minutes cart hold time limit exceeded. Reserved stock returned to store availability.',
            ),
          ]

          // =================== CASE 3: CART REMOVED ===================
          else if (type == 'cartRemoved') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : 'Reserved in cart',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.remove_shopping_cart_outlined,
              iconColor: const Color(0xFF546E7A),
              title: 'Manually Removed from Cart',
              actorText: 'Removed by $userName ($dept)',
              dateTimeText:
                  revertedAt != null ? _formatDateTime(revertedAt) : 'Removed',
              note: remark.isNotEmpty
                  ? remark
                  : 'Item manually removed from cart by requester before requisition was submitted.',
            ),
          ]

          // ===================== CASE 4: REQUESTED =====================
          else if (type == 'requested') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
              note: reason.isNotEmpty
                  ? 'Reason: $reason'
                  : 'Stock soft-locked for approval',
            ),
            if (data['isPending'] == false && approvedByName.isNotEmpty) ...[
              _buildTimelineItem(
                isLast: true,
                isCompleted: true,
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF2E7D32),
                title: 'Requisition Approved',
                actorText: 'Approved by $approvedByName',
                dateTimeText: approvedAt != null
                    ? _formatDateTime(approvedAt)
                    : 'Approved',
                note: 'Approved for counter dispatch',
              ),
            ] else ...[
              _buildTimelineItem(
                isLast: true,
                isCompleted: false,
                icon: Icons.pending_actions_rounded,
                iconColor: _ink500,
                title: 'Awaiting Manager Decision',
                actorText:
                    'Pending review by department manager or store admin',
                dateTimeText: 'Pending Review',
                note: 'Weekly auto-revert timeline: 7 days without decision',
              ),
            ],
          ]

          // ================== CASE 5: READY FOR ISSUE ==================
          else if (type == 'readyForIssue') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
              note: reason.isNotEmpty ? 'Reason: $reason' : null,
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Requisition Approved',
              actorText: approvedByName.isNotEmpty
                  ? 'Approved by $approvedByName'
                  : 'Approved by Management',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Approved',
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.outbox_rounded,
              iconColor: const Color(0xFF5E35B1),
              title: 'Ready for Counter Issue',
              actorText: 'Reserved stock waiting at store counter',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'At Counter',
              note: 'Recipient department notified for collection',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: false,
              icon: Icons.assignment_late_outlined,
              iconColor: _ink500,
              title: 'Counter Handover Pending',
              actorText:
                  'Awaiting recipient $userName to collect at store counter',
              dateTimeText: 'Waiting Pickup',
              note: 'Unclaimed items held until month-end inventory timeline',
            ),
          ]

          // ===================== CASE 6: REJECTED =====================
          else if (type == 'rejected') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
              note: reason.isNotEmpty ? 'Reason: $reason' : null,
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.cancel_rounded,
              iconColor: const Color(0xFFC62828),
              title: 'Requisition Rejected',
              actorText: rejectedByName.isNotEmpty
                  ? 'Rejected by $rejectedByName'
                  : 'Rejected by Management',
              dateTimeText: rejectedAt != null
                  ? _formatDateTime(rejectedAt)
                  : 'Rejected',
              note: remark.isNotEmpty
                  ? 'Rejection note: $remark'
                  : (reason.isNotEmpty
                      ? 'Reason: $reason'
                      : 'Request declined. Stock soft-lock released.'),
            ),
          ]

          // ============== CASE 7: EXPIRED WEEKLY (7 DAYS) ==============
          else if (type == 'expiredWeekly') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
              note: reason.isNotEmpty ? 'Reason: $reason' : null,
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.history_toggle_off_rounded,
              iconColor: const Color(0xFFD84315),
              title: 'Auto-Revert: Weekly (7 Days) Timeline Reached',
              actorText: 'System Auto-Revert Engine',
              dateTimeText: revertedAt != null
                  ? _formatDateTime(revertedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : '7d Reached'),
              note: remark.isNotEmpty
                  ? remark
                  : 'Auto-revert: Weekly (7 days) requisition timeline reached without approval. Reserved stock restored.',
            ),
          ]

          // ============ CASE 8: EXPIRED MONTH END UNCLAIMED ============
          else if (type == 'expiredMonthEnd') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Requisition Approved',
              actorText: approvedByName.isNotEmpty
                  ? 'Approved by $approvedByName'
                  : 'Approved by Management',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Approved',
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.outbox_rounded,
              iconColor: const Color(0xFF5E35B1),
              title: 'Ready for Counter Issue',
              actorText: 'Placed at store counter for pickup',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Counter Stock',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.event_busy_rounded,
              iconColor: const Color(0xFFC2185B),
              title: 'Auto-Revert: Monthly Unclaimed Timeline Reached',
              actorText: 'Store Month-End Clearance System',
              dateTimeText: revertedAt != null
                  ? _formatDateTime(revertedAt)
                  : 'Month-End Timeline Reached',
              note: remark.isNotEmpty
                  ? remark
                  : 'Auto-revert: Monthly unclaimed timeline reached at store counter. Stock returned to shelf.',
            ),
          ]

          // ================ CASE 9: REVERTED APPROVAL ================
          else if (type == 'revertedApproval') ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Requisition Approved',
              actorText: approvedByName.isNotEmpty
                  ? 'Approved by $approvedByName'
                  : 'Approved by Management',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Approved',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.replay_rounded,
              iconColor: const Color(0xFF6A1B9A),
              title: 'Approval Reverted by Authority',
              actorText: reverterName.isNotEmpty
                  ? 'Reverted by $reverterName'
                  : 'Reverted by Management',
              dateTimeText: revertedAt != null
                  ? _formatDateTime(revertedAt)
                  : 'Reverted',
              note: remark.isNotEmpty
                  ? remark
                  : 'Requisition approval revoked; reserved stock returned to general inventory.',
            ),
          ]

          // ===================== CASE 10: ISSUED =====================
          else ...[
            _buildTimelineItem(
              isFirst: true,
              isCompleted: true,
              icon: Icons.shopping_cart_outlined,
              iconColor: const Color(0xFF1565C0),
              title: 'Added to Cart',
              actorText: 'By $userName • $dept',
              dateTimeText: addedAt != null
                  ? _formatDateTime(addedAt)
                  : (createdAt != null
                      ? _formatDateTime(createdAt)
                      : 'Cart hold'),
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFE65100),
              title: issNo.isNotEmpty
                  ? 'Requisition Requested #$issNo'
                  : 'Requisition Requested',
              actorText: 'Requested by $userName ($dept)',
              dateTimeText:
                  createdAt != null ? _formatDateTime(createdAt) : 'Submitted',
              note: reason.isNotEmpty ? 'Reason: $reason' : null,
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.check_circle_rounded,
              iconColor: const Color(0xFF2E7D32),
              title: 'Requisition Approved',
              actorText: approvedByName.isNotEmpty
                  ? 'Approved by $approvedByName'
                  : 'Approved by Management',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Approved',
            ),
            _buildTimelineItem(
              isCompleted: true,
              icon: Icons.outbox_rounded,
              iconColor: const Color(0xFF5E35B1),
              title: 'Ready for Counter Issue',
              actorText: 'Dispatched to store issue counter',
              dateTimeText: approvedAt != null
                  ? _formatDateTime(approvedAt)
                  : 'Ready',
            ),
            _buildTimelineItem(
              isLast: true,
              isCompleted: true,
              icon: Icons.assignment_turned_in_rounded,
              iconColor: const Color(0xFF00796B),
              title: 'Physically Issued to Recipient',
              actorText: issuedByName.isNotEmpty
                  ? 'Handed over by $issuedByName to $userName'
                  : 'Handed over at store counter to $userName',
              dateTimeText:
                  issuedAt != null ? _formatDateTime(issuedAt) : 'Issued',
              note: () {
                final baseNote = data['racks'] != null &&
                        (data['racks'] is List) &&
                        (data['racks'] as List).isNotEmpty
                    ? 'From: ${(data['racks'] as List).map((r) => r['rackName'] ?? '').join(', ')}'
                    : 'Stock transferred and issue closed';
                final uPrice = (data['unitPrice'] as num?)?.toDouble() ?? 0.0;
                final tPrice = (data['totalPrice'] as num?)?.toDouble() ?? 0.0;
                final qty = data['quantity'] ?? 1;
                if (uPrice > 0) {
                  final totalStr = tPrice > 0
                      ? tPrice.toStringAsFixed(2)
                      : (uPrice * qty).toStringAsFixed(2);
                  return '$baseNote\n• Issued from Old Stock first: $qty pcs @ ₹${uPrice.toStringAsFixed(2)}/pc (Total: ₹$totalStr)';
                }
                return baseNote;
              }(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    bool isFirst = false,
    bool isLast = false,
    required bool isCompleted,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String actorText,
    required String dateTimeText,
    String? note,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Icon and Vertical Line
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isCompleted ? iconColor.withValues(alpha: 0.15) : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCompleted ? iconColor : _stroke,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 11,
                    color: isCompleted ? iconColor : _ink500,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: isCompleted ? iconColor.withValues(alpha: 0.4) : _stroke,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Step Details
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 2 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isCompleted ? _ink900 : _ink600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dateTimeText,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: isCompleted ? iconColor : _ink500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    actorText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: _ink700,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isCompleted ? _ink600 : _ink500,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(29),
              ),
              child: Icon(icon, size: 28, color: _ink500),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _ink900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: _ink600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
