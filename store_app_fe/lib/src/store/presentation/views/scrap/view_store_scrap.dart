// lib/src/store/presentation/views/scrap/scrap_view_paged.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:store_app/src/components/socket_manager.dart';

import 'create_store_scrap.dart';

/* ===================== Palette (shared look) ===================== */

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

/* ===================== Query Models ===================== */

class ScrapQuery {
  final int page;
  final int limit;
  final String sort; // "-createdAt", "createdAt", "qty", "-qty"
  final String search; // matches note/_item.name/_place.name
  final String item; // item name/id text
  final String place; // place name/id text
  final String? dateFrom; // "YYYY-MM-DD" or ISO
  final String? dateTo; // "YYYY-MM-DD" or ISO

  const ScrapQuery({
    required this.page,
    required this.limit,
    required this.sort,
    required this.search,
    required this.item,
    required this.place,
    this.dateFrom,
    this.dateTo,
  });

  ScrapQuery copyWith({
    int? page,
    int? limit,
    String? sort,
    String? search,
    String? item,
    String? place,
    String? dateFrom,
    String? dateTo,
  }) {
    return ScrapQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      sort: sort ?? this.sort,
      search: search ?? this.search,
      item: item ?? this.item,
      place: place ?? this.place,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "sort": sort,
    "search": search.trim(),
    "item": item.trim(),
    "place": place.trim(),
    "dateFrom": dateFrom,
    "dateTo": dateTo,
  };
}

class PagedScrap {
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  const PagedScrap({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* ===================== Socket Stream Provider ===================== */

final scrapPagedProvider = StreamProvider.autoDispose
    .family<PagedScrap, ScrapQuery>((ref, q) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedScrap>(sync: true);

      void handler(dynamic data) {
        try {
          final list =
              (data['rows'] as List? ?? const [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e as Map),
                  )
                  .toList();
          controller.add(
            PagedScrap(
              rows: list,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? q.page) as int,
              limit: (data['limit'] ?? q.limit) as int,
            ),
          );
        } catch (e, st) {
          debugPrint('scrapPagedProvider map error: $e\n$st');
          controller.add(
            PagedScrap(rows: const [], total: 0, page: q.page, limit: q.limit),
          );
        }
      }

      socket.on("store:listScrapPaged", handler);
      socket.emit("store:listScrapPaged", q.toJson());

      ref.onDispose(() {
        socket.off("store:listScrapPaged", handler);
        controller.close();
      });

      // skeleton first
      yield PagedScrap(rows: const [], total: 0, page: q.page, limit: q.limit);

      await for (final v in controller.stream) {
        yield v;
      }
    });

/* ===================== Page ===================== */

class ScrapViewPage extends ConsumerStatefulWidget {
  const ScrapViewPage({super.key});
  @override
  ConsumerState<ScrapViewPage> createState() => _ScrapViewPageState();
}

class _ScrapViewPageState extends ConsumerState<ScrapViewPage> {
  static const double _pagerHeight = 64;

  ScrapQuery _q = const ScrapQuery(
    page: 1,
    limit: 12,
    sort: '-createdAt',
    search: '',
    item: '',
    place: '',
  );

