// lib/features/store_items/views/receive/receive_to_place_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Your providers (adjust paths if different)
import '../../../controllers/store_place_controller.dart'
    show storePlaceAllDataStreamProvider;
import '../../../controllers/store_item_receiving_controller.dart'
    show itemReceiveControllerProvider;

/* ───────────────────────────────────────────────────────────
 * Palette (match dashboard)
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
 * Light helpers
 * ─────────────────────────────────────────────────────────── */
TextStyle _title(BuildContext c) => Theme.of(
  c,
).textTheme.titleMedium!.copyWith(color: _ink900, fontWeight: FontWeight.w800);
TextStyle _muted([double s = 12]) =>
    TextStyle(color: _ink600, fontSize: s, fontWeight: FontWeight.w600);

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
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
 * Page
 *  - Expects a full Receiving document in [receiving] (Map)
 *  - User selects Item (line), Place, quantities
 * ─────────────────────────────────────────────────────────── */
class ReceiveToPlacePage extends ConsumerStatefulWidget {
  const ReceiveToPlacePage({super.key, required this.receiving});
  final Map<String, dynamic> receiving;

  @override
  ConsumerState<ReceiveToPlacePage> createState() => _ReceiveToPlacePageState();
}

/* ---------------- lite models & parsing ---------------- */

class _PlaceLite {
  final String id;
  final String name;
  const _PlaceLite({required this.id, required this.name});

  static _PlaceLite fromAny(dynamic d) {
    try {
      if (d.runtimeType.toString() == 'StorePlace') {
        final id = d.id?.toString() ?? '';
        final name = d.name?.toString() ?? '';
        return _PlaceLite(id: id, name: name);
      }
    } catch (_) {}
    if (d is Map<String, dynamic>) {
      final rawId =
          d['_id']?.toString() ??
          d['id']?.toString() ??
          d[r'$oid']?.toString() ??
          '';
      return _PlaceLite(id: rawId, name: (d['name'] ?? '').toString());
    }
    return const _PlaceLite(id: '', name: '');
  }
}

class _LineLite {
  final String itemId;
  final String itemName;
  final int remaining; // approved - received - scrap
  const _LineLite({
    required this.itemId,
    required this.itemName,
    required this.remaining,
  });

  static String _extractId(dynamic v) {
    if (v is String) return v;
    if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    return v?.toString() ?? '';
  }

  static int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

  static _LineLite fromMap(Map<String, dynamic> m) {
    final id = _extractId(m['itemId']);
    final name = (m['itemName'] ?? '').toString();
    final rem = (_toInt(m['approvedQty']) -
            _toInt(m['receivedQty']) -
            _toInt(m['scrapQty']))
        .clamp(0, 1 << 30);
    return _LineLite(itemId: id, itemName: name, remaining: rem);
  }
}

class _ReceiveToPlacePageState extends ConsumerState<ReceiveToPlacePage> {
  // receiving meta
  String get _recId => (widget.receiving['_id'] ?? '').toString();
  String get _recNo => (widget.receiving['recNo'] ?? '').toString();
  String get _source => (widget.receiving['source'] ?? '').toString();

