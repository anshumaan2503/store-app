import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/store_notification_controller.dart';
import '../../../controllers/stock_refill_request_controller.dart';
import '../../../domains/models/store_notification_model.dart';
import '../items/stock_refill_request_create_page.dart';

const _ink900 = Color(0xFF282321);
const _ink700 = Color(0xFF4D4542);
const _ink600 = Color(0xFF867471);
const _surface = Color(0xFFFFFFFF);
const _surfaceAlt = Color(0xFFFFF4E2);
const _stroke = Color(0xFFDFE1D6);
const _yellowAlert = Color(0xFFF9A825);
const _dangerRed = Color(0xFFE53935);

/// Bell button placed in the Store header shell.
/// Shows unread badge count and opens the StoreNotificationsSheet on tap.
class StoreNotificationBellButton extends ConsumerWidget {
  const StoreNotificationBellButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadAv = ref.watch(storeUnreadNotificationCountProvider);
    final unreadCount = unreadAv.value ?? 0;

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _stroke),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const StoreNotificationsSheet(),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Icon(
                unreadCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_outlined,
                color: unreadCount > 0 ? _yellowAlert : _ink900,
                size: 20,
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: _yellowAlert,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Slide-over notification list sheet for Store inventory notifications.
class StoreNotificationsSheet extends ConsumerStatefulWidget {
  const StoreNotificationsSheet({super.key});

  @override
  ConsumerState<StoreNotificationsSheet> createState() =>
      _StoreNotificationsSheetState();
}

class _StoreNotificationsSheetState
    extends ConsumerState<StoreNotificationsSheet> {
  @override
  void initState() {
    super.initState();
    // Refresh notifications quietly in background on opening sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(storeNotificationControllerProvider.notifier).refresh();
    });
  }

  Future<void> _openRefillRequest(StoreNotificationModel notif) async {
    // Mark as read when user acts upon it
    if (!notif.isRead) {
      ref
          .read(storeNotificationControllerProvider.notifier)
          .markAsRead(notif.id);
    }

    final itemModel = notif.toItemModel();

    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StockRefillRequestCreatePage(item: itemModel),
      ),
    );

    if (ok == true && mounted) {
      ref.read(storeNotificationControllerProvider.notifier).refresh();
      ref.invalidate(pendingRefillRequestsCountProvider);
      ref.invalidate(refillRequestsListProvider);
    }
  }

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required IconData icon,
    required String label,
  }) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: _dangerRed,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLeft) ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white, size: 22),
          if (isLeft) ...[
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifsAv = ref.watch(storeNotificationListProvider);
    final unreadAv = ref.watch(storeUnreadNotificationCountProvider);
    final unreadCount = unreadAv.value ?? 0;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: const BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x28000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _stroke,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _yellowAlert.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: _yellowAlert,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'Notifications',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _ink900,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _yellowAlert.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _yellowAlert.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                '$unreadCount unread',
                                style: const TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 10.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (unreadCount > 0)
                      Tooltip(
                        message: 'Mark all notifications as read',
                        child: TextButton.icon(
                          onPressed: () {
                            ref
                                .read(storeNotificationControllerProvider.notifier)
                                .markAllAsRead();
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'All notifications marked as read',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: _ink700,
                          ),
                          label: Text(
                            MediaQuery.of(context).size.width < 400
                                ? 'Mark read'
                                : 'Mark all read',
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: _ink700),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),

              // Instruction Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                color: _surfaceAlt.withValues(alpha: 0.45),
                child: const Row(
                  children: [
                    Icon(Icons.swipe_rounded, size: 14, color: _ink600),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Slide left or right to remove • Tap card or button to mark as read',
                        style: TextStyle(
                          color: _ink600,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, color: _stroke),

              // Notification Content
              Expanded(
                child: notifsAv.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFC62828),
                            size: 32,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Failed to load notifications: $e',
                            style: const TextStyle(
                              color: _ink700,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => ref
                                .read(
                                    storeNotificationControllerProvider.notifier)
                                .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: _surfaceAlt.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _stroke),
                                ),
                                child: const Icon(
                                  Icons.notifications_none_rounded,
                                  color: _ink600,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No Notifications',
                                style: TextStyle(
                                  color: _ink900,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'All caught up! Stock alerts, arrival notices, and auto-issue updates will appear here.',
                                style: TextStyle(
                                  color: _ink600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              FilledButton.tonalIcon(
                                onPressed: () => ref
                                    .read(storeNotificationControllerProvider
                                        .notifier)
                                    .refresh(),
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
                      itemCount: notifications.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return Dismissible(
                          key: ValueKey('notification_${notif.id}'),
                          direction: DismissDirection.horizontal,
                          background: _buildSwipeBackground(
                            alignment: Alignment.centerLeft,
                            icon: Icons.delete_outline_rounded,
                            label: 'Remove',
                          ),
                          secondaryBackground: _buildSwipeBackground(
                            alignment: Alignment.centerRight,
                            icon: Icons.delete_outline_rounded,
                            label: 'Remove',
                          ),
                          onDismissed: (direction) {
                            ref
                                .read(storeNotificationControllerProvider.notifier)
                                .removeNotification(notif.id);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Removed "${notif.itemName.isNotEmpty ? notif.itemName : notif.title}"',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                          },
                          child: _NotificationCard(
                            notification: notif,
                            onCardTap: () {
                              if (!notif.isRead) {
                                ref
                                    .read(storeNotificationControllerProvider
                                        .notifier)
                                    .markAsRead(notif.id);
                              }
                            },
                            onMarkAsRead: () {
                              ref
                                  .read(storeNotificationControllerProvider
                                      .notifier)
                                  .markAsRead(notif.id);
                            },
                            onRemove: () {
                              ref
                                  .read(storeNotificationControllerProvider
                                      .notifier)
                                  .removeNotification(notif.id);
                              ScaffoldMessenger.of(context).clearSnackBars();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Removed "${notif.itemName.isNotEmpty ? notif.itemName : notif.title}"',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            onRefillTap: () => _openRefillRequest(notif),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onCardTap,
    required this.onMarkAsRead,
    required this.onRemove,
    required this.onRefillTap,
  });

  final StoreNotificationModel notification;
  final VoidCallback onCardTap;
  final VoidCallback onMarkAsRead;
  final VoidCallback onRemove;
  final VoidCallback onRefillTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final isStockArrived = notification.type == 'STOCK_ARRIVED';
    final isAutoIssue = notification.type == 'AUTO_ISSUE_RAISED';

    final Color themeColor = isStockArrived
        ? const Color(0xFF2E7D32)
        : (isAutoIssue ? const Color(0xFF1565C0) : _yellowAlert);

    final IconData themeIcon = isStockArrived
        ? Icons.inventory_2_rounded
        : (isAutoIssue
            ? Icons.assignment_turned_in_rounded
            : Icons.notifications_active_rounded);

    final Color unreadBgColor = isStockArrived
        ? const Color(0xFFE8F5E9).withValues(alpha: 0.5)
        : (isAutoIssue
            ? const Color(0xFFE3F2FD).withValues(alpha: 0.5)
            : const Color(0xFFFFFDE7).withValues(alpha: 0.35));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: isUnread ? unreadBgColor : _surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnread ? themeColor.withValues(alpha: 0.6) : _stroke,
              width: isUnread ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isUnread
                    ? themeColor.withValues(alpha: 0.1)
                    : const Color(0x06000000),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Type & Title & Read status
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isUnread ? themeColor : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    themeIcon,
                    color: themeColor,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    notification.title,
                    style: TextStyle(
                      color: _ink900,
                      fontWeight:
                          isUnread ? FontWeight.w900 : FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (notification.createdAt != null)
                    Text(
                      _formatDate(notification.createdAt!),
                      style: const TextStyle(
                        color: _ink600,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Item details
              Row(
                children: [
                  Expanded(
                    child: Text(
                      notification.itemName.isNotEmpty
                          ? notification.itemName
                          : 'Item',
                      style: const TextStyle(
                        color: _ink900,
                        fontWeight: FontWeight.w900,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  if (notification.itemCode.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceAlt.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _stroke),
                      ),
                      child: Text(
                        notification.itemCode,
                        style: const TextStyle(
                          color: _ink900,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 6),

              // Message
              Text(
                notification.message,
                style: const TextStyle(
                  color: _ink700,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),

              const SizedBox(height: 12),

              // Action Row (Left: Read status & Mark as read & Remove, Right: Primary Action)
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Left Side Actions
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isUnread) ...[
                        InkWell(
                          onTap: onMarkAsRead,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 13,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Mark as read',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceAlt.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.done_all_rounded,
                                size: 13,
                                color: _ink600,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Read',
                                style: TextStyle(
                                  color: _ink600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        color: _ink600,
                        tooltip: 'Remove notification',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ],
                  ),

                  // Right Side Primary Action
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStockArrived) ...[
                        InkWell(
                          onTap: onMarkAsRead,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF2E7D32)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 14,
                                  color: Color(0xFF2E7D32),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Stock in Rack',
                                  style: TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (isAutoIssue) ...[
                        InkWell(
                          onTap: onMarkAsRead,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.assignment_turned_in_outlined,
                                  size: 14,
                                  color: Color(0xFF1565C0),
                                ),
                                SizedBox(width: 5),
                                Text(
                                  'Auto-Issue Created',
                                  style: TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (notification.hasPendingRefill) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F2ED),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _stroke),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.hourglass_top_rounded,
                                size: 14,
                                color: _ink600,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Indent Pending',
                                style: TextStyle(
                                  color: _ink600,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        FilledButton.icon(
                          onPressed: onRefillTap,
                          style: FilledButton.styleFrom(
                            backgroundColor: _ink900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 7,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1.5,
                          ),
                          icon: const Icon(
                            Icons.add_shopping_cart_rounded,
                            size: 14,
                          ),
                          label: const Text(
                            'Raise Indent',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
