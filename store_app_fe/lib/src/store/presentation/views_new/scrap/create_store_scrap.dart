// lib/features/store/pages/scrap_from_place_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:store_app/src/store/domains/models/store_item_model.dart';

import '../../../controllers/store_item_controller.dart';
import '../../../controllers/store_place_controller.dart';
import '../../../../auth/shared/repositories/shared_preference_repository.dart';

/* ===================== Palette (shared look) ===================== */

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = Color(0xFFFFF4E2);

/* ===================== Page ===================== */

class ScrapFromPlacePage extends ConsumerStatefulWidget {
  const ScrapFromPlacePage({super.key});
  @override
  ConsumerState<ScrapFromPlacePage> createState() => _ScrapFromPlacePageState();
}

/* ---------- Light models (unchanged logic) ---------- */

class _ItemLite {
  final String id;
  final String name;
  final String unit;
  final int avail; // overall available (for info only)
  const _ItemLite(this.id, this.name, this.unit, this.avail);

  static _ItemLite fromAny(dynamic d) {
    if (d is StoreItem) {
      return _ItemLite(
        d.id.toString(),
        d.name,
        d.unit,
        d.stockAvailableQuantity,
      );
    }
    final m = d as Map<String, dynamic>;
    final id = (m['_id'] ?? m['id'] ?? '').toString();
    return _ItemLite(
      id,
      (m['name'] ?? '').toString(),
      (m['unit'] ?? '').toString(),
      int.tryParse('${m['stockAvailableQuantity'] ?? 0}') ?? 0,
    );
  }
}

class _PlaceLite {
  final String id;
  final String name;
  final int placeAvail; // total - issued - completed
  const _PlaceLite({
    required this.id,
    required this.name,
    required this.placeAvail,
  });
}

class _ScrapFromPlacePageState extends ConsumerState<ScrapFromPlacePage> {
  final _formKey = GlobalKey<FormState>();

  _ItemLite? _item;
  _PlaceLite? _place;
  final _qtyCtrl = TextEditingController();

  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (_item == null) {
      _toast('Select item');
      return;
    }
    if (_place == null) {
      _toast('Select place');
      return;
    }
    final n = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (n <= 0) {
      _toast('Scrap qty must be > 0');
      return;
    }
    if (n > _place!.placeAvail) {
      _toast('Cannot scrap more than place available (${_place!.placeAvail})');
      return;
    }

    final userId =
        await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';

