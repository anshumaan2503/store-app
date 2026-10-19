import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_scrap_model.dart';
import '../domains/repositories/store_scrap_repository.dart';

class ScrapPagedResult {
  final List<StoreScrapModel> rows;
  final int total;
  final int page;
  final int limit;
  const ScrapPagedResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

@immutable
class ScrapPagedQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;

  const ScrapPagedQuery({
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
      other is ScrapPagedQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort;

  @override
  int get hashCode => Object.hash(page, limit, search, sort);
}

final scrapPagedStreamProvider = StreamProvider.autoDispose
    .family<ScrapPagedResult, ScrapPagedQuery>((ref, q) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<ScrapPagedResult>();

      int asInt(dynamic v, int fallback) {
        if (v is int) return v;
        if (v is num) return v.toInt();
        return int.tryParse('$v') ?? fallback;
      }

      void handler(dynamic data) {
        try {
          if (data is! Map) return;

          final rowsRaw = (data['rows'] as List?) ?? const [];
          final list =
              rowsRaw.map((e) {
                final m = StoreScrapModel.fromMap(e);
                return m;
              }).toList();

          ctrl.add(
            ScrapPagedResult(
              rows: list,
              total: asInt(data['total'], list.length),
              page: asInt(data['page'], q.page),
              limit: asInt(data['limit'], q.limit),
            ),
          );
        } catch (e, st) {
          debugPrint('store:findAllScrapPaged handler error: $e\n$st');
        }
      }

      socket.on('store:findAllScrapPaged', handler);
      socket.emit('store:findAllScrapPaged', q.toJson());

      // prevent infinite loading
      ctrl.add(
        ScrapPagedResult(
          rows: const [],
          total: 0,
          page: q.page,
          limit: q.limit,
        ),
      );

      ref.onDispose(() {
        socket.off('store:findAllScrapPaged', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final findAllScrapDataStreamProvider =
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
        } catch (e, st) {
          debugPrint('store:findAllScrap handler error: $e\n$st');
        }
      }

      socket.on('store:findAllScrap', handler);
      socket.emit('store:findAllScrap', {});

      ref.onDispose(() {
        socket.off('store:findAllScrap', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final storeScrapControllerProvider = Provider(
  (ref) => StoreScrapController(ref),
);

class StoreScrapController extends StateNotifier<bool> {
  final Ref ref;
  StoreScrapController(this.ref) : super(false);

  Future<bool> scrapItem({
    required String itemId,
    required int qty,
    required String createdBy,
    required String rackId,
    required String roomId,
    String? remark,
  }) async {
    state = true;

    bool ok = false;
    final res = await ref
        .read(storeScrapRepositoryProvider)
        .scrapItem(
          itemId: itemId,
          qty: qty,
          createdBy: createdBy,
          remark: remark,
          rackId: rackId,
          roomId: roomId,
        );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Scrapd' : 'Scrap failed'));
    });

    state = false;
    return ok;
  }
}
