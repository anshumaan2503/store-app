// lib/features/store/pages/issue_to_place_by_item_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../controllers/store_item_issue_controller.dart';
import '../../../../controllers/store_place_controller.dart';
import 'issue_lite.dart';

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

class IssueToPlaceByItemPage extends ConsumerStatefulWidget {
  const IssueToPlaceByItemPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<IssueToPlaceByItemPage> createState() =>
      _IssueToPlaceByItemPageState();
}

class _PlaceLite {
  final String id;
  final String name;
  final int availableHere; // total - IssuedQuantity - completedQuantity
  const _PlaceLite({
    required this.id,
    required this.name,
    required this.availableHere,
  });
}

class _IssueToPlaceByItemPageState
    extends ConsumerState<IssueToPlaceByItemPage> {
  IssueLite? _selectedIssue;
  _PlaceLite? _selectedPlace;
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
    final it = widget.itemId;
    final iss = _selectedIssue;
    final pl = _selectedPlace;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;

    if (iss == null) return _toast('Select issue');
    if (pl == null) return _toast('Select place');
    if (qty <= 0) return _toast('Quantity must be > 0');
    if (qty > iss.remaining) {
      return _toast('Cannot exceed issue remaining (${iss.remaining})');
    }
    if (qty > pl.availableHere) {
      return _toast('Place has only ${pl.availableHere} available');
    }

    final payload = {
      'itemid': it,
      'placeId': pl.id,
      'issueId': iss.id,
      'quantity': qty,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemIssueControllerProvider)
          .itemIssueToPlace(itemIssueToPlace: payload);
      if (!mounted) return;
      _toast(ok ? 'Issued to place' : 'Issue failed');
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final issuesAsync = ref.watch(
      itemIssuesByItemStreamProvider(widget.itemId),
    );
    final spiqAsync = ref.watch(storePlaceQuantityAllDataStreamProvider);

    final canSubmit =
        !_busy && _selectedIssue != null && _selectedPlace != null;

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
            Icon(Icons.call_split_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Issue Item To Place',
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
                constraints: const BoxConstraints(maxWidth: 760),
                child: _Card(
                  radius: 20,
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Header(),
                      const SizedBox(height: 18),

                      // Issues dropdown
                      issuesAsync.when(
                        loading:
                            () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: LinearProgressIndicator(minHeight: 2),
                            ),
                        error:
                            (e, _) => _InfoBanner(
                              title: 'Failed to load issues',
                              message: '$e',
                            ),
                        data: (list) {
                          final items = list; // List<IssueLite>

                          final safeValue =
                              (_selectedIssue != null &&
                                      items.any(
                                        (x) => x.id == _selectedIssue!.id,
                                      ))
                                  ? items.firstWhere(
                                    (x) => x.id == _selectedIssue!.id,
                                  )
                                  : null;

                          return _DropdownField<IssueLite>(
                            label: 'Issue *',
                            hint: 'Select an approved issue',
                            icon: Icons.upload_rounded,
                            value: safeValue,
                            items: items,
                            itemLabel:
                                (it) =>
                                    '${it.issNo}  (Approved issued items: ${it.remaining})',
                            onChanged: (v) {
                              setState(() {
                                _selectedIssue = v;
                                _selectedPlace = null;
                                _qtyCtrl.clear();
                              });
                            },
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // Places dropdown (availability from SPIQ)
                      spiqAsync.when(
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
                        data: (raw) {
                          final itemId = widget.itemId;
                          final spiq = (raw as List).cast<dynamic>();

                          final placeOpts = <_PlaceLite>[];
                          for (final d in spiq) {
                            final m = d as Map<String, dynamic>;
                            final mid = (m['itemId'] ?? '').toString();
                            if (mid != itemId) continue;

                            final placeId = (m['placeId'] ?? '').toString();
                            if (placeId.isEmpty) continue;

                            final placeName = (m['placeName'] ?? '').toString();

                            final total = _toInt(m['totalQuantity']);
                            final issued = _toInt(m['IssuedQuantity']);
                            final completed = _toInt(m['completedQuantity']);
                            final availableHere = total - issued - completed;

                            if (availableHere <= 0) continue;

                            placeOpts.add(
                              _PlaceLite(
                                id: placeId,
                                name: placeName.isEmpty ? placeId : placeName,
                                availableHere: availableHere,
                              ),
                            );
                          }

                          final safeValue =
                              (_selectedPlace != null &&
                                      placeOpts.any(
                                        (p) => p.id == _selectedPlace!.id,
                                      ))
                                  ? placeOpts.firstWhere(
                                    (p) => p.id == _selectedPlace!.id,
                                  )
                                  : null;

                          return _DropdownField<_PlaceLite>(
                            label: 'Place *',
                            hint:
                                (_selectedIssue == null)
                                    ? 'Select issue first'
                                    : 'Select place',
                            icon: Icons.place_rounded,
                            value: safeValue,
                            items: placeOpts,
                            itemLabel:
                                (p) =>
                                    '${p.name}  (Avail here: ${p.availableHere})',
                            onChanged:
                                (_selectedIssue == null)
                                    ? null
                                    : (v) {
                                      setState(() {
                                        _selectedPlace = v;
                                        _qtyCtrl.clear();
                                      });
                                    },
                          );
                        },
                      ),

                      const SizedBox(height: 14),

                      // Quantity
                      _TextField(
                        controller: _qtyCtrl,
                        label: 'Quantity *',
                        hint: 'Enter quantity',
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
                                : Icons.remove_done_rounded,
                        label: _busy ? 'Issuing...' : 'Issue',
                        busy: _busy,
                        onTap:
                            (canSubmit || _busy)
                                ? (_busy ? null : _submit)
                                : null,
                      ),

                      if (!canSubmit && !_busy) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Select issue, place, and enter valid quantity to enable Issue.',
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

  static int _toInt(dynamic v) {
    if (v is int) return v;
    return int.tryParse('$v') ?? 0;
  }
}

/* ---------------- Supporting Widgets ---------------- */

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
  const _Header();

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
          child: const Icon(Icons.call_split_rounded, color: _ink900),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Issue Item To Place',
            style: TextStyle(
              color: _ink900,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
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
