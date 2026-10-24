import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:store_app/src/auth/shared/providers/auth_model_provider.dart';
import 'package:store_app/src/auth/shared/repositories/shared_preference_repository.dart';

import '../../../controllers/guided_tour_controller.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../controllers/store_item_issue_controller.dart';
import 'package:store_app/src/store_page/controllers/indent_draft_controller.dart';
import 'package:store_app/src/store_page/domains/models/issue_models.dart';
import 'package:store_app/src/store_page/presentation/view/indent/indent_drafts_page.dart';
import './store_cart_timer_settings_sheet.dart';

/* ---------------- Palette ---------------- */
const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);

const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);

const _accentMint = Color(0xFFB6D3CC);
const _bgTop = Color(0xFFFFFFF3);
const _bgBottom = _surfaceAlt;

class StoreCartPage extends ConsumerStatefulWidget {
  const StoreCartPage({super.key});

  @override
  ConsumerState<StoreCartPage> createState() => _StoreCartPageState();
}

class _StoreCartPageState extends ConsumerState<StoreCartPage> {
  final _reasonCtrl = TextEditingController();
  final _remarkCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _reasonCtrl.dispose();
    _remarkCtrl.dispose();
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
        backgroundColor: isError ? Colors.red.shade700 : _ink900,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitRequest(StoreCartState cart) async {
    if (cart.isEmpty) {
      _showSnack('Cart is empty', isError: true);
      return;
    }

    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showSnack('Please enter a Reason for Request', isError: true);
      return;
    }

    final sp = ref.read(spRepositoryProvider);
    final uid = await sp.getStringValue('uid');
    if (uid.trim().isEmpty) {
      _showSnack('Missing user session. Please re-login.', isError: true);
      return;
    }

    // Split cart items into available stock (Issue Request) and shortage (Indent Draft)
    final issueLines = <Map<String, dynamic>>[];
    final indentDraftLines = <Map<String, dynamic>>[];

    for (final item in cart.items) {
      final avail = item.availableForIssue;
      final shortfall = item.shortfallForIndent;

      if (avail > 0) {
        issueLines.add({
          'itemId': item.id,
          'requestedQty': avail,
        });
      }

      if (shortfall > 0) {
        indentDraftLines.add({
          'itemId': item.id,
          'quantity': shortfall,
          'reason': reason,
          'itemName': item.itemName,
          'itemCode': item.itemCode,
          'unit': item.unit,
          'imageUrl': item.imageUrl,
        });
      }
    }

