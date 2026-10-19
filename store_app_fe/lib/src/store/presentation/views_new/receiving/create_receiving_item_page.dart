// lib/src/store/presentation/views/receiving/receiving_create_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ===== existing app imports (unchanged) =====
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_item_receiving_controller.dart';
import '../../../domains/models/store_item_model.dart';
import '../../../controllers/store_item_controller.dart';

// If your provider symbol is different, re-alias it here.
// final storeItemAllDataStreamProvider = yourRealProvider;

/* ───────────────────────── Palette (light) ───────────────────────── */

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

/* ───────────────────────── Lite models (unchanged) ───────────────────────── */
class _ItemLite {
  final String id;
  final String name;
  final int available;
  final String unit;
  _ItemLite({
    required this.id,
    required this.name,
    required this.available,
    required this.unit,
  });

  factory _ItemLite.fromModel(StoreItem m) => _ItemLite(
    id: m.id,
    name: m.name,
    available: m.stockAvailableQuantity,
    unit: m.unit,
  );

  factory _ItemLite.fromDoc(Map<String, dynamic> m) {
    String id = '';
    final rawId = m['_id'];
    if (rawId is Map && rawId['\$oid'] != null) {
      id = rawId['\$oid'] as String;
    } else if (rawId != null) {
      id = rawId.toString();
    }
    final avail = (m['stockAvailableQuantity'] ?? 0);
    return _ItemLite(
      id: id,
      name: (m['name'] ?? '').toString(),
      available: avail is int ? avail : int.tryParse('$avail') ?? 0,
      unit: (m['unit'] ?? '').toString(),
    );
  }
}

class _ReceiveLine {
  final String itemId;
  final String itemName;
  final int qty;
  final String unit;
  final int available;
  _ReceiveLine({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.available,
  });

  Map<String, dynamic> toBackend() => {
    "itemid": itemId,
    "itemname": itemName,
    "receiveqty": qty,
  };
}

/* ───────────────────────── Page ───────────────────────── */

class ReceivingCreatePage extends ConsumerStatefulWidget {
  const ReceivingCreatePage({super.key});
  @override
  ConsumerState<ReceivingCreatePage> createState() =>
      _ReceivingCreatePageState();
}