  final _searchCtrl = TextEditingController();
  Timer? _debounceSearch;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _q.search;
    _searchCtrl.addListener(() {
      _debounceSearch?.cancel();
      _debounceSearch = Timer(const Duration(milliseconds: 300), () {
        setState(() => _q = _q.copyWith(page: 1, search: _searchCtrl.text));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(scrapPagedProvider(_q));
    });
  }

  @override
  void dispose() {
    _debounceSearch?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openFilterSheet() async {
    final res = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _FilterSheet(
            initial: _FilterResult(
              item: _q.item,
              place: _q.place,
              dateFrom: _q.dateFrom,
              dateTo: _q.dateTo,
              limit: _q.limit,
              sort: _q.sort,
            ),
          ),
    );
    if (res != null) {
      setState(() {
        _q = _q.copyWith(
          page: 1,
          item: res.item,
          place: res.place,
          dateFrom: res.dateFrom,
          dateTo: res.dateTo,
          limit: res.limit,
          sort: res.sort,
        );
      });
    }
  }

  void _resetAll() {
    _searchCtrl.text = '';
    setState(() {
      _q = const ScrapQuery(
        page: 1,
        limit: 12,
        sort: '-createdAt',
        search: '',
        item: '',
        place: '',
        dateFrom: null,
        dateTo: null,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final paged = ref.watch(scrapPagedProvider(_q));

    return Scaffold(
      backgroundColor: _bgBottom,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.delete_sweep_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Scrap History',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ScrapFromPlacePage()),
          );
        },
        backgroundColor: _ink900,
        foregroundColor: _surface,
        icon: const Icon(Icons.delete_outline_rounded),
        label: const Text('Add scrap'),
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
                  // compact search bar (card style)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _SearchCard(
                        controller: _searchCtrl,
                        hint: 'Search note / item / place',
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),

                  // results
                  paged.when(
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
                        (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: _Card(
                              radius: 14,
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error: $e',
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    data: (pg) {
                      if (pg.rows.isEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            12,
                            8,
                            12,
                            12 + _pagerHeight,
                          ),
                          sliver: const SliverToBoxAdapter(
                            child: _Card(
                              radius: 16,
                              padding: EdgeInsets.all(24),
                              child: _EmptyState(),
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
                        sliver: SliverList.separated(
                          itemCount: pg.rows.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ScrapRow(doc: pg.rows[i]),
                        ),
                      );
                    },
                  ),
                ],
              ),

              // sticky pager
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: paged.maybeWhen(
                    data:
                        (pg) => _PagerBar(
                          height: _pagerHeight,
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

/* ===================== Search Card ===================== */

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
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  const Icon(Icons.search_rounded, color: _ink600, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(color: _ink900),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: hint,
                        hintStyle: const TextStyle(color: _ink600),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  if (controller.text.isNotEmpty)
                    IconButton(
                      splashRadius: 18,
                      icon: const Icon(
                        Icons.close_rounded,
                        color: _ink600,
                        size: 18,
                      ),
                      onPressed: () => controller.clear(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _PillBtn(
            icon: Icons.tune_rounded,
            label: 'Filter',
            onTap: onFilterTap,
          ),
          const SizedBox(width: 8),
          _PillBtn(
            icon: Icons.restart_alt_rounded,
            label: 'Reset',
            onTap: onReset,
            subtle: true,
          ),
        ],
      ),
    );
  }
}

/* ===================== Filter Sheet (card style) ===================== */

class _FilterResult {
  final String item;
  final String place;
  final String? dateFrom;
  final String? dateTo;
  final int limit;
  final String sort;

  const _FilterResult({
    required this.item,
    required this.place,
    required this.dateFrom,
    required this.dateTo,
    required this.limit,
    required this.sort,
  });

  _FilterResult copyWith({
    String? item,
    String? place,
    String? dateFrom,
    String? dateTo,
    int? limit,
    String? sort,
  }) {
    return _FilterResult(
      item: item ?? this.item,
      place: place ?? this.place,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      limit: limit ?? this.limit,
      sort: sort ?? this.sort,
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final _FilterResult initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late _FilterResult _v;
  final _itemCtrl = TextEditingController();
  final _placeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _v = widget.initial;
    _itemCtrl.text = _v.item;
    _placeCtrl.text = _v.place;
  }

  @override
  void dispose() {
    _itemCtrl.dispose();
    _placeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: Theme.of(
              ctx,
            ).colorScheme.copyWith(primary: _ink900, onPrimary: _surface), dialogTheme: DialogThemeData(backgroundColor: _surface),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final v =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
      setState(() {
        if (isFrom) {
          _v = _v.copyWith(dateFrom: v);
        } else {
          _v = _v.copyWith(dateTo: v);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.52,
      minChildSize: 0.40,
      maxChildSize: 0.90,
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

              // Item / Place
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _Field(
                    controller: _itemCtrl,
                    label: 'Item',
                    hint: 'Item name / id',
                    icon: Icons.shopping_cart_outlined,
                    onChanged: (v) => setState(() => _v = _v.copyWith(item: v)),
                  ),
                  _Field(
                    controller: _placeCtrl,
                    label: 'Place',
                    hint: 'Place name / id',
                    icon: Icons.place_rounded,
                    onChanged:
                        (v) => setState(() => _v = _v.copyWith(place: v)),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Date range
              const Text(
                'Date range',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _PillBtn(
                    icon: Icons.event_outlined,
                    label:
                        _v.dateFrom == null ? 'From' : 'From: ${_v.dateFrom}',
                    onTap: () => _pickDate(isFrom: true),
                  ),
                  _PillBtn(
                    icon: Icons.event_outlined,
                    label: _v.dateTo == null ? 'To' : 'To: ${_v.dateTo}',
                    onTap: () => _pickDate(isFrom: false),
                  ),
                  if (_v.dateFrom != null || _v.dateTo != null)
                    _PillBtn(
                      icon: Icons.clear_rounded,
                      label: 'Clear dates',
                      onTap:
                          () => setState(
                            () =>
                                _v = _v.copyWith(dateFrom: null, dateTo: null),
                          ),
                      subtle: true,
                    ),
                ],
              ),

              const SizedBox(height: 14),

              // Page size
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

              // Sort
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
                    value: 'qty',
                    label: 'Qty ↑',
                    selected: _v.sort == 'qty',
                    onTap: () => setState(() => _v = _v.copyWith(sort: 'qty')),
                  ),
                  _SortChip(
                    value: '-qty',
                    label: 'Qty ↓',
                    selected: _v.sort == '-qty',
                    onTap: () => setState(() => _v = _v.copyWith(sort: '-qty')),
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

/* ===================== Pager (bottom) ===================== */

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

/* ===================== Row / Cards ===================== */

class _ScrapRow extends StatelessWidget {
  const _ScrapRow({required this.doc});
  final Map<String, dynamic> doc;

  String _fmtDt(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}  ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final created = (doc['createdAt'] ?? '').toString();
    final item =
        ((doc['itemName'] ?? '') as String).isNotEmpty
            ? (doc['itemName'] ?? '').toString()
            : (doc['itemId'] ?? '').toString();
    final place =
        ((doc['placeName'] ?? '') as String).isNotEmpty
            ? (doc['placeName'] ?? '').toString()
            : (doc['placeId'] ?? '').toString();
    final qty = (doc['qty'] ?? 0).toString();
    final unit =
        ((doc['itemUnit'] ?? '') as String).isNotEmpty ? doc['itemUnit'] : '-';
    final refNo =
        ((doc['refNo'] ?? '') as String).isNotEmpty ? doc['refNo'] : '—';
    final op =
        ((doc['operatedByName'] ?? '') as String).isNotEmpty
            ? doc['operatedByName']
            : '—';
    final note =
        ((doc['note'] ?? '') as String).isNotEmpty ? doc['note'] : null;

    return _ScrapTicketCard(
      timeText: _fmtDt(created),
      refText: refNo,
      itemText: item,
      unitText: unit,
      placeText: place,
      operatorText: op,
      qtyText: qty,
      noteText: note,
    );
  }
}

class _KVP extends StatelessWidget {
  const _KVP({
    required this.icon,
    required this.label,
    required this.value,
  }) : bold = false;
  final IconData icon;
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _ink700),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
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

/* ===================== Inputs & Buttons ===================== */

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.radius = 16,
    this.padding = const EdgeInsets.all(16),
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
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _ink600),
              prefixIcon: Icon(icon, color: _ink600),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 12,
              ),
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
                borderSide: const BorderSide(color: _ink900, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
      color: subtle ? _surface : _accentMint,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: subtle ? _stroke : _accentMint),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _ink900),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
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
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _surface),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _surface,
                  fontWeight: FontWeight.w800,
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _stroke),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: _ink900),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
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

/* ===================== Empty State ===================== */

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _accentPeach.withValues(alpha: .45),
          ),
          child: const Icon(Icons.inbox_outlined, size: 40, color: _ink900),
        ),
        const SizedBox(height: 12),
        const Text(
          'No scrap records',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Tap “Add scrap” to create your first record.',
          style: TextStyle(color: _ink700.withValues(alpha: .9)),
        ),
      ],
    );
  }
}

