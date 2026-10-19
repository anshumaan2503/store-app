// ui/pages/place_stock_view_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../components/socket_manager.dart';
import '../../../domains/models/store_place_model.dart';
import '../../../controllers/store_place_controller.dart'
    show PlaceItemQty, storePlaceAllDataStreamProvider;
import '../../views_new/issue/qr_code_scanner/qr_code_scanner.dart';
import '../issue/qr_code_scanner/qr_code_print_page_place.dart';

/* ---------------- Palette (match dashboard) ---------------- */
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

/* ---------------- small text helpers ---------------- */
TextStyle _title(BuildContext c) => Theme.of(
  c,
).textTheme.titleMedium!.copyWith(color: _ink900, fontWeight: FontWeight.w800);
TextStyle _muted([double s = 12]) =>
    TextStyle(color: _ink600, fontSize: s, fontWeight: FontWeight.w600);

/* ---------------- light card ---------------- */
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
  }) : border = true;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(radius),
        border: border ? Border.all(color: _stroke) : null,
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

/* ---------------- model helpers ---------------- */
StorePlace _storePlaceFromAny(dynamic d) {
  if (d is StorePlace) return d;
  if (d is Map<String, dynamic>) return StorePlace.fromMap(d);
  return StorePlace(
    id: '',
    name: '',
    code: '',
    type: '',
    stockItemId: const [],
    remark: '',
    createdBy: '',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );
}

/* ---------------- query model ---------------- */
class PlaceItemsQuery {
  final String placeId;
  final String search;
  final int page; // 1-based
  final int limit;
  const PlaceItemsQuery({
    required this.placeId,
    this.search = '',
    this.page = 1,
    this.limit = 12,
  });
  int get skip => (page - 1) * limit;
  PlaceItemsQuery copyWith({
    String? placeId,
    String? search,
    int? page,
    int? limit,
  }) => PlaceItemsQuery(
    placeId: placeId ?? this.placeId,
    search: search ?? this.search,
    page: page ?? this.page,
    limit: limit ?? this.limit,
  );
  Map<String, dynamic> toJson() => {
    "placeId": placeId,
    if (search.trim().isNotEmpty) "search": search.trim(),
    "limit": limit,
    "skip": skip,
  };
}

/* ---------------- socket stream: items by place ---------------- */
final placeItemsPagedStreamProvider = StreamProvider.autoDispose
    .family<List<PlaceItemQty>, PlaceItemsQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<List<PlaceItemQty>>(sync: true);

      // ✅ unique request id for this provider instance
      final rid = DateTime.now().microsecondsSinceEpoch.toString();

      void handler(dynamic data) {
        try {
          // ✅ We only accept Map responses that match OUR rid and placeId
          if (data is! Map) return;

          if (data['rid']?.toString() != rid) return;
          if (data['placeId']?.toString() != query.placeId) return;

          final List raw =
              (data['data'] is List) ? (data['data'] as List) : const [];
          final rows =
              raw
                  .map((e) => PlaceItemQty.fromMap(e as Map<String, dynamic>))
                  .toList();

          controller.add(rows);
        } catch (_) {
          controller.add(<PlaceItemQty>[]);
        }
      }

      // ✅ attach listener FIRST
      socket.on("stock:listPlaceItems", handler);

      // ✅ include rid in request
      socket.emit("stock:listPlaceItems", {...query.toJson(), "rid": rid});

      ref.onDispose(() {
        socket.off("stock:listPlaceItems", handler);
        controller.close();
      });

      yield const <PlaceItemQty>[];
      await for (final v in controller.stream) {
        yield v;
      }
    });

/* ---------------- page ---------------- */
class PlaceStockViewPage extends ConsumerStatefulWidget {
  const PlaceStockViewPage({super.key});
  @override
  ConsumerState<PlaceStockViewPage> createState() => _PlaceStockViewPageState();
}

class _PlaceStockViewPageState extends ConsumerState<PlaceStockViewPage> {
  final TextEditingController _placeSearchCtrl = TextEditingController();

