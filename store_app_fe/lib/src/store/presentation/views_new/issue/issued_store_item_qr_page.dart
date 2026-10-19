// lib/src/store/presentation/views/issue/issued_store_item_qr_paged.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:store_app/src/components/socket_manager.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../domains/models/store_item_model.dart';
import '../../widgets/badge_chip_widget.dart';
import 'create_store_issue.dart';
import 'issue_item/issue_item_in_single.dart';
import 'qr_code_scanner/qr_code_print_page.dart';

/* ───────────────────── Light Palette ───────────────────── */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

final _cardBorder = BorderSide(color: _stroke, width: 1);

/* =========================================================
   1) Query + Paged model
   ========================================================= */

class StoreItemQuery {
  final int page;
  final int limit;
  final String search; // item name / code / category / id
  final String sort; // e.g. "-createdAt", "name"

  const StoreItemQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.sort,
  });

  StoreItemQuery copyWith({
    int? page,
    int? limit,
    String? search,
    String? sort,
  }) {
    return StoreItemQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "sort": sort,
  };
}

class PagedStoreItems {
  final List<StoreItem> rows;
  final int total;
  final int page;
  final int limit;

  const PagedStoreItems({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* =========================================================
   2) Socket stream provider (server-side pagination)
   ========================================================= */

final storeItemPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedStoreItems, StoreItemQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedStoreItems>(sync: true);

      void handler(dynamic data) {
        try {
          final list =
              (data['rows'] as List? ?? const [])
                  .map((e) => StoreItem.fromMap(e as Map<String, dynamic>))
                  .toList();

          controller.add(
            PagedStoreItems(
              rows: list,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? query.page) as int,
              limit: (data['limit'] ?? query.limit) as int,
            ),
          );
        } catch (_) {}
      }

      socket.on("store:findAllStoreItemFilter", handler);
      socket.emit("store:findAllStoreItemFilter", query.toJson());

      ref.onDispose(() {
        socket.off("store:findAllStoreItemFilter", handler);
        controller.close();
      });

      // Initial empty
      yield PagedStoreItems(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      await for (final v in controller.stream) {
        yield v;
      }
    });

/* =========================================================
   3) PAGE
   ========================================================= */

class IssuedStoreItemQrPage extends ConsumerStatefulWidget {
  const IssuedStoreItemQrPage({super.key});

  @override
  ConsumerState<IssuedStoreItemQrPage> createState() =>
      _IssuedStoreItemQrPageState();
}

class _IssuedStoreItemQrPageState extends ConsumerState<IssuedStoreItemQrPage> {
  static const double _pagerHeight = 64;