/// A branded, “ticket-style” card with a subtle top ribbon, bold quantity,
/// and neatly-grouped metadata. Responsive for narrow/wide widths.
class _ScrapTicketCard extends StatelessWidget {
  const _ScrapTicketCard({
    required this.timeText,
    required this.refText,
    required this.itemText,
    required this.unitText,
    required this.placeText,
    required this.operatorText,
    required this.qtyText,
    required this.noteText,
  });

  final String timeText;
  final String refText;
  final String itemText;
  final String unitText;
  final String placeText;
  final String operatorText;
  final String qtyText;
  final String? noteText;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 680;

          final header = Row(
            children: [
              // left: time
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 16, color: _ink700),
                  const SizedBox(width: 6),
                  Text(
                    timeText,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // right: reference tag
              _Tag(icon: Icons.confirmation_number_rounded, label: refText),
            ],
          );

          final titleLine = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  itemText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Tag(
                icon: Icons.straighten_rounded,
                label: unitText,
                subtle: true,
              ),
            ],
          );

          final metaLeft = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaRow(
                icon: Icons.place_rounded,
                label: 'Place',
                value: placeText,
              ),
              _MetaRow(
                icon: Icons.person_rounded,
                label: 'Operator',
                value: operatorText,
              ),
            ],
          );

          final qtyRight = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _QtyBadge(qty: qtyText),
              const SizedBox(height: 8),
              const Text(
                'Qty',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
            ],
          );

          final metaBlock =
              wide
                  ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: metaLeft),
                      const SizedBox(width: 12),
                      qtyRight,
                    ],
                  )
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      metaLeft,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerLeft, child: qtyRight),
                    ],
                  );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // subtle colored ribbon
              Container(
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: const LinearGradient(
                    colors: [_accentMint, _accentPeach],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),

              header,
              const SizedBox(height: 10),
              titleLine,
              const SizedBox(height: 10),

              Divider(color: _stroke.withValues(alpha: .9), height: 20),

              metaBlock,

              if (noteText != null) ...[
                Divider(color: _stroke.withValues(alpha: .9), height: 24),
                _NoteBlock(text: noteText!),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _ink700),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
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

class _QtyBadge extends StatelessWidget {
  const _QtyBadge({required this.qty});
  final String qty;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _accentMint.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accentMint),
      ),
      child: Text(
        qty,
        style: const TextStyle(
          color: _ink900,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label, this.subtle = false});
  final IconData icon;
  final String label;
  final bool subtle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: subtle ? _surface : _accentPeach.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: subtle ? _stroke : _accentPeach),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink900),
          const SizedBox(width: 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _NoteBlock extends StatelessWidget {
  const _NoteBlock({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.sticky_note_2_rounded, size: 16, color: _ink700),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _stroke),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
