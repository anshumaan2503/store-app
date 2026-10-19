import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../auth/shared/repositories/shared_preference_repository.dart';
import 'package:store_app/src/components/motion_widgets.dart';
import '../../../../components/utils.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/guided_tour_controller.dart';
import '../../../controllers/store_item_issue_controller.dart';
import '../../../controllers/store_items_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../cart/store_cart_page.dart';

/* ---------------- Palette (your theme) ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

const _accentMint = Color(0xFFB6D3CC);
const _accentBlue = Color(0xFFB7E6FF);

const _shadow = [
  BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
];

/* -----------------------------------------------------------------------------
  IMPORTANT:
  Your backend should:
    - socket.on  : 'store:itemsubcategory'
    - socket.emit: 'store:itemsubcategory'
    - gateway should client.emit('store:itemsubcategory', rows)

  This provider waits for the first response and then closes.
  It DOES NOT push an immediate empty list (so Riverpod stays "loading"
  until real data arrives or timeout triggers).
----------------------------------------------------------------------------- */

/* ---------------- Page ---------------- */

class IssueCreatePage extends ConsumerStatefulWidget {
  const IssueCreatePage({super.key});

  @override
  ConsumerState<IssueCreatePage> createState() => _IssueCreatePageState();
}

class _IssueCreatePageState extends ConsumerState<IssueCreatePage> {
  // 0: select base item (cards)
  // 1: create form (dropdown + lines)
  int _step = 0;

  bool _busy = false;

  // Step 0
  String _itemSearch = '';
  StoreItemsModel? _baseItem;

  // Step 1
  bool _subLoading = false;
  List<StoreItemsModel> _subItems = [];
  String? _lineItemId;

  final _qtyCtrl = TextEditingController(text: '1');
  final _reasonCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();

  final List<_IssueLineDraft> _lines = [];

  ProviderSubscription<AsyncValue<List<StoreItemsModel>>>? _subcatSub;
  String? _subcatForItemId;
  String? _autoAddedForBaseId; // to avoid duplicate auto-add

  @override
  void dispose() {
    _subcatSub?.close();
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    _remarkCtrl.dispose();
    super.dispose();
  }

  int _asInt(String s, int fallback) => int.tryParse(s.trim()) ?? fallback;

  StoreItemsModel? _findById(List<StoreItemsModel> list, String? id) {
    if (id == null) return null;
    for (final x in list) {
      if (x.id == id) return x;
    }
    return null;
  }

  void _subscribeSubcategory(String baseItemId) {
    if (_subcatForItemId == baseItemId) return;

    _subcatSub?.close();
    _subcatForItemId = baseItemId;

    setState(() {
      _subLoading = true;
      _subItems = [];
      // keep dropdown fallback to base item until WS data arrives
    });

    _subcatSub = ref.listenManual<AsyncValue<List<StoreItemsModel>>>(
      itemSubcategoryProvider(baseItemId),
      (prev, next) {
        next.when(
          loading: () {},
          error: (e, st) {
            if (!mounted) return;
            setState(() {
              _subLoading = false;
              _subItems = [];
            });
          },
          data: (list) {
            if (!mounted) return;

            final base = _baseItem;
            setState(() {
              _subLoading = false;
              _subItems = list;

              if (list.isNotEmpty) {
                _lineItemId = list.first.id;
              } else {
                _lineItemId = base?.id;
                // If dropdown empty => auto add base item line with qty 1
                if (base != null &&
                    _lines.isEmpty &&
                    (_autoAddedForBaseId != base.id)) {
                  final qty = 1;
                  final globalInCart = ref.read(globalInCartProvider);
                  final inCart = globalInCart[base.id] ?? 0;
                  final avail = (base.stockAvailableQuantity - inCart).clamp(0, 999999);
                  if (avail > 0) {
                    _lines.add(
                      _IssueLineDraft(
                        itemId: base.id,
                        itemName: base.itemName,
                        qty: qty,
                        avail: avail,
                        unit: base.unit,
                      ),
                    );
                    _autoAddedForBaseId = base.id;
                  }
                }
              }
            });
          },
        );
      },
    );
  }

