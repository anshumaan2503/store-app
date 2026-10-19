// lib/src/store/presentation/views/store_item/store_items_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../controllers/store_item_controller.dart';
import '../../../domains/models/store_item_model.dart';
import '../issue/qr_code_scanner/qr_code_print_page.dart';
import 'package:store_app/src/components/motion_widgets.dart';
import 'create_store_item.dart';

/* ───────────────────────────────────────────────────────────
 * Palette (unified with dashboard)
 * ─────────────────────────────────────────────────────────── */
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

/* ───────────────────────────────────────────────────────────
 * Page
 * ─────────────────────────────────────────────────────────── */
class StoreItemsPage extends ConsumerStatefulWidget {
  const StoreItemsPage({super.key});

  @override
  ConsumerState<StoreItemsPage> createState() => _StoreItemsPageState();
}

class _StoreItemsPageState extends ConsumerState<StoreItemsPage> {
  static const double _pagerHeight = 64;

  // Local query state
  StoreItemQuery _query = const StoreItemQuery(
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
    _searchCtrl.text = _query.search;
    _searchCtrl.addListener(() {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _query = StoreItemQuery(
            page: 1,
            limit: _query.limit,
            search: _searchCtrl.text,
            sort: _query.sort,
          );
        });
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openFilterSheet() async {
    final res = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (_) => _FilterSheet(
            initial: _FilterResult(limit: _query.limit, sort: _query.sort),
          ),
    );
    if (res != null) {
      setState(() {
        _query = StoreItemQuery(
          page: 1,
          limit: res.limit,
          search: _query.search,
          sort: res.sort,
        );
      });
    }
  }

