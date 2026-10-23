import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../auth/controllers/users_controller.dart';
import '../../../../components/motion_widgets.dart';
import '../../../controllers/store_cart_controller.dart';
import '../../../domains/models/store_items_model.dart';
import '../../widgets/store_ui_state_widgets.dart';
import 'find_item_page.dart';
import 'item_scan_page.dart';
import 'qr_code/qr_code_print_item_page.dart';
import 'stock_refill_request_create_page.dart';
import '../new_store_home_page.dart';
import 'item_activity_breakdown_sheet.dart';
import 'item_rate_history_sheet.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _accentMint = Color(0xFFB6D3CC);

enum ItemCardAction { edit, transferRack, transferItem, delete }

class ItemListCard extends StatelessWidget {
  const ItemListCard({
    super.key,
    required this.item,
    required this.canEdit,
    this.canDelete = false,
    this.canFind = false,
    required this.hasQty,
    required this.onEdit,
    this.onDelete,
    this.onTransferRack,
    this.onTransferItem,
    this.index = 0,
    this.stockMetricsKey,
    this.editButtonKey,
    this.detailsKey,
    this.actionsKey,
    this.addToCartKey,
  });

  final StoreItemsModel item;
  final bool canEdit;
  final bool canDelete;
  final bool canFind;
  final bool hasQty;
  final int index;
  final Key? stockMetricsKey;
  final Key? editButtonKey;
  final Key? detailsKey;
  final Key? actionsKey;
  final Key? addToCartKey;

  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTransferRack; // only when qty == 0
  final VoidCallback? onTransferItem; // only when qty > 0

