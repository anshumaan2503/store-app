// issues_list_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/auth_controller.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/domains/models/auth_model.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../domains/models/store_issue_model.dart';
import '../../widgets/store_ui_state_widgets.dart';
import 'issue_create_page.dart';
import 'issue_find_items_page.dart';
import 'issue_scan_page.dart';
import 'qr_code_issue/item_issue_verify_scan_page.dart';
import 'qr_code_issue/qr_scanner_item_issue_page.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../../../controllers/store_cart_controller.dart';
import '../cart/store_cart_page.dart';
import '../items/find_item_page.dart';

/* ---------------- Palette (matches your theme) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _ink500 = Color(0xFFA89F91);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentMint = Color(0xFFB6D3CC);
// const _accentBlueBorder = Color(0xFFB9C7FF);
// const _accentGreenBorder = Color(0xFFBFE6D6);

const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

/* ---------------- helpers ---------------- */
int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

// String _st(dynamic v) => (v ?? '').toString().trim().toUpperCase();

// bool _isClosedLike(String st) => st.contains('CANCEL');

/// Remaining to approve (requested - approved - approvedReject)
int _remainApprove(IssueLine l) => math.max(
  0,
  _i(l.requestedQty) - _i(l.approvedQty) - _i(l.approvedRejectQty),
);

/// Remaining to issue (approved - issued - issuedReject)
// int _remainIssue(IssueLine l) =>
//     math.max(0, _i(l.approvedQty) - _i(l.issuedQty) - _i(l.issuedRejectQty));

// /// Remaining to return (issued - (returned + scrap))
// int _remainReturn(IssueLine l) =>
//     math.max(0, _i(l.issuedQty) - (_i(l.returnQty) + _i(l.scrapQty)));

// /// ✅ FIX: was IssueCardUi (undefined) -> IssueModel
// bool _hasAnyApproved(IssueModel issue) =>
//     issue.lines.any((l) => _i(l.approvedQty) > 0);

// bool _canReturnLineByRules(IssueLine l) {
//   final approved = _i(l.approvedQty);
//   final issued = _i(l.issuedQty);
//   final returned = _i(l.returnQty);
//   final scrap = _i(l.scrapQty);

//   if (issued <= 0) return false;

//   // issued must be >= (returned + scrap)
//   if (issued < (returned + scrap)) return false;

//   // safe check: approved should be >= issued (common sense)
//   if (approved < issued) return false;

//   return (issued - (returned + scrap)) > 0;
// }

enum IssueTabSection {
  ready,
  partial,
  history,
}

class _AbovePaginationFloatingActionButtonLocation
    extends FloatingActionButtonLocation {
  const _AbovePaginationFloatingActionButtonLocation({this.offsetY = 64.0});

  final double offsetY;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final standardOffset =
        FloatingActionButtonLocation.endFloat.getOffset(scaffoldGeometry);
    return Offset(standardOffset.dx, standardOffset.dy - offsetY);
  }
}

class IssuesListPage extends ConsumerStatefulWidget {
  const IssuesListPage({
    super.key,
    this.scanIssueButtonKey,
  });

  final GlobalKey? scanIssueButtonKey;

  @override
  ConsumerState<IssuesListPage> createState() => _IssuesListPageState();
}

class _IssuesListPageState extends ConsumerState<IssuesListPage> {
  final _searchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  String _search = '';
  int _page = 1;
  final int _limit = 10;
  IssueTabSection _tabSection = IssueTabSection.ready;

  GlobalKey get _scanKey =>
      widget.scanIssueButtonKey ?? GuidedTourController.scanIssueButtonKey;

  void _dismissTourIfActive({String? uid}) {
    final tourState = ref.read(guidedTourStateProvider);
    if (tourState.hasSteps && !tourState.isSessionDismissed && tourState.totalSteps <= 1) {
      ref.read(guidedTourControllerProvider).dismissTour(
            uid: uid ?? '',
            dontShowAgain: false,
          );
    }
  }

