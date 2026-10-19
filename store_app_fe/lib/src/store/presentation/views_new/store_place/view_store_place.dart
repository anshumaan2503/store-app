// lib/src/store/presentation/views/store_place/view_store_place.dart
// ───────────────────────────────────────────────────────────
// Store Places — Visual refresh (no logic changes)
// Pager moved into scroll (fixes FAB overlap); tighter chips,
// safer text constraints, responsive card padding.
// ───────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/controllers/users_controller.dart';
import '../../../domains/models/store_place_model.dart';
import '../../../controllers/store_place_controller.dart'
    show
        StorePlaceQuery,
        storePlaceControllerProvider,
        storePlacePagedStreamProvider;
import 'create_store_place.dart';

/* ───────────────────────────────────────────────────────────
 * Palette
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
 * Breakpoints & helpers
 * ─────────────────────────────────────────────────────────── */
enum _BpSize { xs, sm, md, lg, xl }

class _Bp {
  final _BpSize size;
  final double scale;

  _Bp._(this.size, this.scale);

  factory _Bp.of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final ts = MediaQuery.textScaleFactorOf(context).clamp(1.0, 1.25);
    if (w < 360) return _Bp._(_BpSize.xs, 0.86 * ts);
    if (w < 600) return _Bp._(_BpSize.sm, 0.94 * ts);
    if (w < 900) return _Bp._(_BpSize.md, 1.00 * ts);
    if (w < 1200) return _Bp._(_BpSize.lg, 1.06 * ts);
    return _Bp._(_BpSize.xl, 1.10 * ts);
  }

  bool get isNarrow => size == _BpSize.xs || size == _BpSize.sm;
}

/* ───────────────────────────────────────────────────────────
 * Atoms
 * ─────────────────────────────────────────────────────────── */

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
    final bp = _Bp.of(context);
    final resolvedRadius = (radius * bp.scale).clamp(12.0, 22.0);
    final baseInset = (padding.horizontal + padding.vertical) / 4;
    final inset = (baseInset * bp.scale).clamp(10.0, 20.0).toDouble();
    final resolvedPadding = EdgeInsets.symmetric(
      horizontal: math.max(12, inset),
      vertical: math.max(10, inset * 0.9),
    );
    final blur = (12 * bp.scale).clamp(8.0, 18.0);
    final y = (6 * bp.scale).clamp(4.0, 10.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(resolvedRadius),
        border: Border.all(color: _stroke),
        boxShadow: [
          BoxShadow(
            color: const Color(0x14000000),
            blurRadius: blur,
            offset: Offset(0, y),
          ),
        ],
      ),
      child: Padding(padding: resolvedPadding, child: child),
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

/* ───────────────────────────────────────────────────────────
 * Search
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
    final bp = _Bp.of(context);
    final fieldHeight = bp.isNarrow ? 42.0 : 46.0;

    return _Card(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: fieldHeight,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 10),
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
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller,
                    builder: (_, v, __) {
                      if (v.text.isEmpty) return const SizedBox(width: 10);
                      return IconButton(
                        splashRadius: 18,
                        tooltip: 'Clear',
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _ink600,
                        ),
                        onPressed: () => controller.clear(),
                      );
                    },
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

/* ───────────────────────────────────────────────────────────
 * Filter sheet
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
      initialChildSize: 0.40,
      minChildSize: 0.30,
      maxChildSize: 0.85,
      builder: (ctx, scroll) {
        return _Card(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: ListView(
            controller: scroll,
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
 * Sticky pager (now in scroll)
 * ─────────────────────────────────────────────────────────── */
class _StickyPager extends StatelessWidget {
  const _StickyPager({
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
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Previous',
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

/* ───────────────────────────────────────────────────────────
 * Place card (visual only)
 * ─────────────────────────────────────────────────────────── */
class _PlaceCard extends ConsumerStatefulWidget {
  const _PlaceCard({required this.item});
  final StorePlace item;

  @override
  ConsumerState<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<_PlaceCard> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final it = widget.item;
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canEditPlace = canAdmin || perms.contains('storeplaceedit');
    final canDeletePlace = canAdmin || perms.contains('storeplacedelete');

    return _Card(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 560;

          final left = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMint.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.store_mall_directory_rounded,
                  color: _ink900,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + code chip
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            (it.name).toString(),
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
                        if ((it.code).toString().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _accentPeach,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _stroke),
                            ),
                            child: Text(
                              it.code,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Meta chips — tight and safe
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _meta(
                          Icons.category_rounded,
                          it.type.isEmpty ? '-' : it.type,
                        ),
                        _meta(
                          Icons.notes_rounded,
                          it.remark.isEmpty ? '—' : it.remark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );

          final actions = Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.end,
            children: [
              if (canEditPlace)
                _SmallAction(
                  tooltip: 'Edit place',
                  icon: Icons.edit_location_alt_rounded,
                  onTap: () async {
                    final changed = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StorePlaceFormPage(initial: it),
                      ),
                    );
                    if (changed == true && mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('Updated')));
                    }
                  },
                ),
              if (canDeletePlace)
                _deleting
                    ? const SizedBox(
                      width: 30,
                      height: 30,
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                    : _SmallAction(
                      tooltip: 'Delete place',
                      icon: Icons.delete_forever_rounded,
                      color: Colors.red,
                      onTap: () async {
                        final sure = await showDialog<bool>(
                          context: context,
                          builder:
                              (_) => AlertDialog(
                                title: const Text('Delete store place?'),
                                content: Text(
                                  'Delete "${it.name}" permanently?',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed:
                                        () => Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed:
                                        () => Navigator.pop(context, true),
                                    style: FilledButton.styleFrom(
                                      foregroundColor: Colors.red.shade700,
                                    ),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                        );
                        if (sure != true) return;

                        setState(() => _deleting = true);
                        final ok = await ref
                            .read(storePlaceControllerProvider)
                            .deleteStorePlace(id: it.id);
                        if (!mounted) return;
                        setState(() => _deleting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok ? 'Deleted' : 'Delete failed'),
                          ),
                        );
                      },
                    ),
            ],
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                left,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _meta(IconData ic, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: _stroke),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(ic, size: 14, color: _ink600),
        const SizedBox(width: 6),
        // ✅ Use Flexible instead of ConstrainedBox
        Flexible(
          fit: FlexFit.tight,
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis, // graceful truncation
            softWrap: false,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.tooltip,
    required this.icon,
    this.color,
    required this.onTap,
  });
  final String tooltip;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: _stroke),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, color: color ?? _ink900),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Page
 * ─────────────────────────────────────────────────────────── */