  void _showItemImagePreview(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (_) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stroke),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Item Image Preview',
                          style: TextStyle(
                            color: _ink900,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded, color: _ink900),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _stroke),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.65,
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(20),
                    ),
                    child: Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: SizedBox.expand(
                          child: Image.network(
                            Uri.encodeFull(imageUrl),
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (_, __, ___) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white70,
                                  size: 42,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl.toString().trim().isNotEmpty;
    final isOut = item.stockAvailableQuantity <= 0;
    final isMobile = MediaQuery.of(context).size.width < 700;

    // Low-stock alert bell indicator
    Widget? stockBell;
    final availQty = item.stockAvailableQuantity;
    final totalQty = item.totalStockQuantity;
    final bool isItemMaxReached = item.maxCapacity > 0 &&
        availQty >= item.maxCapacity;

    if (availQty <= 0) {
      stockBell = Tooltip(
        message: 'Out of stock — Click to raise indent',
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StockRefillRequestCreatePage(item: item),
              ),
            );
          },
          child: const Padding(
            padding: EdgeInsets.all(4.0),
            child: Icon(
              Icons.notifications_active,
              size: 16,
              color: Color(0xFFC62828),
            ),
          ),
        ),
      );
    } else {
      final lowStockThreshold = item.minStockQuantity > 0
          ? item.minStockQuantity
          : ((totalQty * 0.1) < 1 ? 1 : (totalQty * 0.1));
      if (availQty <= lowStockThreshold) {
        stockBell = Tooltip(
          message: 'Near out of stock — Click to raise indent',
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StockRefillRequestCreatePage(item: item),
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(4.0),
              child: Icon(
                Icons.notifications_active,
                size: 16,
                color: Color(0xFFF9A825),
              ),
            ),
          ),
        );
      }
    }

    final cardContent = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ItemScanPage(
                initialItemId: item.id,
                canEdit: canEdit,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _stroke.withValues(alpha: 0.9),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 10,
                offset: Offset(0, 3),
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
          // Item Image / Icon Container
          SizedBox(
            width: 48,
            height: 48,
            child: Container(
              decoration: BoxDecoration(
                color: _accentMint.withValues(alpha: .40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasImage
                  ? InkWell(
                      onTap: () => _showItemImagePreview(
                        context,
                        item.imageUrl.toString().trim(),
                      ),
                      child: Image.network(
                        item.imageUrl.toString().trim(),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                          Icons.inventory_2_rounded,
                          color: _ink900,
                          size: 22,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.inventory_2_rounded,
                      color: _ink900,
                      size: 22,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + Status Chip + Low-Stock Bell
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        item.itemName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Consumer(
                      builder: (context, ref, _) {
                        final user = ref.watch(userFindOneDataStreamProvider).value;
                        final canRaise = user?.canIndentRaise ?? false;
                        if (!canRaise) return const SizedBox.shrink();

                        return Tooltip(
                          message: isItemMaxReached
                              ? 'Maximum quantity reached (${item.maxCapacity}) — cannot raise indent'
                              : 'Raise Indent Request',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: isItemMaxReached
                                ? () {
                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: const Color(0xFFC62828),
                                        content: Text(
                                          'Item "${item.itemName}" has reached its maximum quantity of ${item.maxCapacity}. Manual indent request cannot be generated.',
                                        ),
                                      ),
                                    );
                                  }
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            StockRefillRequestCreatePage(item: item),
                                      ),
                                    );
                                  },
                            child: Container(
                              padding: const EdgeInsets.all(3.5),
                              decoration: BoxDecoration(
                                color: isItemMaxReached
                                    ? const Color(0xFFF5F5F5)
                                    : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isItemMaxReached
                                      ? const Color(0xFFE0E0E0)
                                      : const Color(0xFFBFDBFE),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                isItemMaxReached
                                    ? Icons.block_rounded
                                    : Icons.post_add_rounded,
                                size: 15,
                                color: isItemMaxReached
                                    ? const Color(0xFF9E9E9E)
                                    : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    if (stockBell != null) ...[
                      const SizedBox(width: 4),
                      stockBell,
                    ],
                    const SizedBox(width: 6),
                    StockStatusChip(
                      availableQty: item.stockAvailableQuantity,
                      minStock:
                          item.minStockQuantity > 0
                              ? item.minStockQuantity
                              : null,
                      isIndentReady: item.isIndentReady,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 5),

                // Code + Category tags row
                Wrap(
                  key: detailsKey,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Item Code Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceAlt,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        item.itemCode,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _ink900,
                        ),
                      ),
                    ),

                    if (item.minStockQuantity > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFE0B2),
                          ),
                        ),
                        child: Text(
                          'Min: ${item.minStockQuantity}',
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE65100),
                          ),
                        ),
                      ),

                    if (item.isScrap)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFFFCDD2),
                          ),
                        ),
                        child: const Text(
                          'SCRAP',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFC62828),
                          ),
                        ),
                      ),

                    if (item.categoryLabel.isNotEmpty)
                      Text(
                        item.categoryLabel,
                        style: const TextStyle(
                          color: _ink700,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),

                    if (item.unit.isNotEmpty)
                      Text(
                        '• ${item.unit}',
                        style: const TextStyle(
                          color: _ink600,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Stock Metrics Row
                Wrap(
                  key: stockMetricsKey,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // 1. Available Badge (Deducts active in-cart units in real time)
                    Consumer(
                      builder: (context, ref, _) {
                        final globalInCart = ref.watch(globalInCartProvider);
                        final globalQty = globalInCart[item.id] ?? 0;
                        final myCartQty = ref.watch(storeCartProvider).findById(item.id)?.quantity ?? 0;
                        final inCartQty = globalQty > 0 ? globalQty : myCartQty;
                        final effectiveAvailable = (item.stockAvailableQuantity - inCartQty).clamp(0, 999999);
                        final isOutEffective = effectiveAvailable <= 0;

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isOutEffective
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xE8E8F5E9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOutEffective
                                    ? Icons.cancel_outlined
                                    : Icons.check_circle_outline,
                                size: 11,
                                color: isOutEffective
                                    ? const Color(0xFFC62828)
                                    : const Color(0xFF2E7D32),
                              ),
                              const SizedBox(width: 3.5),
                              Text(
                                'Available: $effectiveAvailable',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: isOutEffective
                                      ? const Color(0xFFC62828)
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // 2. In Cart Badge (Global in-cart count across all departments/accounts)
                    Consumer(
                      builder: (context, ref, _) {
                        final globalInCart = ref.watch(globalInCartProvider);
                        final globalQty = globalInCart[item.id] ?? 0;
                        final myCartQty = ref.watch(storeCartProvider).findById(item.id)?.quantity ?? 0;
                        final inCartQty = globalQty > 0 ? globalQty : myCartQty;
                        final hasInCart = inCartQty > 0;

                        return Tooltip(
                          message: hasInCart
                              ? '$inCartQty unit(s) in cart across departments • Click to view who & which dept'
                              : 'No units currently in any cart • Click to view details',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () {
                                showItemActivityBreakdownSheet(
                                  context,
                                  item: item,
                                  initialTab: ItemBreakdownTab.inCart,
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: hasInCart
                                      ? const Color(0xFFE3F2FD)
                                      : _surfaceAlt.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: hasInCart
                                        ? const Color(0xFF90CAF9)
                                        : _stroke,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.shopping_cart_outlined,
                                      size: 11,
                                      color: hasInCart
                                          ? const Color(0xFF1565C0)
                                          : _ink700,
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      'In Cart: $inCartQty',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: hasInCart
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                        color: hasInCart
                                            ? const Color(0xFF1565C0)
                                            : _ink700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // 3. Requested Badge (Soft-locked / pending department requests)
                    Tooltip(
                      message: item.stockRequestedQuantity > 0
                          ? '${item.stockRequestedQuantity} ${item.unit.isEmpty ? "units" : item.unit} requested • Click to see who requested'
                          : 'No pending department requests • Click to view details',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            showItemActivityBreakdownSheet(
                              context,
                              item: item,
                              initialTab: ItemBreakdownTab.requested,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.stockRequestedQuantity > 0
                                  ? const Color(0xFFFFF3E0)
                                  : _surfaceAlt.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.stockRequestedQuantity > 0
                                    ? const Color(0xFFFFB74D)
                                    : _stroke,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.stockRequestedQuantity > 0) ...[
                                  const Icon(
                                    Icons.hourglass_top_rounded,
                                    size: 11,
                                    color: Color(0xFFE65100),
                                  ),
                                  const SizedBox(width: 3.5),
                                ],
                                Text(
                                  'Requested: ${item.stockRequestedQuantity}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: item.stockRequestedQuantity > 0
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: item.stockRequestedQuantity > 0
                                        ? const Color(0xFFE65100)
                                        : _ink700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 4. Ready for Issue Badge (Approved requests waiting for physical issue at store counter)
                    Tooltip(
                      message: item.stockIssueQuantity > 0
                          ? '${item.stockIssueQuantity} ${item.unit.isEmpty ? "units" : item.unit} ready at counter • Click to see recipient details'
                          : 'No items queued for issue • Click to view details',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            showItemActivityBreakdownSheet(
                              context,
                              item: item,
                              initialTab: ItemBreakdownTab.readyForIssue,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: item.stockIssueQuantity > 0
                                  ? const Color(0xFFEDE7F6)
                                  : _surfaceAlt.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.stockIssueQuantity > 0
                                    ? const Color(0xFFB39DDB)
                                    : _stroke,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (item.stockIssueQuantity > 0) ...[
                                  const Icon(
                                    Icons.outbox_rounded,
                                    size: 11,
                                    color: Color(0xFF5E35B1),
                                  ),
                                  const SizedBox(width: 3.5),
                                ],
                                Text(
                                  isMobile
                                      ? 'Ready: ${item.stockIssueQuantity}'
                                      : 'Ready for Issue: ${item.stockIssueQuantity}',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: item.stockIssueQuantity > 0
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: item.stockIssueQuantity > 0
                                        ? const Color(0xFF5E35B1)
                                        : _ink700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 5. Activity & Lifecycle Details Trigger Button
                    Tooltip(
                      message: 'View all department activity, cart holds, requisitions & decisions',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: () {
                            showItemActivityBreakdownSheet(
                              context,
                              item: item,
                              initialTab: ItemBreakdownTab.inCart,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _surfaceAlt.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _stroke),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.history_edu_rounded,
                                  size: 11,
                                  color: _ink700,
                                ),
                                SizedBox(width: 3.5),
                                Text(
                                  'Details',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: _ink700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Total Badge (Preserved - hidden for now as instructed)
                    if (false)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceAlt.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _stroke),
                        ),
                        child: Text(
                          'Total: ${item.totalStockQuantity}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _ink700,
                          ),
                        ),
                      ),

                    if (item.maxCapacity > 0)
                      Text(
                        item.stockAvailableQuantity >= item.maxCapacity
                            ? 'Max: ${item.maxCapacity} (Reached)'
                            : 'Max: ${item.maxCapacity}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.stockAvailableQuantity >= item.maxCapacity
                              ? const Color(0xFFC62828)
                              : _ink600,
                          fontWeight: item.stockAvailableQuantity >= item.maxCapacity
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            _buildActionButtons(context),
          ],
        ],
      ),
      if (isMobile) ...[
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 0.5, color: _stroke),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: _buildActionButtons(context),
        ),
      ],
    ],
  ),
),
),
);

    if (index < 12) {
      return StaggeredFadeIn(
        index: index,
        offsetMs: 35,
        child: RepaintBoundary(child: cardContent),
      );
    }

    return RepaintBoundary(child: cardContent);
  }

  Widget _buildActionButtons(BuildContext context) {
    return Wrap(
      key: actionsKey,
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(userFindOneDataStreamProvider).value;
            final canIssue = user != null && (
                user.isSuperAdmin ||
                user.appWorks.contains("storeadmin") ||
                user.appWorks.contains("storissueadd")
            );
            if (!canIssue) return const SizedBox.shrink();

            final cart = ref.watch(storeCartProvider);
            final inCart = cart.findById(item.id);

            return _ActionIconButton(
              key: addToCartKey,
              icon: inCart != null
                  ? Icons.shopping_cart_rounded
                  : Icons.add_shopping_cart_rounded,
              tooltip: inCart != null
                  ? 'In Cart (${inCart.quantity}) — Click to add +1'
                  : 'Add to Requisition Cart',
              color: inCart != null ? const Color(0xFFE8F5E9) : null,
              iconColor: inCart != null ? const Color(0xFF2E7D32) : null,
              onTap: () {
                final added = ref.read(storeCartProvider.notifier).addItem(
                  item,
                  qty: 1,
                  onStockError: (err) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(err),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
                if (added) {
                  final globalInCart = ref.read(globalInCartProvider);
                  final globalQty = globalInCart[item.id] ?? 0;
                  final eff = (item.stockAvailableQuantity - globalQty).clamp(0, 999999);
                  final msg = eff <= 0
                      ? 'Added ${item.itemName} to Cart (Out of stock — routed to Indent Draft)'
                      : 'Added ${item.itemName} to Requisition Cart';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(msg),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
            );
          },
        ),
        if (canEdit)
          _ActionIconButton(
            key: editButtonKey,
            icon: Icons.edit_outlined,
            tooltip: 'Edit Item',
            onTap: onEdit,
          ),
        _ActionIconButton(
          icon: Icons.qr_code_2_rounded,
          tooltip: 'QR Code',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => QRCodePrintItemPage(
                  storeItemList: [item],
                ),
              ),
            );
          },
        ),
        if (canFind)
          _ActionIconButton(
            icon: Icons.location_searching_rounded,
            tooltip: 'Find Location',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindItemPage(
                    isStandalone: true,
                    initialItem: item,
                  ),
                ),
              );
            },
          ),
        Consumer(
          builder: (context, ref, _) {
            final user = ref.watch(userFindOneDataStreamProvider).value;
            final canViewRates = user != null && (
              user.isSuperAdmin ||
              user.appWorks.contains("storeadmin") ||
              user.appWorks.contains("storeitemrateview")
            );
            if (!canViewRates) return const SizedBox.shrink();

            return _ActionIconButton(
              icon: Icons.currency_rupee_rounded,
              tooltip: 'Rate History',
              onTap: () {
                showItemRateHistorySheet(context, item: item);
              },
            );
          },
        ),
      ],
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          splashColor: _ink900.withValues(alpha: 0.1),
          highlightColor: Colors.transparent,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color ?? _surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _stroke),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor ?? _ink900, size: 17),
          ),
        ),
      ),
    );
  }
}

