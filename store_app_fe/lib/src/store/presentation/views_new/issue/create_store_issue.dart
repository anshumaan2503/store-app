import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Theme widgets
import '../../../../auth/widgets/app_bar_page.dart'; // still fine to keep
// not used now, can remove if you want

// Data/providers
import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_item_controller.dart'
    show storeItemAllDataStreamProvider;
import '../../../controllers/store_item_issue_controller.dart'
    show itemIssueControllerProvider;
import '../../../domains/models/store_item_model.dart' show StoreItem;

/* ---------- light palette ---------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2); // soft warm fill for inputs/pills
const _stroke = Color(0xFFDFE1D6);
const _mint = Color(0xFFB6D3CC); // subtle accent for hover/splash

class IssueCreatePage extends ConsumerStatefulWidget {
  const IssueCreatePage({super.key});
  @override
  ConsumerState<IssueCreatePage> createState() => _IssueCreatePageState();
}

/* ---------- lite models ---------- */

class _ItemLite {
  final String id;
  final String name;
  final String unit;
  final int avail;

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

class _Line {
  final _ItemLite item;
  int qty;
  _Line({required this.item, required this.qty});
}

/* ---------- page ---------- */

class _IssueCreatePageState extends ConsumerState<IssueCreatePage> {
  final _formKey = GlobalKey<FormState>();

  // header fields
  final _reason = TextEditingController();
  final _remark = TextEditingController();

  // line editor
  _ItemLite? _selected;
  final _qtyCtrl = TextEditingController();

  // lines table
  final List<_Line> _lines = [];

  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    _remark.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  void _addLine() {
    final sel = _selected;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (sel == null) {
      _snack('Select item');
      return;
    }
    if (qty <= 0) {
      _snack('Qty must be > 0');
      return;
    }
    if (qty > sel.avail) {
      _snack('Qty cannot exceed available (${sel.avail})');
      return;
    }
    if (_lines.any((l) => l.item.id == sel.id)) {
      _snack('Item already in the table');
      return;
    }

    setState(() {
      _lines.add(_Line(item: sel, qty: qty));
      _selected = null;
      _qtyCtrl.clear();
    });
  }

  void _deleteLineAt(int i) {
    setState(() {
      _lines.removeAt(i);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty) {
      _snack('Add at least one item');
      return;
    }

    for (final l in _lines) {
      if (l.qty <= 0) {
        _snack('Each line must have qty > 0');
        return;
      }
      if (l.qty > l.item.avail) {
        _snack('Line "${l.item.name}" exceeds available (${l.item.avail})');
        return;
      }
    }

    final userId =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final body = {
      "userId": userId,
      "reason": _reason.text.trim(),
      "remark": _remark.text.trim(),
      "lines": [
        for (final l in _lines)
          {
            "itemid": l.item.id,
            "qty": l.qty,
            "unit": l.item.unit,
            "itemname": l.item.name,
          },
      ],
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .createItemIssue(itemIssueModel: body);
      if (!mounted) return;
      _snack(ok ? 'Issue created' : 'Create failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (mounted) _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(storeItemAllDataStreamProvider);

    return Scaffold(
      // light top app bar (GlassAppBar uses white icons/text – still OK on light)
      appBar: const GlassAppBar(
        title: Row(
          children: [
            Icon(Icons.upload_rounded, color: _ink900),
            SizedBox(width: 8),
            Text('Create Issue', style: TextStyle(color: _ink900)),
          ],
        ),
        // If your GlassAppBar forces white, switch to a normal AppBar instead.
      ),
      backgroundColor: const Color(0xFFFAF7EF), // warm page background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Container(
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _stroke),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashFactory: InkRipple.splashFactory,
                      highlightColor: _mint.withValues(alpha: .15),
                      splashColor: _mint.withValues(alpha: .20),
                      inputDecorationTheme: InputDecorationTheme(
                        filled: true,
                        fillColor: _surfaceAlt,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _stroke),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: _stroke),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: _ink900.withValues(alpha: .65),
                            width: 1.2,
                          ),
                        ),
                        prefixIconColor: _ink700,
                        hintStyle: const TextStyle(color: _ink700),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _title('Header'),
                        _textField(
                          controller: _reason,
                          label: 'Reason',
                          icon: Icons.flag_rounded,
                        ),
                        const SizedBox(height: 10),
                        _textField(
                          controller: _remark,
                          label: 'Remark',
                          icon: Icons.notes_rounded,
                        ),
                        const SizedBox(height: 16),

                        _title('Add Line'),
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
                            final all =
                                (docs as List)
                                    .map<_ItemLite>(_ItemLite.fromAny)
                                    .where((it) => it.avail > 0)
                                    .toList();

                            final selectedIds =
                                _lines.map((l) => l.item.id).toSet();
                            final available =
                                all
                                    .where((it) => !selectedIds.contains(it.id))
                                    .toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    // Item dropdown
                                    Expanded(
                                      flex: 3,
                                      child: _ItemDropdown(
                                        label: 'Item',
                                        items: available,
                                        value: _selected,
                                        onChanged:
                                            (v) =>
                                                setState(() => _selected = v),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Qty field
                                    SizedBox(
                                      width: 150,
                                      child: _qtyField(
                                        controller: _qtyCtrl,
                                        label: 'Qty (≤ avail)',
                                        icon: Icons.onetwothree_rounded,
                                        max: _selected?.avail,
                                        skipNullIfLinesExist: _lines.isNotEmpty,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    FilledButton.icon(
                                      onPressed: _addLine,
                                      icon: const Icon(Icons.add_rounded),
                                      label: const Text('Add'),
                                    ),
                                  ],
                                ),
                                if (_selected != null) ...[
                                  const SizedBox(height: 10),
                                  _InfoBar(item: _selected!),
                                ],
                              ],
                            );
                          },
                        ),

