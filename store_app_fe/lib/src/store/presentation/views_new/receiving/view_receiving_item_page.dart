// lib/src/store/presentation/views/receiving/receiving_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';



import '../../../../auth/controllers/users_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../components/socket_manager.dart';
import '../../../controllers/store_item_receiving_controller.dart';
import 'create_receiving_item_page.dart';
import 'edit_receiving_item_page.dart';
import 'receive_to_place_page.dart';

/* ───────────────────────────────────────────────────────────
 * Palette (dashboard)
 * ─────────────────────────────────────────────────────────── */
const _ink900 = Color(0xFF282321);
const _ink800 = Color(0xFF3A3330);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _accentPeach = Color(0xFFF3D7C0);

const _bgTop = Color(0xFFFFFFF9);
const _bgBottom = _surfaceAlt;

/* ───────────────────────────────────────────────────────────
 * Tiny theme helpers
 * ─────────────────────────────────────────────────────────── */
TextStyle _tTitle(BuildContext c) => Theme.of(
  c,
).textTheme.titleMedium!.copyWith(color: _ink900, fontWeight: FontWeight.w800);
TextStyle _muted([double s = 12]) =>
    TextStyle(color: _ink600, fontSize: s, fontWeight: FontWeight.w600);

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
  }) : margin = null;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _stroke),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Query + Paged models (unchanged)
 * ─────────────────────────────────────────────────────────── */
class ReceivingQuery {
  final int page;
  final int limit;
  final String search; // recNo/source search
  final String? status; // DRAFT/APPROVED/CLOSED/CANCELLED
  final String item; // item name/code text
  final String sort; // e.g. -createdAt, createdAt

  const ReceivingQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.status,
    required this.item,
    required this.sort,
  });

  ReceivingQuery copyWith({
    int? page,
    int? limit,
    String? search,
    String? status,
    String? item,
    String? sort,
  }) {
    return ReceivingQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status,
      item: item ?? this.item,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "status": status,
    "item": item,
    "sort": sort,
  };
}

class PagedReceivings {
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  const PagedReceivings({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* ───────────────────────────────────────────────────────────
 * Socket paged provider (unchanged)
 * ─────────────────────────────────────────────────────────── */
final itemReceivePagedStreamProvider = StreamProvider.autoDispose
    .family<PagedReceivings, ReceivingQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedReceivings>(sync: true);

      void handler(dynamic data) {
        try {
          final rows =
              (data['rows'] as List? ?? const [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e),
                  )
                  .toList();

          controller.add(
            PagedReceivings(
              rows: rows,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? query.page) as int,
              limit: (data['limit'] ?? query.limit) as int,
            ),
          );
        } catch (_) {}
      }

      socket.on("store:receiving:paged", handler);
      socket.emit("store:receiving:paged", query.toJson());

      ref.onDispose(() {
        socket.off("store:receiving:paged", handler);
        controller.close();
      });

      yield PagedReceivings(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      await for (final v in controller.stream) {
        yield v;
      }
    });

/* ───────────────────────────────────────────────────────────
 * Page
 * ─────────────────────────────────────────────────────────── */
class ReceivingListPage extends ConsumerStatefulWidget {
  const ReceivingListPage({super.key});
  @override
  ConsumerState<ReceivingListPage> createState() => _ReceivingListPageState();
}

class _ReceivingListPageState extends ConsumerState<ReceivingListPage> {
  static const double _stickyPagerHeight = 64;

  ReceivingQuery _q = const ReceivingQuery(
    page: 1,
    limit: 12,
    search: '',
    status: null,
    item: '',
    sort: '-createdAt',
  );

  final _searchCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  Timer? _debounce1;
  Timer? _debounce2;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _q.search;
    _itemCtrl.text = _q.item;

    _searchCtrl.addListener(() {
      _debounce1?.cancel();
      _debounce1 = Timer(const Duration(milliseconds: 350), () {
        setState(
          () => _q = _q.copyWith(page: 1, search: _searchCtrl.text.trim()),
        );
      });
    });

