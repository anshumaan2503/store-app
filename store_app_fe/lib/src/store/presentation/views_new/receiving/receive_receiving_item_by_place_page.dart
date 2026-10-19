// lib/features/store_items/views/receive/receive_to_place_by_place_select_receiving.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/store_place_controller.dart';
// <- kept for your project deps, not used here
// not used (we use light AppBar)

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
 * Typo helpers + light card
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
  }) : border = true, margin = null;
  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final bool border;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
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

/* ───────────────────────────────────────────────────────────
 * Page
 *  - Uses your existing providers / models:
 *    receivingOpenListStreamProvider, itemReceiveControllerProvider,
 *    ReceivingLite, ReceivingLineLite (imported via your controller exports).
 * ─────────────────────────────────────────────────────────── */
class ReceiveToPlaceByPlaceSelectReceiving extends ConsumerStatefulWidget {
  const ReceiveToPlaceByPlaceSelectReceiving({
    super.key,
    required this.placeId,
  });
  final String placeId;

  @override
  ConsumerState<ReceiveToPlaceByPlaceSelectReceiving> createState() =>
      _ReceiveToPlaceByPlaceSelectReceivingState();
}

class _ReceiveToPlaceByPlaceSelectReceivingState
    extends ConsumerState<ReceiveToPlaceByPlaceSelectReceiving> {
  ReceivingLite? _selReceiving;
  ReceivingLineLite? _selLine;

  final _receiveQtyCtrl = TextEditingController();
  final _scrapQtyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _receiveQtyCtrl.dispose();
    _scrapQtyCtrl.dispose();
    super.dispose();
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  int get _remainingSelected => _selLine?.remaining ?? 0;

  Future<void> _submit() async {
    final rec = _selReceiving;
    final line = _selLine;
    final placeId = widget.placeId.trim();

    final receiveQty =
        int.tryParse(
          _receiveQtyCtrl.text.trim().isEmpty
              ? '0'
              : _receiveQtyCtrl.text.trim(),
        ) ??
        0;
    final scrapQty =
        int.tryParse(
          _scrapQtyCtrl.text.trim().isEmpty ? '0' : _scrapQtyCtrl.text.trim(),
        ) ??
        0;

    // validations
    if (rec == null) {
      _toast('Select a receiving');
      return;
    }
    if (line == null) {
      _toast('Select an item');
      return;
    }
    if (placeId.isEmpty) {
      _toast('Place is missing');
      return;
    }
    if (receiveQty < 0 || scrapQty < 0) {
      _toast('Quantities must be ≥ 0');
      return;
    }
    final totalIn = receiveQty + scrapQty;
    if (totalIn <= 0) {
      _toast('Enter at least one positive quantity');
      return;
    }
    final rem = _remainingSelected;
    if (totalIn > rem) {
      _toast('Total (receive + scrap) cannot exceed remaining ($rem)');
      return;
    }

    final payload = {
      "itemid": line.itemId,
      "placeId": placeId,
      "receiveId": rec.id,
      "quantity": receiveQty,
      "scrapQuantity": scrapQty,
    };

    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(itemReceiveControllerProvider)
          .itemReceiveToPlace(itemReceiveToPlace: payload);
      if (!mounted) return;
      _toast(ok ? 'Saved' : 'Failed');
      if (ok) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _toast('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final receivingsAsync = ref.watch(receivingOpenListStreamProvider);

    // Keep selected line if still present after list refresh.
    final ReceivingLineLite? safeLine =
        (_selLine != null &&
                _selReceiving != null &&
                _selReceiving!.lines.any((l) => l.itemId == _selLine!.itemId))
            ? _selReceiving!.lines.firstWhere(
              (l) => l.itemId == _selLine!.itemId,
            )
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
          children: const [
            Icon(Icons.inventory_2_rounded, color: _ink900),
            SizedBox(width: 8),
            Text(
              'Receive to Place',
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
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: receivingsAsync.when(
                    loading:
                        () => const Padding(
                          padding: EdgeInsets.all(8),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                    error: (e, _) => Text('Error: $e', style: _muted()),
                    data: (receivings) {
                      if (receivings.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Receivings', style: _title(context)),
                            const SizedBox(height: 8),
                            _Card(
                              radius: 12,
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.inbox_outlined,
                                    color: _ink700,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'No open receivings found',
                                    style: _muted(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }

                      final ReceivingLite? safeRec =
                          (_selReceiving != null &&
                                  receivings.any(
                                    (r) => r.id == _selReceiving!.id,
                                  ))
                              ? receivings.firstWhere(
                                (r) => r.id == _selReceiving!.id,
                              )
                              : null;

                      if (safeRec == null && _selReceiving != null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _selReceiving = null;
                            _selLine = null;
                            _receiveQtyCtrl.clear();
                            _scrapQtyCtrl.clear();
                          });
                        });
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Target Place', style: _title(context)),
                          const SizedBox(height: 6),
                          _ReadonlyField(value: widget.placeId),
                          const SizedBox(height: 16),

                          Text('1) Select Receiving', style: _title(context)),
                          const SizedBox(height: 6),
                          _LightDropdown<ReceivingLite>(
                            value: safeRec,
                            hint: 'Select receiving',
                            icon: Icons.local_shipping,
                            items: [
                              for (final r in receivings)
                                DropdownMenuItem(
                                  value: r,
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.local_shipping,
                                        size: 18,
                                        color: _ink700,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${r.recNo} • ${r.source}',
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(${r.lines.length} items)',
                                        style: _muted(11),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged:
                                (v) => setState(() {
                                  _selReceiving = v;
                                  _selLine = null;
                                  _receiveQtyCtrl.clear();
                                  _scrapQtyCtrl.clear();
                                }),
                          ),

                          const SizedBox(height: 16),
                          Text(
                            '2) Select Item from Receiving',
                            style: _title(context),
                          ),
                          const SizedBox(height: 6),
                          _LightDropdown<ReceivingLineLite>(
                            value: safeLine,
                            hint: 'Select item',
                            icon: Icons.inventory_2_rounded,
                            items: [
                              for (final l
                                  in (_selReceiving?.lines ??
                                      const <ReceivingLineLite>[]))
                                DropdownMenuItem(
                                  value: l,
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
                                          l.itemName.isEmpty
                                              ? l.itemId
                                              : l.itemName,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _ink900,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '(Remain: ${l.remaining})',
                                        style: _muted(11),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged:
                                (v) => setState(() {
                                  _selLine = v;
                                  _receiveQtyCtrl.clear();
                                  _scrapQtyCtrl.clear();
                                }),
                          ),
                          if (safeLine != null) ...[
                            const SizedBox(height: 8),
                            _Pill(
                              label: 'Remaining',
                              value: '${safeLine.remaining} ${safeLine.unit}',
                            ),
                          ],

                          const SizedBox(height: 18),
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
                          const SizedBox(height: 20),

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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
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
 * UI atoms (light variants)
 * ─────────────────────────────────────────────────────────── */

class _ReadonlyField extends StatelessWidget {
  const _ReadonlyField({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: TextFormField(
        readOnly: true,
        initialValue: value,
        style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          filled: true,
          fillColor: _surfaceAlt.withValues(alpha: .5),
          hintStyle: const TextStyle(color: _ink600),
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
    );
  }
}

class _LightDropdown<T> extends StatelessWidget {
  const _LightDropdown({
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
      isExpanded: true,
      items: items,
      onChanged: onChanged,
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