class _ReceivingCreatePageState extends ConsumerState<ReceivingCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _source = TextEditingController();
  final _remark = TextEditingController();

  String? _selectedItemId;
  final _qty = TextEditingController();

  final List<_ReceiveLine> _lines = [];
  final Set<String> _pickedIds = {};

  bool _saving = false;

  @override
  void dispose() {
    _source.dispose();
    _remark.dispose();
    _qty.dispose();
    super.dispose();
  }

  void _addLineFor(_ItemLite it) {
    final q = int.tryParse(_qty.text.trim()) ?? 0;
    if (q <= 0) {
      _snack('Quantity must be > 0');
      return;
    }
    if (_pickedIds.contains(it.id) || _lines.any((l) => l.itemId == it.id)) {
      _snack('Item already added');
      return;
    }
    setState(() {
      _lines.add(
        _ReceiveLine(
          itemId: it.id,
          itemName: it.name,
          qty: q,
          unit: it.unit,
          available: it.available,
        ),
      );
      _pickedIds.add(it.id);
      _selectedItemId = null;
      _qty.clear();
    });
  }

  void _removeLineAt(int index) {
    setState(() {
      final removed = _lines.removeAt(index);
      _pickedIds.remove(removed.itemId);
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty) {
      _snack('Add at least one item line');
      return;
    }
    if (_lines.any((l) => l.qty <= 0)) {
      _snack('All lines must have qty > 0');
      return;
    }
    if (_selectedItemId != null &&
        (_qty.text.trim().isEmpty || int.tryParse(_qty.text.trim()) == null)) {
      _snack('Press + to add the selected item');
      return;
    }
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    final payload = {
      "source": _source.text.trim(),
      "remark": _remark.text.trim(),
      "userId": createdBy,
      "lines": _lines.map((e) => e.toBackend()).toList(),
    };

    setState(() => _saving = true);
    try {
      await ref
          .read(itemReceiveControllerProvider)
          .createItemReceive(itemReceiveModel: payload);
      if (!mounted) return;
      _snack('Receiving created');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(storeItemAllDataStreamProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Row(
          children: const [
            Icon(Icons.move_to_inbox_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Create Receiving',
              style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        centerTitle: false,
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
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 26),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: _Card(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // Header section
                        _SectionHeader(
                          icon: Icons.description_outlined,
                          title: 'Header',
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _source,
                          label: 'Source / From',
                          icon: Icons.factory_rounded,
                          required: true,
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _remark,
                          label: 'Remark',
                          icon: Icons.notes_rounded,
                        ),

                        const SizedBox(height: 18),
                        _SectionHeader(
                          icon: Icons.add_shopping_cart_outlined,
                          title: 'Add Line',
                        ),
                        const SizedBox(height: 8),

                        // Item chooser + qty
                        itemsAsync.when(
                          loading:
                              () => const Padding(
                                padding: EdgeInsets.symmetric(vertical: 18),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          error:
                              (e, _) => Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Text(
                                  'Error loading items: $e',
                                  style: const TextStyle(color: _ink700),
                                ),
                              ),
                          data: (docs) {
                            final List<_ItemLite> all =
                                docs
                                    .map<_ItemLite?>((e) {
                                      return _ItemLite.fromModel(e);
                                      if (e is Map<String, dynamic>) {
                                        return _ItemLite.fromDoc({
                                          "_id": e.id,
                                          "name": e.name,
                                          "stockAvailableQuantity":
                                              e.stockAvailableQuantity,
                                          "unit": e.unit,
                                        });
                                      }
                                      return null;
                                    })
                                    .whereType<_ItemLite>()
                                    .toList();

                            final available =
                                all
                                    .where((i) => !_pickedIds.contains(i.id))
                                    .toList();

                            return _LineEditor(
                              items: available,
                              selectedId: _selectedItemId,
                              qtyController: _qty,
                              onSelect:
                                  (id) => setState(() => _selectedItemId = id),
                              onAdd: () {
                                final it = all.firstWhere(
                                  (x) => x.id == _selectedItemId,
                                  orElse:
                                      () => _ItemLite(
                                        id: '',
                                        name: '',
                                        available: 0,
                                        unit: '',
                                      ),
                                );
                                if (it.id.isEmpty) {
                                  _snack('Select an item');
                                  return;
                                }
                                _addLineFor(it);
                              },
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        _SectionHeader(
                          icon: Icons.list_alt_outlined,
                          title: 'Lines',
                        ),
                        const SizedBox(height: 8),

                        if (_lines.isEmpty)
                          _Card(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: const [
                                Icon(Icons.info_outline, color: _ink700),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No items added yet',
                                    style: TextStyle(color: _ink700),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          _LinesTable(lines: _lines, onRemove: _removeLineAt),

                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: _PeachButton(
                            onPressed: _saving ? null : _submit,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_saving)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: _ink900,
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.save_rounded,
                                    color: _ink900,
                                  ),
                                const SizedBox(width: 8),
                                Text(
                                  _saving ? 'Saving…' : 'Create',
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

/* ───────────────────────── Light Atoms ───────────────────────── */

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _accentMint.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _stroke),
          ),
          child: Icon(icon, color: _ink900, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink700, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator:
              (v) =>
                  (required && (v?.trim().isEmpty ?? true)) ? 'Required' : null,
          style: const TextStyle(color: _ink900),
          decoration: InputDecoration(
            isDense: true,
            hintText: '',
            prefixIcon: Icon(icon, color: _ink700),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: _cardBorder,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: _cardBorder,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _accentMint, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget? child;
  final EdgeInsetsGeometry? padding;
  const _Card({this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
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
      child: Padding(
        padding: padding ?? const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}

/* ───────────────────────── Line editor (dropdown + qty + add) ───────────────────────── */

class _LineEditor extends StatelessWidget {
  const _LineEditor({
    required this.items,
    required this.selectedId,
    required this.qtyController,
    required this.onSelect,
    required this.onAdd,
  });

  final List<_ItemLite> items;
  final String? selectedId;
  final TextEditingController qtyController;
  final ValueChanged<String?> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 560;

        final dropdown = _ItemDropdownById(
          items: items,
          valueId: selectedId,
          onChanged: onSelect,
        );

        final qty = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quantity',
              style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: _ink900),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0',
                prefixIcon: const Icon(
                  Icons.onetwothree_rounded,
                  color: _ink700,
                ),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _cardBorder,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _cardBorder,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accentMint, width: 2),
                ),
              ),
            ),
          ],
        );

        final addBtn = Align(
          alignment: wide ? Alignment.bottomRight : Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(top: wide ? 0 : 10),
            child: _PeachButton.icon(
              icon: Icons.add_rounded,
              label: 'Add',
              onPressed: onAdd,
            ),
          ),
        );

        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(flex: 5, child: dropdown),
              const SizedBox(width: 10),
              Expanded(flex: 3, child: qty),
              const SizedBox(width: 10),
              addBtn,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              dropdown,
              const SizedBox(height: 10),
              qty,
              const SizedBox(height: 10),
              addBtn,
            ],
          );
        }
      },
    );
  }
}

