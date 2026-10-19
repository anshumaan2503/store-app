// lib/src/store/presentation/views/issue/issue_closed_list_paged.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/socket_manager.dart';
import 'issue_detail_page.dart';
import 'issue_return_item_page.dart';

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

/* ---------------- Models ---------------- */

class ClosedIssueQuery {
  final int page;
  final int limit;
  final String search; // issNo/reason/lines.itemName
  final List<String> status;
  final String sort; // "-createdAt" etc.

  const ClosedIssueQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.status,
    required this.sort,
  });

  ClosedIssueQuery copyWith({
    int? page,
    int? limit,
    String? search,
    List<String>? status,
    String? sort,
  }) {
    return ClosedIssueQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status ?? this.status,
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

/* --------- Socket Stream Provider (server paging) --------- */

final closedIssuesPagedProvider = StreamProvider.autoDispose
    .family<PagedIssues, ClosedIssueQuery>((ref, q) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedIssues>(sync: true);

      void handler(dynamic data) {
        try {
          final list =
              (data['rows'] as List? ?? const [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map),
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

      socket.on("store:findStatusItemIssueClosePaged", handler);
      socket.emit("store:findStatusItemIssueClosePaged", q.toJson());

      ref.onDispose(() {
        socket.off("store:findStatusItemIssueClosePaged", handler);
        controller.close();
      });

      yield PagedIssues(rows: const [], total: 0, page: q.page, limit: q.limit);

      await for (final v in controller.stream) {
        yield v;
      }
    });

/* ---------------- Page (light theme) ---------------- */

class IssueClosedListPage extends ConsumerStatefulWidget {
  const IssueClosedListPage({super.key});

  @override
  ConsumerState<IssueClosedListPage> createState() =>
      _IssueClosedListPageState();
}

class _IssueClosedListPageState extends ConsumerState<IssueClosedListPage> {
  static const double _stickyPagerHeight = 64;

  ClosedIssueQuery _q = const ClosedIssueQuery(
    page: 1,
    limit: 10,
    search: '',
    status: ['CLOSED'],
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
      ref.refresh(closedIssuesPagedProvider(_q));
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
      _q = const ClosedIssueQuery(
        page: 1,
        limit: 10,
        status: ['CLOSED'],
        search: '',
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
      setState(() => _q = _q.copyWith(page: 1, limit: r.limit, sort: r.sort));
    }
  }

  @override
  Widget build(BuildContext context) {
    final paged = ref.watch(closedIssuesPagedProvider(_q));

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
            Icon(Icons.done_all_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Closed Issues',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
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
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Search + Filter / Reset
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SearchToolbar(
                        controller: _searchCtrl,
                        hint: 'Search Issue No / Reason / Item name',
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
                              title: 'No closed issues',
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
                          itemBuilder:
                              (_, i) => _ClosedIssueRow(doc: pg.rows[i]),
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

/* ---------------- Filter Sheet (page size + sort) ---------------- */

class _FilterResult {
  final List<String> status;
  final int limit; // 8,10,12,20,32
  final String sort; // -createdAt, createdAt, issNo, -issNo
  const _FilterResult({
    required this.status,
    required this.limit,
    required this.sort,
  });

  _FilterResult copyWith({List<String>? status, int? limit, String? sort}) =>
      _FilterResult(
        status: status ?? this.status,
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
                [8, 10, 12, 20, 32].map((n) {
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

/* ---------------- Compact search bar + buttons ---------------- */

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

/* ---------------- Rows & widgets ---------------- */

class _ClosedIssueRow extends StatefulWidget {
  const _ClosedIssueRow({required this.doc});
  final Map<String, dynamic> doc;

  @override
  State<_ClosedIssueRow> createState() => _ClosedIssueRowState();
}

class _ClosedIssueRowState extends State<_ClosedIssueRow> {
  bool _expanded = false;

  void _toggleExpand() => setState(() => _expanded = !_expanded);

  Color _statusColor() => const Color(0xFF6366F1); // Closed → Indigo

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final issNo = (doc['issNo'] ?? '').toString();
    final reason = (doc['reason'] ?? '').toString();
    final created = (doc['createdAt'] ?? '').toString();
    final tint = _statusColor();

    return _Card(
      padding: const EdgeInsets.all(12),
      borderColor: tint.withValues(alpha: .35),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _toggleExpand,
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
                  child: const Icon(Icons.done_all_rounded, color: _ink900),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issNo,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                        ),
                        overflow: TextOverflow.ellipsis,
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
                const SizedBox(width: 8),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 180),
                  turns: _expanded ? 0.5 : 0.0,
                  child: const Icon(Icons.expand_more_rounded, color: _ink700),
                ),
              ],
            ),
          ),

          // Expanding section
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child:
                _expanded
                    ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Status: CLOSED',
                              style: TextStyle(
                                color: tint,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
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
                                        builder:
                                            (_) =>
                                                IssueDetailPage(id: doc['_id']),
                                      ),
                                    );
                                  },
                                ),
                                _PeachButton.icon(
                                  icon: Icons.undo_rounded,
                                  label: 'Return',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (_) =>
                                                IssueReturnPage(issueDoc: doc),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/* ---------------- Sticky Pager (light) ---------------- */

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

/* ---------------- Legacy pager helper (kept if used elsewhere) ---------------- */

class _PagerBar extends StatelessWidget {
  const _PagerBar({
    required this.total,
    required this.pageSize,
    required this.pageIndex,
    required this.onPrev,
    required this.onNext,
    required this.onJump,
  });

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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