  StoreItemQuery _q = const StoreItemQuery(
    page: 1,
    limit: 12,
    search: "",
    sort: "-createdAt",
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
      ref.refresh(storeItemPagedStreamProvider(_q));
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
      _q = const StoreItemQuery(
        page: 1,
        limit: 12,
        search: "",
        sort: "-createdAt",
      );
    });
  }

  Future<void> _openFilterSheet() async {
    final r = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (_) => _FilterSheet(
            initial: _FilterResult(limit: _q.limit, sort: _q.sort),
          ),
    );
    if (r != null) {
      setState(() {
        _q = _q.copyWith(page: 1, limit: r.limit, sort: r.sort);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagedAsync = ref.watch(storeItemPagedStreamProvider(_q));
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canIssueAdd = canAdmin || perms.contains('storissueadd');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        // If you want a back button here:
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: const [
            Icon(Icons.inventory_2_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Store Items',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      floatingActionButton:
          (canIssueAdd)
              ? _PeachFab(
                icon: Icons.add_box_rounded,
                label: 'Issue Create',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const IssueCreatePage()),
                  );
                },
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SearchToolbar(
                        controller: _searchCtrl,
                        hint: 'Search by name / category / code / id',
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),
                  pagedAsync.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    error:
                        (e, _) => SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            16 + _pagerHeight,
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
                    data: (paged) {
                      if (paged.rows.isEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            16 + _pagerHeight,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _EmptyState(
                              title: 'No items found',
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
                          16 + _pagerHeight,
                        ),
                        sliver: SliverLayoutBuilder(
                          builder: (context, constraints) {
                            final maxW = constraints.crossAxisExtent;
                            const desiredTileW = 320.0;
                            const gap = 12.0;
                            final cols = (maxW / (desiredTileW + gap))
                                .floor()
                                .clamp(1, 4);

                            return SliverMasonryGrid.count(
                              crossAxisCount: cols,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childCount: paged.rows.length,
                              itemBuilder:
                                  (context, i) =>
                                      _StoreItemCard(item: paged.rows[i]),
                            );
                          },
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
                  child: pagedAsync.maybeWhen(
                    data:
                        (paged) => _StickyPager(
                          height: _pagerHeight,
                          total: paged.total,
                          pageSize: paged.limit,
                          pageIndex: paged.page,
                          onPrev:
                              paged.page > 1
                                  ? () => setState(() {
                                    _q = StoreItemQuery(
                                      page: paged.page - 1,
                                      limit: paged.limit,
                                      search: _q.search,
                                      sort: _q.sort,
                                    );
                                  })
                                  : null,
                          onNext:
                              (paged.page * paged.limit < paged.total)
                                  ? () => setState(() {
                                    _q = StoreItemQuery(
                                      page: paged.page + 1,
                                      limit: paged.limit,
                                      search: _q.search,
                                      sort: _q.sort,
                                    );
                                  })
                                  : null,
                          onJump:
                              (p) => setState(() {
                                _q = StoreItemQuery(
                                  page: p,
                                  limit: paged.limit,
                                  search: _q.search,
                                  sort: _q.sort,
                                );
                              }),
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

/* =================== Responsive Light Search Toolbar =================== */

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

        // Small screens: stack into two rows to avoid overflow
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

        // Wide: single row
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
                    tooltip: 'Clear',
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

/* =================== Filter Sheet (Light) =================== */

class _FilterResult {
  final int limit;
  final String sort;
  const _FilterResult({required this.limit, required this.sort});

  _FilterResult copyWith({int? limit, String? sort}) =>
      _FilterResult(limit: limit ?? this.limit, sort: sort ?? this.sort);
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _FilterResult initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterResult _v;

  @override
  void initState() {
    super.initState();
    _v = widget.initial;
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
          const SizedBox(height: 16),

          _Section(
            label: 'Page size',
            child: Wrap(
              spacing: 8,
              children:
                  [8, 12, 20, 32].map((n) {
                    final selected = _v.limit == n;
                    return ChoiceChip(
                      label: Text('$n'),
                      selected: selected,
                      onSelected:
                          (_) => setState(() => _v = _v.copyWith(limit: n)),
                      selectedColor: _accentMint,
                      backgroundColor: _surface,
                      labelStyle: TextStyle(
                        color: _ink900,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                      shape: StadiumBorder(side: _cardBorder),
                    );
                  }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          _Section(
            label: 'Sort',
            child: Wrap(
              spacing: 8,
              children: [
                _sortChip('Newest', '-createdAt'),
                _sortChip('Oldest', 'createdAt'),
                _sortChip('Name ↑', 'name'),
                _sortChip('Name ↓', '-name'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PeachButton.icon(
                  icon: Icons.check_rounded,
                  label: 'Apply',
                  onPressed: () => Navigator.pop(context, _v),
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

  Widget _sortChip(String label, String value) {
    final selected = _v.sort == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _v = _v.copyWith(sort: value)),
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

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink700, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/* =================== Sticky Pager (Light) =================== */

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

/* =================== Item Card (Light) =================== */

class _StoreItemCard extends ConsumerStatefulWidget {
  const _StoreItemCard({required this.item});
  final StoreItem item;

  @override
  ConsumerState<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends ConsumerState<_StoreItemCard> {
  bool _expanded = false;
  void _toggleExpand() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final it = widget.item;

    Widget headerImage() => Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _surfaceAlt,
              border: Border.all(color: _stroke),
              image:
                  it.imageUrl.isNotEmpty
                      ? DecorationImage(
                        image: NetworkImage(it.imageUrl),
                        fit: BoxFit.cover,
                      )
                      : null,
            ),
            child:
                it.imageUrl.isEmpty
                    ? const Center(
                      child: Icon(
                        Icons.photo_outlined,
                        color: _ink600,
                        size: 36,
                      ),
                    )
                    : null,
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: Tooltip(
            message: 'Print QR',
            child: Material(
              color: Colors.transparent,
              child: Ink(
                decoration: BoxDecoration(
                  color: _surface.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QRCodePrintPage(storeItemList: [it]),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Icon(
                      Icons.qr_code_2_rounded,
                      color: _ink900,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

    Widget titleRow() => Row(
      children: [
        Expanded(
          child: Text(
            it.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(width: 8),
        BadgeChip(icon: Icons.category_outlined, label: it.category),
      ],
    );

    Widget stockRow() => Wrap(spacing: 6, runSpacing: 6, children: const []);

    final totalP = _StockPill(
      label: 'Total',
      value: it.totalStockQuantity,
      icon: Icons.all_inbox_outlined,
    );
    final availP = _StockPill(
      label: 'Avail',
      value: it.stockAvailableQuantity,
      icon: Icons.inventory_outlined,
    );
    final issP = _StockPill(
      label: 'Issued',
      value: it.stockIssueQuantity,
      icon: Icons.outbox_outlined,
    );
    final comP = _StockPill(
      label: 'Complete',
      value: it.stockissueCompleted,
      icon: Icons.outbox_outlined,
    );
    final scrapP = _StockPill(
      label: 'Scrap',
      value: it.stockscrapQuantity,
      icon: Icons.delete_outline,
    );

    Widget actions() => Center(
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          _MintOutlineButton.icon(
            icon: Icons.qr_code_2_rounded,
            label: 'QR Code',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => QRCodePrintPage(storeItemList: [it]),
                ),
              );
            },
          ),
          _PeachButton.icon(
            icon: Icons.upload_rounded,
            label: 'Issue',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IssueCreateOneItemPage(itemId: it.id),
                ),
              );
            },
          ),
        ],
      ),
    );

    Widget expandToggle() => InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.circular(10),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Show details',
              style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
            ),
            SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, color: _ink700),
          ],
        ),
      ),
    );

    return _Card(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerImage(),
          const SizedBox(height: 8),
          titleRow(),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [totalP, availP, issP, comP, scrapP],
          ),
          const SizedBox(height: 6),
          expandToggle(),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: actions(),
            ),
          ),
        ],
      ),
    );
  }
}

/* =================== Light Pills / Buttons / Cards =================== */

class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final dynamic value;
  final IconData icon;

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toString();
    final n = num.tryParse(v.toString());
    return (n ?? 0).toString();
  }

  @override
  Widget build(BuildContext context) {
    final text = '$label: ${_fmt(value)}';
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 110, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _accentMint.withValues(alpha: .30),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _stroke),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _ink700),
              const SizedBox(width: 6),
              Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: .2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({this.child, this.padding, this.height});
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
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
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
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

/* =================== Light Buttons =================== */

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

class _PeachFab extends StatelessWidget {
  const _PeachFab({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: _accentPeach,
      foregroundColor: _ink900,
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _stroke),
      ),
    );
  }
}
