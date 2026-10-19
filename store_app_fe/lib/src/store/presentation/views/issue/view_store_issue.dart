// lib/src/store/presentation/views/issue/issue_list_paged.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/socket_manager.dart';
import '../../../controllers/store_item_issue_controller.dart';

import 'edit_store_issue.dart';
import 'issue_detail_page.dart';
import 'issue_to_place_page.dart';
import 'qr_code_scanner/qr_code_scanner.dart';

/* ───────────────────────── Palette ───────────────────────── */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF8);
const _bgBottom = _surfaceAlt;

final _cardBorder = BorderSide(color: _stroke, width: 1);

/* =========================
 * Query + Result models
 * ========================= */
class IssueQuery {
  final int page;
  final int limit;
  final String search; // issue no / reason / item name
  final String? status; // null = all
  final String sort; // e.g. "-createdAt"
  const IssueQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.status,
    required this.sort,
  });

  IssueQuery copyWith({
    int? page,
    int? limit,
    String? search,
    String? status, // can be null
    String? sort,
  }) {
    return IssueQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "status": status,
    "sort": sort,
  };
}

class PagedIssues {
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  const PagedIssues({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* ==========================================
 * Socket provider with server-side pagination
 * Event: store:findAllItemIssuePaged
 * ========================================== */
final itemIssuePagedStreamProvider = StreamProvider.autoDispose
    .family<PagedIssues, IssueQuery>((ref, q) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedIssues>(sync: true);

      void handler(dynamic data) {
        try {
          final list =
              (data['rows'] as List? ?? const [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e),
                  )
                  .toList();
          controller.add(
            PagedIssues(
              rows: list,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? q.page) as int,
              limit: (data['limit'] ?? q.limit) as int,
            ),
          );
        } catch (_) {}
      }

      socket.on("store:findAllItemIssuePaged", handler);
      socket.emit("store:findAllItemIssuePaged", q.toJson());

      ref.onDispose(() {
        socket.off("store:findAllItemIssuePaged", handler);
        controller.close();
      });

      // initial empty
      yield PagedIssues(rows: const [], total: 0, page: q.page, limit: q.limit);

      await for (final v in controller.stream) {
        yield v;
      }
    });

/* =========================
 * Paged Issue List Page (light theme)
 * ========================= */
class IssueListPage extends ConsumerStatefulWidget {
  const IssueListPage({super.key});

  @override
  ConsumerState<IssueListPage> createState() => _IssueListPageState();
}

class _IssueListPageState extends ConsumerState<IssueListPage> {
  static const double _stickyPagerHeight = 64;

  IssueQuery _q = const IssueQuery(
    page: 1,
    limit: 12,
    search: '',
    status: null,
    sort: '-createdAt',
  );

  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _q.search;
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 350), () {
        setState(
          () => _q = _q.copyWith(page: 1, search: _searchCtrl.text.trim()),
        );
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(itemIssuePagedStreamProvider(_q));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _searchCtrl.text = '';
    setState(() {
      _q = const IssueQuery(
        page: 1,
        limit: 12,
        search: '',
        status: null,
        sort: '-createdAt',
      );
    });
  }

