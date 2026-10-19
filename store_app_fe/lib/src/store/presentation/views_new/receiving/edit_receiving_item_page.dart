import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
// ← keeps your existing dependency (not used visually)
import '../../../controllers/store_item_controller.dart'
    show storeItemAllDataStreamProvider;
import '../../../controllers/store_item_receiving_controller.dart'
    show itemReceiveControllerProvider;
import '../../../domains/models/store_item_model.dart' show StoreItem;

/* ───────────── Light Palette ───────────── */

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

/* ───────────── Widget ───────────── */

class ReceivingEditPage extends ConsumerStatefulWidget {
  const ReceivingEditPage({super.key, required this.rec});

  /// Whole receiving document passed in
  final Map<String, dynamic> rec;

  @override
  ConsumerState<ReceivingEditPage> createState() => _ReceivingEditPageState();
}

/* ───────────── Lite item + line (unchanged logic) ───────────── */

class _ItemLite {
  final String id;
  final String name;
  final String unit;
  final int avail;

  const _ItemLite({
    required this.id,
    required this.name,
    required this.unit,
    required this.avail,
  });

  static _ItemLite fromAny(dynamic d) {
    if (d is StoreItem) return _ItemLite.fromModel(d);
    if (d is Map<String, dynamic>) return _ItemLite.fromMap(d);
    return const _ItemLite(id: '', name: '', unit: '', avail: 0);
    // Fallback empty
  }

  static _ItemLite fromModel(StoreItem m) => _ItemLite(
    id: (m.id).toString(),
    name: m.name,
    unit: m.unit,
    avail: m.stockAvailableQuantity,
  );

  static _ItemLite fromMap(Map<String, dynamic> m) {
    final rawId = m['_id']?.toString() ?? m['id']?.toString() ?? '';
    return _ItemLite(
      id: rawId,
      name: (m['name'] ?? '').toString(),
      unit: (m['unit'] ?? '').toString(),
      avail: int.tryParse('${m['stockAvailableQuantity'] ?? 0}') ?? 0,
    );
  }
}

class _Line {
  final _ItemLite item;
  int qty;
  _Line({required this.item, required this.qty});
}

/* ───────────── Page State ───────────── */

