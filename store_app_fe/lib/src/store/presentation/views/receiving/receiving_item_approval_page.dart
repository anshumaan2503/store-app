// lib/src/store/presentation/views/receiving/receiving_approve_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_item_receiving_controller.dart'
    show
        ReceivingPagedQuery,
        PagedReceivings,
        receivingPagedStreamProvider,
        itemReceiveControllerProvider;

import 'edit_receiving_item_page.dart';
import 'receving_detail_page.dart';
import 'receive_to_place_page.dart';

/* ───────────────────────── Palette ───────────────────────── */

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

/* ───────────────────────── Page ───────────────────────── */

class ReceivingApprovePage extends ConsumerStatefulWidget {
  const ReceivingApprovePage({super.key});

  @override
  ConsumerState<ReceivingApprovePage> createState() =>
      _ReceivingApprovePageState();
}

class _ReceivingApprovePageState extends ConsumerState<ReceivingApprovePage> {
  static const double _stickyPagerHeight = 64;

  ReceivingPagedQuery _q = const ReceivingPagedQuery(
    page: 1,
    limit: 12,
    search: '',
    status: ['DRAFT'],
    item: '',
    sort: '-createdAt',
  );

  final _searchCtrl = TextEditingController();
  final _itemCtrl = TextEditingController();
  Timer? _deb1, _deb2;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = _q.search;
    _itemCtrl.text = _q.item;