  Future<void> _openFilterSheet() async {
    final r = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => _FilterSheet(
            initial: _FilterResult(
              status: _q.status,
              limit: _q.limit,
              sort: _q.sort,
            ),
          ),
    );
    if (r != null) {
      setState(() {
        _q = _q.copyWith(
          page: 1,
          status: r.status,
          limit: r.limit,
          sort: r.sort,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paged = ref.watch(itemIssuePagedStreamProvider(_q));
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canIssueMoveToPlace =
        canAdmin || perms.contains('storissuefromstock');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Row(
          children: [
            Icon(Icons.outbox_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Issues',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      floatingActionButton:
          (canIssueMoveToPlace)
              ? FloatingActionButton.extended(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrCodeScanner()),
                  );
                },
                icon: const Icon(Icons.qr_code_scanner_rounded, color: _ink900),
                label: const Text(
                  'Scan',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                ),
                backgroundColor: _accentPeach,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: _stroke),
                ),
              )
              : null,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Search + filter/reset
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SearchToolbar(
                        controller: _searchCtrl,
                        hint: 'Search by Issue No / Reason / Item name',
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),

                  // Body
                  paged.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    error:
                        (e, _) => SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            8 + _stickyPagerHeight,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _Card(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error: $e',
                                style: const TextStyle(color: _ink700),
                              ),
                            ),
                          ),
                        ),
                    data: (pg) {
                      if (pg.rows.isEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            22 + _stickyPagerHeight,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _EmptyState(
                              title: 'No issues found',
                              icon: Icons.inbox_outlined,
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          12 + _stickyPagerHeight,
                        ),
                        sliver: SliverList.separated(
                          itemCount: pg.rows.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _IssueRow(issue: pg.rows[i]),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // Sticky pager
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: paged.maybeWhen(
                    data:
                        (pg) => _StickyPager(
                          height: _stickyPagerHeight,
                          total: pg.total,
                          pageSize: pg.limit,
                          pageIndex: pg.page,
                          onPrev:
                              pg.page > 1
                                  ? () => setState(
                                    () => _q = _q.copyWith(page: pg.page - 1),
                                  )
                                  : null,
                          onNext:
                              (pg.page * pg.limit < pg.total)
                                  ? () => setState(
                                    () => _q = _q.copyWith(page: pg.page + 1),
                                  )
                                  : null,
                          onJump:
                              (p) => setState(() => _q = _q.copyWith(page: p)),
                        ),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* =========================
 * Small widgets (cards/actions)
 * ========================= */

class _IssueRow extends ConsumerStatefulWidget {
  const _IssueRow({required this.issue});
  final Map<String, dynamic> issue;

  @override
  ConsumerState<_IssueRow> createState() => _IssueRowState();
}

class _IssueRowState extends ConsumerState<_IssueRow> {
  bool _saving = false;
  bool _expanded = false;

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'DRAFT':
        return const Color(0xFFF59E0B);
      case 'APPROVED':
        return const Color(0xFF22C55E);
      case 'CLOSED':
        return const Color(0xFF6366F1);
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      default:
        return Colors.grey;
    }
  }

  Future<void> _close() async {
    setState(() => _saving = true);
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
      final body = {"id": widget.issue['_id'], "userId": createdBy};
      await ref
          .read(itemIssueControllerProvider)
          .closeItemIssue(returnItemIssue: body);
      if (!mounted) return;
      _showSnack('Closed');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleExpand() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');

    final canIssueEdit = canAdmin || perms.contains('storissueedit');
    final canIssueClose = canAdmin || perms.contains('storissueclose');
    final canIssueMoveToPlace =
        canAdmin || perms.contains('storissuefromstock');

    final m = widget.issue;
    final status = (m['status'] ?? '').toString();
    final created = m['createdAt']?.toString() ?? '';
    final issNo = m['issNo']?.toString() ?? '';
    final reason = m['reason']?.toString() ?? '';
    final tint = _statusColor(status);

    return _Card(
      padding: const EdgeInsets.all(12),
      borderColor: tint.withValues(alpha: .35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssueDetailPage(id: m['_id']),
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _accentMint.withValues(alpha: .45),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(Icons.outbox_rounded, color: _ink900),
                ),
                const SizedBox(width: 12),

                // info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issNo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reason,
                        style: const TextStyle(color: _ink700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        created,
                        style: const TextStyle(color: _ink600, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Expand toggle
          InkWell(
            onTap: _toggleExpand,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _expanded ? 'Hide actions' : 'Show actions',
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: _ink700,
                  ),
                ],
              ),
            ),
          ),

          // Bottom explanation (expandable)
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                children: [
                  // Status name
                  Text(
                    status,
                    style: TextStyle(
                      color: tint,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Centered, overflow-safe buttons
                  Center(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        _MintOutlineButton.icon(
                          icon: Icons.visibility_rounded,
                          label: 'View',
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IssueDetailPage(id: m['_id']),
                              ),
                            );
                          },
                        ),

                        if (status == 'APPROVED' && canIssueMoveToPlace)
                          _PeachButton.icon(
                            icon: Icons.inventory_2_rounded,
                            label: 'Move to Place',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          IssueToPlacePage(issueId: m['_id']),
                                ),
                              );
                            },
                          ),
                        if (status == 'APPROVED' && canIssueClose)
                          _PeachButton.icon(
                            icon:
                                _saving
                                    ? Icons.hourglass_top_rounded
                                    : Icons.verified_rounded,
                            label: _saving ? 'Saving…' : 'Close',
                            onPressed: _saving ? null : _close,
                          ),

                        if (status == 'DRAFT' && canIssueEdit)
                          _MintOutlineButton.icon(
                            icon: Icons.edit_rounded,
                            label: 'Edit',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IssueEditPage(issue: m),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* =========================
 * Sticky pager (light)
 * ========================= */
class _StickyPager extends StatelessWidget {
  const _StickyPager({
    required this.height,
    required this.total,
    required this.pageSize,
    required this.pageIndex,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

  final double height;
  final int total;
  final int pageSize;
  final int pageIndex; // 1-based
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final pages = total == 0 ? 1 : ((total - 1) / pageSize).floor() + 1;

    return _Card(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous',
            color: _ink900,
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(pages, (i) {
                  final idx = i + 1;
                  final selected = idx == pageIndex;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: ChoiceChip(
                      label: Text('$idx'),
                      selected: selected,
                      onSelected: (_) => onJump(idx),
                      selectedColor: _accentMint,
                      backgroundColor: _surface,
                      labelStyle: TextStyle(
                        color: _ink900,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: StadiumBorder(side: _cardBorder),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Next',
            color: _ink900,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/* =========================
 * Bottom Sheet: Status + Page size + Sort (light)
 * ========================= */
class _FilterResult {
  final String? status; // null, DRAFT, APPROVED, CLOSED, CANCELLED
  final int limit; // 8,12,20,32
  final String sort; // -createdAt, createdAt, issNo, -issNo

  const _FilterResult({
    required this.status,
    required this.limit,
    required this.sort,
  });

  _FilterResult copyWith({String? status, int? limit, String? sort}) =>
      _FilterResult(
        status: status,
        limit: limit ?? this.limit,
        sort: sort ?? this.sort,
      );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _FilterResult initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterResult v;

  @override
  void initState() {
    super.initState();
    v = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _stroke,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Filters',
              style: TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Status',
              style: TextStyle(color: _ink700, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _statusChip(
                null,
                'All',
                Icons.all_inbox_rounded,
                v.status == null,
                () => setState(() => v = v.copyWith(status: null)),
              ),
              _statusChip(
                'DRAFT',
                'Draft',
                Icons.description_rounded,
                v.status == 'DRAFT',
                () => setState(() => v = v.copyWith(status: 'DRAFT')),
              ),
              _statusChip(
                'APPROVED',
                'Approved',
                Icons.verified_rounded,
                v.status == 'APPROVED',
                () => setState(() => v = v.copyWith(status: 'APPROVED')),
              ),
              _statusChip(
                'CLOSED',
                'Closed',
                Icons.lock_clock_rounded,
                v.status == 'CLOSED',
                () => setState(() => v = v.copyWith(status: 'CLOSED')),
              ),
              _statusChip(
                'CANCELLED',
                'Cancelled',
                Icons.cancel_rounded,
                v.status == 'CANCELLED',
                () => setState(() => v = v.copyWith(status: 'CANCELLED')),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Page size
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Page size',
              style: TextStyle(color: _ink700, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children:
                [8, 12, 20, 32].map((n) {
                  final selected = v.limit == n;
                  return ChoiceChip(
                    label: Text('$n'),
                    selected: selected,
                    onSelected: (_) => setState(() => v = v.copyWith(limit: n)),
                    selectedColor: _accentMint,
                    backgroundColor: _surface,
                    labelStyle: TextStyle(
                      color: _ink900,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    shape: StadiumBorder(side: _cardBorder),
                  );
                }).toList(),
          ),

          const SizedBox(height: 16),

          // Sort
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Sort',
              style: TextStyle(color: _ink700, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _sortChip(
                '-createdAt',
                'Newest',
                v.sort == '-createdAt',
                () => setState(() => v = v.copyWith(sort: '-createdAt')),
              ),
              _sortChip(
                'createdAt',
                'Oldest',
                v.sort == 'createdAt',
                () => setState(() => v = v.copyWith(sort: 'createdAt')),
              ),
              _sortChip(
                'issNo',
                'Issue No ↑',
                v.sort == 'issNo',
                () => setState(() => v = v.copyWith(sort: 'issNo')),
              ),
              _sortChip(
                '-issNo',
                'Issue No ↓',
                v.sort == '-issNo',
                () => setState(() => v = v.copyWith(sort: '-issNo')),
              ),
            ],
          ),

          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _PeachButton.icon(
                  icon: Icons.check_rounded,
                  label: 'Apply',
                  onPressed: () => Navigator.pop(context, v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MintOutlineButton.icon(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusChip(
    String? key,
    String label,
    IconData icon,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _accentPeach,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: StadiumBorder(side: _cardBorder),
    );
  }

  Widget _sortChip(
    String value,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _accentPeach,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: StadiumBorder(side: _cardBorder),
    );
  }
}

/* =========================
 * Search toolbar (responsive)
 * ========================= */
class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({
    required this.controller,
    required this.hint,
    required this.onFilterTap,
    required this.onReset,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onFilterTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;

        if (w < 520) {
          return _Card(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _SearchField(controller: controller, hint: hint),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _PeachButton.icon(
                      icon: Icons.tune_rounded,
                      label: 'Filter',
                      onPressed: onFilterTap,
                    ),
                    const SizedBox(width: 8),
                    _MintOutlineButton.icon(
                      icon: Icons.restart_alt_rounded,
                      label: 'Reset',
                      onPressed: onReset,
                    ),
                  ],
                ),
              ],
            ),
          );
        }

        return _Card(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(child: _SearchField(controller: controller, hint: hint)),
              const SizedBox(width: 8),
              _PeachButton.icon(
                icon: Icons.tune_rounded,
                label: 'Filter',
                onPressed: onFilterTap,
              ),
              const SizedBox(width: 8),
              _MintOutlineButton.icon(
                icon: Icons.restart_alt_rounded,
                label: 'Reset',
                onPressed: onReset,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        style: const TextStyle(color: _ink900),
        decoration: InputDecoration(
          isDense: true,
          hintText: hint,
          hintStyle: const TextStyle(color: _ink600),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: _ink700,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          filled: true,
          fillColor: _surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: _cardBorder,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: _cardBorder,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _accentMint, width: 2),
          ),
          suffixIcon:
              (controller.text.isNotEmpty)
                  ? IconButton(
                    onPressed: () => controller.clear(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: _ink700,
                      size: 18,
                    ),
                  )
                  : null,
        ),
      ),
    );
  }
}

/* =========================
 * Reusable light components
 * ========================= */

class _Card extends StatelessWidget {
  const _Card({this.child, this.padding, this.height, this.borderColor});

  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? height;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor ?? _stroke, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 44, color: _ink600),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/* ---- Buttons: Peach filled & Mint outline ---- */

class _PeachButton extends StatelessWidget {
  const _PeachButton({required this.onPressed, required this.child});
  final VoidCallback? onPressed;
  final Widget child;

  static Widget icon({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return _PeachButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _ink900, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: _accentPeach,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _stroke),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}

class _MintOutlineButton extends StatelessWidget {
  const _MintOutlineButton({
    required this.onPressed,
    required this.child,
  });
  final VoidCallback? onPressed;
  final Widget child;

  static Widget icon({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return _MintOutlineButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _ink900, size: 18),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _accentMint, width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: child,
        ),
      ),
    );
  }
}