  @override
  void dispose() {
    _placeSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(storePlaceAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      floatingActionButton: FloatingActionButton.extended(
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
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.warehouse_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Place Stock',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        centerTitle: true,
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Card(
                      radius: 16,
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: TextField(
                                controller: _placeSearchCtrl,
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: InputDecoration(
                                  hintText:
                                      'Search places by name / code / type',
                                  hintStyle: const TextStyle(color: _ink600),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: _ink600,
                                  ),
                                  filled: true,
                                  fillColor: _surfaceAlt.withValues(alpha: .5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: _stroke,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: _stroke,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: _ink900,
                                      width: 1.2,
                                    ),
                                  ),
                                  suffixIcon:
                                      _placeSearchCtrl.text.isEmpty
                                          ? null
                                          : IconButton(
                                            tooltip: 'Clear',
                                            onPressed:
                                                () => setState(
                                                  _placeSearchCtrl.clear,
                                                ),
                                            icon: const Icon(
                                              Icons.clear_rounded,
                                              color: _ink600,
                                            ),
                                          ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    placesAsync.when(
                      loading:
                          () => const _Card(
                            padding: EdgeInsets.zero,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                      error:
                          (e, _) =>
                              _Card(child: Text('Error: $e', style: _muted())),
                      data: (docs) {
                        final places =
                            (docs as List)
                                .map<StorePlace>(_storePlaceFromAny)
                                .where((p) => p.id.isNotEmpty)
                                .toList();

                        final filter =
                            _placeSearchCtrl.text.trim().toLowerCase();
                        final visible =
                            filter.isEmpty
                                ? places
                                : places.where((p) {
                                  final txt =
                                      '${p.name} ${p.code} ${p.type}'
                                          .toLowerCase();
                                  return txt.contains(filter);
                                }).toList();

                        if (visible.isEmpty) {
                          return _Card(
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.domain_disabled_rounded,
                                  color: _ink600,
                                ),
                                const SizedBox(width: 8),
                                Text('No places found', style: _muted()),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Card(
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.home_work_outlined,
                                    color: _ink900,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Places (${visible.length})',
                                    style: _title(context),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // ✅ ListView.builder inside SingleChildScrollView
                            ListView.builder(
                              itemCount: visible.length,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final p = visible[index];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _PlaceCard(
                                    key: ValueKey(p.id),
                                    place: p,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------- place card ---------------- */
class _PlaceCard extends ConsumerStatefulWidget {
  const _PlaceCard({super.key, required this.place});
  final StorePlace place;

  @override
  ConsumerState<_PlaceCard> createState() => _PlaceCardState();
}

class _PlaceCardState extends ConsumerState<_PlaceCard> {
  bool _expanded = false;
  late PlaceItemsQuery _query;
  final TextEditingController _itemSearchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = PlaceItemsQuery(
      placeId: widget.place.id,
      search: '',
      page: 1,
      limit: 12,
    );

    _itemSearchCtrl.addListener(() {
      final txt = _itemSearchCtrl.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _query = _query.copyWith(search: txt, page: 1));
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  void _onQrTap() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QRCodePrintPlacePage(storePlaceList: [widget.place]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = widget.place;
    final titleText = place.name.isEmpty ? place.id : place.name;
    // final rowsAsync = ref.watch(placeItemsPagedStreamProvider(_query));

    return _Card(
      radius: 18,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: _stroke),
        child: ExpansionTile(
          initiallyExpanded: false,
          onExpansionChanged: (v) => setState(() => _expanded = v),
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          collapsedIconColor: _ink700,
          iconColor: _ink900,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accentMint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.place_rounded, color: _ink900),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$titleText (${place.code})',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // IconButton(
              //   tooltip: 'Print Place QR',
              //   onPressed: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder:
              //             (_) =>
              //                 PlaceStockReceivePage(placeId: widget.place.id),
              //       ),
              //     );
              //   },
              //   icon: const Icon(Icons.check_box, color: _ink700),
              // ),
              IconButton(
                tooltip: 'Print Place QR',
                onPressed: _onQrTap,
                icon: const Icon(Icons.qr_code_2_rounded, color: _ink700),
              ),
            ],
          ),
          subtitle:
              place.type.isEmpty ? null : Text(place.type, style: _muted(12)),
          children: [
            if (!_expanded)
              const SizedBox.shrink()
            else
              PlaceItemsExpandedSection(
                key: ValueKey('place-items-${widget.place.id}'), // ✅ important
                placeId: widget.place.id,
              ),
          ],
        ),
      ),
    );
  }
}

class PlaceItemsExpandedSection extends ConsumerStatefulWidget {
  const PlaceItemsExpandedSection({super.key, required this.placeId});

  final String placeId;

  @override
  ConsumerState<PlaceItemsExpandedSection> createState() =>
      _PlaceItemsExpandedSectionState();
}

class _PlaceItemsExpandedSectionState
    extends ConsumerState<PlaceItemsExpandedSection> {
  late PlaceItemsQuery _query;
  final TextEditingController _itemSearchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _query = PlaceItemsQuery(
      placeId: widget.placeId,
      search: '',
      page: 1,
      limit: 12,
    );

    _itemSearchCtrl.addListener(() {
      final txt = _itemSearchCtrl.text.trim();
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          _query = _query.copyWith(search: txt, page: 1);
        });
      });
    });
  }

  @override
  void didUpdateWidget(covariant PlaceItemsExpandedSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ if placeId changes (should not, because Key is stable), still safe:
    if (oldWidget.placeId != widget.placeId) {
      setState(() {
        _query = _query.copyWith(placeId: widget.placeId, page: 1);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _itemSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(placeItemsPagedStreamProvider(_query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          radius: 14,
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _itemSearchCtrl,
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Filter items by name…',
                      hintStyle: const TextStyle(color: _ink600),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _ink600,
                      ),
                      filled: true,
                      fillColor: _surfaceAlt.withValues(alpha: .5),
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
                        borderSide: const BorderSide(
                          color: _ink900,
                          width: 1.2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<int>(
                tooltip: 'Page size',
                icon: const Icon(Icons.filter_list_rounded, color: _ink700),
                onSelected: (n) {
                  setState(() {
                    _query = _query.copyWith(limit: n, page: 1);
                  });
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(value: 8, child: Text('8 / page')),
                      PopupMenuItem(value: 12, child: Text('12 / page')),
                      PopupMenuItem(value: 20, child: Text('20 / page')),
                    ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        rowsAsync.when(
          loading: () => const LinearProgressIndicator(minHeight: 2),
          error:
              (e, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text('Error: $e', style: _muted()),
              ),
          data: (rows) {
            if (rows.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.inbox_outlined, color: _ink600),
                    const SizedBox(width: 8),
                    Text('No items found', style: _muted()),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _ItemsTable(rows: rows),
                const SizedBox(height: 10),
                _PagerBarSlim(
                  page: _query.page,
                  hasPrev: _query.page > 1,
                  hasNext: rows.length >= _query.limit,
                  onPrev:
                      _query.page > 1
                          ? () => setState(() {
                            _query = _query.copyWith(page: _query.page - 1);
                          })
                          : null,
                  onNext:
                      rows.length >= _query.limit
                          ? () => setState(() {
                            _query = _query.copyWith(page: _query.page + 1);
                          })
                          : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/* ---------------- items table ---------------- */
class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.rows});
  final List<PlaceItemQty> rows;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 12,
      child: Column(children: [_header(), ...rows.map(_row)]),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: _stroke)),
    ),
    child: Row(
      children: const [
        Expanded(flex: 6, child: _H('Item')),
        Expanded(flex: 2, child: _H('Total')),
        Expanded(flex: 2, child: _H('Issued')),
        Expanded(flex: 2, child: _H('Completed')),
        Expanded(flex: 2, child: _H('Available')),
      ],
    ),
  );

  Widget _row(PlaceItemQty r) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: _stroke.withValues(alpha: .6))),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 6,
          child: Row(
            children: [
              const Icon(Icons.inventory_2_rounded, size: 16, color: _ink600),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.itemName.isEmpty ? r.itemId : r.itemName,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 2, child: _V('${r.total}')),
        Expanded(flex: 2, child: _V('${r.issued}')),
        Expanded(flex: 2, child: _V('${r.completed}')),
        Expanded(
          flex: 2,
          child: Text(
            '${r.available}',
            textAlign: TextAlign.left,
            style: TextStyle(
              color: r.available >= 0 ? _ink900 : Colors.red.shade700,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _H extends StatelessWidget {
  const _H(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Text(
    t,
    style: const TextStyle(color: _ink700, fontWeight: FontWeight.w800),
  );
}

class _V extends StatelessWidget {
  const _V(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Text(
    t,
    style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
  );
}

/* ---------------- slim pager ---------------- */
class _PagerBarSlim extends StatelessWidget {
  const _PagerBarSlim({
    required this.page,
    required this.hasPrev,
    required this.hasNext,
    required this.onPrev,
    required this.onNext,
  });

  final int page;
  final bool hasPrev;
  final bool hasNext;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return _Card(
      radius: 12,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous',
            onPressed: hasPrev ? onPrev : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: hasPrev ? _ink900 : _ink600.withValues(alpha: 0.4),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Page $page',
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Next',
            onPressed: hasNext ? onNext : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: hasNext ? _ink900 : _ink600.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