/* ───────────────────────── Item dropdown (light) ───────────────────────── */

class _ItemDropdownById extends StatelessWidget {
  const _ItemDropdownById({
    required this.items,
    required this.valueId,
    required this.onChanged,
  });
  final List<_ItemLite> items;
  final String? valueId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final String? safeValue =
        (valueId != null && items.any((e) => e.id == valueId)) ? valueId : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item',
          style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (ctx, constraints) {
            final totalW =
                constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0;
            final nameColW = (totalW - 170).clamp(80.0, 520.0);

            List<Widget> rowChild(_ItemLite i) => [
              const Icon(Icons.inventory_2_rounded, size: 18, color: _ink700),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: nameColW),
                child: Text(
                  i.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _ink900),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${i.available}${i.unit.isEmpty ? '' : ' ${i.unit}'})',
                style: const TextStyle(fontSize: 12, color: _ink600),
              ),
            ];

            return DropdownButtonFormField<String>(
              key: ValueKey(items.length),
              initialValue: safeValue,
              isDense: false,
              isExpanded: true,
              items:
                  items
                      .map(
                        (i) => DropdownMenuItem<String>(
                          value: i.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: rowChild(i),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: onChanged,
              style: const TextStyle(color: _ink900),
              dropdownColor: _surface,
              iconEnabledColor: _ink700,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search, color: _ink700),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _cardBorder,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: _cardBorder,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _accentMint, width: 2),
                ),
              ),
              selectedItemBuilder:
                  (ctx) =>
                      items.map((i) => Row(children: rowChild(i))).toList(),
            );
          },
        ),
      ],
    );
  }
}

/* ───────────────────────── Lines table (fixed widths) ───────────────────────── */

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines, required this.onRemove});
  final List<_ReceiveLine> lines;
  final void Function(int index) onRemove;

  static const double _colItem = 300;
  static const double _colQty = 90;
  static const double _colAvail = 130;
  static const double _colAction = 48;
  static const double _gap = 8;

  double get _minTableWidth =>
      _colItem + _gap + _colQty + _gap + _colAvail + _gap + _colAction;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: _minTableWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    SizedBox(
                      width: _LinesTable._colItem,
                      child: Text(
                        'Item',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: _LinesTable._gap),
                    SizedBox(
                      width: _LinesTable._colQty,
                      child: Text(
                        'Receive',
                        style: TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: _LinesTable._gap),
                    SizedBox(
                      width: _LinesTable._colAvail,
                      child: Text(
                        'Avail.',
                        style: TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    SizedBox(width: _LinesTable._gap),
                    SizedBox(width: _LinesTable._colAction),
                  ],
                ),
              ),
              const Divider(color: _stroke, height: 10),
              // rows
              for (int i = 0; i < lines.length; i++) ...[
                _row(lines[i], i),
                if (i != lines.length - 1)
                  const Divider(color: _stroke, height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(_ReceiveLine l, int index) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _colItem,
          child: Text(
            l.itemName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink900),
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _colQty,
          child: Text('${l.qty}', style: const TextStyle(color: _ink900)),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _colAvail,
          child: Text(
            '${l.available}${l.unit.isEmpty ? '' : ' ${l.unit}'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _ink700),
          ),
        ),
        const SizedBox(width: _gap),
        SizedBox(
          width: _colAction,
          child: IconButton(
            tooltip: 'Remove',
            onPressed: () => onRemove(index),
            icon: const Icon(Icons.close_rounded, color: _ink700, size: 20),
          ),
        ),
      ],
    );
  }
}

/* ───────────────────────── Buttons (light) ───────────────────────── */

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
            style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: _ink900),
            child: child,
          ),
        ),
      ),
    );
  }
}
