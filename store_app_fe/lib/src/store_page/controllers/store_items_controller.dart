import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_items_model.dart';
import '../domains/models/item_rate_history_model.dart';
import '../domains/models/store_rack_model.dart';
import '../domains/repositories/store_items_repository.dart';

/* ---------------- Paged items stream ---------------- */

class ItemPagedResult {
  final List<StoreItemsModel> rows;
  final int total;
  final int page;
  final int limit;
  const ItemPagedResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

@immutable
class ItemPagedQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;
  final String? rackId;
  final String? categoryId;

  const ItemPagedQuery({
    this.page = 1,
    this.limit = 12,
    this.search = '',
    this.sort = '-createdAt',
    this.rackId,
    this.categoryId,
  });

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "sort": sort,
    if (rackId != null) "rackId": rackId,
    if (categoryId != null) "categoryId": categoryId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemPagedQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort &&
          other.rackId == rackId &&
          other.categoryId == categoryId;

  @override
  int get hashCode =>
      Object.hash(page, limit, search, sort, rackId, categoryId);
}

final itemAllPagedStreamProvider =
    StreamProvider.autoDispose<List<StoreItemsModel>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreItemsModel>> roomStream = StreamController(
        sync: true,
      );
      List<StoreItemsModel> returnValue = [];
      socketManager.getSocket().emit("store:findRealAllItemPaged", {});
      socketManager.getSocket().on("store:findRealAllItemPaged", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreItemsModel.fromMap(element));
        }
        roomStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });

final itemPagedStreamProvider = StreamProvider.autoDispose
    .family<ItemPagedResult, ItemPagedQuery>((ref, q) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<ItemPagedResult>();

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
                final m = Map<String, dynamic>.from(e as Map);
                return StoreItemsModel.fromMap(m);
              }).toList();

          ctrl.add(
            ItemPagedResult(
              rows: list,
              total: asInt(data['total'], list.length),
              page: asInt(data['page'], q.page),
              limit: asInt(data['limit'], q.limit),
            ),
          );
        } catch (e, st) {
          debugPrint('store:findAllItemPaged handler error: $e\n$st');
        }
      }

      socket.on('store:findAllItemPaged', handler);
      socket.emit('store:findAllItemPaged', q.toJson());

      // prevent infinite loading
      ctrl.add(
        ItemPagedResult(rows: const [], total: 0, page: q.page, limit: q.limit),
      );

      ref.onDispose(() {
        socket.off('store:findAllItemPaged', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final itemScrapPagedStreamProvider = StreamProvider.autoDispose
    .family<ItemPagedResult, ItemPagedQuery>((ref, q) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<ItemPagedResult>();

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
                final m = Map<String, dynamic>.from(e as Map);
                return StoreItemsModel.fromMap(m);
              }).toList();

          ctrl.add(
            ItemPagedResult(
              rows: list,
              total: asInt(data['total'], list.length),
              page: asInt(data['page'], q.page),
              limit: asInt(data['limit'], q.limit),
            ),
          );
        } catch (e, st) {
          debugPrint('store:findScrapAllItemPaged handler error: $e\n$st');
        }
      }

      socket.on('store:findScrapAllItemPaged', handler);
      socket.emit('store:findScrapAllItemPaged', q.toJson());

      // prevent infinite loading
      ctrl.add(
        ItemPagedResult(rows: const [], total: 0, page: q.page, limit: q.limit),
      );

      ref.onDispose(() {
        socket.off('store:findScrapAllItemPaged', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final itemFindOneStreamProvider = StreamProvider.autoDispose.family<
  StoreItemsModel?,
  String
>((ref, itemId) async* {
  final socket = ref.watch(socketProvider).getSocket();
  final ctrl = StreamController<StoreItemsModel?>(sync: true);

  String? readOid(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;

    if (v is Map) {
      // Mongo Extended JSON: { "$oid": "..." }
      final oid = v[r'$oid'];
      if (oid != null) return oid.toString();

      // Sometimes nested: { "_id": { "$oid": ... } }
      final nested = v['_id'];
      if (nested != null) return readOid(nested);
    }

    return v.toString();
  }

  String? readDateIso(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v.toUtc().toIso8601String();
    if (v is String) {
      return DateTime.tryParse(v)?.toUtc().toIso8601String() ?? v;
    }

    if (v is Map) {
      // Mongo Extended JSON: { "$date": "..." }  or sometimes { "$date": 1700000000000 }
      final dv = v[r'$date'];
      if (dv is String) {
        return DateTime.tryParse(dv)?.toUtc().toIso8601String() ?? dv;
      }
      if (dv is int) {
        return DateTime.fromMillisecondsSinceEpoch(
          dv,
          isUtc: true,
        ).toIso8601String();
      }
    }

    return v.toString();
  }

  Map<String, dynamic> normalizeItemMap(Map raw) {
    final m = Map<String, dynamic>.from(raw);

    // normalize ids
    m['_id'] = readOid(m['_id']) ?? readOid(m['id']);
    m['itemNameId'] = readOid(m['itemNameId']);
    m['rackId'] = readOid(m['rackId']);
    m['categoryId'] = readOid(m['categoryId']);

    // normalize dates (only if your model expects String/ISO)
    final ca = readDateIso(m['createdAt']);
    final ua = readDateIso(m['updatedAt']);
    if (ca != null) m['createdAt'] = ca;
    if (ua != null) m['updatedAt'] = ua;

    return m;
  }

  Timer? timeout;

  void handler(dynamic data) {
    try {
      timeout?.cancel();

      // IMPORTANT: backend may emit null when not found
      if (data == null) {
        ctrl.add(null);
        return;
      }

      // your backend emits a single object (Map) directly
      if (data is! Map) {
        ctrl.addError(
          'Unexpected payload for store:findOneItem: ${data.runtimeType}',
        );
        return;
      }

      // keep compatibility with wrapped formats if you later change backend
      final raw = data['data'] ?? data['item'] ?? data;

      if (raw == null) {
        ctrl.add(null);
        return;
      }
      if (raw is! Map) {
        ctrl.addError(
          'Unexpected payload for store:findOneItem raw: ${raw.runtimeType}',
        );
        return;
      }

      final map = normalizeItemMap(raw);

      // Now filter works even with {"$oid": "..."}
      final rid = (map['_id'] ?? map['id'])?.toString();
      if (rid != null && rid.isNotEmpty && rid != itemId) return;

      ctrl.add(StoreItemsModel.fromMap(map));
    } catch (e, st) {
      ctrl.addError(e, st);
    }
  }

  socket.on('store:findOneItem', handler);
  socket.emit('store:findOneItem', {'id': itemId});

  // Prevent infinite loading if server never responds
  timeout = Timer(const Duration(seconds: 10), () {
    if (!ctrl.isClosed) ctrl.addError('Timeout: store:findOneItem');
  });

  ref.onDispose(() {
    timeout?.cancel();
    socket.off('store:findOneItem', handler);
    ctrl.close();
  });

  await for (final v in ctrl.stream) {
    yield v;
  }
});

/* ---------------- WS: same item racks ----------------
   Purpose: Transfer Item popup
   - fetch racks that already have SAME item mapped in DB
   Event:
     emit: store:findSameItemRacks { itemId }
     on:   store:findSameItemRacks { rows: [...] }
------------------------------------------------------ */

final sameItemRacksWithItemAndRackDataStreamProvider = StreamProvider.family
    .autoDispose<List<StoreRack>, Map<String, dynamic>>((ref, dto) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreRack>> sameItemRacksStream = StreamController(
        sync: true,
      );
      List<StoreRack> returnValue = [];
      socketManager.getSocket().emit("store:sameItemRacksWithItemAndRack", {
        'itemId': dto["itemId"],
        'rackId': dto["rackId"],
      });
      socketManager.getSocket().on("store:sameItemRacksWithItemAndRack", (
        data,
      ) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreRack.fromMap(element));
        }
        sameItemRacksStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in sameItemRacksStream.stream) {
        yield returnValue;
      }
    });