  Future<void> _openCreateIssue() async {
    _dismissTourIfActive();
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const IssueCreatePage()));

    if (!mounted) return;
    if (created == true) {
      setState(() => _page = 1);
      ref.invalidate(pagedIssuesStreamProvider);
    }
  }

  Widget _buildTopSectionTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 640;

        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _stroke),
          ),
          child: Row(
            children: [
              Expanded(
                child: KeyedSubtree(
                  key: GuidedTourController.approvedRequestsTabKey,
                  child: KeyedSubtree(
                    key: GuidedTourController.pendingApprovalsTabKey,
                    child: _buildSectionTabButton(
                      title: 'Ready for Issue',
                      subtitle: 'Awaiting approval',
                      icon: Icons.outbox_rounded,
                      isSelected: _tabSection == IssueTabSection.ready,
                      activeColor: const Color(0xFF5E35B1),
                      activeBgColor: const Color(0xFFEDE7F6),
                      isCompact: isCompact,
                      onTap: () {
                        if (_tabSection != IssueTabSection.ready) {
                          setState(() {
                            _tabSection = IssueTabSection.ready;
                            _page = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSectionTabButton(
                  title: 'Partial Issued',
                  subtitle: 'Approved & ready for pickup',
                  icon: Icons.hourglass_top_rounded,
                  isSelected: _tabSection == IssueTabSection.partial,
                  activeColor: const Color(0xFFE65100),
                  activeBgColor: const Color(0xFFFFF3E0),
                  isCompact: isCompact,
                  onTap: () {
                    if (_tabSection != IssueTabSection.partial) {
                      setState(() {
                        _tabSection = IssueTabSection.partial;
                        _page = 1;
                      });
                    }
                  },
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSectionTabButton(
                  title: 'Issue History',
                  subtitle: 'All completed issues',
                  icon: Icons.history_edu_rounded,
                  isSelected: _tabSection == IssueTabSection.history,
                  activeColor: const Color(0xFF00796B),
                  activeBgColor: const Color(0xFFE0F2F1),
                  isCompact: isCompact,
                  onTap: () {
                    if (_tabSection != IssueTabSection.history) {
                      setState(() {
                        _tabSection = IssueTabSection.history;
                        _page = 1;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTabButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required Color activeBgColor,
    required VoidCallback onTap,
    required bool isCompact,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            vertical: isCompact ? 9 : 8,
            horizontal: isCompact ? 4 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelected ? _surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? activeColor.withValues(alpha: 0.35) : Colors.transparent,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1.5),
                    )
                  ]
                : null,
          ),
          child: isCompact
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 15,
                      color: isSelected ? activeColor : _ink600,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: isSelected ? activeColor : _ink700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isSelected ? activeBgColor : Colors.black.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: isSelected ? activeColor : _ink600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                              color: isSelected ? activeColor : _ink700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 10,
                              color: isSelected ? _ink700 : _ink600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pagedUser = ref.watch(userFindOneDataStreamProvider);

    return pagedUser.when(
      loading: () => const LinearProgressIndicator(minHeight: 2),
      error:
          (e, _) => StoreErrorView(
            error: e,
            onRetry: () => ref.invalidate(userFindOneDataStreamProvider),
          ),

      data: (user) {
        if (user == null) {
          return Scaffold(
            backgroundColor: _surface,
            appBar: AppBar(
              elevation: 0,
              backgroundColor: _surface,
              surfaceTintColor: Colors.transparent,
              iconTheme: const IconThemeData(color: _ink900),
              title: const Text(
                'Issues',
                style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
              ),
            ),
            body: const StoreEmptyStateWidget(message: 'User not found'),
          );
        }
        final canCreate =
            user.isSuperAdmin ||
            user.appWorks.contains("storeadmin") ||
            user.appWorks.contains("storissueadd");

        final canViewAll =
            user.isSuperAdmin ||
            user.appWorks.contains("storeadmin") ||
            user.appWorks.contains("storissueview") ||
            user.appWorks.contains("storissueapprove") ||
            user.appWorks.contains("storissuereject") ||
            user.appWorks.contains("storissuefromstock") ||
            user.appWorks.contains("storissuereturn") ||
            user.appWorks.contains("historyissueItem");

        final query = IssueQuery(
          search: _search,
          page: _page,
          limit: _limit,
          sort: '-createdAt',
          createdBy: canViewAll ? null : user.uid,
          tab: _tabSection == IssueTabSection.ready
              ? 'ready'
              : (_tabSection == IssueTabSection.partial ? 'partial' : 'history'),
        );
        final issuesAv = ref.watch(pagedIssuesStreamProvider(query));
        return Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _surface,
            surfaceTintColor: Colors.transparent,
            iconTheme: const IconThemeData(color: _ink900),
            title: const Text(
              'Issues',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
            ),
            actions: [
              if (canCreate) ...[

                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: IconButton.filled(
                    tooltip: 'Create Issue',
                    style: IconButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: _surface,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20, color: _surface),
                    onPressed: _openCreateIssue,
                  ),
                ),
              ],
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
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        _buildTopSectionTabs(),
                        const SizedBox(height: 10),
                          _SearchBarRow(
                            controller: _searchCtrl,
                            onChanged:
                                (v) => setState(() {
                                  _search = v.trim();
                                  _page = 1;
                                }),
                            onReset: () {
                              _searchCtrl.clear();
                              setState(() {
                                _search = '';
                                _page = 1;
                              });
                            },
                            onCreate:
                                (user.isSuperAdmin ||
                                        user.appWorks.contains("storeadmin") ||
                                        user.appWorks.contains("storissueadd"))
                                    ? _openCreateIssue
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: issuesAv.when(
                              loading: () => const StoreLoadingWidget(),
                              error:
                                  (e, _) => StoreErrorView(
                                  error: e,
                                  onRetry:
                                      () => ref.invalidate(
                                        pagedIssuesStreamProvider(query),
                                      ),
                                ),
                            data: (paged) {
                              final rows = paged.rows;
                              if (rows.isEmpty) {
                                return StoreEmptyStateWidget(
                                  message: _tabSection == IssueTabSection.ready
                                      ? 'No pending requisitions awaiting approval found'
                                      : (_tabSection == IssueTabSection.partial
                                          ? 'No approved requisitions ready for pickup found'
                                          : 'No completed issue history found'),
                                  searchQuery: _search,
                                  onClearSearch:
                                      () => setState(() {
                                        _searchCtrl.clear();
                                        _search = '';
                                        _page = 1;
                                      }),
                                );
                              }
                              return Scrollbar(
                                controller: _scrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                interactive: true,
                                child: ListView.separated(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.only(bottom: 90),
                                  itemCount: rows.length,
                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, i) {
                                    final issue = rows[i];

                                    return _IssueCard(
                                      key: ValueKey(issue.id), // ✅ important
                                      isFirst: i == 0,
                                      isHistory: _tabSection == IssueTabSection.history,
                                      issue: issue,
                                      onChanged:
                                          () => ref.invalidate(
                                            pagedIssuesStreamProvider(query),
                                          ),
                                      user: user,
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        issuesAv.when(
                          loading: () => const SizedBox(height: 34),
                          error: (_, __) => const SizedBox(height: 34),
                          data:
                              (paged) => _Pager(
                                page: _page,
                                totalPages: (paged.total / paged.limit).ceil(),
                                onPage: (p) => setState(() => _page = p),
                              ),
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

/* ---------------- Search Row ---------------- */

class _SearchBarRow extends StatelessWidget {
  const _SearchBarRow({
    required this.controller,
    required this.onChanged,
    this.onFilter,
    required this.onReset,
    this.onCreate,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onFilter;
  final VoidCallback onReset;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 600;
    final isVeryNarrow = width < 370;

    return _Card(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText:
                    isVeryNarrow
                        ? 'Search...'
                        : 'Search by Issue / Reason / Item',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                filled: true,
                fillColor: _surface,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
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
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink900,
              side: const BorderSide(color: _stroke),
              padding: const EdgeInsets.all(10),
              minimumSize: const Size(40, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Icon(Icons.refresh_rounded, size: 18),
          ),
          if (onCreate != null && isDesktop) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onCreate,
              style: ElevatedButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text(
                'Create Issue',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------- Card ---------------- */

class _IssueCard extends ConsumerStatefulWidget {
  const _IssueCard({
    super.key,
    this.isFirst = false,
    this.isHistory = false,
    required this.issue,
    required this.user,
    required this.onChanged,
  });

  final bool isFirst;
  final bool isHistory;
  final AuthModel user;
  final IssueModel issue;
  final VoidCallback onChanged;

  @override
  ConsumerState<_IssueCard> createState() => __IssueCardState();
}

class __IssueCardState extends ConsumerState<_IssueCard> {
  late bool _cardExpanded;
  bool _open = true;

  @override
  void initState() {
    super.initState();
    _cardExpanded = !widget.isHistory;
  }

  @override
  void didUpdateWidget(covariant _IssueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isHistory != widget.isHistory) {
      _cardExpanded = !widget.isHistory;
    }
  }

  void _openFindItem(IssueLine line) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => FindItemPage(
              isStandalone: true,
              initialItemId: line.itemId,
              initialItemName: line.itemName,
              initialQuantity: line.requestedQty > 0 ? line.requestedQty : null,
            ),
      ),
    );
  }

  void _openFindItems(IssueModel issue) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IssueFindItemsPage(issue: issue),
      ),
    );
  }

  Future<void> _openScanItem(IssueModel issue, IssueLine line) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder:
            (_) => ItemIssueVerifyScanPage(
              issue: issue,
              line: line,
            ),
      ),
    );

    if (!mounted) return;

    if (result == false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cancel_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text(
                'Wrong QR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: Color(0xFFC62828),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );
    } else if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified: ${line.itemName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      final canIssueFromStock =
          issue.isApproved && !issue.isRejected && !issue.isFullyPickedUp;
      final unissuedCount = issue.lines.fold<int>(
        0,
        (sum, l) => sum + (l.approvedQty - l.issuedQty).clamp(0, 999999),
      );

      if (canIssueFromStock && unissuedCount > 0) {
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => IssueSheet(
                issue: issue,
                onChanged: widget.onChanged,
                targetItemId: line.itemId,
              ),
        );
      }
    }
  }

  Future<void> _handleRevertApproval(
    BuildContext context,
    IssueModel issue,
    int unissuedCount,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.undo_rounded, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text(
              'Revert Approval',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _ink900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to revert approval for ${issue.issNo}?\n\n'
              '• $unissuedCount unit(s) currently waiting at the counter will be returned to Pending Request hold.\n'
              '• Ready for Issue stock will decrease.\n'
              '• The request will return to Draft/Pending status so you can re-approve or reject it.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _ink700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Reason for revert (Optional)',
                labelStyle: const TextStyle(color: _ink600),
                hintText: 'e.g. Requested quantity changed',
                hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE65100), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Revert', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = (await ref.read(spRepositoryProvider).getStringValue('uid')).trim();
      if (uid.isEmpty) {
        showSnackBar('Missing user ID');
        return;
      }
      final ok = await ref.read(issueControllerProvider).revertApproval(
        issueId: issue.id,
        revertedBy: uid,
        reason: reasonCtrl.text.trim(),
      );
      if (ok) {
        widget.onChanged();
      }
    }
  }

  Future<void> _handleRejectRequest(
    BuildContext context,
    IssueModel issue,
  ) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text(
              'Reject Request',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _ink900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject requisition ${issue.issNo}?\n\n'
              '• All requested items will be rejected.\n'
              '• The requested quantity held in stock will be reset to 0.\n'
              '• This request will be closed and cannot be approved or issued.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _ink700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Reason for rejection (Optional)',
                labelStyle: const TextStyle(color: _ink600),
                hintText: 'e.g. Out of stock, not required',
                hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _stroke),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _stroke),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Reject', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uid = (await ref.read(spRepositoryProvider).getStringValue('uid')).trim();
      if (uid.isEmpty) {
        showSnackBar('Missing user ID');
        return;
      }
      final ok = await ref.read(issueControllerProvider).rejectIssue(
        issueId: issue.id,
        rejectedBy: uid,
        reason: reasonCtrl.text.trim(),
      );
      if (ok) {
        widget.onChanged();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final issue = widget.issue;
    final createdByAv = ref.watch(userByIdProvider(issue.createdBy));
    final isRejected = issue.isRejected;
    final canApprove = !isRejected && issue.lines.any((l) => _remainApprove(l) > 0);
    // final canReturn = issue.lines.any((l) => _canReturnLineByRules(l));

    final totalApproved = issue.lines.fold<int>(0, (sum, l) => sum + _i(l.approvedQty));
    final totalIssued = issue.lines.fold<int>(0, (sum, l) => sum + _i(l.issuedQty));
    final canRevert = !isRejected && totalApproved > 0 && totalIssued < totalApproved;
    final isFullyPickedUp = !isRejected && totalApproved > 0 && totalIssued >= totalApproved;
    final unissuedCount = totalApproved - totalIssued;
    final canReject = !isRejected && totalIssued == 0;
    final isIssueApproved =
        !isRejected && (issue.isApproved || issue.approvedAt != null || totalApproved > 0);

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
        final creatorName =
            (user?.name.trim().isNotEmpty == true) ? user!.name : 'Requester';

        final a =
            (widget.user.divisionIds)
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final b =
            (user?.divisionIds ?? const [])
                .map((e) => e.trim().toLowerCase())
                .where((e) => e.isNotEmpty)
                .toSet();

        final hasCommon =
            widget.user.isSuperAdmin ||
            a.isEmpty ||
            b.isEmpty ||
            a.intersection(b).isNotEmpty;

        final canFindItem =
            widget.user.isSuperAdmin ||
            widget.user.appWorks.contains('storeadmin') ||
            widget.user.appWorks.contains('storeitemfind');

        final canIssueFromStock =
            widget.user.isSuperAdmin ||
            widget.user.appWorks.contains('storeadmin') ||
            widget.user.appWorks.contains('storissuefromstock');

        final hasApprovePerm =
            widget.user.isSuperAdmin ||
            widget.user.appWorks.contains('storeadmin') ||
            widget.user.appWorks.contains('storissueapprove');

        final hasRejectPerm =
            widget.user.isSuperAdmin ||
            widget.user.appWorks.contains('storeadmin') ||
            widget.user.appWorks.contains('storissuereject') ||
            widget.user.appWorks.contains('storissueapprove');

        return StoreCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() => _cardExpanded = !_cardExpanded),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _surfaceAlt.withValues(alpha: .8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _stroke),
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: _ink900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Text(
                              issue.issNo,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (isRejected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFEBEE),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFFFCDD2),
                                  ),
                                ),
                                child: const Text(
                                  'REJECTED',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFC62828),
                                  ),
                                ),
                              )
                            else if (isFullyPickedUp)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFFD1C4E9),
                                  ),
                                ),
                                child: const Text(
                                  'PICKED UP',
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF5E35B1),
                                  ),
                                ),
                              )
                            else if (totalApproved > 0)
                              KeyedSubtree(
                                key: widget.isFirst ? GuidedTourController.readyForIssueBadgeKey : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFA5D6A7),
                                    ),
                                  ),
                                  child: const Text(
                                    'READY FOR ISSUE',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF2E7D32),
                                    ),
                                  ),
                                ),
                              )
                            else
                              KeyedSubtree(
                                key: widget.isFirst ? GuidedTourController.readyForIssueBadgeKey : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFCC80),
                                    ),
                                  ),
                                  child: const Text(
                                    'PENDING APPROVAL',
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        KeyedSubtree(
                          key: widget.isFirst
                              ? GuidedTourController.issueQuantityStepperKey
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                issue.reason.isEmpty ? '—' : issue.reason,
                                style: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Created By - $creatorName',
                                style: const TextStyle(
                                  color: _ink700,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatStoreDateTime(issue.createdAt),
                          style: const TextStyle(
                            color: _ink600,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        if (!_cardExpanded && issue.lines.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _surfaceAlt.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _stroke),
                            ),
                            child: Text(
                              '${issue.lines.length} ${issue.lines.length == 1 ? 'Item' : 'Items'} (${issue.totalRequested} units) • ${issue.lines.map((l) => l.itemName).where((s) => s.isNotEmpty).take(2).join(', ')}${issue.lines.length > 2 ? ' +${issue.lines.length - 2} more' : ''}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _ink900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 200),
                    turns: _cardExpanded ? 0.5 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _surfaceAlt.withValues(alpha: 0.45),
                      ),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: _ink700,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState:
                    _cardExpanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                firstChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
              _buildMilestoneAuditBox(issue, creatorName),
              const SizedBox(height: 10),

              KeyedSubtree(
                key: widget.isFirst
                    ? GuidedTourController.requisitionLineItemsKey
                    : null,
                child: KeyedSubtree(
                  key: widget.isFirst && (!canFindItem || issue.lines.isEmpty)
                      ? GuidedTourController.issueShelfCoordinatesKey
                      : null,
                  child: _ItemsAccordion(
                    lines: issue.lines,
                    initialExpanded: issue.lines.length <= 1,
                    onFindItem: canFindItem ? _openFindItem : null,
                    onScanItem:
                        isIssueApproved ? (line) => _openScanItem(issue, line) : null,
                  ),
                ),
              ),

              const SizedBox(height: 10),
              InkWell(
                onTap: () => setState(() => _open = !_open),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _open ? 'Hide actions' : 'Show actions',
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        _open
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: _ink700,
                      ),
                    ],
                  ),
                ),
              ),

              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState:
                    _open
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: KeyedSubtree(
                    key: widget.isFirst && !canApprove
                        ? GuidedTourController.firstIssueApproveButtonKey
                        : null,
                    child: KeyedSubtree(
                      key: widget.isFirst && !(canIssueFromStock && unissuedCount > 0)
                          ? GuidedTourController.firstIssueDispatchButtonKey
                          : null,
                      child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if ((hasApprovePerm || hasRejectPerm) &&
                            hasCommon) ...[
                          if (canApprove && hasApprovePerm)
                            FilledButton.icon(
                              key: widget.isFirst
                                  ? GuidedTourController.firstIssueApproveButtonKey
                                  : null,
                              onPressed: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,

                                  // ✅ keeps sheet "staying there" unless user presses Close button
                                  isDismissible: false,
                                  enableDrag: false,

                                  builder:
                                      (_) => _ApproveSheet(
                                        issue: issue,

                                        // ✅ refresh list AFTER approve (inside sheet)
                                        refreshIssues: widget.onChanged,
                                      ),
                                );
                              },
                              icon: const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                              ),
                              label: const Text('Approve'),
                              style: filledStyle,
                            ),
                          if (canReject && hasRejectPerm)
                            FilledButton.icon(
                              onPressed: () => _handleRejectRequest(context, issue),
                              icon: const Icon(
                                Icons.cancel_rounded,
                                size: 18,
                              ),
                              label: const Text('Reject'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                                foregroundColor: const Color(0xFFC62828),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          if (canRevert && hasApprovePerm)
                            FilledButton.icon(
                              onPressed: () => _handleRevertApproval(
                                context,
                                issue,
                                unissuedCount,
                              ),
                              icon: const Icon(
                                Icons.undo_rounded,
                                size: 18,
                              ),
                              label: Text(
                                totalIssued > 0
                                    ? 'Revert Unissued ($unissuedCount)'
                                    : 'Revert Approval',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFFE0B2),
                                foregroundColor: const Color(0xFFBF360C),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          if (isFullyPickedUp)
                            KeyedSubtree(
                              key: widget.isFirst
                                  ? GuidedTourController.issueConfirmDispatchKey
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEDE7F6),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFD1C4E9),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.lock_outline_rounded,
                                      size: 15,
                                      color: Color(0xFF5E35B1),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Picked Up ($totalIssued) • Cannot Revert',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF5E35B1),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                        if (canIssueFromStock && unissuedCount > 0)
                          KeyedSubtree(
                            key: widget.isFirst
                                ? GuidedTourController.firstIssueDispatchButtonKey
                                : null,
                            child: FilledButton.icon(
                              onPressed: () async {
                                await showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  builder:
                                      (_) => IssueSheet(
                                        issue: issue,
                                        onChanged: widget.onChanged,
                                      ),
                                );
                              },
                              icon: const Icon(
                                Icons.local_shipping_rounded,
                                size: 18,
                              ),
                              label: const Text('Issue (Pick Up)'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2E7D32),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                        if (canFindItem && issue.lines.isNotEmpty)
                          KeyedSubtree(
                            key: widget.isFirst
                                ? GuidedTourController.issueShelfCoordinatesKey
                                : null,
                            child: FilledButton.icon(
                              onPressed: () => _openFindItems(issue),
                              icon: const Icon(
                                Icons.location_searching_rounded,
                                size: 18,
                              ),
                              label: Text(
                                issue.lines.length == 1
                                    ? 'Find Item'
                                    : 'Find Items (${issue.lines.length})',
                              ),
                              style: filledStyle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
            ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMilestoneAuditBox(IssueModel issue, String creatorName) {
    final hasApproved = issue.isApproved || issue.approvedAt != null || issue.totalApproved > 0;
    final hasRejected = issue.isRejected || issue.rejectedAt != null;
    final hasIssued = issue.isFullyPickedUp || issue.totalIssued > 0;
    final deptName = issue.departmentName.isNotEmpty ? issue.departmentName : 'General Operations';

    final approverText = issue.approvedByName.isNotEmpty
        ? issue.approvedByName
        : (issue.approvedBy.isNotEmpty ? issue.approvedBy : 'Management');
    final rejectorText = issue.rejectedByName.isNotEmpty
        ? issue.rejectedByName
        : (issue.rejectedBy.isNotEmpty ? issue.rejectedBy : 'Management');
    final issuerText = issue.latestIssuedByName.isNotEmpty
        ? issue.latestIssuedByName
        : 'Store Staff';

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_outlined, size: 13, color: _ink700),
              const SizedBox(width: 4.5),
              const Text(
                'Requisition & Issue Milestones',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _ink900,
                ),
              ),

            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 600;
              return isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Request
                        Expanded(
                          child: _buildMilestoneStep(
                            icon: Icons.edit_note_rounded,
                            iconColor: const Color(0xFFE65100),
                            title: '1. Requested',
                            primaryText: formatStoreDateTime(issue.createdAt),
                            secondaryText: 'By $creatorName ($deptName)',
                            isCompleted: true,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: _stroke,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        // 2. Decision
                        Expanded(
                          child: _buildMilestoneStep(
                            icon: hasRejected
                                ? Icons.cancel_outlined
                                : (hasApproved ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded),
                            iconColor: hasRejected
                                ? const Color(0xFFC62828)
                                : (hasApproved ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                            title: hasRejected ? '2. Rejected' : (hasApproved ? '2. Approved' : '2. Approval'),
                            primaryText: hasRejected
                                ? (issue.rejectedAt != null ? formatStoreDateTime(issue.rejectedAt!) : 'Rejected')
                                : (hasApproved
                                    ? (issue.approvedAt != null ? formatStoreDateTime(issue.approvedAt!) : 'Approved')
                                    : 'Pending Review'),
                            secondaryText: hasRejected
                                ? 'By $rejectorText'
                                : (hasApproved ? 'By $approverText' : 'Awaiting Manager'),
                            isCompleted: hasApproved || hasRejected,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: _stroke,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        // 3. Issue
                        Expanded(
                          child: _buildMilestoneStep(
                            icon: hasIssued ? Icons.assignment_turned_in_rounded : Icons.outbox_rounded,
                            iconColor: hasIssued ? const Color(0xFF00796B) : const Color(0xFF5E35B1),
                            title: hasIssued ? '3. Issued' : '3. Counter Issue',
                            primaryText: hasIssued
                                ? (issue.latestIssuedAt != null ? formatStoreDateTime(issue.latestIssuedAt!) : 'Issued')
                                : (hasApproved ? 'Ready at Counter' : 'Pending Approval'),
                            secondaryText: hasIssued
                                ? 'By $issuerText (${issue.totalIssued} units)'
                                : (hasApproved ? 'Ready for recipient pickup' : 'Waiting approval'),
                            isCompleted: hasIssued,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildMilestoneStep(
                          icon: Icons.edit_note_rounded,
                          iconColor: const Color(0xFFE65100),
                          title: '1. Requested',
                          primaryText: formatStoreDateTime(issue.createdAt),
                          secondaryText: 'By $creatorName ($deptName)',
                          isCompleted: true,
                        ),
                        const Divider(height: 12, color: _stroke),
                        _buildMilestoneStep(
                          icon: hasRejected
                              ? Icons.cancel_outlined
                              : (hasApproved ? Icons.check_circle_outline_rounded : Icons.hourglass_top_rounded),
                          iconColor: hasRejected
                              ? const Color(0xFFC62828)
                              : (hasApproved ? const Color(0xFF2E7D32) : const Color(0xFFE65100)),
                          title: hasRejected ? '2. Rejected' : (hasApproved ? '2. Approved' : '2. Approval'),
                          primaryText: hasRejected
                              ? (issue.rejectedAt != null ? formatStoreDateTime(issue.rejectedAt!) : 'Rejected')
                              : (hasApproved
                                  ? (issue.approvedAt != null ? formatStoreDateTime(issue.approvedAt!) : 'Approved')
                                  : 'Pending Review'),
                          secondaryText: hasRejected
                              ? 'By $rejectorText'
                              : (hasApproved ? 'By $approverText' : 'Awaiting Manager'),
                          isCompleted: hasApproved || hasRejected,
                        ),
                        const Divider(height: 12, color: _stroke),
                        _buildMilestoneStep(
                          icon: hasIssued ? Icons.assignment_turned_in_rounded : Icons.outbox_rounded,
                          iconColor: hasIssued ? const Color(0xFF00796B) : const Color(0xFF5E35B1),
                          title: hasIssued ? '3. Issued' : '3. Counter Issue',
                          primaryText: hasIssued
                              ? (issue.latestIssuedAt != null ? formatStoreDateTime(issue.latestIssuedAt!) : 'Issued')
                              : (hasApproved ? 'Ready at Counter' : 'Pending Approval'),
                          secondaryText: hasIssued
                              ? 'By $issuerText (${issue.totalIssued} units)'
                              : (hasApproved ? 'Ready for recipient pickup' : 'Waiting approval'),
                          isCompleted: hasIssued,
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneStep({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String primaryText,
    required String secondaryText,
    required bool isCompleted,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: isCompleted ? iconColor.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
            shape: BoxShape.circle,
            border: Border.all(color: isCompleted ? iconColor : _stroke),
          ),
          child: Icon(icon, size: 12, color: isCompleted ? iconColor : _ink500),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: isCompleted ? _ink900 : _ink600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                primaryText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isCompleted ? iconColor : _ink700,
                ),
              ),
              Text(
                secondaryText,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: _ink600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ---------------- Items Accordion (Responsive Mobile & Laptop) ---------------- */

class _ItemsAccordion extends StatefulWidget {
  const _ItemsAccordion({
    required this.lines,
    this.initialExpanded = false,
    this.onFindItem,
    this.onScanItem,
  });

  final List<IssueLine> lines;
  final bool initialExpanded;
  final void Function(IssueLine)? onFindItem;
  final void Function(IssueLine)? onScanItem;

  @override
  State<_ItemsAccordion> createState() => _ItemsAccordionState();
}

class _ItemsAccordionState extends State<_ItemsAccordion> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  Widget _statusBadge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }

  Widget _metricChip(String label, String value, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: fg.withValues(alpha: 0.75),
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lines;
    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        child: const Center(
          child: Text(
            'No items requested',
            style: TextStyle(
              color: _ink600,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final totalReq = lines.fold<int>(0, (sum, l) => sum + _i(l.requestedQty));
    final totalApproved = lines.fold<int>(0, (sum, l) => sum + _i(l.approvedQty));
    final totalRemaining = lines.fold<int>(0, (sum, l) => sum + _remainApprove(l));

    final count = lines.length;
    final itemNamesSummary = lines
            .map((l) => l.itemName.trim())
            .where((s) => s.isNotEmpty)
            .take(2)
            .join(', ') +
        (count > 2 ? ' +${count - 2} more' : '');

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 550;

        return Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _expanded ? _accentMint.withValues(alpha: 0.8) : _stroke,
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accordion Header Bar
              InkWell(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _expanded
                        ? _surfaceAlt.withValues(alpha: 0.5)
                        : _surfaceAlt.withValues(alpha: 0.25),
                    border: _expanded
                        ? const Border(bottom: BorderSide(color: _stroke))
                        : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _stroke.withValues(alpha: 0.7)),
                        ),
                        child: const Icon(
                          Icons.format_list_bulleted_rounded,
                          size: 15,
                          color: _ink900,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 2,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  '$count ${count == 1 ? 'Item' : 'Items'}',
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _ink900.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '$totalReq units',
                                    style: const TextStyle(
                                      color: _ink700,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (!_expanded && itemNamesSummary.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                itemNamesSummary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _ink600,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Progress status indicator
                      if (totalRemaining > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Text(
                            '$totalRemaining pending',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        )
                      else if (totalApproved > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA5D6A7)),
                          ),
                          child: const Text(
                            'All Approved',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.w800,
                              fontSize: 10.5,
                            ),
                          ),
                        ),
                      const SizedBox(width: 6),
                      // Animated expand/collapse arrow
                      AnimatedRotation(
                        duration: const Duration(milliseconds: 200),
                        turns: _expanded ? 0.5 : 0.0,
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: _ink700,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Animated Accordion Content
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState:
                    _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                firstChild: isDesktop
                    ? _buildDesktopTable(lines)
                    : _buildMobileCards(lines),
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<IssueLine> lines) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _surfaceAlt.withValues(alpha: 0.15),
            border: const Border(bottom: BorderSide(color: _stroke)),
          ),
          child: const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'ITEM',
                  style: TextStyle(
                    color: _ink600,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'REQ',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'APPROVED',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'ISSUED',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'STATUS / NOTES',
                    style: TextStyle(
                      color: _ink600,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Rows
        for (int i = 0; i < lines.length; i++) ...[
          _buildDesktopRow(lines[i], isLast: i == lines.length - 1),
        ],
      ],
    );
  }

  Widget _buildDesktopRow(IssueLine row, {required bool isLast}) {
    final rem = _remainApprove(row);
    final ret = _i(row.returnQty);
    final scrap = _i(row.scrapQty);
    final rej = _i(row.approvedRejectQty) + _i(row.issuedRejectQty);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _surface,
        border: isLast ? null : const Border(bottom: BorderSide(color: _stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.itemName,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (widget.onScanItem != null && _i(row.approvedQty) > 0)
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    color: _ink600,
                    tooltip: 'Scan Item QR to Verify',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => widget.onScanItem!(row),
                  ),
                if (widget.onFindItem != null)
                  IconButton(
                    icon: const Icon(Icons.location_searching_rounded, size: 16),
                    color: _ink600,
                    tooltip: 'Find Rack Location',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => widget.onFindItem!(row),
                  ),
              ],
            ),
          ),
          Expanded(flex: 2, child: _QtyPill('${_i(row.requestedQty)}')),
          Expanded(
            flex: 2,
            child: _QtyPill(
              '${_i(row.approvedQty)}',
              color: _i(row.approvedQty) > 0
                  ? _accentMint.withValues(alpha: 0.8)
                  : null,
            ),
          ),
          Expanded(
            flex: 2,
            child: _QtyPill(
              '${_i(row.issuedQty)}',
              color: _i(row.issuedQty) > 0 ? const Color(0xFFD1C4E9) : null,
            ),
          ),
          Expanded(
            flex: 3,
            child: Center(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  if (rem > 0)
                    _statusBadge(
                      'Rem: $rem',
                      const Color(0xFFFEF3C7),
                      const Color(0xFF92400E),
                    ),
                  if (rej > 0)
                    _statusBadge(
                      'Rej: $rej',
                      const Color(0xFFFEE2E2),
                      const Color(0xFF991B1B),
                    ),
                  if (ret > 0)
                    _statusBadge(
                      'Ret: $ret',
                      const Color(0xFFE0F2FE),
                      const Color(0xFF0369A1),
                    ),
                  if (scrap > 0)
                    _statusBadge(
                      'Scrap: $scrap',
                      const Color(0xFFFFEDD5),
                      const Color(0xFFC2410C),
                    ),
                  if (row.unitPrice > 0)
                    _statusBadge(
                      '₹${row.unitPrice.toStringAsFixed(row.unitPrice % 1 == 0 ? 0 : 2)}/pc (Old Stock)',
                      const Color(0xFFF0FDF4),
                      const Color(0xFF166534),
                    ),
                  if (rem == 0 && rej == 0 && ret == 0 && scrap == 0)
                    _statusBadge(
                      '✓ Complete',
                      const Color(0xFFE8F5E9),
                      const Color(0xFF2E7D32),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCards(List<IssueLine> lines) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          for (int i = 0; i < lines.length; i++) ...[
            _buildMobileCard(lines[i]),
            if (i < lines.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileCard(IssueLine row) {
    final rem = _remainApprove(row);
    final ret = _i(row.returnQty);
    final scrap = _i(row.scrapQty);
    final rej = _i(row.approvedRejectQty) + _i(row.issuedRejectQty);
    final showScan = widget.onScanItem != null && _i(row.approvedQty) > 0;
    final showFind = widget.onFindItem != null;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 3),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _ink900,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  row.itemName,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              if (showScan)
                InkWell(
                  onTap: () => widget.onScanItem!(row),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      size: 16,
                      color: _ink700,
                    ),
                  ),
                ),
              if (showScan && showFind)
                const SizedBox(width: 4),
              if (showFind)
                InkWell(
                  onTap: () => widget.onFindItem!(row),
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.location_searching_rounded,
                      size: 16,
                      color: _ink700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _metricChip('Req', '${_i(row.requestedQty)}', const Color(0xFFF3F4F6), _ink900),
              _metricChip('Appr', '${_i(row.approvedQty)}', _accentMint.withValues(alpha: 0.4), _ink900),
              _metricChip('Issued', '${_i(row.issuedQty)}', const Color(0xFFEDE7F6), const Color(0xFF5E35B1)),
              if (row.unitPrice > 0)
                _metricChip('Issue Rate', '₹${row.unitPrice.toStringAsFixed(row.unitPrice % 1 == 0 ? 0 : 2)} (Old Stock)', const Color(0xFFF0FDF4), const Color(0xFF166534)),
              if (rem > 0)
                _metricChip('Rem', '$rem', const Color(0xFFFEF3C7), const Color(0xFF92400E)),
              if (rej > 0)
                _metricChip('Rej', '$rej', const Color(0xFFFEE2E2), const Color(0xFF991B1B)),
              if (ret > 0)
                _metricChip('Ret', '$ret', const Color(0xFFE0F2FE), const Color(0xFF0369A1)),
              if (scrap > 0)
                _metricChip('Scrap', '$scrap', const Color(0xFFFFEDD5), const Color(0xFFC2410C)),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyPill extends StatelessWidget {
  const _QtyPill(this.t, {this.color});
  final String t;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(minWidth: 50),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color ?? _surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: color != null
                ? Colors.transparent
                : _accentMint.withValues(alpha: .9),
            width: 1.2,
          ),
        ),
        child: Text(
          t,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

/* ---------------- Approve Sheet ---------------- */

class _ApproveSheet extends ConsumerStatefulWidget {
  const _ApproveSheet({required this.issue, required this.refreshIssues});

  final IssueModel issue;
  final VoidCallback refreshIssues;

  @override
  ConsumerState<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends ConsumerState<_ApproveSheet> {
  late List<IssueLine> _lines;

  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _rejectQtyCtrls = {};
  final Map<String, String> _modes = {}; // add|set
  final Set<String> _busyLineIds = {};
  final Set<String> _expandedLineIds = {};
  final Set<String> _selectedItemIds = {};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _bulkBusy = false;

  bool get _canApproveNow => _lines.any((l) => _remainApprove(l) > 0);

  @override
  void initState() {
    super.initState();

    _lines = List<IssueLine>.from(widget.issue.lines);

    for (final l in _lines) {
      _modes[l.itemId] = 'add';
      final ra = _remainApprove(l);
      _qtyCtrls[l.itemId] = TextEditingController(text: ra > 0 ? '$ra' : '0');
      _rejectQtyCtrls[l.itemId] = TextEditingController(text: '0');
      if (ra > 0) {
        _expandedLineIds.add(l.itemId);
      }
    }

    if (_expandedLineIds.length > 1) {
      final first = _expandedLineIds.first;
      _expandedLineIds.clear();
      _expandedLineIds.add(first);
    }

    // ✅ If already fully approved, close the sheet automatically
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_canApproveNow) {
        widget.refreshIssues();
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
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
    final uid = (await ref.read(spRepositoryProvider).getStringValue('uid'));
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
    final rejectQty = _asInt(_rejectQtyCtrls[line.itemId]?.text ?? '', 0);

    final remaining = _remainApprove(line);
    final requested = _i(line.requestedQty);

    if (mode == 'add' && remaining <= 0) {
      showSnackBar('Nothing remaining to approve');
      return;
    }

    if (qty < 0 || rejectQty < 0) {
      showSnackBar('Qty cannot be negative');
      return;
    }

    final total = qty + rejectQty;

    if (mode == 'add') {
      if (total <= 0) {
        showSnackBar('Enter qty or reject qty (>0)');
        return;
      }
      if (total > remaining) {
        showSnackBar('Total cannot exceed remaining ($remaining)');
        return;
      }
    } else {
      if (total > requested) {
        showSnackBar('Set total cannot exceed requested ($requested)');
        return;
      }
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
            approvedRejectQty: rejectQty,
            mode: mode,
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

      final nextApprovedReject =
          int.tryParse((updatedLine['approvedRejectQty'] ?? '').toString()) ??
          _i(line.approvedRejectQty);

      bool allDoneAfter = false;

      if (updatedItemId.isNotEmpty) {
        setState(() {
          _lines =
              _lines.map((x) {
                if (x.itemId == updatedItemId) {
                  final nx = x.copyWith(
                    approvedQty: nextApproved,
                    approvedRejectQty: nextApprovedReject,
                  );

                  final ra = _remainApprove(nx);
                  _qtyCtrls[x.itemId]?.text = ra > 0 ? '$ra' : '0';
                  _rejectQtyCtrls[x.itemId]?.text = '0';
                  return nx;
                }
                return x;
              }).toList();

          allDoneAfter = _lines.every((l) => _remainApprove(l) <= 0);
        });
      }

      widget.refreshIssues();

      if (allDoneAfter && mounted) {
        Navigator.pop(context);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Updated successfully')));
    } catch (e) {
      showSnackBar('Approve failed: $e');
    } finally {
      if (mounted) setState(() => _busyLineIds.remove(line.itemId));
    }
  }

  Future<void> _rejectOne(IssueLine line) async {
    final remaining = _remainApprove(line);
    if (remaining <= 0) return;
    _qtyCtrls[line.itemId]?.text = '0';
    _rejectQtyCtrls[line.itemId]?.text = '$remaining';
    await _approveOne(line);
  }

  Future<void> _rejectAllRequest() async {
    final uid = await _getUid();
    if (!mounted) return;
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cancel_rounded, color: Color(0xFFC62828)),
            SizedBox(width: 8),
            Text(
              'Reject Entire Request',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: _ink900,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to reject requisition ${widget.issue.issNo}?\n\n'
              '• All requested items will be rejected.\n'
              '• The requested quantity held in stock will be reset to 0.\n'
              '• This request will be closed and cannot be approved or issued.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: _ink700,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Reason for rejection (Optional)',
                labelStyle: const TextStyle(color: _ink600),
                hintText: 'e.g. Out of stock, not required',
                hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.6)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _stroke),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC62828),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Reject All', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final ok = await ref.read(issueControllerProvider).rejectIssue(
        issueId: widget.issue.id,
        rejectedBy: uid,
        reason: reasonCtrl.text.trim(),
      );
      if (ok) {
        widget.refreshIssues();
        if (mounted) Navigator.pop(context);
      }
    }
  }

  Future<void> _approveSelected() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final targetLines = _selectedItemIds.isEmpty
        ? _lines.where((l) => _remainApprove(l) > 0).toList()
        : _lines.where((l) => _selectedItemIds.contains(l.itemId) && _remainApprove(l) > 0).toList();

    if (targetLines.isEmpty) {
      showSnackBar('Nothing remaining to approve');
      return;
    }

    final linesPayload = targetLines.map((l) {
      final remaining = _remainApprove(l);
      final qty = _asInt(_qtyCtrls[l.itemId]?.text ?? '', remaining);
      return {
        'itemId': l.itemId,
        'approvedQty': qty > 0 ? qty : remaining,
        'mode': 'add',
      };
    }).toList();

    setState(() => _bulkBusy = true);
    try {
      final res = await ref.read(issueControllerProvider).approveBulk(
        issueId: widget.issue.id,
        approvedBy: uid,
        lines: linesPayload,
      );

      if (res != null) {
        widget.refreshIssues();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      showSnackBar('Bulk approve failed: $e');
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Future<void> _rejectSelected() async {
    final uid = await _getUid();
    if (uid.isEmpty) {
      showSnackBar('Missing uid');
      return;
    }

    final pendingLines = _lines.where((l) => _remainApprove(l) > 0).toList();
    final targetLines = _selectedItemIds.isEmpty
        ? pendingLines
        : _lines.where((l) => _selectedItemIds.contains(l.itemId) && _remainApprove(l) > 0).toList();

    if (targetLines.isEmpty) {
      showSnackBar('Nothing to reject');
      return;
    }

    if (targetLines.length == pendingLines.length) {
      await _rejectAllRequest();
      return;
    }

    setState(() => _bulkBusy = true);
    try {
      for (final line in targetLines) {
        final remaining = _remainApprove(line);
        if (remaining <= 0) continue;
        await ref.read(issueControllerProvider).approveLine(
          issueId: widget.issue.id,
          itemId: line.itemId,
          approvedBy: uid,
          approvedQty: 0,
          approvedRejectQty: remaining,
          mode: 'add',
        );
      }
      widget.refreshIssues();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      showSnackBar('Reject failed: $e');
    } finally {
      if (mounted) setState(() => _bulkBusy = false);
    }
  }

  Widget _buildQtyStepper({
    required String label,
    required TextEditingController controller,
    required int max,
    required Color activeColor,
    required VoidCallback onChanged,
  }) {
    final current = _asInt(controller.text, 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: _ink700,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1D5DB), width: 1.5),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: current > 0
                    ? () {
                        final n = math.max(0, current - 1);
                        controller.text = '$n';
                        onChanged();
                      }
                    : null,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Icon(
                    Icons.remove_rounded,
                    size: 16,
                    color: current > 0 ? activeColor : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => onChanged(),
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 6),
                  ),
                ),
              ),
              InkWell(
                onTap: current < max
                    ? () {
                        final n = math.min(max, current + 1);
                        controller.text = '$n';
                        onChanged();
                      }
                    : null,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  child: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: current < max ? activeColor : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.86;
    final totalRemaining = _lines.fold<int>(0, (sum, l) => sum + _remainApprove(l));

    final selectedCount = _selectedItemIds.length;

    final filteredLines = _lines.where((l) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery;
      return l.itemName.toLowerCase().contains(q);
    }).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: maxH,
            ),
            child: Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Material(
                color: Colors.transparent,
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
                      // 1. Dynamic Header (Full issue number visibility on mobile)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 6,
                                  runSpacing: 3,
                                  children: [
                                    const Text(
                                      'Approve Requisition:',
                                      style: TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: _stroke),
                                      ),
                                      child: Text(
                                        widget.issue.issNo,
                                        style: const TextStyle(
                                          color: _ink900,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${_lines.length} ${_lines.length == 1 ? "item" : "items"} · $totalRemaining units pending',
                                  style: const TextStyle(
                                    color: _ink600,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 2. Search Field
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _stroke),
                        ),
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink900),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Search items (e.g. name, code...)...',
                            hintStyle: const TextStyle(fontSize: 12.5, color: _ink600),
                            prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _ink600),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16, color: _ink600),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // 3. Selection & Bulk Action Bar (Direct 1-click Approve All & Reject All; selection badge only when items selected)
                      Wrap(
                        alignment: selectedCount > 0 ? WrapAlignment.spaceBetween : WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (selectedCount > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBFDBFE)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Color(0xFF2563EB),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$selectedCount selected',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                      color: Color(0xFF1E40AF),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () => setState(() => _selectedItemIds.clear()),
                                    child: const Text(
                                      'Clear',
                                      style: TextStyle(
                                        color: Color(0xFF2563EB),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: _bulkBusy || !_canApproveNow ? null : _approveSelected,
                                icon: _bulkBusy
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.done_all_rounded, size: 14),
                                label: Text(
                                  selectedCount > 0
                                      ? (isDesktop ? 'Approve Selected ($selectedCount)' : 'Approve ($selectedCount)')
                                      : 'Approve All',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF059669),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  minimumSize: const Size(0, 32),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              const SizedBox(width: 6),
                              TextButton.icon(
                                onPressed: _bulkBusy || !_canApproveNow ? null : _rejectSelected,
                                icon: const Icon(Icons.cancel_outlined, size: 14, color: Color(0xFFC62828)),
                                label: Text(
                                  selectedCount > 0
                                      ? (isDesktop ? 'Reject Selected ($selectedCount)' : 'Reject ($selectedCount)')
                                      : 'Reject All',
                                  style: const TextStyle(
                                    color: Color(0xFFC62828),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFC62828),
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                                  minimumSize: const Size(0, 32),
                                  backgroundColor: const Color(0xFFFFEBEE),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // 4. Items List
                      Expanded(
                        child: filteredLines.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    _searchQuery.isNotEmpty
                                        ? 'No items match "$_searchQuery"'
                                        : 'No requisition items found',
                                    style: const TextStyle(
                                      color: _ink600,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredLines.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, i) {
                                  final l = filteredLines[i];
                                  final busy = _busyLineIds.contains(l.itemId);
                                  final remaining = _remainApprove(l);
                                  final isExpanded = _expandedLineIds.contains(l.itemId);
                                  final isFullyApproved = remaining <= 0;
                                  final disabled = busy || isFullyApproved;
                                  final isSelected = _selectedItemIds.contains(l.itemId);

                                  return Container(
                                    decoration: BoxDecoration(
                                      color: _surface,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isExpanded
                                            ? _accentMint.withValues(alpha: 0.8)
                                            : (isFullyApproved
                                                ? const Color(0xFFA5D6A7).withValues(alpha: 0.6)
                                                : _stroke),
                                        width: isExpanded ? 1.5 : 1,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x06000000),
                                          blurRadius: 6,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Item Header Bar with Checkbox
                                        InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (isExpanded) {
                                                _expandedLineIds.remove(l.itemId);
                                              } else {
                                                _expandedLineIds.add(l.itemId);
                                              }
                                            });
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                            color: isFullyApproved
                                                ? const Color(0xFFE8F5E9).withValues(alpha: 0.35)
                                                : (isExpanded
                                                    ? _surfaceAlt.withValues(alpha: 0.45)
                                                    : Colors.transparent),
                                            child: Row(
                                              children: [
                                                // Selection Checkbox
                                                Checkbox(
                                                  value: isSelected,
                                                  activeColor: const Color(0xFF059669),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  visualDensity: VisualDensity.compact,
                                                  onChanged: disabled
                                                      ? null
                                                      : (val) {
                                                          setState(() {
                                                            if (val == true) {
                                                              _selectedItemIds.add(l.itemId);
                                                            } else {
                                                              _selectedItemIds.remove(l.itemId);
                                                            }
                                                          });
                                                        },
                                                ),
                                                const SizedBox(width: 4),

                                                // Icon
                                                Container(
                                                  padding: const EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: isFullyApproved
                                                        ? const Color(0xFFE8F5E9)
                                                        : _surfaceAlt.withValues(alpha: .6),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Icon(
                                                    isFullyApproved
                                                        ? Icons.check_circle_rounded
                                                        : Icons.inventory_2_outlined,
                                                    size: 16,
                                                    color: isFullyApproved
                                                        ? const Color(0xFF059669)
                                                        : _ink900,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),

                                                // Item Info
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        l.itemName,
                                                        maxLines: 2,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                          color: isFullyApproved ? _ink700 : _ink900,
                                                          fontWeight: FontWeight.w800,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Wrap(
                                                        spacing: 5,
                                                        runSpacing: 3,
                                                        crossAxisAlignment: WrapCrossAlignment.center,
                                                        children: [
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                            decoration: BoxDecoration(
                                                              color: _surfaceAlt.withValues(alpha: 0.5),
                                                              borderRadius: BorderRadius.circular(5),
                                                            ),
                                                            child: Text(
                                                              'Req: ${_i(l.requestedQty)}',
                                                              style: const TextStyle(
                                                                color: _ink700,
                                                                fontWeight: FontWeight.w700,
                                                                fontSize: 10.5,
                                                              ),
                                                            ),
                                                          ),
                                                          if (isFullyApproved)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFE8F5E9),
                                                                borderRadius: BorderRadius.circular(5),
                                                              ),
                                                              child: Text(
                                                                '✓ Fully Approved (${_i(l.approvedQty)})',
                                                                style: const TextStyle(
                                                                  color: Color(0xFF2E7D32),
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 10.5,
                                                                ),
                                                              ),
                                                            )
                                                          else
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEF3C7),
                                                                borderRadius: BorderRadius.circular(5),
                                                              ),
                                                              child: Text(
                                                                'Remaining: $remaining',
                                                                style: const TextStyle(
                                                                  color: Color(0xFF92400E),
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 10.5,
                                                                ),
                                                              ),
                                                            ),
                                                          if (_i(l.approvedRejectQty) > 0)
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                              decoration: BoxDecoration(
                                                                color: const Color(0xFFFEE2E2),
                                                                borderRadius: BorderRadius.circular(5),
                                                              ),
                                                              child: Text(
                                                                'Rejected: ${_i(l.approvedRejectQty)}',
                                                                style: const TextStyle(
                                                                  color: Color(0xFF991B1B),
                                                                  fontWeight: FontWeight.w800,
                                                                  fontSize: 10.5,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),

                                                // Expand/Collapse Chevron (Quick button removed per requirement)
                                                AnimatedRotation(
                                                  duration: const Duration(milliseconds: 200),
                                                  turns: isExpanded ? 0.5 : 0.0,
                                                  child: const Icon(
                                                    Icons.keyboard_arrow_down_rounded,
                                                    size: 20,
                                                    color: _ink700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        // Expanded Content Area
                                        if (isExpanded) ...[
                                          const Divider(height: 1, color: _stroke),
                                          Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.stretch,
                                              children: [
                                                if (!disabled) ...[
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: _buildQtyStepper(
                                                          label: 'Approve Qty',
                                                          controller: _qtyCtrls[l.itemId]!,
                                                          max: remaining,
                                                          activeColor: const Color(0xFF059669),
                                                          onChanged: () => setState(() {}),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: _buildQtyStepper(
                                                          label: 'Reject Qty',
                                                          controller: _rejectQtyCtrls[l.itemId]!,
                                                          max: remaining,
                                                          activeColor: const Color(0xFFC62828),
                                                          onChanged: () => setState(() {}),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 12),
                                                ],

                                                // Bottom Action Row: Confirm Approve & Reject side by side
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: FilledButton.icon(
                                                        onPressed: disabled ? null : () => _approveOne(l),
                                                        icon: busy
                                                            ? const SizedBox(
                                                                width: 14,
                                                                height: 14,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  color: Colors.white,
                                                                ),
                                                              )
                                                            : const Icon(Icons.check_rounded, size: 16),
                                                        label: Text(
                                                          busy
                                                              ? 'Approving...'
                                                              : (isFullyApproved ? 'Approved' : 'Confirm Approve'),
                                                        ),
                                                        style: FilledButton.styleFrom(
                                                          backgroundColor: const Color(0xFF059669),
                                                          foregroundColor: Colors.white,
                                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          textStyle: const TextStyle(
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: OutlinedButton.icon(
                                                        onPressed: disabled || remaining <= 0 ? null : () => _rejectOne(l),
                                                        icon: busy
                                                            ? const SizedBox(
                                                                width: 14,
                                                                height: 14,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth: 2,
                                                                  color: Color(0xFFC62828),
                                                                ),
                                                              )
                                                            : const Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFC62828)),
                                                        label: Text(
                                                          busy ? 'Rejecting...' : 'Reject',
                                                          style: const TextStyle(
                                                            color: Color(0xFFC62828),
                                                            fontWeight: FontWeight.w800,
                                                            fontSize: 12.5,
                                                          ),
                                                        ),
                                                        style: OutlinedButton.styleFrom(
                                                          foregroundColor: const Color(0xFFC62828),
                                                          side: const BorderSide(color: Color(0xFFFFCDD2)),
                                                          backgroundColor: const Color(0xFFFFEBEE),
                                                          padding: const EdgeInsets.symmetric(vertical: 9),
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
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
          ),
        );
      },
    );
  }
}

/* ---------------- Pager + Card ---------------- */

class _Pager extends StatelessWidget {
  const _Pager({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final tp = totalPages < 1 ? 1 : totalPages;

    int start = (page - 2).clamp(1, tp);
    int end = (start + 4).clamp(1, tp);
    start = (end - 4).clamp(1, tp);

    final pages = <int>[];
    for (int p = start; p <= end; p++) {
      pages.add(p);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 360;
        final btnWidth = isNarrow ? 36.0 : 42.0;
        final btnHeight = isNarrow ? 32.0 : 34.0;
        final btnPadding = isNarrow ? 3.0 : 5.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: page <= 1 ? null : () => onPage(page - 1),
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                ),
                ...pages.map((p) {
                  final active = p == page;
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: btnPadding),
                    child: InkWell(
                      onTap: () => onPage(p),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: btnWidth,
                        height: btnHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? _accentMint.withValues(alpha: .75) : _surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _stroke),
                        ),
                        child: Text(
                          '$p',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: isNarrow ? 12 : 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: page >= tp ? null : () => onPage(page + 1),
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(14)});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