    final payload = {
      if (userId.isNotEmpty) 'userId': userId,
      'itemid': _item!.id,
      'placeId': _place!.id,
      'quantity': n,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(storeItemControllerProvider)
          .scrapStoreItem(storeItemModel: payload);
      if (!mounted) return;
      _toast(ok ? 'Scrap recorded' : 'Scrap failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (mounted) _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(storeItemAllDataStreamProvider);
    final spiqAsync = ref.watch(storePlaceQuantityAllDataStreamProvider);

    final selectedItemId = _item?.id;

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
              'Scrap from Place',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  radius: 20,
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Select what you want to scrap, from where, and how much.',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 1) Item
                        const _Label('Item'),
                        itemsAsync.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error:
                              (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: _ink900),
                              ),
                          data: (docs) {
                            final items =
                                (docs as List)
                                    .map<_ItemLite>(_ItemLite.fromAny)
                                    .where((x) => x.id.isNotEmpty)
                                    .toList();

                            final safeValue =
                                (_item != null &&
                                        items.any((i) => i.id == _item!.id))
                                    ? items.firstWhere((i) => i.id == _item!.id)
                                    : null;

                            return _Dropdown<_ItemLite>(
                              value: safeValue,
                              hint: 'Select item',
                              icon: Icons.inventory_2_rounded,
                              items:
                                  items
                                      .map(
                                        (it) => DropdownMenuItem(
                                          value: it,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 220,
                                                    ),
                                                child: Text(
                                                  it.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '• ${it.unit}',
                                                style: const TextStyle(
                                                  color: _ink700,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(Avail: ${it.avail})',
                                                style: const TextStyle(
                                                  color: _ink700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setState(() {
                                    _item = v;
                                    _place = null;
                                    _qtyCtrl.clear();
                                  }),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // 2) Place
                        const _Label('Place'),
                        spiqAsync.when(
                          loading:
                              () => const LinearProgressIndicator(minHeight: 2),
                          error:
                              (e, _) => Text(
                                'Error: $e',
                                style: const TextStyle(color: _ink900),
                              ),
                          data: (raw) {
                            final spiqs = (raw as List).cast<dynamic>();
                            final places = <_PlaceLite>[];

                            if (selectedItemId != null &&
                                selectedItemId.isNotEmpty) {
                              for (final d in spiqs) {
                                final m = (d as Map).cast<String, dynamic>();
                                final itemId = (m['itemId'] ?? '').toString();
                                if (itemId != selectedItemId) continue;

                                final placeId = (m['placeId'] ?? '').toString();
                                final placeName =
                                    (m['placeName'] ?? '').toString();
                                final total =
                                    int.tryParse(
                                      '${m['totalQuantity'] ?? 0}',
                                    ) ??
                                    0;
                                final issued =
                                    int.tryParse(
                                      '${m['IssuedQuantity'] ?? 0}',
                                    ) ??
                                    0;
                                final completed =
                                    int.tryParse(
                                      '${m['completedQuantity'] ?? 0}',
                                    ) ??
                                    0;
                                final placeAvail = total - issued - completed;
                                if (placeAvail > 0) {
                                  places.add(
                                    _PlaceLite(
                                      id: placeId,
                                      name:
                                          placeName.isEmpty
                                              ? placeId
                                              : placeName,
                                      placeAvail: placeAvail,
                                    ),
                                  );
                                }
                              }
                            }

                            final safePlace =
                                (_place != null &&
                                        places.any((p) => p.id == _place!.id))
                                    ? places.firstWhere(
                                      (p) => p.id == _place!.id,
                                    )
                                    : null;

                            return _Dropdown<_PlaceLite>(
                              value: safePlace,
                              hint:
                                  _item == null
                                      ? 'Select item first'
                                      : 'Select place',
                              icon: Icons.place_rounded,
                              items:
                                  places
                                      .map(
                                        (p) => DropdownMenuItem(
                                          value: p,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ConstrainedBox(
                                                constraints:
                                                    const BoxConstraints(
                                                      maxWidth: 260,
                                                    ),
                                                child: Text(
                                                  p.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    color: _ink900,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '(Avail here: ${p.placeAvail})',
                                                style: const TextStyle(
                                                  color: _ink700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                              onChanged:
                                  (v) => setState(() {
                                    _place = v;
                                    _qtyCtrl.clear();
                                  }),
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        // 3) Scrap quantity
                        const _Label('Scrap Quantity'),
                        SizedBox(
                          width: 260,
                          child: TextFormField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: _inputDecoration(
                              prefixIcon: Icons.numbers_rounded,
                              hint: 'Enter quantity',
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: _PrimaryBtn(
                            icon:
                                _busy
                                    ? Icons.hourglass_top_rounded
                                    : Icons.delete_forever_rounded,
                            label: _busy ? 'Scrapping...' : 'Scrap',
                            busy: _busy,
                            onTap: _busy ? null : _submit,
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
      ),
    );
  }
}

/* ===================== UI bits ===================== */

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

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
      ),
    );
  }
}

InputDecoration _inputDecoration({required IconData prefixIcon, String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _ink600),
    prefixIcon: Icon(prefixIcon, color: _ink600),
    filled: true,
    fillColor: _surface,
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _stroke),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _stroke),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _ink900, width: 1.2),
    ),
  );
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.hint,
    required this.icon,
  });

  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String hint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      items: items,
      onChanged: onChanged,
      style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
      iconEnabledColor: _ink900,
      decoration: _inputDecoration(prefixIcon: icon, hint: hint),
      dropdownColor: _surface,
      menuMaxHeight: 360,
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ink900,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _surface,
                  ),
                )
              else
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