final sameItemRacksStreamProvider = StreamProvider.autoDispose
    .family<List<StoreRack>, String>((ref, itemId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreRack>>(sync: true);

      void handler(dynamic data) {
        try {
          List rawList = const [];

          // backend emits List
          if (data is List) {
            rawList = data;
          }
          // if someday you emit {rows:[...]}
          else if (data is Map && data['rows'] is List) {
            rawList = data['rows'] as List;
          } else {
            debugPrint(
              'store:sameItemRacks unexpected payload: ${data.runtimeType}',
            );
            return;
          }

          final racks =
              rawList
                  .whereType<Map>()
                  .map((e) => StoreRack.fromMap(Map<String, dynamic>.from(e)))
                  .toList();

          ctrl.add(racks);
        } catch (e, st) {
          debugPrint('store:sameItemRacks handler error: $e\n$st');
        }
      }

      // IMPORTANT: request/response should be different events (recommended)
      socket.on('store:sameItemRacks:res', handler);
      socket.emit('store:sameItemRacks:req', {"itemId": itemId});

      // prevent infinite loading
      ctrl.add(const <StoreRack>[]);

      ref.onDispose(() {
        socket.off('store:sameItemRacks:res', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final itemSubcategoryProvider = StreamProvider.autoDispose.family<
  List<StoreItemsModel>,
  String
>((ref, itemId) {
  final socket = ref.watch(socketProvider).getSocket();
  final ctrl = StreamController<List<StoreItemsModel>>(sync: true);

  String normalizeId(dynamic v) {
    if (v == null) return '';
    // handle mongo like { "$oid": "..." }
    if (v is Map && v.containsKey(r'$oid')) return v[r'$oid'].toString();
    return v.toString();
  }

  void handler(dynamic data) {
    // Ignore request echo payloads (Map like {"itemId": ...})
    if (data is Map && data['itemId'] != null) return;

    List<dynamic>? list;

    if (data is List) {
      list = data;
    } else if (data is Map && data['rows'] is List) {
      list = (data['rows'] as List).cast<dynamic>();
    } else {
      debugPrint(
        'store:itemsubcategory unexpected payload: ${data.runtimeType}',
      );
      return;
    }

    try {
      final items = <StoreItemsModel>[];

      for (final e in list) {
        if (e == null) continue;
        if (e is! Map) continue;

        final m = Map<String, dynamic>.from(e);

        // normalize _id -> id (important)
        if (m['id'] == null && m['_id'] != null) {
          m['id'] = normalizeId(m['_id']);
        }

        items.add(StoreItemsModel.fromMap(m));
      }

      ctrl.add(items);

      // Remove listener after we successfully got a real response list
      socket.off('store:itemsubcategory', handler);

      // Optional: close stream after 1 response (since this is request/response)
      ctrl.close();
    } catch (e, st) {
      debugPrint('store:itemsubcategory handler error: $e\n$st');
    }
  }

  socket.on('store:itemsubcategory', handler);
  socket.emit('store:itemsubcategory', {'itemId': itemId});

  ref.onDispose(() {
    socket.off('store:itemsubcategory', handler);
    if (!ctrl.isClosed) ctrl.close();
  });

  return ctrl.stream;
});

final parentcategoryItemAllDataStreamProvider = StreamProvider.family
    .autoDispose<List<StoreItemsModel>, String>((ref, itemId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreItemsModel>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final items = <StoreItemsModel>[];
          for (var element in data) {
            if (element is Map) {
              items.add(
                StoreItemsModel.fromMap(Map<String, dynamic>.from(element)),
              );
            }
          }
          if (!ctrl.isClosed) ctrl.add(items);
        } catch (e, st) {
          debugPrint('store:itemsubcategory handler error: $e\n$st');
        }
      }

      socket.on('store:itemsubcategory', handler);
      socket.emit('store:itemsubcategory', {'itemId': itemId});

      ref.onDispose(() {
        socket.off('store:itemsubcategory', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final oneItemAllDataStreamProvider = StreamProvider.family
    .autoDispose<List<StoreItemsModel>, String>((ref, itemId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreItemsModel>>();

      void handler(dynamic data) {
        try {
          final items = <StoreItemsModel>[];
          if (data is List) {
            for (var element in data) {
              if (element is Map) {
                items.add(
                  StoreItemsModel.fromMap(Map<String, dynamic>.from(element)),
                );
              }
            }
          } else if (data is Map) {
            items.add(
              StoreItemsModel.fromMap(Map<String, dynamic>.from(data)),
            );
          }
          if (!ctrl.isClosed) ctrl.add(items);
        } catch (e, st) {
          debugPrint('store:itemOne handler error: $e\n$st');
        }
      }

      socket.on('store:itemOne', handler);
      socket.emit('store:itemOne', {'itemId': itemId});

      ref.onDispose(() {
        socket.off('store:itemOne', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final findRackByItemIdDataStreamProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, itemId) {
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
          debugPrint('store:findRackByItemIdScrapData handler error: $e\n$st');
        }
      }

      socket.on('store:findRackByItemIdScrapData', handler);
      socket.emit('store:findRackByItemIdScrapData', {'itemId': itemId});

      ref.onDispose(() {
        socket.off('store:findRackByItemIdScrapData', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final scrapItemAllDataStreamProvider = StreamProvider.family
    .autoDispose<List<StoreRack>, Map<String, dynamic>>((ref, items) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreRack>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final racks = <StoreRack>[];
          for (var element in data) {
            if (element is Map) {
              racks.add(StoreRack.fromMap(Map<String, dynamic>.from(element)));
            }
          }
          if (!ctrl.isClosed) ctrl.add(racks);
        } catch (e, st) {
          debugPrint('store:scrapItemAllData handler error: $e\n$st');
        }
      }

      socket.on('store:scrapItemAllData', handler);
      socket.emit('store:scrapItemAllData', {
        'itemId': items['itemId'],
        'roomId': items['roomId'],
      });

      ref.onDispose(() {
        socket.off('store:scrapItemAllData', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final rackItemStreamProvider = StreamProvider.autoDispose
    .family<StoreItemsModel?, String>((ref, rackId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<StoreItemsModel?>();

      void handler(dynamic data) {
        try {
          if (data == null) {
            ctrl.add(null);
            return;
          }
          if (data is Map) {
            final m = Map<String, dynamic>.from(data);
            ctrl.add(StoreItemsModel.fromMap(m));
          }
        } catch (e) {
          debugPrint('store:rackItem handler error: $e');
        }
      }

      socket.on('store:rackItem', handler);
      socket.emit('store:rackItem', {"rackId": rackId});

      ctrl.add(null);

      ref.onDispose(() {
        socket.off('store:rackItem', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final rackItemListStreamProvider = StreamProvider.family
    .autoDispose<List<StoreItemsModel>, String>((ref, rackId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreItemsModel>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final items = <StoreItemsModel>[];
          for (var element in data) {
            if (element is Map) {
              items.add(
                StoreItemsModel.fromMap(Map<String, dynamic>.from(element)),
              );
            }
          }
          if (!ctrl.isClosed) ctrl.add(items);
        } catch (e, st) {
          debugPrint('store:findrackItemListData handler error: $e\n$st');
        }
      }

      socket.on('store:findrackItemListData', handler);
      socket.emit('store:findrackItemListData', {'rackId': rackId});

      ref.onDispose(() {
        socket.off('store:findrackItemListData', handler);
        if (!ctrl.isClosed) ctrl.close();
      });

      return ctrl.stream;
    });

final findOneRackStreamProvider = StreamProvider.autoDispose
    .family<StoreRack?, String>((ref, rackId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<StoreRack?>();

      void handler(dynamic data) {
        try {
          if (data == null) {
            ctrl.add(null);
            return;
          }
          if (data is Map) {
            final m = Map<String, dynamic>.from(data);
            ctrl.add(StoreRack.fromMap(m));
          }
        } catch (e) {
          debugPrint('store:rackItem handler error: $e');
        }
      }

      socket.on('store:findOneRack', handler);
      socket.emit('store:findOneRack', {"rackId": rackId});

      ctrl.add(null);

      ref.onDispose(() {
        socket.off('store:findOneRack', handler);
        ctrl.close();
      });
      return ctrl.stream;
    });

/* ---------------- Controller ---------------- */

final storeItemsControllerProvider = Provider(
  (ref) => StoreItemsController(ref),
);

class StoreItemsController extends StateNotifier<bool> {
  final Ref ref;
  StoreItemsController(this.ref) : super(false);

  Future<String?> createItems({required Map<String, dynamic> dto}) async {
    state = true;
    String? createdId;
    bool ok = false;
    final res = await ref.read(storeItemsRepositoryProvider).create(dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Created' : 'Create failed'),
      );
      if (ok) {
        final created = data['data'] as Map<String, dynamic>?;
        createdId = (created?['_id'] ?? created?['id'])?.toString();
      }
    });

    state = false;
    return createdId;
  }

  Future<bool> updateItems({
    required String id,
    required Map<String, dynamic> dto,
  }) async {
    state = true;

    bool ok = false;
    final res = await ref.read(storeItemsRepositoryProvider).update(id, dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Updated' : 'Update failed'),
      );
    });

    state = false;
    return ok;
  }

  Future<bool> deleteItems(String id) async {
    state = true;

    bool ok = false;
    final res = await ref.read(storeItemsRepositoryProvider).delete(id);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Deleted' : 'Delete failed'),
      );
    });

    state = false;
    return ok;
  }

  /// ✅ Transfer Rack (only allowed when item qty == 0 on backend)
  Future<bool> transferRack({
    required String itemId,
    required String toRackId,
  }) async {
    state = true;

    bool ok = false;
    final res = await ref
        .read(storeItemsRepositoryProvider)
        .transferRack(itemId: itemId, toRackId: toRackId);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = (data['status'] == true) || (data['ok'] == true);
      showSnackBar(
        data['msg']?.toString() ??
            (ok ? 'Rack Item Removed' : 'Transfer failed'),
      );
    });

    state = false;
    return ok;
  }

  Future<bool> removeRack({required String toRackId}) async {
    state = true;

    bool ok = false;
    final res = await ref
        .read(storeItemsRepositoryProvider)
        .removeRack(toRackId: toRackId);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = (data['status'] == true) || (data['ok'] == true);
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Rack Transfered' : 'Transfer failed'),
      );
    });

    state = false;
    return ok;
  }

  /// ✅ Transfer Item Qty (qty <= available qty enforced on backend)
  Future<bool> transferItem({
    required String itemId,
    required String fromRackId,
    required String toRackId,
    required int qty,
  }) async {
    state = true;

    bool ok = false;
    final res = await ref
        .read(storeItemsRepositoryProvider)
        .transferItem(
          itemId: itemId,
          fromRackId: fromRackId,
          toRackId: toRackId,
          qty: qty,
        );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = (data['status'] == true) || (data['ok'] == true);
      showSnackBar(
        data['msg']?.toString() ??
            (ok ? 'Item transferred' : 'Transfer failed'),
      );
    });

    state = false;
    return ok;
  }
}

/* ---------------- Item Rate History provider ---------------- */

final itemRateHistoryProvider =
    FutureProvider.autoDispose.family<ItemRateHistoryModel, String>((ref, itemId) async {
  final repo = ref.read(storeItemsRepositoryProvider);
  final res = await repo.getRateHistory(itemId);
  return res.fold(
    (l) => throw Exception(l.message),
    (r) => ItemRateHistoryModel.fromMap(r),
  );
});

