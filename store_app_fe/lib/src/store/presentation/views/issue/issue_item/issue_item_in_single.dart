import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../../controllers/store_item_controller.dart';
import '../../../../controllers/store_item_issue_controller.dart';
import '../../../../domains/models/store_item_model.dart';

/* ---------- light palette ---------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _mint = Color(0xFFB6D3CC);

class IssueCreateOneItemPage extends ConsumerStatefulWidget {
  const IssueCreateOneItemPage({super.key, required this.itemId});
  final String itemId;

  @override
  ConsumerState<IssueCreateOneItemPage> createState() =>
      _IssueCreateOneItemPageState();
}

class _IssueCreateOneItemPageState
    extends ConsumerState<IssueCreateOneItemPage> {
  final _formKey = GlobalKey<FormState>();

  final _reason = TextEditingController();
  final _remark = TextEditingController();
  final _qtyCtrl = TextEditingController();

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

  Future<void> _submit(StoreItem item) async {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      _snack('Quantity must be > 0');
      return;
    }
    if (qty > item.stockAvailableQuantity) {
      _snack(
        'Quantity cannot exceed available (${item.stockAvailableQuantity})',
      );
      return;
    }

    final userId =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final body = {
      "userId": userId,
      "reason": _reason.text.trim(),
      "remark": _remark.text.trim(),
      "lines": [
        {
          "itemid": item.id,
          "qty": qty,
          "unit": item.unit,
          "itemname": item.name,
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
    final itemAsync = ref.watch(storeItemOneDataStreamProvider(widget.itemId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const GlassAppBarLightPill(
        title: Row(
          children: [
            Icon(Icons.upload_rounded),
            SizedBox(width: 8),
            Text('Issue Item'),
          ],
        ),
      ),

      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: _surfaceAlt),
          SafeArea(
            child: itemAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text('Error: $e', style: TextStyle(color: _ink700)),
                  ),
              data: (item) {
                if (item == null) {
                  return const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 26),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
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
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    _pill('Unit', item.unit),
                                    const SizedBox(width: 8),
                                    _pill(
                                      'Available',
                                      '${item.stockAvailableQuantity}',
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                _fieldLabel('Reason (optional)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _reason,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter reason',
                                    prefixIcon: Icon(Icons.flag_rounded),
                                  ),
                                  style: const TextStyle(color: _ink900),
                                ),
                                const SizedBox(height: 10),

                                _fieldLabel('Remark (optional)'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _remark,
                                  decoration: const InputDecoration(
                                    hintText: 'Enter remark',
                                    prefixIcon: Icon(Icons.notes_rounded),
                                  ),
                                  style: const TextStyle(color: _ink900),
                                ),
                                const SizedBox(height: 16),

                                _fieldLabel('Quantity'),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (v) {
                                    final n = int.tryParse(v?.trim() ?? '');
                                    if (n == null) return 'Enter number';
                                    if (n <= 0) return 'Must be > 0';
                                    if (n > item.stockAvailableQuantity) {
                                      return 'Must be ≤ ${item.stockAvailableQuantity}';
                                    }
                                    return null;
                                  },
                                  decoration: const InputDecoration(
                                    hintText: 'Enter quantity',
                                    prefixIcon: Icon(Icons.onetwothree_rounded),
                                  ),
                                  style: const TextStyle(color: _ink900),
                                ),

                                const SizedBox(height: 18),
                                FilledButton.icon(
                                  onPressed: _busy ? null : () => _submit(item),
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
                                  label: Text(
                                    _busy ? 'Saving...' : 'Create Issue',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(String k, String v) => Container(
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

  Widget _fieldLabel(String label) => Text(
    label,
    style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
  );
}

/// --- Pill Glass App Bar (light) ---
/// Usage:
/// appBar: const GlassAppBarLightPill(
///   title: Row(
///     children: [Icon(Icons.upload_rounded), SizedBox(width: 8), Text('Issue Item')],
///   ),
/// ),
class GlassAppBarLightPill extends StatelessWidget
    implements PreferredSizeWidget {
  const GlassAppBarLightPill({
    super.key,
    required this.title,
    this.actions,
    this.onBack,
    this.height = 64,
    this.radius = 16,
    this.blurSigma = 18,
  });

  final Widget title;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final double height;
  final double radius;
  final double blurSigma;

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final double top = MediaQuery.of(context).padding.top;

    Widget circle(Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _surface.withValues(alpha: .92),
        border: Border.all(color: _stroke.withValues(alpha: .7)),
      ),
      child: child,
    );

    return Padding(
      // status bar + gutters to show the rounded pill
      padding: EdgeInsets.fromLTRB(12, top + 8, 12, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: .88),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: _stroke),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000), // soft
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              height: height - 8,
              child: Row(
                children: [
                  const SizedBox(width: 6),
                  // back
                  circle(
                    Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onBack ?? () => Navigator.maybePop(context),
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: _ink900,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // title enforces dark ink style
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        letterSpacing: .1,
                      ),
                      child: IconTheme(
                        data: const IconThemeData(color: _ink900),
                        child: title,
                      ),
                    ),
                  ),

                  // optional actions
                  if (actions != null && actions!.isNotEmpty) ...[
                    for (final a in actions!) ...[
                      const SizedBox(width: 4),
                      circle(
                        Padding(padding: const EdgeInsets.all(2), child: a),
                      ),
                    ],
                    const SizedBox(width: 6),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
