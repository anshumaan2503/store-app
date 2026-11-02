import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/repositories/store_receive_repository.dart';
import 'stock_refill_request_controller.dart';
import 'store_items_controller.dart';
import 'store_rack_controller.dart';

class ReceivePagedResult {
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  const ReceivePagedResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

@immutable
class ReceivePagedQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;

  const ReceivePagedQuery({
    this.page = 1,
    this.limit = 12,
    this.search = '',
    this.sort = '-createdAt',
  });

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "sort": sort,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReceivePagedQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort;

  @override
  int get hashCode => Object.hash(page, limit, search, sort);
}

final receivePagedStreamProvider = StreamProvider.autoDispose
    .family<ReceivePagedResult, ReceivePagedQuery>((ref, q) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<ReceivePagedResult>();
      Timer? timeoutTimer;

      int asInt(dynamic v, int fallback) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse('$v') ?? fallback;
      }

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is! Map) return;

          final rowsRaw = (data['rows'] as List?) ?? const [];
          final list =
              rowsRaw.map((e) {
                final m = Map<String, dynamic>.from(e as Map);
                return m;
              }).toList();

          if (!ctrl.isClosed) {
            ctrl.add(
              ReceivePagedResult(
                rows: list,
                total: asInt(data['total'], list.length),
                page: asInt(data['page'], q.page),
                limit: asInt(data['limit'], q.limit),
              ),
            );
          }
        } catch (e, st) {
          debugPrint('store:findAllReceivePaged handler error: $e\n$st');
        }
      }

      socket.on('store:findAllReceivePaged', handler);
      socket.emit('store:findAllReceivePaged', q.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!ctrl.isClosed) {
          ctrl.add(
            ReceivePagedResult(
              rows: const [],
              total: 0,
              page: q.page,
              limit: q.limit,
            ),
          );
        }
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findAllReceivePaged', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final findAllReceiveDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<Map<String, dynamic>>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = <Map<String, dynamic>>[];
          for (var element in data) {
            if (element is Map) {
              list.add(Map<String, dynamic>.from(element));
            }
          }
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (e) {
          debugPrint('store:findAllReceive handler error: $e');
        }
      }

      socket.on('store:findAllReceive', handler);
      socket.emit('store:findAllReceive', {});

      ref.onDispose(() {
        socket.off('store:findAllReceive', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final storeReceiveControllerProvider = Provider(
  (ref) => StoreReceiveController(ref),
);

class StoreReceiveController extends StateNotifier<bool> {
  final Ref ref;
  StoreReceiveController(this.ref) : super(false);

  Future<Map<String, dynamic>> receiveItem({
    required String itemId,
    required int qty,
    required String receivedBy,
    required String rackId,
    String? remark,
    String? indentId,
    double? unitPrice,
    String? grnId,
    String? grnNo,
    bool? autoIssue,
  }) async {
    state = true;

    bool ok = false;
    String id = "";
    final res = await ref
        .read(storeReceiveRepositoryProvider)
        .receiveItem(
          itemId: itemId,
          qty: qty,
          receivedBy: receivedBy,
          remark: remark,
          rackId: rackId,
          indentId: indentId,
          unitPrice: unitPrice,
          grnId: grnId,
          grnNo: grnNo,
          autoIssue: autoIssue,
        );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      id = data['id'];
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Received' : 'Receive failed'),
      );
      if (ok) {
        ref.invalidate(refillRequestsListProvider);
        ref.invalidate(pendingRefillRequestsCountProvider);
        ref.invalidate(storeAllRackPagedStreamProvider);
        if (itemId.isNotEmpty) {
          ref.invalidate(uncreditedApprovedIndentsProvider(itemId));
          ref.invalidate(itemFindOneStreamProvider(itemId));
        }
        ref.invalidate(itemPagedStreamProvider);
      }
    });

    state = false;
    return {"id": id, "ok": ok};
  }

  Future<Map<String, dynamic>> uploadReceiveImageBase64({
    required String receiveId,
    required String dataUrl,
  }) async {
    state = true;

    bool ok = false;
    String imageUrl = "";

    String? error;

    final res = await ref
        .read(storeReceiveRepositoryProvider)
        .uploadReceiveImageBase64(receiveId: receiveId, dataUrl: dataUrl);

    res.fold((f) {
      error = f.message;
    }, (data) {
      ok = data['success'] == true;
      imageUrl =
          (data['imageUrl'] ?? data['entity']?['imageUrl'] ?? '').toString();
    });

    state = false;

    return {"ok": ok, "imageUrl": imageUrl, "error": error};
  }
}