    setState(() => _submitting = true);
    try {
      IssueDraftResult? issueResult;

      // 1. Process available stock as an Issue Request
      if (issueLines.isNotEmpty) {
        final dto = <String, dynamic>{
          'createdBy': uid.trim(),
          'reason': reason,
          'remark': _remarkCtrl.text.trim().isEmpty ? reason : _remarkCtrl.text.trim(),
          'lines': issueLines,
        };
        final ctrl = ref.read(issueControllerProvider);
        issueResult = await ctrl.createDraft(dto);
      }

      String? indentNo;
      // 2. Automatically save remaining units as Indent Requirement and submit as pending Indent
      if (indentDraftLines.isNotEmpty) {
        await ref
            .read(indentDraftControllerProvider.notifier)
            .addDraftItems(indentDraftLines);
        final combinedRes = await ref
            .read(indentDraftControllerProvider.notifier)
            .submitCombined(reason: reason);
        if (combinedRes != null) {
          indentNo = combinedRes['groupIndentNumber']?.toString();
        }
      }

      if (!mounted) return;

      // 3. Clear the Requisition Cart
      await ref.read(storeCartProvider.notifier).clearCart();
      ref.read(globalInCartProvider.notifier).refresh();

      // 4. Feedback based on split result
      if (issueLines.isNotEmpty && indentDraftLines.isNotEmpty) {
        _showSnack(
          'Issue Request ${issueResult?.issNo ?? ''} created! Indent Request ${indentNo != null ? '($indentNo) ' : ''}submitted for shortage units.',
        );
      } else if (issueLines.isNotEmpty) {
        _showSnack('Issue Request ${issueResult?.issNo ?? ''} created successfully!');
      } else {
        _showSnack(
          'Items out of stock: Indent Request ${indentNo != null ? '($indentNo) ' : ''}submitted for approval!',
        );
      }

      ref.read(guidedTourControllerProvider).requestSection('items');
      Navigator.of(context).pop(true);
    } catch (e) {
      _showSnack('Failed to submit request: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Clear Cart?',
          style: TextStyle(color: _ink900, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to remove all items from your requisition cart?',
          style: TextStyle(color: _ink700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _ink600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: _surface,
            ),
            onPressed: () async {
              await ref.read(storeCartProvider.notifier).clearCart();
              ref.read(globalInCartProvider.notifier).refresh();
              Navigator.pop(ctx);
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(storeCartProvider);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: _ink900),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Flexible(
              child: Text(
                'Requisition Cart',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _ink900, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            if (cart.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _ink900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cart.lineCount}',
                  style: const TextStyle(
                    color: _surface,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final draftState = ref.watch(indentDraftControllerProvider);
              return Badge.count(
                count: draftState.lineCount,
                isLabelVisible: draftState.lineCount > 0,
                backgroundColor: _ink900,
                textColor: _surface,
                child: IconButton(
                  tooltip: 'View Indent Review List (${draftState.lineCount})',
                  icon: const Icon(Icons.assignment_outlined, color: _ink900),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const IndentDraftsPage(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          if (ref.watch(authModelProvider)?.isSuperAdmin == true)
            IconButton(
              tooltip: 'Cart Auto-Revert Settings',
              icon: const Icon(Icons.timer_outlined, color: _ink700),
              onPressed: () => showCartTimerSettingsSheet(context),
            ),
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear Cart',
              icon: const Icon(Icons.delete_sweep_outlined, color: _ink700),
              onPressed: _confirmClearCart,
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
        child: cart.isEmpty
            ? _buildEmptyState()
            : _buildCartContent(cart),
      ),
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
                Icons.shopping_cart_outlined,
                size: 44,
                color: _ink600,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Your Cart is Empty',
              style: TextStyle(
                color: _ink900,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Browse store items or scan machine QR codes to add products into your requisition cart.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink600,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _ink900,
                foregroundColor: _surface,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'Browse Items',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartContent(StoreCartState cart) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            trackVisibility: true,
            interactive: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 5-minute Auto-expiry notice banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 16, color: Color(0xFFE65100)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Items in cart are held for 5 minutes. Submit your request before the timer expires or items will be auto-removed.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF5D4037),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section: Items in Cart
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Items to Request (${cart.lineCount})',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Total: ${cart.totalCount} units',
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final item = cart.items[idx];
                      return _buildCartItemCard(item);
                    },
                  ),

                  const SizedBox(height: 20),

                  // Section: Issue Details Form
                  Container(
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _stroke),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.assignment_outlined, size: 18, color: _ink900),
                            SizedBox(width: 8),
                            Text(
                              'Request Details',
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _reasonCtrl,
                          style: const TextStyle(
                            color: _ink900,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Reason for Issue *',
                            labelStyle: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'e.g. Scheduled machine maintenance, replacement part',
                            hintStyle: TextStyle(
                              color: _ink600.withValues(alpha: 0.55),
                              fontSize: 12.5,
                            ),
                            prefixIcon: const Icon(Icons.edit_note_rounded, color: _ink900),
                            filled: true,
                            fillColor: _surfaceAlt.withValues(alpha: 0.4),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _ink900, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _remarkCtrl,
                          style: const TextStyle(
                            color: _ink900,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Remark (Optional)',
                            labelStyle: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: 'e.g. Urgent priority, Line 2 production',
                            hintStyle: TextStyle(
                              color: _ink600.withValues(alpha: 0.55),
                              fontSize: 12.5,
                            ),
                            prefixIcon: const Icon(Icons.comment_outlined, color: _ink700),
                            filled: true,
                            fillColor: _surfaceAlt.withValues(alpha: 0.4),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _stroke),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: _ink900, width: 1.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
        ),

        // Bottom Checkout Bar
        Container(
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
                final isNarrow = constraints.maxWidth < 430;

                final summaryWidget = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${cart.lineCount} Items (${cart.totalCount} units)',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Soft hold for 30m upon submission',
                      style: TextStyle(color: _ink600, fontSize: 11),
                    ),
                  ],
                );

                final submitButton = SizedBox(
                  key: GuidedTourController.requisitionCartSubmitKey,
                  height: 48,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _ink900,
                      foregroundColor: _surface,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _submitting ? null : () => _submitRequest(cart),
                    icon: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _surface,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      _submitting ? 'Submitting...' : 'Submit Request',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                );

                if (isNarrow) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      summaryWidget,
                      const SizedBox(height: 10),
                      submitButton,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: summaryWidget),
                    submitButton,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCartItemCard(StoreCartItem item) {
    final notifier = ref.read(storeCartProvider.notifier);
    final hasImg = item.imageUrl.isNotEmpty;
    final availForIssue = item.availableForIssue;
    final shortfall = item.shortfallForIndent;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: shortfall > 0 ? const Color(0xFFFFCC80) : _stroke,
          width: shortfall > 0 ? 1.5 : 1,
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
              // Thumbnail
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _accentMint.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                clipBehavior: Clip.antiAlias,
                child: hasImg
                    ? Image.network(
                        item.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_rounded,
                          size: 20,
                          color: _ink900,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_rounded,
                        size: 20,
                        color: _ink900,
                      ),
              ),
              const SizedBox(width: 10),

              // Title & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.itemName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _stroke),
                          ),
                          child: Text(
                            item.itemCode,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _ink900,
                            ),
                          ),
                        ),
                        if (item.categoryLabel != null &&
                            item.categoryLabel!.isNotEmpty)
                          Text(
                            item.categoryLabel!,
                            style: const TextStyle(
                              color: _ink600,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        Text(
                          '• ${item.unit}',
                          style: const TextStyle(
                            color: _ink600,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (StoreCartItem.activeTimeoutEnabled)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: item.remainingTime.inSeconds < 60
                                  ? const Color(0xFFFFEBEE)
                                  : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.remainingTime.inSeconds < 60
                                    ? const Color(0xFFEF9A9A)
                                    : const Color(0xFFFFCC80),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 11,
                                  color: item.remainingTime.inSeconds < 60
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFFE65100),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  item.remainingFormatted,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: item.remainingTime.inSeconds < 60
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFFE65100),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Delete Button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red.shade700,
                onPressed: () => notifier.removeItem(item.id),
                tooltip: 'Remove',
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: _stroke),
          const SizedBox(height: 10),

          // Stepper & Stock status row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Stock allocation info
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (availForIssue > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFA5D6A7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 12, color: Color(0xFF2E7D32)),
                            const SizedBox(width: 4),
                            Text(
                              '$availForIssue Issue (Stock)',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (shortfall > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFFCC80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.assignment_outlined, size: 12, color: Color(0xFFE65100)),
                            const SizedBox(width: 4),
                            Text(
                              '$shortfall to Indent',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFE65100),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Quantity Stepper
              Container(
                height: 36,
                decoration: BoxDecoration(
                  color: _surfaceAlt.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _stroke),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 16, color: _ink900),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () => notifier.decrement(item.id),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '${item.quantity}',
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add, size: 16, color: _ink900),
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      onPressed: () => notifier.increment(item.id),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