  void _resetAll() {
    _searchCtrl.text = '';
    setState(() {
      _query = const StoreItemQuery(
        page: 1,
        limit: 12,
        search: '',
        sort: '-createdAt',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pagedAsync = ref.watch(storeItemPagedStreamProvider(_query));
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };

    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canAddItem = canAdmin || perms.contains('storeitemadd');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: AppBackButton(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
          canAddItem
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreItemFormPage(),
                    ),
                  );
                },
                backgroundColor: _ink900,
                foregroundColor: _surface,
                icon: const Icon(Icons.add_box_rounded),
                label: const Text('Add item'),
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
                  // Search / Filters
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _SearchCard(
                        controller: _searchCtrl,
                        hint: 'Search by name / category / code / id',
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),

                  // Results
                  pagedAsync.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                    error:
                        (e, _) => SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            12 + _pagerHeight,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _Card(
                              radius: 16,
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'Error loading items.',
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    data: (paged) {
                      if (paged.rows.isEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            12 + _pagerHeight,
                          ),
                          sliver: SliverToBoxAdapter(
                            child: _Card(
                              radius: 16,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 84,
                                    height: 84,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _accentPeach.withValues(alpha: .45),
                                    ),
                                    child: const Icon(
                                      Icons.inbox_outlined,
                                      size: 40,
                                      color: _ink900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _query.search.isEmpty
                                        ? 'No items found'
                                        : 'No results for “${_query.search}”',
                                    style: const TextStyle(
                                      color: _ink900,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: EdgeInsets.fromLTRB(
                          12,
                          8,
                          12,
                          12 + _pagerHeight,
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
                              itemBuilder: (context, i) {
                                return _StoreItemCard(item: paged.rows[i]);
                              },
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
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: pagedAsync.maybeWhen(
                    data:
                        (paged) => _PagerBar(
                          height: _pagerHeight,
                          total: paged.total,
                          pageSize: paged.limit,
                          pageIndex: paged.page,
                          onPrev:
                              paged.page > 1
                                  ? () => setState(() {
                                    _query = StoreItemQuery(
                                      page: paged.page - 1,
                                      limit: paged.limit,
                                      search: _query.search,
                                      sort: _query.sort,
                                    );
                                  })
                                  : null,
                          onNext:
                              (paged.page * paged.limit < paged.total)
                                  ? () => setState(() {
                                    _query = StoreItemQuery(
                                      page: paged.page + 1,
                                      limit: paged.limit,
                                      search: _query.search,
                                      sort: _query.sort,
                                    );
                                  })
                                  : null,
                          onJump:
                              (p) => setState(() {
                                _query = StoreItemQuery(
                                  page: p,
                                  limit: paged.limit,
                                  search: _query.search,
                                  sort: _query.sort,
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

/* ───────────────────────────────────────────────────────────
 * Search Card (light)
 * ─────────────────────────────────────────────────────────── */
class _SearchCard extends StatelessWidget {
  const _SearchCard({
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
    return _Card(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search & Filter',
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _stroke, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.search_rounded,
                        color: _ink600,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: 'Search items…',
                            hintStyle: TextStyle(
                              color: _ink600,
                              fontWeight: FontWeight.w500,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      if (controller.text.isNotEmpty)
                        IconButton(
                          splashRadius: 20,
                          icon: const Icon(
                            Icons.close_rounded,
                            color: _ink600,
                            size: 20,
                          ),
                          onPressed: () => controller.clear(),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _PillBtn(
                icon: Icons.tune_rounded,
                label: 'Filter',
                onTap: onFilterTap,
              ),
              const SizedBox(width: 10),
              _PillBtn(
                icon: Icons.restart_alt_rounded,
                label: 'Reset',
                onTap: onReset,
                subtle: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Filter Sheet (light)
 * ─────────────────────────────────────────────────────────── */
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.34,
      minChildSize: 0.28,
      maxChildSize: 0.80,
      builder: (ctx, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 16)],
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Filters',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 14),

              const Text(
                'Page size',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children:
                    [8, 12, 20, 32].map((n) {
                      final selected = _v.limit == n;
                      return ChoiceChip(
                        label: Text('$n'),
                        selected: selected,
                        onSelected:
                            (_) => setState(() => _v = _v.copyWith(limit: n)),
                        selectedColor: _ink900,
                        backgroundColor: _surface,
                        labelStyle: TextStyle(
                          color: selected ? _surface : _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: selected ? _ink900 : _stroke),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 14),

              const Text(
                'Sort',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _SortChip(
                    value: '-createdAt',
                    label: 'Newest',
                    selected: _v.sort == '-createdAt',
                    onTap:
                        () => setState(
                          () => _v = _v.copyWith(sort: '-createdAt'),
                        ),
                  ),
                  _SortChip(
                    value: 'createdAt',
                    label: 'Oldest',
                    selected: _v.sort == 'createdAt',
                    onTap:
                        () =>
                            setState(() => _v = _v.copyWith(sort: 'createdAt')),
                  ),
                  _SortChip(
                    value: 'name',
                    label: 'Name ↑',
                    selected: _v.sort == 'name',
                    onTap: () => setState(() => _v = _v.copyWith(sort: 'name')),
                  ),
                  _SortChip(
                    value: '-name',
                    label: 'Name ↓',
                    selected: _v.sort == '-name',
                    onTap:
                        () => setState(() => _v = _v.copyWith(sort: '-name')),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _PrimaryBtn(
                      icon: Icons.check_rounded,
                      label: 'Apply',
                      onTap: () => Navigator.pop(context, _v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SecondaryBtn(
                      icon: Icons.close_rounded,
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String value;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _ink900,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: selected ? _surface : _ink900,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: selected ? _ink900 : _stroke),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Sticky Pager (light)
 * ─────────────────────────────────────────────────────────── */
class _PagerBar extends StatelessWidget {
  const _PagerBar({
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
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: height - 8,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded, color: _ink900),
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
                        selectedColor: _ink900,
                        backgroundColor: _surface,
                        labelStyle: TextStyle(
                          color: selected ? _surface : _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: BorderSide(color: selected ? _ink900 : _stroke),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Next',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded, color: _ink900),
            ),
          ],
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Store Item Card
 * ─────────────────────────────────────────────────────────── */
class _StoreItemCard extends ConsumerStatefulWidget {
  const _StoreItemCard({required this.item});
  final StoreItem item;

  @override
  ConsumerState<_StoreItemCard> createState() => _StoreItemCardState();
}

class _StoreItemCardState extends ConsumerState<_StoreItemCard>
    with SingleTickerProviderStateMixin {
  bool _deleting = false;
  bool _expanded = false;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animController.forward();
    } else {
      _animController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };

    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canEditItem = canAdmin || perms.contains('storeitemedit');
    final canDeleteItem = canAdmin || perms.contains('storeitemdelete');

    Widget headerImage() => Stack(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _surface,
              border: Border.all(color: _stroke, width: 1),
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
                    ? Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: _accentPeach.withValues(alpha: 0.2),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.photo_outlined,
                          color: _ink600,
                          size: 40,
                        ),
                      ),
                    )
                    : null,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QRCodePrintPage(storeItemList: [it]),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: _ink900,
                  size: 22,
                ),
              ),
            ),
          ),
        ),
      ],
    );

    Widget titleRow() => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                it.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _BadgeChip(icon: Icons.category_outlined, label: it.category),
      ],
    );

    Widget stockRow() => Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _StockPill(
          label: 'Total',
          value: it.totalStockQuantity,
          icon: Icons.all_inbox_outlined,
          color: _accentMint,
        ),
        _StockPill(
          label: 'Available',
          value: it.stockAvailableQuantity,
          icon: Icons.inventory_outlined,
          color: _accentPeach,
        ),
        _StockPill(
          label: 'Issued',
          value: it.stockIssueQuantity,
          icon: Icons.outbox_outlined,
          color: _ink600,
        ),
        _StockPill(
          label: 'Scrap',
          value: it.stockscrapQuantity,
          icon: Icons.delete_outline,
          color: Colors.red.withValues(alpha: 0.3),
        ),
      ],
    );

    final deleteBtn = _PrimaryBtn(
      icon:
          _deleting
              ? Icons.hourglass_top_rounded
              : Icons.delete_outline_rounded,
      label: _deleting ? 'Deleting…' : 'Delete',
      busy: _deleting,
      danger: true,
      onTap:
          _deleting
              ? null
              : () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder:
                      (_) => AlertDialog(
                        title: const Text('Delete item?'),
                        content: Text('Delete "${it.name}" permanently?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => Navigator.pop(context, true),
                            style: FilledButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                            ),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                );
                if (confirm != true) return;

                setState(() => _deleting = true);
                final ok = await ref
                    .read(storeItemControllerProvider)
                    .deleteStoreItem(id: it.id);
                if (!mounted) return;
                setState(() => _deleting = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok ? 'Deleted ${it.name}' : 'Delete failed'),
                  ),
                );
              },
    );

    final editBtn = _SecondaryBtn(
      icon: Icons.edit_rounded,
      label: 'Edit',
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StoreItemFormPage(initial: it)),
        );
      },
    );

    Widget bottomActions() => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: [
            if (canEditItem) SizedBox(width: 130, child: editBtn),
            if (canDeleteItem) SizedBox(width: 130, child: deleteBtn),
          ],
        ),
      ],
    );

    Widget expandToggle() => InkWell(
      onTap: _toggleExpand,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _expanded ? 'Hide' : 'Show actions',
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 6),
            RotationTransition(
              turns: Tween(begin: 0.0, end: 0.5).animate(_animController),
              child: const Icon(
                Icons.expand_more_rounded,
                color: _ink700,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );

    return _Card(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerImage(),
          const SizedBox(height: 12),
          titleRow(),
          const SizedBox(height: 10),
          stockRow(),
          const SizedBox(height: 10),
          Container(height: 1, color: _stroke.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          expandToggle(),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: bottomActions(),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Small UI bits (Cards, Pills, Buttons, Chips)
 * ─────────────────────────────────────────────────────────── */
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _stroke, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  _Card copyWith({Widget? child, double? radius, EdgeInsets? padding}) => _Card(
    radius: radius ?? this.radius,
    padding: padding ?? this.padding,
    child: child ?? this.child,
  );
}

class _PillBtn extends StatelessWidget {
  const _PillBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtle = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: subtle ? Colors.transparent : _accentMint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: subtle ? _stroke : Colors.transparent,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _ink900, weight: 600),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? Colors.red.shade700 : _ink900;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_surface),
                  ),
                )
              else
                Icon(icon, size: 18, color: _surface),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _surface,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _accentPeach.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _ink900, size: 16, weight: 600),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StockPill extends StatelessWidget {
  const _StockPill({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });
  final String label;
  final dynamic value;
  final IconData icon;
  final Color? color;

  String _fmt(dynamic v) {
    if (v == null) return '0';
    if (v is num) return v.toString();
    final n = num.tryParse(v.toString());
    return (n ?? 0).toString();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = color ?? _accentMint;
    final text = _fmt(value);
    return Container(
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withValues(alpha: 0.4), width: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: _ink900),
          const SizedBox(height: 4),
          Text(
            text,
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
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink700,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