  // Faster: do NOT await WS before switching step
  void _continueToForm() {
    final it = _baseItem;
    if (it == null) return;

    setState(() {
      _step = 1;
      _lineItemId = it.id; // fallback to base item
      _qtyCtrl.text = '1';
      _lines.clear();
      _autoAddedForBaseId = null;
    });

    _subscribeSubcategory(it.id);
  }

  void _addLine() {
    final base = _baseItem;
    if (base == null) return;

    final dropdownItems =
        _subItems.isEmpty ? <StoreItemsModel>[base] : _subItems;

    final chosen = _findById(dropdownItems, _lineItemId);

    if (chosen == null) {
      showSnackBar('Select item');
      return;
    }

    final qty = _asInt(_qtyCtrl.text, 0);
    if (qty <= 0) {
      showSnackBar('Enter qty > 0');
      return;
    }

    final globalInCart = ref.read(globalInCartProvider);
    final inCart = globalInCart[chosen.id] ?? 0;
    final avail = (chosen.stockAvailableQuantity - inCart).clamp(0, 999999);
    if (qty > avail) {
      showSnackBar('Qty cannot be greater than available ($avail)');
      return;
    }

    // subCategoryId is the CATEGORY of the dropdown-selected item
    final subCategoryIdRaw = chosen.categoryId;
    final subCategoryId =
        (subCategoryIdRaw == null)
            ? null
            : subCategoryIdRaw.toString().trim().isEmpty
            ? null
            : subCategoryIdRaw.toString().trim();

    setState(() {
      final idx = _lines.indexWhere((x) => x.itemId == chosen.id);

      if (idx >= 0) {
        final next = _lines[idx].qty + qty;
        if (next > avail) {
          showSnackBar('Total qty exceeds available ($avail)');
          return;
        }
        _lines[idx] = _lines[idx].copyWith(qty: next, avail: avail);
      } else {
        _lines.add(
          _IssueLineDraft(
            itemId: chosen.id,
            itemName: chosen.itemName,
            qty: qty,
            avail: avail,
            unit: chosen.unit,
            subCategoryId: subCategoryId, // store it here
          ),
        );
      }

      _qtyCtrl.text = '1';
    });
  }