class _ReceivingEditPageState extends ConsumerState<ReceivingEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _source = TextEditingController(
    text: (widget.rec['source'] ?? '').toString(),
  );
  late final TextEditingController _remark = TextEditingController(
    text: (widget.rec['remark'] ?? '').toString(),
  );

  final _qtyCtrl = TextEditingController();
  _ItemLite? _selected;

  final List<_Line> _lines = [];
  bool _submitting = false;

  String get _id => (widget.rec['_id'] ?? '').toString();
  String get _status => (widget.rec['status'] ?? '').toString();
  bool get _isDraft => _status == 'DRAFT';

  @override
  void initState() {
    super.initState();
    final rawLines = (widget.rec['lines'] as List?) ?? const [];
    for (final l in rawLines) {
      final itemId = (l['itemId'] ?? '').toString();
      final q =
          int.tryParse('${l['requestedQty'] ?? l['receiveqty'] ?? 0}') ?? 0;
      _lines.add(
        _Line(
          item: _ItemLite(id: itemId, name: '(loading...)', unit: '', avail: 0),
          qty: q,
        ),
      );
    }
  }

  @override
  void dispose() {
    _source.dispose();
    _remark.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _hydrateLineItems(List<_ItemLite> all) {
    final byId = {for (final i in all) i.id: i};
    bool changed = false;
    for (int i = 0; i < _lines.length; i++) {
      final current = _lines[i];
      if (current.item.name == '(loading...)') {
        final real = byId[current.item.id];
        if (real != null) {
          _lines[i] = _Line(item: real, qty: current.qty);
          changed = true;
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  Map<String, dynamic> _buildUpdatePayload(String userId) => {
    "id": _id,
    "source": _source.text.trim(),
    "remark": _remark.text.trim(),
    "userId": userId,
    "lines": [
      for (final l in _lines)
        {"itemid": l.item.id, "itemname": l.item.name, "receiveqty": l.qty},
    ],
  };

  Future<void> _submit() async {
    if (!_isDraft) return;

    if (!_formKey.currentState!.validate()) return;
    if (_lines.isEmpty || _lines.any((l) => l.qty <= 0)) {
      _snack('Add at least one item with qty > 0');
      return;
    }

    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    final body = _buildUpdatePayload(createdBy);

    setState(() => _submitting = true);
    try {
      final ok = await ref
          .read(itemReceiveControllerProvider)
          .updateItemReceive(itemReceiveModel: body);
      if (!mounted) return;
      _snack(ok ? 'Receiving updated' : 'Update failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _addSelected() {
    if (!_isDraft) return;

    final sel = _selected;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (sel == null) {
      _snack('Select an item');
      return;
    }
    if (qty <= 0) {
      _snack('Quantity must be > 0');
      return;
    }
    if (_lines.any((l) => l.item.id == sel.id)) {
      _snack('Item already in the list');
      return;
    }

    setState(() {
      _lines.add(_Line(item: sel, qty: qty));
      _selected = null;
      _qtyCtrl.clear();
    });
  }

  void _deleteLineAt(int idx) {
    if (!_isDraft) return;
    setState(() => _lines.removeAt(idx));
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
          children: [
            const Icon(Icons.edit_document, color: _ink900),
            const SizedBox(width: 8),
            // ✅ Flexible title that auto-scales font to avoid overflow
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Edit Receiving • ${widget.rec['recNo'] ?? ''}',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                    fontSize: 18.0, // base size, will shrink automatically
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (!_isDraft)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'READ ONLY',
                  style: TextStyle(color: _ink700, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
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
                  padding: const EdgeInsets.all(18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _SectionHeader(
                          icon: Icons.description_outlined,
                          title: 'Header',
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _source,
                          label: 'Source / From',
                          icon: Icons.factory_rounded,
                          requiredField: true,
                          enabled: _isDraft,
                        ),
                        const SizedBox(height: 10),
                        _Field(
                          controller: _remark,
                          label: 'Remark',
                          icon: Icons.notes_rounded,
                          enabled: _isDraft,
                        ),

                        const SizedBox(height: 18),
                        const _SectionHeader(
                          icon: Icons.list_alt_outlined,
                          title: 'Lines',
                        ),
                        const SizedBox(height: 10),

                        itemsAsync.when(
                          loading:
                              () => const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          error:
                              (e, _) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Error loading items: $e',
                                  style: const TextStyle(color: _ink700),
                                ),
                              ),
                          data: (docs) {
                            final List<_ItemLite> all =
                                (docs as List)
                                    .map<_ItemLite>(_ItemLite.fromAny)
                                    .where((it) => it.id.isNotEmpty)
                                    .toList();

                            _hydrateLineItems(all);

                            final selectedIds =
                                _lines.map((l) => l.item.id).toSet();
                            final available =
                                all
                                    .where((it) => !selectedIds.contains(it.id))
                                    .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_isDraft)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _ItemDropdown(
                                          items: available,
                                          value: _selected,
                                          onChanged:
                                              (v) =>
                                                  setState(() => _selected = v),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      SizedBox(
                                        width: 140,
                                        child: _NumberField(
                                          controller: _qtyCtrl,
                                          label: 'Qty',
                                          icon: Icons.numbers_rounded,
                                          min: 1,
                                          validate: false,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _PeachButton.icon(
                                        icon: Icons.add_rounded,
                                        label: 'Add',
                                        onPressed: _addSelected,
                                      ),
                                    ],
                                  ),

                                if (_isDraft && _selected != null) ...[
                                  const SizedBox(height: 12),
                                  _InfoRow(item: _selected!),
                                ],

                                const SizedBox(height: 16),
                                _LinesTable(
                                  lines: _lines,
                                  onDelete: _isDraft ? _deleteLineAt : null,
                                ),
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 20),
                        SizedBox(
                          height: 44,
                          child: _PeachButton(
                            onPressed:
                                _isDraft && !_submitting ? _submit : null,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_submitting)
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
                                  _submitting
                                      ? 'Saving...'
                                      : _isDraft
                                      ? 'Save Changes'
                                      : 'Locked',
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

/* ───────────── Light UI atoms ───────────── */

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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool requiredField;
  final bool enabled;
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.requiredField = false,
    this.enabled = true,
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
          enabled: enabled,
          validator:
              (v) =>
                  (requiredField && (v?.trim().isEmpty ?? true))
                      ? 'Required'
                      : null,
          style: const TextStyle(color: _ink900),
          decoration: InputDecoration(
            isDense: true,
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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final int min;
  final bool validate;
  const _NumberField({
    required this.controller,
    required this.label,
    required this.icon,
    this.min = 0,
    this.validate = true,
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
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator:
              !validate
                  ? null
                  : (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null) return 'Enter number';
                    if (n < min) return 'Min $min';
                    return null;
                  },
          style: const TextStyle(color: _ink900),
          decoration: InputDecoration(
            isDense: true,
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

/* ───────────── Dropdown and lines ───────────── */

class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final List<_ItemLite> items;
  final _ItemLite? value;
  final ValueChanged<_ItemLite?> onChanged;

  @override
  Widget build(BuildContext context) {
    final _ItemLite? safeValue =
        (value != null && items.any((e) => e.id == value!.id))
            ? items.firstWhere((e) => e.id == value!.id)
            : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Item',
          style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<_ItemLite>(
          initialValue: safeValue,
          isExpanded: true,
          items: [
            for (final it in items)
              DropdownMenuItem<_ItemLite>(
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
                        it.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${it.unit}',
                      style: const TextStyle(color: _ink600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(Avail: ${it.avail})',
                      style: const TextStyle(color: _ink600),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
          dropdownColor: _surface,
          style: const TextStyle(color: _ink900),
          iconEnabledColor: _ink700,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Select item',
            prefixIcon: const Icon(Icons.search, color: _ink700),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.item});
  final _ItemLite item;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [_pill('Unit', item.unit), _pill('Available', '${item.avail}')],
    );
  }

  Widget _pill(String k, String v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _accentMint.withValues(alpha: .30),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$k: ',
              style: const TextStyle(
                color: _ink700,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: v,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines, required this.onDelete});

  final List<_Line> lines;
  final void Function(int index)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return _Card(
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
      );
    }

    return _Card(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _stroke)),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 36),
              ],
            ),
          ),
          for (int i = 0; i < lines.length; i++)
            _LineRow(
              line: lines[i],
              onDelete: onDelete == null ? null : () => onDelete!(i),
            ),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, this.onDelete});
  final _Line line;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _stroke.withValues(alpha: .7))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              line.item.name,
              style: const TextStyle(
                color: _ink900,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text('${line.qty}', style: const TextStyle(color: _ink900)),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Remove',
              icon: const Icon(Icons.delete_outline_rounded, color: _ink700),
            ),
        ],
      ),
    );
  }
}

/* ───────────── Buttons (light) ───────────── */

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
