import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/widgets/app_bar_page.dart'; // GlassAppBar
import '../../../controllers/store_item_issue_controller.dart';
import '../../widgets/glass_widget.dart';

// Providers you already have
import '../../../controllers/store_item_controller.dart'
    show storeItemAllDataStreamProvider; // Stream<List<StoreItem or Map>>

// If you have a typed StoreItem model
import '../../../domains/models/store_item_model.dart' show StoreItem;

class IssueEditPage extends ConsumerStatefulWidget {
  const IssueEditPage({super.key, required this.issue});
  final Map<String, dynamic> issue;

  @override
  ConsumerState<IssueEditPage> createState() => _IssueEditPageState();
}

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
    if (d is StoreItem) {
      return _ItemLite(
        id: (d.id).toString(),
        name: d.name,
        unit: d.unit,
        avail: d.stockAvailableQuantity,
      );
    }
    final m = d as Map<String, dynamic>;
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

class _IssueEditPageState extends ConsumerState<IssueEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  _ItemLite? _selected;

  final List<_Line> _lines = [];
  bool _submitting = false;

  String get _id => (widget.issue['_id'] ?? '').toString();
  String get _status => (widget.issue['status'] ?? '').toString();
  bool get _isDraft => _status == 'DRAFT';

  @override
  void initState() {
    super.initState();
    _reasonCtrl.text = (widget.issue['reason'] ?? '').toString();
    final rawLines = (widget.issue['lines'] as List?) ?? const [];
    for (final l in rawLines) {
      final m = (l as Map<String, dynamic>);
      final iid = (m['itemId'] ?? '').toString();
      final q = int.tryParse('${m['requestedQty'] ?? m['issueqty'] ?? 0}') ?? 0;
      _lines.add(
        _Line(
          item: _ItemLite(id: iid, name: '(loading...)', unit: '', avail: 0),
          qty: q,
        ),
      );
    }
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  void _hydrateLines(List<_ItemLite> all) {
    final byId = {for (final i in all) i.id: i};
    bool changed = false;
    for (int i = 0; i < _lines.length; i++) {
      final cur = _lines[i];
      if (cur.item.name == '(loading...)') {
        final real = byId[cur.item.id];
        if (real != null) {
          _lines[i] = _Line(item: real, qty: cur.qty);
          changed = true;
        }
      }
    }
    if (changed && mounted) setState(() {});
  }

  Map<String, dynamic> _payload() {
    return {
      "id": _id,
      "reason": _reasonCtrl.text.trim(),
      "lines": [
        for (final l in _lines)
          {"itemid": l.item.id, "itemname": l.item.name, "issueqty": l.qty},
      ],
    };
  }

  Future<void> _submit() async {
    if (!_isDraft) return;
    if (!_formKey.currentState!.validate()) return;

    if (_lines.isEmpty || _lines.any((l) => l.qty <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item with qty > 0')),
      );
      return;
    }

    // print(_payload());

    setState(() => _submitting = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .updateItemIssue(itemIssueModel: _payload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ok ? 'Issue updated' : 'Update failed')),
      );
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _addSelected() {
    if (!_isDraft) return;
    final sel = _selected;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (sel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an item')));
      return;
    }
    if (qty <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quantity must be > 0')));
      return;
    }
    if (_lines.any((l) => l.item.id == sel.id)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item already in list')));
      return;
    }

    setState(() {
      _lines.add(_Line(item: sel, qty: qty));
      _selected = null;
      _qtyCtrl.clear();
    });
  }

  void _removeAt(int i) {
    if (!_isDraft) return;
    setState(() => _lines.removeAt(i));
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(storeItemAllDataStreamProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Text('Edit Issue • ${widget.issue['issNo'] ?? ''}'),
          ],
        ),
        actions: [
          if (!_isDraft)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'READ ONLY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/login_bg.png', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: .10)),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Glass(
                    radius: 22,
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Header',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _textField(
                            _reasonCtrl,
                            'Reason',
                            Icons.notes_rounded,
                            req: true,
                            enabled: _isDraft,
                          ),
                          const SizedBox(height: 16),

                          const Text(
                            'Lines',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),

                          itemsAsync.when(
                            loading:
                                () => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                            error:
                                (e, _) => Text(
                                  'Error: $e',
                                  style: const TextStyle(color: Colors.white),
                                ),
                            data: (docs) {
                              final all =
                                  (docs as List)
                                      .map<_ItemLite>(_ItemLite.fromAny)
                                      .where((e) => e.id.isNotEmpty)
                                      .toList();

                              _hydrateLines(all);

                              final chosen =
                                  _lines.map((l) => l.item.id).toSet();
                              final available =
                                  all
                                      .where((x) => !chosen.contains(x.id))
                                      .toList();

                              return Column(
                                children: [
                                  if (_isDraft)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _ItemDropdown(
                                            items: available,
                                            value: _selected,
                                            onChanged:
                                                (v) => setState(
                                                  () => _selected = v,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        SizedBox(
                                          width: 140,
                                          child: _numField(
                                            _qtyCtrl,
                                            'Qty',
                                            Icons.numbers_rounded,
                                            min: 1,
                                            // ✅ Skip the “Enter number” check when table already has items
                                            skipNullIfLinesExist:
                                                _lines.isNotEmpty,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        FilledButton.icon(
                                          onPressed: _addSelected,
                                          icon: const Icon(Icons.add_rounded),
                                          label: const Text('Add'),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 12),
                                  _IssueLinesTableEditable(
                                    lines: _lines,
                                    onDelete: _isDraft ? _removeAt : null,
                                  ),
                                ],
                              );
                            },
                          ),

                          const SizedBox(height: 18),
                          FilledButton.icon(
                            onPressed:
                                _isDraft && !_submitting ? _submit : null,
                            icon:
                                _submitting
                                    ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(Icons.save_rounded),
                            label: Text(
                              _submitting
                                  ? 'Saving...'
                                  : _isDraft
                                  ? 'Save Changes'
                                  : 'Locked',
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
        ],
      ),
    );
  }

  Widget _textField(
    TextEditingController c,
    String label,
    IconData icon, {
    bool req = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .9),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          enabled: enabled,
          validator:
              (v) => (req && (v?.trim().isEmpty ?? true)) ? 'Required' : null,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white),
            filled: true,
            fillColor: Colors.white.withValues(alpha: enabled ? .10 : .06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _numField(
    TextEditingController c,
    String label,
    IconData icon, {
    int min = 0,
    bool skipNullIfLinesExist = false, // <-- NEW
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: .9),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: c,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) {
            // ✅ If table already has at least one item, don't block on empty input
            if (skipNullIfLinesExist && (v == null || v.trim().isEmpty)) {
              return null;
            }
            final n = int.tryParse(v?.trim() ?? '');
            if (n == null) return 'Enter number';
            if (n < min) return 'Min $min';
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white),
            filled: true,
            fillColor: Colors.white.withValues(alpha: .10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(color: Colors.white),
        ),
      ],
    );
  }
}

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
    final safeValue =
        (value != null && items.any((e) => e.id == value!.id))
            ? items.firstWhere((e) => e.id == value!.id)
            : null;

    return DropdownButtonFormField<_ItemLite>(
      initialValue: safeValue,
      dropdownColor: const Color(0xFF1F2544),
      decoration: InputDecoration(
        hintText: 'Select item',
        prefixIcon: const Icon(Icons.inventory_2_rounded, color: Colors.white),
        filled: true,
        fillColor: Colors.white.withValues(alpha: .10),
        hintStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      items: [
        for (final it in items)
          DropdownMenuItem(
            value: it,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  it.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text('• ${it.unit}'),
                const SizedBox(width: 8),
                Text('(Avail: ${it.avail})'),
              ],
            ),
          ),
      ],
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
    );
  }
}

class _IssueLinesTableEditable extends StatelessWidget {
  const _IssueLinesTableEditable({required this.lines, required this.onDelete});
  final List<_Line> lines;
  final void Function(int index)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: const Center(
          child: Text(
            'No items added yet',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: .18)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: .14)),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    'Item',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Qty',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                SizedBox(width: 36),
              ],
            ),
          ),
          for (int i = 0; i < lines.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: .08)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      lines[i].item.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${lines[i].qty}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (onDelete != null)
                    IconButton(
                      onPressed: () => onDelete!(i),
                      tooltip: 'Remove',
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