class StorePlaceListPage extends ConsumerStatefulWidget {
  const StorePlaceListPage({super.key});

  @override
  ConsumerState<StorePlaceListPage> createState() => _StorePlaceListPageState();
}

class _StorePlaceListPageState extends ConsumerState<StorePlaceListPage> {
  StorePlaceQuery _query = const StorePlaceQuery(
    page: 1,
    limit: 12,
    search: "",
    sort: "-createdAt",
  );

  StorePlaceQuery _withPage(int page) => StorePlaceQuery(
    page: page,
    limit: _query.limit,
    search: _query.search,
    sort: _query.sort,
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
        if (!mounted) return;
        setState(() {
          _query = StorePlaceQuery(
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
          (_) => const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _FilterSheet(
              initial: _FilterResult(limit: 12, sort: '-createdAt'),
            ),
          ),
    );
    if (res != null) {
      setState(() {
        _query = StorePlaceQuery(
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
      _query = const StorePlaceQuery(
        page: 1,
        limit: 12,
        search: '',
        sort: '-createdAt',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final paged = ref.watch(storePlacePagedStreamProvider(_query));
    final user = ref.watch(userFindOneDataStreamProvider).value;
    final isSuperAdmin = user?.isSuperAdmin == true;
    final perms = {
      for (final e in (user?.appWorks ?? const [])) e.toString().trim(),
    };
    final canAdmin = isSuperAdmin || perms.contains('storeadmin');
    final canAddPlace = canAdmin || perms.contains('storeplaceadd');

    return Scaffold(
      backgroundColor: _surface,
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
            Icon(Icons.maps_home_work_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Store Places',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      floatingActionButton:
          canAddPlace
              ? FloatingActionButton.extended(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                icon: const Icon(Icons.add_location_alt_rounded),
                label: const Text('Add place'),
                onPressed: () async {
                  final changed = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StorePlaceFormPage(),
                    ),
                  );
                  if (changed == true && mounted) {
                    setState(() {
                      _query = StorePlaceQuery(
                        page: 1,
                        limit: _query.limit,
                        search: _query.search,
                        sort: _query.sort,
                      );
                    });
                  }
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
          child: CustomScrollView(
            slivers: [
              // Search
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  child: _SearchCard(
                    controller: _searchCtrl,
                    hint: 'Search place by name / code / type / id',
                    onFilterTap: _openFilterSheet,
                    onReset: _resetAll,
                  ),
                ),
              ),

              // Data
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
                    (e, _) => const SliverPadding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                      sliver: SliverToBoxAdapter(
                        child: _Card(
                          radius: 16,
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'Error loading places',
                            style: TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                data: (pg) {
                  if (pg.rows.isEmpty) {
                    return const SliverPadding(
                      padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
                      sliver: SliverToBoxAdapter(
                        child: _Card(
                          radius: 16,
                          padding: EdgeInsets.all(24),
                          child: _EmptyState(),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                    sliver: SliverList.separated(
                      itemCount: pg.rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _PlaceCard(item: pg.rows[i]),
                    ),
                  );
                },
              ),

              // Pager — now part of scroll to avoid FAB overlap
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    12,
                    0,
                    12,
                    96,
                  ), // bottom room for FAB
                  child: paged.maybeWhen(
                    data:
                        (pg) => _StickyPager(
                          total: pg.total,
                          pageSize: pg.limit,
                          pageIndex: pg.page,
                          onPrev:
                              pg.page > 1
                                  ? () => setState(
                                    () => _query = _withPage(pg.page - 1),
                                  )
                                  : null,
                          onNext:
                              (pg.page * pg.limit < pg.total)
                                  ? () => setState(
                                    () => _query = _withPage(pg.page + 1),
                                  )
                                  : null,
                          onJump: (p) => setState(() => _query = _withPage(p)),
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
 * Empty state
 * ─────────────────────────────────────────────────────────── */
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        SizedBox(
          width: 84,
          height: 84,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x33F3D7C0),
            ),
            child: Center(
              child: Icon(
                Icons.domain_disabled_rounded,
                size: 40,
                color: _ink900,
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(
          'No store places found',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ink900,
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Tap “Add place” to create your first location.',
          style: TextStyle(color: _ink700),
        ),
      ],
    );
  }
}