  Future<void> _submitCreate() async {
    final uid = await ref.read(spRepositoryProvider).getStringValue('uid');
    if (uid.trim().isEmpty) {
      showSnackBar('Missing user id (uid)');
      return;
    }
    if (_lines.isEmpty) {
      showSnackBar('Add at least 1 line');
      return;
    }

    setState(() => _busy = true);
    try {
      final dto = <String, dynamic>{
        'createdBy': uid,
        'reason': _reasonCtrl.text.trim(),
        'remark': _remarkCtrl.text.trim(),
        'lines':
            _lines
                .map(
                  (l) => {
                    'itemId': l.itemId, // each selected item
                    'requestedQty': l.qty, // qty per line
                  },
                )
                .toList(),
      };

      // depending on your provider type, use one of these:
      // final ctrl = ref.read(issueControllerProvider.notifier);
      final ctrl = ref.read(issueControllerProvider);

      await ctrl.createDraft(dto);

      if (!mounted) return;
      await ref.read(storeCartProvider.notifier).clearCart();
      ref.read(globalInCartProvider.notifier).refresh();
      showSnackBar('Issue created successfully');
      Navigator.pop(context, true);
    } catch (e) {
      showSnackBar('Create issue failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Future<void> _submitCreate() async {
  //   final uid =
  //       await ref.read(spRepositoryProvider).getStringValue('uid') ?? '';
  //   if (uid.trim().isEmpty) {
  //     showSnackBar('Missing user id (uid)');
  //     return;
  //   }
  //   if (_lines.isEmpty) {
  //     showSnackBar('Add at least 1 line');
  //     return;
  //   }

  //   final base = _baseItem;
  //   if (base == null) {
  //     showSnackBar('Select base item first');
  //     return;
  //   }

  //   setState(() => _busy = true);
  //   try {
  //     final ctrl = ref.read(issueControllerProvider);

  //     // Your backend creates 1 draft issue per request.
  //     // So we create drafts per line.
  //     for (final l in _lines) {
  //       await ctrl.createDraft(
  //         itemId: l.itemId, // IMPORTANT: selected card item id
  //         requestedQty: l.qty, // qty
  //         createdBy: uid, // uid must be ObjectId string
  //         subCategoryId: l.subCategoryId, // optional bucket categoryId
  //         reason: _reasonCtrl.text.trim(),
  //         remark: _remarkCtrl.text.trim(),
  //       );
  //     }

  //     if (!mounted) return;
  //     showSnackBar('Issue draft(s) created successfully');
  //     Navigator.pop(context);
  //   } catch (e) {
  //     showSnackBar('Create issue failed: $e');
  //   } finally {
  //     if (mounted) setState(() => _busy = false);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: do not fetch 800 on first load if your API is slow.
    // Use 200 and rely on search.
    final itemsAv = ref.watch(
      itemPagedStreamProvider(
        ItemPagedQuery(page: 1, limit: 200, search: _itemSearch, sort: 'name'),
      ),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        canvasColor: _surface,
        cardColor: _surface,
        dialogBackgroundColor: _surface,
        colorScheme: Theme.of(context).colorScheme.copyWith(
          surface: _surface,
          primary: const Color(0xFF2563EB),
        ),
      ),
      child: Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        leading: const Padding(
          padding: EdgeInsets.only(left: 10, top: 10, bottom: 10),
          child: AppBackButton(),
        ),
        title: const Text(
          'Create Issue',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final cart = ref.watch(storeCartProvider);
              return Badge.count(
                count: cart.lineCount,
                isLabelVisible: cart.lineCount > 0,
                backgroundColor: _ink900,
                textColor: _surface,
                child: IconButton(
                  tooltip: 'Requisition Cart (${cart.lineCount})',
                  icon: const Icon(Icons.shopping_cart_outlined, color: _ink900),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const StoreCartPage()),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(width: 8),
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
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _Card(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child:
                        _step == 0
                            ? _stepSelectItem(itemsAv)
                            : _stepCreateForm(),
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

  Widget _stepSelectItem(AsyncValue<ItemPagedResult> itemsAv) {
    return Column(
      key: const ValueKey('step0'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Select Item',
          style: TextStyle(
            color: _ink900,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          onChanged: (v) => setState(() => _itemSearch = v.trim()),
          style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
          cursorColor: const Color(0xFF2563EB),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2563EB)),
            hintText: 'Search item...',
            hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.55)),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: itemsAv.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (paged) {
              final rows = paged.rows;
              if (rows.isEmpty) {
                return const Center(
                  child: Text(
                    'No items found',
                    style: TextStyle(
                      color: _ink700,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final it = rows[i];
                  final inCart = ref.watch(globalInCartProvider)[it.id] ?? 0;
                  final effAvail = (it.stockAvailableQuantity - inCart).clamp(0, 999999);
                  final sel = _baseItem?.id == it.id;

                  return InkWell(
                    onTap: _busy ? null : () => setState(() => _baseItem = it),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: sel ? _accentMint : _stroke,
                          width: sel ? 1.5 : 1.0,
                        ),
                        boxShadow: _shadow,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _surfaceAlt.withValues(alpha: .8),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: _stroke),
                            ),
                            child: Icon(
                              sel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: _ink900,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  it.itemName,
                                  style: const TextStyle(
                                    color: _ink900,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${it.itemCode} • Unit: ${it.unit} • Avail: $effAvail',
                                  style: const TextStyle(
                                    color: _ink700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  it.itemName.isEmpty
                                      ? '—'
                                      : it.itemName,
                                  style: const TextStyle(
                                    color: _ink600,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: (_baseItem == null || _busy) ? null : _continueToForm,
          style: FilledButton.styleFrom(
            backgroundColor: _accentBlue,
            foregroundColor: _ink900,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          label: const Text(
            'Continue',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }

  Widget _stepCreateForm() {
    final base = _baseItem!;
    final dropdownItems =
        _subItems.isEmpty ? <StoreItemsModel>[base] : _subItems;

    return Column(
      key: const ValueKey('step1'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Header',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),

        const Text(
          'Reason',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _reasonCtrl,
          style: const TextStyle(color: _ink900, fontSize: 14, fontWeight: FontWeight.w600),
          cursorColor: const Color(0xFF2563EB),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.flag_outlined, color: Color(0xFF2563EB)),
            hintText: 'Reason for Issue',
            hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.55)),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Text(
          'Remark',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _remarkCtrl,
          style: const TextStyle(color: _ink900, fontSize: 14, fontWeight: FontWeight.w600),
          cursorColor: const Color(0xFF2563EB),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF2563EB)),
            hintText: 'Remark (Optional)',
            hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.55)),
            filled: true,
            fillColor: _surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 16),
        const Text(
          'Add Line',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),

        // Inline loading (fast UX): do not block page
        if (_subLoading)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentMint.withValues(alpha: .20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Loading subcategory items...',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // If finished and empty => we already fallback to base and auto-add line (if possible)
        if (!_subLoading && _subItems.isEmpty)
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _accentMint.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _stroke),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: _ink900),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No subcategory items found. Using the selected item directly.',
                    style: TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),

        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;

            final itemPicker = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Item',
                      style: TextStyle(
                        color: _ink700,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_subLoading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _lineItemId,
                  isExpanded: true,
                  dropdownColor: _surface,
                  style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600, fontSize: 14),
                  iconEnabledColor: const Color(0xFF2563EB),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.inventory_2_outlined, color: Color(0xFF2563EB)),
                    hintText: 'Select item',
                    hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.55)),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                  ),
                  items:
                      dropdownItems
                          .map(
                            (it) => DropdownMenuItem<String>(
                              value: it.id,
                              child: Text(
                                it.itemName,
                                style: const TextStyle(color: _ink900, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (_busy || dropdownItems.length <= 1)
                          ? null
                          : (v) => setState(() => _lineItemId = v),
                ),
              ],
            );

            final qtyPicker = Column(
              key: GuidedTourController.issueQuantityStepperKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Qty (≤ avail)',
                  style: TextStyle(
                    color: _ink700,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                  cursorColor: const Color(0xFF2563EB),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.numbers_rounded, color: Color(0xFF2563EB)),
                    hintText: 'Enter qty',
                    hintStyle: TextStyle(color: _ink600.withValues(alpha: 0.55)),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _stroke),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                    ),
                  ),
                ),
              ],
            );

            final toCartBtn = OutlinedButton.icon(
              onPressed: _busy ? null : () {
                final base = _baseItem;
                if (base == null) return;
                final dropdownItems = _subItems.isEmpty ? <StoreItemsModel>[base] : _subItems;
                final chosen = _findById(dropdownItems, _lineItemId);
                if (chosen == null) {
                  showSnackBar('Select item');
                  return;
                }
                final qty = _asInt(_qtyCtrl.text, 0);
                if (qty <= 0) {
                  showSnackBar('Enter qty > 0');
                  return;
                }
                final ok = ref.read(storeCartProvider.notifier).addItem(
                  chosen,
                  qty: qty,
                  onStockError: (err) => showSnackBar(err),
                );
                if (ok) {
                  showSnackBar('Added ${chosen.itemName} ($qty) to Cart!');
                }
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: _ink900,
                iconColor: _ink900,
                side: const BorderSide(color: _stroke),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: _ink900),
              label: const Text(
                'To Cart',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            );

            final addBtn = FilledButton.icon(
              onPressed: _busy ? null : _addLine,
              style: FilledButton.styleFrom(
                backgroundColor: _accentBlue,
                foregroundColor: _ink900,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(flex: 6, child: itemPicker),
                      const SizedBox(width: 8),
                      Expanded(flex: 4, child: qtyPicker),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(height: 46, child: toCartBtn),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(height: 46, child: addBtn),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                Expanded(flex: 7, child: itemPicker),
                const SizedBox(width: 12),
                Expanded(flex: 3, child: qtyPicker),
                const SizedBox(width: 12),
                SizedBox(height: 48, child: toCartBtn),
                const SizedBox(width: 8),
                SizedBox(height: 48, child: addBtn),
              ],
            );
          },
        ),