  // build selectable lines (remaining > 0)
  late final List<_LineLite> _items =
      (() {
        final raw = (widget.receiving['lines'] as List?) ?? const [];
        final list = <_LineLite>[];
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            final l = _LineLite.fromMap(e);
            if (l.itemId.isNotEmpty && l.remaining > 0) list.add(l);
          }
        }
        return list;
      })();

  // selections & inputs
  _LineLite? _selItem;
  _PlaceLite? _selPlace;
  final _receiveQtyCtrl = TextEditingController();
  final _scrapQtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _receiveQtyCtrl.dispose();
    _scrapQtyCtrl.dispose();
    super.dispose();
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  int get _remainingSelected => _selItem?.remaining ?? 0;

  Future<void> _submit() async {
    final item = _selItem;
    final place = _selPlace;
    final receiveQty =
        int.tryParse(
          (_receiveQtyCtrl.text.trim().isEmpty
              ? '0'
              : _receiveQtyCtrl.text.trim()),
        ) ??
        0;
    final scrapQty =
        int.tryParse(
          (_scrapQtyCtrl.text.trim().isEmpty ? '0' : _scrapQtyCtrl.text.trim()),
        ) ??
        0;

    if (item == null) return _snack('Select an item');
    if (place == null) return _snack('Select a place');
    if (receiveQty < 0 || scrapQty < 0) return _snack('Quantities must be ≥ 0');

    final totalIn = receiveQty + scrapQty;
    if (totalIn <= 0) return _snack('Enter at least one positive quantity');

    final rem = _remainingSelected;
    if (totalIn > rem) {
      return _snack('Total (receive + scrap) cannot exceed remaining ($rem)');
    }

    final payload = {
      "itemid": item.itemId,
      "placeId": place.id,
      "receiveId": _recId,
      "quantity": receiveQty,
      "scrapQuantity": scrapQty,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemReceiveControllerProvider)
          .itemReceiveToPlace(itemReceiveToPlace: payload);
      if (!mounted) return;
      _snack(ok ? 'Saved' : 'Failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(storePlaceAllDataStreamProvider);

    // keep selected item if still present
    final _LineLite? safeItem =
        (_selItem != null && _items.any((i) => i.itemId == _selItem!.itemId))
            ? _items.firstWhere((i) => i.itemId == _selItem!.itemId)
            : null;

    return Scaffold(
      backgroundColor: _surface,
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
          children: [
            const Icon(Icons.inventory_2_rounded, color: _ink900),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Receive to Place • $_recNo',
                style: const TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w800,
                ),
                overflow: TextOverflow.ellipsis,
              ),
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
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  radius: 22,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header meta
                      Row(
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
                              Icons.local_shipping,
                              color: _ink900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '$_recNo • $_source',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 1) Item
                      Text('1) Select Item', style: _title(context)),
                      const SizedBox(height: 6),
                      _LightDropdown<_LineLite>(
                        value: safeItem,
                        hint: 'Select item',
                        icon: Icons.inventory_2_rounded,
                        items: [
                          for (final it in _items)
                            DropdownMenuItem<_LineLite>(
                              value: it,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.inventory_2_rounded,
                                    size: 18,
                                    color: _ink700,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      it.itemName.isEmpty
                                          ? it.itemId
                                          : it.itemName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _ink900,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Rem: ${it.remaining})',
                                    style: _muted(11),
                                  ),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (v) {
                          setState(() {
                            _selItem = v;
                            _receiveQtyCtrl.clear();
                            _scrapQtyCtrl.clear();
                          });
                        },
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      if (safeItem != null) ...[
                        const SizedBox(height: 8),
                        _Pill(
                          label: 'Remaining',
                          value: '${safeItem.remaining}',
                        ),
                      ],
                      const SizedBox(height: 16),

                      // 2) Place
                      Text('2) Select Place', style: _title(context)),
                      const SizedBox(height: 6),
                      placesAsync.when(
                        loading:
                            () => const Padding(
                              padding: EdgeInsets.all(8),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        error:
                            (e, _) => Text(
                              'Failed to load places: $e',
                              style: _muted(),
                            ),
                        data: (docs) {
                          final places =
                              (docs as List)
                                  .map<_PlaceLite>(_PlaceLite.fromAny)
                                  .where((p) => p.id.isNotEmpty)
                                  .toList();

                          final _PlaceLite? safePlace =
                              (_selPlace != null &&
                                      places.any((p) => p.id == _selPlace!.id))
                                  ? places.firstWhere(
                                    (p) => p.id == _selPlace!.id,
                                  )
                                  : null;

                          return _LightDropdown<_PlaceLite>(
                            value: safePlace,
                            hint: 'Select place',
                            icon: Icons.place_rounded,
                            items: [
                              for (final p in places)
                                DropdownMenuItem<_PlaceLite>(
                                  value: p,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.place_rounded,
                                        size: 18,
                                        color: _ink700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          p.name.isEmpty ? p.id : p.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (v) => setState(() => _selPlace = v),
                            validator: (v) => v == null ? 'Required' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // 3) Quantities
                      Text('3) Enter Quantities', style: _title(context)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: _QtyField(
                              controller: _receiveQtyCtrl,
                              label: 'Receive Quantity',
                              hint: '0',
                              icon: Icons.add_shopping_cart_rounded,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QtyField(
                              controller: _scrapQtyCtrl,
                              label: 'Scrap Quantity',
                              hint: '0',
                              icon: Icons.delete_forever_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: _surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _busy ? null : _submit,
                          icon:
                              _busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _surface,
                                    ),
                                  )
                                  : const Icon(Icons.download_done_rounded),
                          label: Text(
                            _busy ? 'Saving...' : 'Receive',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ───────────────────────────────────────────────────────────
 * Light form atoms
 * ─────────────────────────────────────────────────────────── */

class _LightDropdown<T> extends StatelessWidget {
  const _LightDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    required this.icon,
    this.validator,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final IconData icon;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _ink600, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: _ink700),
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
          borderSide: const BorderSide(color: _ink900, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      dropdownColor: _surface,
      style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
      iconEnabledColor: _ink700,
    );
  }
}

class _QtyField extends StatelessWidget {
  const _QtyField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _title(context)),
        const SizedBox(height: 6),
        SizedBox(
          height: 44,
          child: TextFormField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: _ink600),
              prefixIcon: Icon(icon, color: _ink700),
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
                borderSide: const BorderSide(color: _ink900, width: 1.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: _muted()),
          Text(
            value,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