                        const SizedBox(height: 16),

                        _title('Lines'),
                        _LinesTable(lines: _lines, onDelete: _deleteLineAt),

                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: _busy ? null : _submit,
                          icon:
                              _busy
                                  ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.save_rounded),
                          label: Text(_busy ? 'Saving...' : 'Create'),
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

  /* ---------- small UI helpers ---------- */

  Widget _title(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
    ),
  );

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator:
              (v) =>
                  (required && (v?.trim().isEmpty ?? true)) ? 'Required' : null,
          decoration: InputDecoration(hintText: label, prefixIcon: Icon(icon)),
          style: const TextStyle(color: _ink900),
        ),
      ],
    );
  }

  Widget _qtyField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int? max,
    bool skipNullIfLinesExist = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            if (skipNullIfLinesExist && (v == null || v.trim().isEmpty)) {
              return null;
            }
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null) return 'Enter number';
            if (n <= 0) return 'Must be > 0';
            if (max != null && n > max) return '≤ $max';
            return null;
          },
          decoration: InputDecoration(
            hintText: 'Enter quantity',
            prefixIcon: Icon(icon),
          ),
          style: const TextStyle(color: _ink900),
        ),
      ],
    );
  }
}

/* ---------- widgets: dropdown, infobar, table ---------- */

class _ItemDropdown extends StatelessWidget {
  const _ItemDropdown({
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  final String label;
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
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<_ItemLite>(
          initialValue: safeValue,
          items: [
            for (final it in items)
              DropdownMenuItem<_ItemLite>(
                value: it,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      it.name,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${it.unit}',
                      style: const TextStyle(color: _ink700),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(Avail: ${it.avail})',
                      style: const TextStyle(color: _ink700),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: onChanged,
          dropdownColor: _surface,
          style: const TextStyle(color: _ink900),
          iconEnabledColor: _ink700,
          decoration: const InputDecoration(
            // hint: Text('Select item', style: TextStyle(color: _ink700)),
            prefixIcon: Icon(Icons.inventory_2_rounded),
            prefixIconColor: _ink700, // optional: make icon dark too
          ),
        ),
      ],
    );
  }
}

class _InfoBar extends StatelessWidget {
  const _InfoBar({required this.item});
  final _ItemLite item;

  @override
  Widget build(BuildContext context) {
    Widget pill(String k, String v) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$k: ',
            style: const TextStyle(color: _ink700, fontWeight: FontWeight.w600),
          ),
          Text(
            v,
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );

    return Row(
      children: [
        pill('Unit', item.unit),
        const SizedBox(width: 8),
        pill('Available', '${item.avail}'),
      ],
    );
  }
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines, required this.onDelete});
  final List<_Line> lines;
  final void Function(int index) onDelete;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _stroke),
        ),
        child: const Center(
          child: Text('No items added yet', style: TextStyle(color: _ink700)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          // header
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
                Expanded(
                  flex: 2,
                  child: Text(
                    'Avail',
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

          // rows
          for (int i = 0; i < lines.length; i++)
            _LineRow(line: lines[i], onDelete: () => onDelete(i)),
        ],
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.line, required this.onDelete});
  final _Line line;
  final VoidCallback onDelete;

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
          Expanded(
            flex: 2,
            child: Text(
              '${line.item.avail}',
              style: const TextStyle(color: _ink700),
            ),
          ),
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