    _itemCtrl.addListener(() {
      _debounce2?.cancel();
      _debounce2 = Timer(const Duration(milliseconds: 350), () {
        setState(() => _q = _q.copyWith(page: 1, item: _itemCtrl.text.trim()));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(itemReceivePagedStreamProvider(_q));
    });
  }

  @override
  void dispose() {
    _debounce1?.cancel();
    _debounce2?.cancel();
    _searchCtrl.dispose();
    _itemCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _searchCtrl.text = '';
    _itemCtrl.text = '';
    setState(() {
      _q = const ReceivingQuery(
        page: 1,
        limit: 12,
        search: '',
        status: null,
        item: '',
        sort: '-createdAt',
      );
    });
  }

  Future<void> _openFilterSheet() async {
    final r = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
    final pagedAsync = ref.watch(itemReceivePagedStreamProvider(_q));
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canReceiveAdd = canAdmin || perms.contains('storreceiveadd');

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.move_to_inbox_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Receivings',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        centerTitle: true,
      ),
      floatingActionButton:
          canReceiveAdd
              ? FloatingActionButton.extended(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ReceivingCreatePage(),
                      ),
                    ),
                icon: const Icon(Icons.add_rounded, color: _ink900),
                label: const Text(
                  'Add Receive',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
                ),
                backgroundColor: _accentMint,
                elevation: 0,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: _LightSearchRow(
                        searchCtrl: _searchCtrl,
                        itemCtrl: _itemCtrl,
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),
                  pagedAsync.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                          ),
                        ),
                    error:
                        (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: _Card(
                              child: Text('Error: $e', style: _muted()),
                            ),
                          ),
                        ),
                    data: (paged) {
                      if (paged.rows.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            child: _Card(
                              padding: const EdgeInsets.all(22),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.inbox_outlined,
                                    color: _ink700,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _q.search.isEmpty &&
                                            (_q.status == null) &&
                                            _q.item.isEmpty
                                        ? 'No receivings found'
                                        : 'No results for current filters',
                                    style: const TextStyle(
                                      color: _ink800,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      return SliverPadding(
                        padding: const EdgeInsets.fromLTRB(
                          16,
                          8,
                          16,
                          16 + _stickyPagerHeight,
                        ),
                        sliver: SliverList.separated(
                          itemCount: paged.rows.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 10),
                          itemBuilder:
                              (_, i) => _ReceivingTile(rec: paged.rows[i]),
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
                        (paged) => _PagerBar(
                          height: _stickyPagerHeight,
                          total: paged.total,
                          pageSize: paged.limit,
                          pageIndex: paged.page,
                          onPrev:
                              paged.page > 1
                                  ? () => setState(
                                    () =>
                                        _q = _q.copyWith(page: paged.page - 1),
                                  )
                                  : null,
                          onNext:
                              (paged.page * paged.limit < paged.total)
                                  ? () => setState(
                                    () =>
                                        _q = _q.copyWith(page: paged.page + 1),
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

/* ───────────────────────────────────────────────────────────
 * Search Row (light)
 * ─────────────────────────────────────────────────────────── */
class _LightSearchRow extends StatelessWidget {
  const _LightSearchRow({
    required this.searchCtrl,
    required this.itemCtrl,
    required this.onFilterTap,
    required this.onReset,
  });

  final TextEditingController searchCtrl;
  final TextEditingController itemCtrl;
  final VoidCallback onFilterTap;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 14,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          _SmallInput(
            controller: searchCtrl,
            hint: 'Search Rec No / Source',
            icon: Icons.search_rounded,
          ),
          const SizedBox(width: 8),
          _SmallInput(
            controller: itemCtrl,
            hint: 'Item name / code',
            icon: Icons.inventory_2_rounded,
          ),
          const SizedBox(width: 8),
          _ChipBtn(
            label: 'Filter',
            icon: Icons.tune_rounded,
            onTap: onFilterTap,
          ),
          const SizedBox(width: 8),
          _ChipBtn(
            label: 'Reset',
            icon: Icons.restart_alt_rounded,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _SmallInput extends StatelessWidget {
  const _SmallInput({
    required this.controller,
    required this.hint,
    required this.icon,
  });
  final TextEditingController controller;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 40,
        child: TextField(
          controller: controller,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _muted(),
            prefixIcon: Icon(icon, color: _ink700, size: 18),
            isDense: true,
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: .5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _ink900, width: 1.2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 8,
            ),
            suffixIcon:
                controller.text.isEmpty
                    ? null
                    : IconButton(
                      tooltip: 'Clear',
                      onPressed: () => controller.clear(),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: _ink600,
                      ),
                    ),
          ),
        ),
      ),
    );
  }
}

class _ChipBtn extends StatelessWidget {
  const _ChipBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _accentMint.withValues(alpha: .35),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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

/* ───────────────────────────────────────────────────────────
 * Filter bottom sheet (light)
 * ─────────────────────────────────────────────────────────── */
class _FilterResult {
  final String? status;
  final int limit;
  final String sort;
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.46,
      minChildSize: 0.34,
      maxChildSize: 0.88,
      builder: (ctx, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            boxShadow: [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 20,
                offset: Offset(0, -6),
              ),
            ],
          ),
          child: ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            children: [
              Center(
                child: Container(
                  width: 42,
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
                'Status',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
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
              const Text(
                'Page size',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
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
                        onSelected:
                            (_) => setState(() => v = v.copyWith(limit: n)),
                        selectedColor: _accentMint,
                        backgroundColor: _surfaceAlt.withValues(alpha: .5),
                        labelStyle: TextStyle(
                          color: _ink900,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: _stroke),
                        ),
                      );
                    }).toList(),
              ),

              const SizedBox(height: 16),
              const Text(
                'Sort',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
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
                    'recNo',
                    'Rec No ↑',
                    v.sort == 'recNo',
                    () => setState(() => v = v.copyWith(sort: 'recNo')),
                  ),
                  _sortChip(
                    '-recNo',
                    'Rec No ↓',
                    v.sort == '-recNo',
                    () => setState(() => v = v.copyWith(sort: '-recNo')),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _LightBtn(
                      label: 'Apply',
                      icon: Icons.check_rounded,
                      onTap: () => Navigator.pop(context, v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _LightBtn(
                      label: 'Cancel',
                      icon: Icons.close_rounded,
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
        children: [
          Icon(icon, size: 16, color: _ink700),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: _accentPeach,
      backgroundColor: _surfaceAlt.withValues(alpha: .5),
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: _stroke),
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
      selectedColor: _accentMint,
      backgroundColor: _surfaceAlt.withValues(alpha: .5),
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: const BorderSide(color: _stroke),
      ),
    );
  }
}

class _LightBtn extends StatelessWidget {
  const _LightBtn({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: _ink900,
          foregroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Receiving Tile (light card)
 * ─────────────────────────────────────────────────────────── */
class _ReceivingTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> rec;
  const _ReceivingTile({required this.rec});

  @override
  ConsumerState<_ReceivingTile> createState() => _ReceivingTileState();
}

class _ReceivingTileState extends ConsumerState<_ReceivingTile> {
  bool _saving = false;
  bool _expanded = false;

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
        return _ink600;
    }
  }

  Future<void> _close() async {
    setState(() => _saving = true);
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
      final body = {"id": widget.rec['_id'], "userId": createdBy};
      await ref
          .read(itemReceiveControllerProvider)
          .closeItemReceive(closeItemReceive: body);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Approved')));
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');

    final canReceiveEdit = canAdmin || perms.contains('storreceiveedit');
    final canReceiveClose = canAdmin || perms.contains('storreceiveclose');
    final canReceiveToStock = canAdmin || perms.contains('storreceivetostock');

    final rec = widget.rec;
    final status = (rec['status'] ?? '').toString();
    final createdAt = (rec['createdAt'] ?? '').toString();
    final recNo = (rec['recNo'] ?? '').toString();
    final source = (rec['source'] ?? '').toString();
    final tint = _statusColor(status);

    return _Card(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accentMint.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _accentMint),
                    ),
                    child: const Icon(
                      Icons.move_to_inbox_rounded,
                      color: _ink900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recNo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetaPill(
                              icon: Icons.store_rounded,
                              text: source.isEmpty ? '—' : source,
                            ),
                            _MetaPill(
                              icon: Icons.schedule_rounded,
                              text: createdAt,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StatusBadge(
                    icon:
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                    tint: tint,
                  ),
                ],
              ),

              if (_expanded) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.brightness_1_rounded, size: 10, color: tint),
                    const SizedBox(width: 8),
                    Text(
                      status.isEmpty ? '—' : status,
                      style: TextStyle(
                        color: tint,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (status == 'APPROVED') ...[
                        if (canReceiveToStock)
                          _GhostBtn(
                            label: 'Add to Stock',
                            icon: Icons.inventory_2_rounded,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ReceiveToPlacePage(receiving: rec),
                                ),
                              );
                            },
                          ),
                        if (canReceiveClose)
                          _GhostBtn(
                            label: _saving ? 'Saving…' : 'Close',
                            icon: _saving ? null : Icons.verified_rounded,
                            busy: _saving,
                            accent: tint,
                            onPressed: _saving ? null : _close,
                          ),
                      ],
                      if (status == 'DRAFT' && canReceiveEdit)
                        _GhostBtn(
                          label: 'Edit',
                          icon: Icons.edit_rounded,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReceivingEditPage(rec: rec),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _ink700),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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

class _GhostBtn extends StatelessWidget {
  const _GhostBtn({
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
    this.accent,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final tint = accent ?? _ink900;
    return Opacity(
      opacity: enabled ? 1 : .7,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon:
            busy
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : (icon != null
                    ? Icon(icon, size: 18, color: tint)
                    : const SizedBox.shrink()),
        label: Text(
          label,
          style: TextStyle(
            color: tint,
            fontWeight: FontWeight.w900,
            letterSpacing: .2,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: tint.withValues(alpha: .45)),
          backgroundColor: _surfaceAlt.withValues(alpha: .4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.icon, required this.tint});
  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: .6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: .45)),
      ),
      child: Icon(icon, size: 18, color: tint),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Pager (light)
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
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: onPrev,
              icon: Icon(
                Icons.chevron_left_rounded,
                color: onPrev != null ? _ink900 : _ink600.withValues(alpha: 0.4),
              ),
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
                        selectedColor: _accentPeach,
                        backgroundColor: _surfaceAlt.withValues(alpha: .5),
                        labelStyle: TextStyle(
                          color: _ink900,
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                          side: const BorderSide(color: _stroke),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Next page',
              onPressed: onNext,
              icon: Icon(
                Icons.chevron_right_rounded,
                color: onNext != null ? _ink900 : _ink600.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
