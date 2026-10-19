import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domains/models/store_notification_model.dart';
import '../domains/repositories/store_notification_repository.dart';

/// Manages notification state with instant optimistic updates
final storeNotificationControllerProvider = StateNotifierProvider<
    StoreNotificationController, AsyncValue<List<StoreNotificationModel>>>(
  (ref) => StoreNotificationController(ref),
);

/// Exposes the notification list AsyncValue (watched by StoreNotificationsSheet)
final storeNotificationListProvider =
    Provider<AsyncValue<List<StoreNotificationModel>>>((ref) {
  return ref.watch(storeNotificationControllerProvider);
});

/// Exposes the live unread count (synchronous & instant on optimistic updates)
final storeUnreadNotificationCountProvider = Provider<AsyncValue<int>>((ref) {
  final notifsAv = ref.watch(storeNotificationControllerProvider);
  return notifsAv.whenData((list) => list.where((n) => !n.isRead).length);
});

class StoreNotificationController
    extends StateNotifier<AsyncValue<List<StoreNotificationModel>>> {
  final Ref _ref;
  bool _isFetching = false;

  StoreNotificationController(this._ref) : super(const AsyncValue.loading()) {
    fetchNotifications();
  }

  Future<void> fetchNotifications({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!silent && !state.hasValue) {
      state = const AsyncValue.loading();
    }

    try {
      final repo = _ref.read(storeNotificationRepositoryProvider);
      final res = await repo.getNotifications();
      res.fold(
        (failure) {
          if (!state.hasValue) {
            state = AsyncValue.error(failure.message, failure.stackTrace);
          }
        },
        (data) {
          state = AsyncValue.data(data);
        },
      );
    } catch (e, st) {
      if (!state.hasValue) {
        state = AsyncValue.error(e.toString(), st);
      }
    } finally {
      _isFetching = false;
    }
  }

  void refresh() {
    fetchNotifications(silent: true);
  }

  Future<bool> markAsRead(String id) async {
    // 1. Optimistic in-memory update
    final current = state.value;
    if (current != null) {
      final updated = current.map((item) {
        if (item.id == id) {
          return item.copyWith(isRead: true, readAt: DateTime.now());
        }
        return item;
      }).toList();
      state = AsyncValue.data(updated);
    }

    // 2. Persist to backend
    final repo = _ref.read(storeNotificationRepositoryProvider);
    final res = await repo.markAsRead(id);
    return res.fold(
      (failure) => false,
      (success) => true,
    );
  }

  Future<bool> markAllAsRead() async {
    // 1. Optimistic in-memory update
    final current = state.value;
    if (current != null) {
      final updated = current.map((item) {
        return item.copyWith(isRead: true, readAt: DateTime.now());
      }).toList();
      state = AsyncValue.data(updated);
    }

    // 2. Persist to backend
    final repo = _ref.read(storeNotificationRepositoryProvider);
    final res = await repo.markAllAsRead();
    return res.fold(
      (failure) => false,
      (success) => true,
    );
  }

  Future<bool> removeNotification(String id) async {
    // 1. Optimistic in-memory removal
    final current = state.value;
    if (current != null) {
      final updated = current.where((item) => item.id != id).toList();
      state = AsyncValue.data(updated);
    }

    // 2. Persist to backend
    final repo = _ref.read(storeNotificationRepositoryProvider);
    final res = await repo.removeNotification(id);
    return res.fold(
      (failure) => false,
      (success) => true,
    );
  }
}