    _searchCtrl.addListener(() {
      _deb1?.cancel();
      _deb1 = Timer(const Duration(milliseconds: 300), () {
        setState(
          () => _q = _q.copyWith(page: 1, search: _searchCtrl.text.trim()),
        );
      });
    });
    _itemCtrl.addListener(() {
      _deb2?.cancel();
      _deb2 = Timer(const Duration(milliseconds: 300), () {
        setState(() => _q = _q.copyWith(page: 1, item: _itemCtrl.text.trim()));
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.refresh(receivingPagedStreamProvider(_q));
    });
  }

  @override
  void dispose() {
    _deb1?.cancel();
    _deb2?.cancel();
    _searchCtrl.dispose();
    _itemCtrl.dispose();
    super.dispose();
  }

  void _resetAll() {
    _searchCtrl.text = '';
    _itemCtrl.text = '';
    setState(() {
      _q = const ReceivingPagedQuery(
        page: 1,
        limit: 12,
        search: '',
        status: ['DRAFT'],
        item: '',
        sort: '-createdAt',
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
    final pageAsync = ref.watch(receivingPagedStreamProvider(_q));

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        titleTextStyle: const TextStyle(
          color: _ink900,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
        title: const Text('Approve Receivings'),
        foregroundColor: _ink900,
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _SearchToolbar(
                        searchCtrl: _searchCtrl,
                        itemCtrl: _itemCtrl,
                        onFilterTap: _openFilterSheet,
                        onReset: _resetAll,
                      ),
                    ),
                  ),
                  pageAsync.when(
                    loading:
                        () => const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                    error:
                        (e, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16 + _stickyPagerHeight,
                            ),
                            child: _Card(
                              child: Text(
                                'Error: $e',
                                style: const TextStyle(color: _ink700),
                              ),
                            ),
                          ),
                        ),
                    data: (paged) {
                      if (paged.rows.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              16 + _stickyPagerHeight,
                            ),
                            child: _EmptyState(
                              title:
                                  _q.search.isEmpty && _q.item.isEmpty
                                      ? 'No pending receivings'
                                      : 'No results for current filters',
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
                          16 + _stickyPagerHeight,
                        ),
                        sliver: SliverList.separated(
                          itemCount: paged.rows.length,
                          itemBuilder:
                              (_, i) =>
                                  _ReceivingApproveCard(rec: paged.rows[i]),
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
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
                  child: pageAsync.maybeWhen(
                    data:
                        (paged) => _StickyPager(
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

/* ───────────────────────── Toolbar ───────────────────────── */

class _SearchToolbar extends StatelessWidget {
  const _SearchToolbar({
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
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 4),
          _PeachButton.icon(
            iconData: Icons.tune_rounded,
            label: 'Filter',
            onPressed: onFilterTap,
          ),
          const SizedBox(width: 8),
          _MintOutlineButton.icon(
            iconData: Icons.restart_alt_rounded,
            label: 'Reset',
            onPressed: onReset,
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
          style: const TextStyle(color: _ink900),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, size: 20, color: _ink700),
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
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────── Filter Sheet ───────────────────────── */

class _FilterResult {
  final List<String> status;
  final int limit;
  final String sort;

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

  bool _eqList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = {...a};
    final sb = {...b};
    return sa.length == sb.length && sa.containsAll(sb);
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Filters',
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _Section(
            label: 'Status',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _statusChip(['DRAFT'], 'Draft', Icons.description_rounded),
                _statusChip(['APPROVED'], 'Approved', Icons.verified_rounded),
                _statusChip(['CLOSED'], 'Closed', Icons.lock_clock_rounded),
                _statusChip(['CANCELLED'], 'Cancelled', Icons.cancel_rounded),
                _statusChip(
                  ['DRAFT', 'APPROVED'],
                  'Draft + Approved',
                  Icons.all_inbox_rounded,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          _Section(
            label: 'Page size',
            child: Wrap(
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
                _sortChip('Rec No ↑', 'recNo'),
                _sortChip('Rec No ↓', '-recNo'),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _PeachButton.icon(
                  iconData: Icons.check_rounded,
                  label: 'Apply',
                  onPressed: () => Navigator.pop(context, v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MintOutlineButton.icon(
                  iconData: Icons.close_rounded,
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

  Widget _statusChip(List<String> key, String label, IconData icon) {
    final selected = _eqList(v.status, key);
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
      onSelected: (_) => setState(() => v = v.copyWith(status: key)),
      selectedColor: _accentPeach,
      backgroundColor: _surface,
      labelStyle: TextStyle(
        color: _ink900,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: StadiumBorder(side: _cardBorder),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = v.sort == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => v = v.copyWith(sort: value)),
      selectedColor: _accentMint,
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

/* ───────────────────────── Sticky Pager ───────────────────────── */

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
            tooltip: 'Previous page',
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
            tooltip: 'Next page',
            color: _ink900,
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Receiving Card ───────────────────────── */

class _ReceivingApproveCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> rec;
  const _ReceivingApproveCard({required this.rec});

  @override
  ConsumerState<_ReceivingApproveCard> createState() =>
      _ReceivingApproveCardState();
}

class _ReceivingApproveCardState extends ConsumerState<_ReceivingApproveCard> {
  final Map<String, TextEditingController> _appr = {};
  final Map<String, int> _requested = {};
  bool _saving = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final lines = (widget.rec['lines'] as List?) ?? const [];
    for (final raw in lines) {
      final l = raw as Map<String, dynamic>;
      final itemId = l['itemId'].toString();
      final req =
          (l['requestedQty'] is int)
              ? (l['requestedQty'] as int)
              : int.tryParse('${l['requestedQty']}') ?? 0;
      _requested[itemId] = req;
      _appr[itemId] = TextEditingController(text: req.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _appr.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _approveOrReject({required bool approve}) async {
    for (final e in _appr.entries) {
      final itemId = e.key;
      final txt = e.value.text.trim();
      final approved = int.tryParse(txt) ?? -1;
      final req = _requested[itemId] ?? 0;
      if (approved < 0) return _snack('Quantity cannot be negative');
      if (approved > req) {
        return _snack('Approved cannot exceed requested ($req)');
      }
    }

    setState(() => _saving = true);
    try {
      final lines = <Map<String, dynamic>>[];
      _appr.forEach((itemId, ctrl) {
        final approved = int.tryParse(ctrl.text.trim()) ?? 0;
        lines.add({"itemId": itemId, "approvedQty": approved});
      });
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final body = {
        "id": widget.rec['_id'],
        "lines": lines,
        "userId": createdBy,
      };

      if (approve) {
        await ref
            .read(itemReceiveControllerProvider)
            .approveItemReceive(approveItemReceive: body);
      } else {
        await ref
            .read(itemReceiveControllerProvider)
            .rejectItemReceive(approveItemReceive: body);
      }

      if (!mounted) return;
      _snack(approve ? 'Approved' : 'Rejected');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        return _ink700;
    }
  }

  void _toggleExpand() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final rec = widget.rec;
    final status = (rec['status'] ?? '').toString();
    final createdAt = (rec['createdAt'] ?? '').toString();
    final recNo = (rec['recNo'] ?? '').toString();
    final source = (rec['source'] ?? '').toString();
    final lines = (rec['lines'] as List?) ?? const [];

    final statusColor = _statusColor(status);

    return _Card(
      padding: const EdgeInsets.all(14),
      borderColor: statusColor.withValues(alpha: .35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReceivingDetailPage(id: rec['_id']),
                ),
              );
            },
            child: Row(
              children: [
                _AvatarBadge(icon: Icons.move_to_inbox_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: _TitleMeta(
                    title: recNo,
                    subtitle1: source,
                    subtitle2: createdAt,
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Hide actions' : 'Show actions',
                  color: _ink700,
                  onPressed: _toggleExpand,
                  icon: Icon(
                    _expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          for (final raw in lines)
            _ReceivingLineRow(
              line: (raw as Map<String, dynamic>),
              controller:
                  _appr[raw['itemId'].toString()] ??
                  TextEditingController(text: '0'),
            ),

          const SizedBox(height: 8),

          AnimatedCrossFade(
            duration: const Duration(milliseconds: 160),
            crossFadeState:
                _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusChip(text: status, color: statusColor),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (status == 'DRAFT')
                      _MintOutlineButton.icon(
                        iconData: Icons.edit_rounded,
                        label: 'Edit',
                        onPressed:
                            _saving
                                ? null
                                : () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ReceivingEditPage(rec: rec),
                                    ),
                                  );
                                },
                      ),
                    if (status == 'APPROVED')
                      _PeachButton.icon(
                        iconData: Icons.inventory_2_rounded,
                        label: 'Add To Stock',
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
                    _PeachButton.icon(
                      iconData:
                          _saving
                              ? Icons.hourglass_top_rounded
                              : Icons.verified_rounded,
                      label: _saving ? 'Saving…' : 'Approve',
                      onPressed:
                          _saving
                              ? null
                              : () => _approveOrReject(approve: true),
                    ),
                    _MintOutlineButton.icon(
                      iconData: Icons.cancel_rounded,
                      label: 'Reject',
                      onPressed:
                          _saving
                              ? null
                              : () => _approveOrReject(approve: false),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Atoms ───────────────────────── */

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
        borderRadius: BorderRadius.circular(12),
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

class _AvatarBadge extends StatelessWidget {
  const _AvatarBadge({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _accentMint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Icon(icon, color: _ink900),
    );
  }
}

class _TitleMeta extends StatelessWidget {
  const _TitleMeta({
    required this.title,
    required this.subtitle1,
    required this.subtitle2,
  });
  final String title;
  final String subtitle1;
  final String subtitle2;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(subtitle1, style: const TextStyle(color: _ink700)),
        Text(subtitle2, style: const TextStyle(color: _ink600, fontSize: 12)),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        text.isEmpty ? '—' : text,
        style: const TextStyle(fontWeight: FontWeight.w700, color: _surface),
      ),
      backgroundColor: color.withValues(alpha: .12),
      side: BorderSide(color: color.withValues(alpha: .35)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
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

/* ───────────────────────── Line Row ───────────────────────── */

class _ReceivingLineRow extends StatelessWidget {
  const _ReceivingLineRow({required this.line, required this.controller});
  final Map<String, dynamic> line;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final itemId = line['itemId'].toString();
    final itemName = (line['itemName'] ?? '').toString();
    final req =
        (line['requestedQty'] is int)
            ? (line['requestedQty'] as int)
            : int.tryParse('${line['requestedQty']}') ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Item: ${itemName.isNotEmpty ? itemName : itemId} • Req: $req',
              style: const TextStyle(color: _ink900),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: TextFormField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                hintStyle: const TextStyle(color: _ink600),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
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
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              keyboardType: TextInputType.number,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ───────────────────────── Buttons ───────────────────────── */

class _PeachButton extends StatelessWidget {
  const _PeachButton({
    required this.onPressed,
    required this.child,
  }) : icon = null;

  // Named constructor (non-const; accepts runtime label)
  _PeachButton.icon({
    required IconData iconData,
    required String label,
    required this.onPressed,
  }) : icon = iconData,
       child = Text(label, style: const TextStyle(fontWeight: FontWeight.w800));

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: _ink900, size: 18),
          const SizedBox(width: 8),
        ],
        DefaultTextStyle.merge(
          style: const TextStyle(color: _ink900),
          child: child,
        ),
      ],
    );

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
          child: content,
        ),
      ),
    );
  }
}

class _MintOutlineButton extends StatelessWidget {
  const _MintOutlineButton({
    required this.onPressed,
    required this.child,
  }) : icon = null;

  // Named constructor (non-const; accepts runtime label)
  _MintOutlineButton.icon({
    required IconData iconData,
    required String label,
    required this.onPressed,
  }) : icon = iconData,
       child = Text(label, style: const TextStyle(fontWeight: FontWeight.w800));

  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, color: _ink900, size: 18),
          const SizedBox(width: 8),
        ],
        DefaultTextStyle.merge(
          style: const TextStyle(color: _ink900),
          child: child,
        ),
      ],
    );

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
          child: content,
        ),
      ),
    );
  }
}
