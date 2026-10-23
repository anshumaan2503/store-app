import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/store_page/controllers/indent_draft_controller.dart';
import 'package:store_app/src/store_page/controllers/guided_tour_controller.dart';
import 'package:store_app/src/store_page/domains/models/indent_draft_model.dart';

/* ---------------- Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class IndentDraftsPage extends ConsumerStatefulWidget {
  const IndentDraftsPage({super.key, this.isEmbedded = false});

  final bool isEmbedded;

  @override
  ConsumerState<IndentDraftsPage> createState() => _IndentDraftsPageState();
}

class _IndentDraftsPageState extends ConsumerState<IndentDraftsPage> {
  final Set<String> _unselectedItemIds = {};
  bool _isSubmitting = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(indentDraftControllerProvider.notifier).fetchDrafts();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? Colors.red.shade700 : _ink900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showEditQuantityDialog(IndentDraftItemModel item) async {
    final controller = TextEditingController(text: item.quantity.toString());
    final reasonController = TextEditingController(text: item.reason);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Edit Indent Quantity: ${item.itemName}',
            style: const TextStyle(color: _ink900, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Item Code: ${item.itemCode} | Unit: ${item.unit}',
                style: const TextStyle(color: _ink600, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                cursorColor: _ink900,
                style: const TextStyle(
                  color: _ink900,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Quantity Needed',
                  labelStyle: const TextStyle(color: _ink700, fontSize: 13, fontWeight: FontWeight.w600),
                  floatingLabelStyle: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _ink900, width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                cursorColor: _ink900,
                style: const TextStyle(
                  color: _ink900,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Justification / Reason (Optional)',
                  labelStyle: const TextStyle(color: _ink700, fontSize: 13, fontWeight: FontWeight.w600),
                  floatingLabelStyle: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _ink900, width: 1.8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _ink600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
              ),
              onPressed: () async {
                final newQty = int.tryParse(controller.text.trim());
                if (newQty == null || newQty <= 0) return;
                await ref.read(indentDraftControllerProvider.notifier).updateQuantity(
                      item.itemId,
                      newQty,
                      reason: reasonController.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (updated == true) {
      _showSnack('Updated ${item.itemName} quantity');
    }
  }

  Future<void> _submitCombinedIndent(List<IndentDraftItemModel> items) async {
    final toSubmit = items
        .where((i) => !_unselectedItemIds.contains(i.itemId))
        .toList();

    if (toSubmit.isEmpty) {
      _showSnack('Please select at least one item to submit', isError: true);
      return;
    }

    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: const Icon(
                  Icons.playlist_add_check_circle_rounded,
                  color: _ink900,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Submit Combined Indent',
                  style: TextStyle(color: _ink900, fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will bundle ${toSubmit.length} item(s) into ONE single Indent Requisition and submit it for Manager Approval (Status: PENDING).',
                style: const TextStyle(color: _ink700, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                cursorColor: _ink900,
                style: const TextStyle(
                  color: _ink900,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  labelText: 'Requisition Remarks (Optional)',
                  labelStyle: const TextStyle(color: _ink700, fontSize: 13, fontWeight: FontWeight.w600),
                  floatingLabelStyle: const TextStyle(color: _ink900, fontWeight: FontWeight.w700),
                  hintText: 'e.g. Monthly department replenishment',
                  hintStyle: const TextStyle(color: _ink600, fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: _surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _stroke, width: 1.2),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: _ink900, width: 1.8),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _ink600, fontWeight: FontWeight.w700)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm & Submit', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      final selectedIds = toSubmit.map((i) => i.itemId).toList();
      final result = await ref.read(indentDraftControllerProvider.notifier).submitCombined(
            itemIds: selectedIds,
            reason: reasonCtrl.text.trim(),
          );

      if (!mounted) return;

      if (result != null) {
        final indentNo = result['groupIndentNumber']?.toString() ?? 'Submitted';
        final count = result['submittedCount']?.toString() ?? '${toSubmit.length}';
        _unselectedItemIds.clear();
        _showSnack('Combined Indent $indentNo ($count items) submitted for Approval!');
      } else {
        final err = ref.read(indentDraftControllerProvider).error ?? 'Submission failed';
        _showSnack(err, isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indentDraftControllerProvider);
    final items = state.items;

    final allSelected = items.isNotEmpty && _unselectedItemIds.isEmpty;

    final bodyContent = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_bgTop, _bgBottom],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          if (widget.isEmbedded && items.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: _surface,
              child: Row(
                children: [
                  Text(
                    '${items.length} item(s) in cart',
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh Real-Time Stock',
                    icon: const Icon(Icons.refresh_rounded,
                        size: 20, color: _ink900),
                    onPressed: () => ref
                        .read(indentDraftControllerProvider.notifier)
                        .fetchDrafts(),
                  ),
                  IconButton(
                    tooltip: 'Clear All Drafts',
                    icon: const Icon(Icons.delete_sweep_outlined,
                        size: 20, color: _ink700),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear Indent Cart?'),
                          content: const Text(
                              'Are you sure you want to remove all unsubmitted indent items from your cart?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel')),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                foregroundColor: _surface,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear All'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(indentDraftControllerProvider.notifier)
                            .clearDrafts();
                        _unselectedItemIds.clear();
                        _showSnack('Indent cart cleared');
                      }
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            child: state.isLoading && items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                    ? _buildEmptyState()
                    : _buildContent(items, allSelected),
          ),
        ],
      ),
    );

    if (widget.isEmbedded) {
      return Container(
        color: _surface,
        child: Column(
          children: [
            Expanded(child: bodyContent),
            if (items.isNotEmpty) _buildBottomBar(items),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Row(
          children: [
            const Text(
              'Indent Cart',
              style: TextStyle(
                  color: _ink900,
                  fontWeight: FontWeight.w900,
                  fontSize: 17),
            ),
            if (items.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: const TextStyle(
                    color: Color(0xFF3730A3),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Real-Time Stock',
            icon: const Icon(Icons.refresh_rounded, color: _ink900),
            onPressed: () => ref
                .read(indentDraftControllerProvider.notifier)
                .fetchDrafts(),
          ),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear All Drafts',
              icon:
                  const Icon(Icons.delete_sweep_outlined, color: _ink700),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Indent Cart?'),
                    content: const Text(
                        'Are you sure you want to remove all unsubmitted indent items from your cart?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          foregroundColor: _surface,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear All'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(indentDraftControllerProvider.notifier)
                      .clearDrafts();
                  _unselectedItemIds.clear();
                  _showSnack('Indent cart cleared');
                }
              },
            ),
        ],
      ),
      body: bodyContent,
      bottomNavigationBar: items.isEmpty ? null : _buildBottomBar(items),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: _surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: _stroke, width: 2),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 44,
                color: _ink600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Indent Cart is Empty',
              style: TextStyle(
                color: _ink900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add multiple items from Store Items to your Indent Cart to raise them together in a single combined indent request.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink600,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: GuidedTourController.indentCartSubmitKey,
              style: FilledButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Browse Store Items'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<IndentDraftItemModel> items, bool allSelected) {
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      trackVisibility: true,
      interactive: true,
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner explaining real-time availability and multi-item single submission
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF3730A3)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Indent Review & Real-Time Stock',
                        style: TextStyle(
                          color: Color(0xFF3730A3),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Review your shortage items with live store stock positions. Select the items you want and combine them into ONE single Indent Request for manager approval.',
                        style: TextStyle(
                          color: Color(0xFF4338CA),
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Select All Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    activeColor: _ink900,
                    checkColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF9E9E9E), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _unselectedItemIds.clear();
                        } else {
                          _unselectedItemIds.addAll(items.map((i) => i.itemId));
                        }
                      });
                    },
                  ),
                  Text(
                    allSelected ? 'Deselect All' : 'Select All (${items.length})',
                    style: const TextStyle(
                      color: _ink900,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              Text(
                '${items.where((i) => !_unselectedItemIds.contains(i.itemId)).length} selected',
                style: const TextStyle(
                  color: _ink600,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // List of Indent Items
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, idx) {
              final item = items[idx];
              final isChecked = !_unselectedItemIds.contains(item.itemId);
              return _buildItemCard(item, isChecked);
            },
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildItemCard(IndentDraftItemModel item, bool isChecked) {
    final notifier = ref.read(indentDraftControllerProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: item.isRestocked ? const Color(0xFF81C784) : _stroke,
          width: item.isRestocked ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              Checkbox(
                value: isChecked,
                activeColor: _ink900,
                checkColor: Colors.white,
                side: const BorderSide(color: Color(0xFF9E9E9E), width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      _unselectedItemIds.remove(item.itemId);
                    } else {
                      _unselectedItemIds.add(item.itemId);
                    }
                  });
                },
              ),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          'Code: ${item.itemCode}',
                          style: const TextStyle(color: _ink600, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '• Unit: ${item.unit}',
                          style: const TextStyle(color: _ink600, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        if (item.reason.isNotEmpty)
                          Text(
                            '• Reason: ${item.reason}',
                            style: const TextStyle(color: _ink700, fontSize: 11, fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Edit / Delete Actions
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: _ink700),
                tooltip: 'Edit Quantity / Reason',
                onPressed: () => _showEditQuantityDialog(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                tooltip: 'Remove',
                onPressed: () async {
                  await notifier.removeItem(item.itemId);
                  _unselectedItemIds.remove(item.itemId);
                  _showSnack('Removed ${item.itemName} from draft list');
                },
              ),
            ],
          ),

          const SizedBox(height: 8),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 8),

          // Real-Time Stock Status & Quantity Stepper Row (Mobile-Optimized)
          LayoutBuilder(
            builder: (context, cardConstraints) {
              final isVeryNarrow = cardConstraints.maxWidth < 350;

              final stockIndicator = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.realTimeAvailableQty > 0
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: item.realTimeAvailableQty > 0
                        ? const Color(0xFFA5D6A7)
                        : const Color(0xFFFFCC80),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.realTimeAvailableQty > 0
                          ? Icons.check_circle_rounded
                          : Icons.hourglass_bottom_rounded,
                      size: 13,
                      color: item.realTimeAvailableQty > 0
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFE65100),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        item.realTimeAvailableQty > 0
                            ? 'Live Stock: ${item.realTimeAvailableQty} available'
                            : 'Live Stock: 0 in store (Shortage)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: item.realTimeAvailableQty > 0
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFE65100),
                        ),
                      ),
                    ),
                  ],
                ),
              );

              final stepper = Container(
                height: 34,
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 14, color: _ink900),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        if (item.quantity > 1) {
                          notifier.updateQuantity(item.itemId, item.quantity - 1);
                        } else {
                          notifier.removeItem(item.itemId);
                        }
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '${item.quantity} ${item.unit}',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 14, color: _ink900),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        notifier.updateQuantity(item.itemId, item.quantity + 1);
                      },
                    ),
                  ],
                ),
              );

              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    stockIndicator,
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: stepper,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: stockIndicator),
                  const SizedBox(width: 10),
                  stepper,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(List<IndentDraftItemModel> items) {
    final toSubmit = items
        .where((i) => !_unselectedItemIds.contains(i.itemId))
        .toList();
    final totalUnits = toSubmit.fold(0, (sum, i) => sum + i.quantity);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        border: const Border(top: BorderSide(color: _stroke)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 460;

            final summaryText = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${toSubmit.length} Items Selected ($totalUnits units)',
                  style: const TextStyle(
                    color: _ink900,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Combined into 1 single indent',
                  style: TextStyle(color: _ink600, fontSize: 11),
                ),
              ],
            );

            final submitBtn = SizedBox(
              height: 46,
              child: FilledButton.icon(
                key: GuidedTourController.indentCartSubmitKey,
                style: FilledButton.styleFrom(
                  backgroundColor: _ink900,
                  foregroundColor: _surface,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: (_isSubmitting || toSubmit.isEmpty)
                    ? null
                    : () => _submitCombinedIndent(items),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _surface),
                      )
                    : const Icon(Icons.send_rounded, size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _isSubmitting ? 'Submitting...' : 'Submit Combined Indent',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  summaryText,
                  const SizedBox(height: 10),
                  submitBtn,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: summaryText),
                submitBtn,
              ],
            );
          },
        ),
      ),
    );
  }
}