        const SizedBox(height: 16),
        const Text(
          'Lines',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _LinesTable(
            lines: _lines,
            onRemove: (id) {
              if (_busy) return;
              setState(() => _lines.removeWhere((x) => x.itemId == id));
            },
          ),
        ),

        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: _ink900,
                iconColor: _ink900,
              ),
              onPressed:
                  _busy
                      ? null
                      : () {
                        _subcatSub?.close();
                        setState(() {
                          _step = 0;
                          _subItems = [];
                          _subLoading = false;
                        });
                      },
              icon: const Icon(Icons.arrow_back_rounded, color: _ink900),
              label: const Text('Back'),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_lines.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () {
                            int count = 0;
                            for (final l in _lines) {
                              final item = StoreCartItem(
                                id: l.itemId,
                                itemName: l.itemName,
                                itemCode: '',
                                unit: l.unit,
                                quantity: l.qty,
                                stockAvailableQuantity: l.avail,
                                categoryId: l.subCategoryId,
                              );
                              final ok = ref.read(storeCartProvider.notifier).addCartItem(
                                item,
                                onStockError: (err) => showSnackBar(err),
                              );
                              if (ok) count++;
                            }
                            if (count > 0) {
                              showSnackBar('Saved $count item(s) to Cart!');
                              Navigator.pop(context, true);
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _ink900,
                      iconColor: _ink900,
                      side: const BorderSide(color: _stroke),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: _ink900),
                    label: const Text(
                      'Save to Cart',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                SizedBox(
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: (_busy || _lines.isEmpty) ? null : _submitCreate,
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentBlue,
                      foregroundColor: _ink900,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon:
                        _busy
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded),
                    label: const Text(
                      'Create',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/* ---------------- Lines table ---------------- */

class _IssueLineDraft {
  final String itemId; // dropdown item id (for UI only)
  final String itemName;
  final int qty;
  final int avail;
  final String unit;

  final String?
  subCategoryId; // IMPORTANT: send this to backend (bucket categoryId)

  const _IssueLineDraft({
    required this.itemId,
    required this.itemName,
    required this.qty,
    required this.avail,
    required this.unit,
    this.subCategoryId,
  });

  _IssueLineDraft copyWith({int? qty, int? avail}) => _IssueLineDraft(
    itemId: itemId,
    itemName: itemName,
    qty: qty ?? this.qty,
    avail: avail ?? this.avail,
    unit: unit,
    subCategoryId: subCategoryId,
  );
}

class _LinesTable extends StatelessWidget {
  const _LinesTable({required this.lines, required this.onRemove});

  final List<_IssueLineDraft> lines;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _stroke),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: _surfaceAlt.withValues(alpha: .35),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              border: const Border(bottom: BorderSide(color: _stroke)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 6, child: _Hdr('Item')),
                Expanded(flex: 2, child: _Hdr('Qty')),
                Expanded(flex: 2, child: _Hdr('Avail')),
                SizedBox(width: 40),
              ],
            ),
          ),
          if (lines.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'No lines added',
                style: TextStyle(color: _ink700, fontWeight: FontWeight.w700),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (_, i) {
                  final l = lines[i];
                  return Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: _stroke)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: Text(
                            l.itemName,
                            style: const TextStyle(
                              color: _ink900,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              '${l.qty}',
                              style: const TextStyle(
                                color: _ink700,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Text(
                              '${l.avail}',
                              style: const TextStyle(
                                color: _ink600,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: IconButton(
                            onPressed: () => onRemove(l.itemId),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: _ink700,
                            ),
                            tooltip: 'Remove',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Hdr extends StatelessWidget {
  const _Hdr(this.t);
  final String t;

  @override
  Widget build(BuildContext context) {
    return Text(
      t,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _ink700, fontWeight: FontWeight.w900),
    );
  }
}

/* ---------------- Card ---------------- */

class _Card extends StatelessWidget {
  const _Card({required this.child}) : padding = const EdgeInsets.all(16);
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _stroke),
        boxShadow: _shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
