// lib/src/store/presentation/views/issue/issue_return_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../controllers/store_item_issue_controller.dart';

// places
import '../../../controllers/store_place_controller.dart'
    show storePlaceAllDataStreamProvider;

// typed model (optional)
import '../../../domains/models/store_place_model.dart' show StorePlace;

/* ---------------- Palette (same as your theme example) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

/* ---------------- Page ---------------- */

class IssueReturnPage extends ConsumerStatefulWidget {
  const IssueReturnPage({super.key, required this.issueDoc});
  final Map<String, dynamic> issueDoc; // Pass the full CLOSED issue doc

  @override
  ConsumerState<IssueReturnPage> createState() => _IssueReturnPageState();
}

class _ItemLite {
  final String id;
  final String name;
  final int returnable; // issued - returned
  const _ItemLite({
    required this.id,
    required this.name,
    required this.returnable,
  });
}

class _PlaceLite {
  final String id;
  final String name;
  const _PlaceLite({required this.id, required this.name});
}

class _IssueReturnPageState extends ConsumerState<IssueReturnPage> {
  _ItemLite? _selectedItem;
  _PlaceLite? _selectedPlace;

  final _qtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  List<_ItemLite> _buildReturnableItems(Map<String, dynamic> doc) {
    final lines = (doc['lines'] as List?) ?? const [];
    final out = <_ItemLite>[];

    for (final raw in lines) {
      final l = raw as Map<String, dynamic>;
      final iid = (l['itemId'] ?? '').toString();
      final name = (l['itemName'] ?? '').toString();

      final issued =
          (l['issuedQty'] is int)
              ? l['issuedQty'] as int
              : int.tryParse('${l['issuedQty']}') ?? 0;

      final returned =
          (l['returnedQty'] is int)
              ? l['returnedQty'] as int
              : int.tryParse('${l['returnedQty']}') ?? 0;

      final ret = issued - returned;
      if (ret > 0) {
        out.add(
          _ItemLite(id: iid, name: name.isEmpty ? iid : name, returnable: ret),
        );
      }
    }

    return out;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (_selectedItem == null) {
      _toast('Select item');
      return;
    }
    if (_selectedPlace == null) {
      _toast('Select place');
      return;
    }

    final n = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (n <= 0) {
      _toast('Quantity must be > 0');
      return;
    }
    if (n > _selectedItem!.returnable) {
      _toast('Cannot return beyond issued (${_selectedItem!.returnable})');
      return;
    }

    final userId =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final body = {
      "userId": userId,
      "itemid": _selectedItem!.id,
      "placeId": _selectedPlace!.id,
      "issueId": (widget.issueDoc['_id'] ?? '').toString(),
      "quantity": n,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .returnItemIssue(returnItemIssue: body);

      if (!mounted) return;
      _toast(ok ? 'Returned to stock' : 'Return failed');
      if (ok) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final doc = widget.issueDoc;
    final issNo = (doc['issNo'] ?? '').toString();

    final items = _buildReturnableItems(doc);
    final placesAsync = ref.watch(storePlaceAllDataStreamProvider);

    final canSubmit =
        !_busy &&
        items.isNotEmpty &&
        _selectedItem != null &&
        _selectedPlace != null;

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
          children: const [
            Icon(Icons.undo_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Return To Stock',
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
                constraints: const BoxConstraints(maxWidth: 720),
                child: _Card(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(issNo: issNo),
                      const SizedBox(height: 18),

                      if (items.isEmpty) ...[
                        const _InfoBanner(
                          title: 'Nothing to return',
                          message:
                              'All lines in this issue are already fully returned, or issued quantity is zero.',
                        ),
                        const SizedBox(height: 18),
                      ],

                      // Item
                      _DropdownField<_ItemLite>(
                        label: 'Item *',
                        hint: 'Select item',
                        icon: Icons.inventory_2_rounded,
                        value:
                            (_selectedItem != null &&
                                    items.any((x) => x.id == _selectedItem!.id))
                                ? items.firstWhere(
                                  (x) => x.id == _selectedItem!.id,
                                )
                                : null,
                        items: items,
                        itemLabel:
                            (it) =>
                                '${it.name}  (Returnable: ${it.returnable})',
                        onChanged:
                            items.isEmpty
                                ? null
                                : (v) {
                                  setState(() {
                                    _selectedItem = v;
                                    _qtyCtrl.clear();
                                  });
                                },
                      ),

                      const SizedBox(height: 14),

                      // Place
                      placesAsync.when(
                        loading:
                            () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        error:
                            (e, _) => _InfoBanner(
                              title: 'Failed to load places',
                              message: '$e',
                            ),
                        data: (places) {
                          final opts =
                              (places as List).map<_PlaceLite>((p) {
                                if (p is StorePlace) {
                                  return _PlaceLite(
                                    id: p.id.toString(),
                                    name: p.name,
                                  );
                                }
                                final m = p as Map<String, dynamic>;
                                return _PlaceLite(
                                  id: (m['_id'] ?? m['id']).toString(),
                                  name: (m['name'] ?? '').toString(),
                                );
                              }).toList();

                          return _DropdownField<_PlaceLite>(
                            label: 'Place *',
                            hint: 'Select place',
                            icon: Icons.place_rounded,
                            value:
                                (_selectedPlace != null &&
                                        opts.any(
                                          (x) => x.id == _selectedPlace!.id,
                                        ))
                                    ? opts.firstWhere(
                                      (x) => x.id == _selectedPlace!.id,
                                    )
                                    : null,
                            items: opts,
                            itemLabel: (pl) => pl.name,
                            onChanged:
                                (v) => setState(() => _selectedPlace = v),
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // Quantity
                      _TextField(
                        controller: _qtyCtrl,
                        label: 'Quantity *',
                        hint:
                            _selectedItem == null
                                ? 'Enter quantity'
                                : 'Max: ${_selectedItem!.returnable}',
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),

                      const SizedBox(height: 22),

                      _PrimaryBtn(
                        icon:
                            _busy
                                ? Icons.hourglass_empty_rounded
                                : Icons.undo_rounded,
                        label: _busy ? 'Returning...' : 'Return',
                        busy: _busy,
                        onTap:
                            (canSubmit || _busy)
                                ? (_busy ? null : _submit)
                                : null,
                      ),

                      if (!canSubmit && !_busy) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Select item, place, and enter valid quantity to enable Return.',
                          style: TextStyle(
                            color: _ink700,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
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

/* ---------------- Supporting Widgets (same design language) ---------------- */

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
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.issNo});
  final String issNo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _accentMint,
          ),
          child: const Icon(Icons.undo_rounded, color: _ink900),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Return To Stock',
                style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Issue #$issNo',
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfaceAlt.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: _ink700),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w600,
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _ink600),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.5),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.hint,
    required this.icon,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.value,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T?>? onChanged;
  final T? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (final it in items)
              DropdownMenuItem<T>(
                value: it,
                child: Text(
                  itemLabel(it),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
          onChanged: onChanged,
          dropdownColor: _surface,
          iconEnabledColor: _ink700,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(
              color: _ink600,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(icon, color: _ink600),
            filled: true,
            fillColor: _surfaceAlt.withValues(alpha: 0.5),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
          ),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        ),
      ],
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
    final disabled = onTap == null;

    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Material(
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
      ),
    );
  }
}
