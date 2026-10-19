// lib/src/store/controllers/store_storeRack_controller.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../components/constants.dart';
import '../../components/utils.dart';
import '../domains/models/store_rack_model.dart';
import 'dart:async';
import '../../components/socket_manager.dart';
import '../domains/repositories/store_rack_repository.dart';
import '../../auth/shared/repositories/shared_preference_repository.dart';

/* -------- Query -------- */
@immutable
class RackQuery {
  final int page; // 1-based
  final int limit;
  final String search;
  final String sort;
  final String? roomId;
  final String? allowItemId;

  const RackQuery({
    this.page = 1,
    this.limit = 12,
    this.search = '',
    this.sort = '-createdAt',
    this.roomId,
    this.allowItemId,
  });

  Map<String, dynamic> toJson() => {
    'page': page,
    'limit': limit,
    'search': search,
    'sort': sort,
    'roomId': roomId,
    'allowItemId': allowItemId,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RackQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort &&
          other.allowItemId == allowItemId &&
          other.roomId == roomId;

  @override
  int get hashCode =>
      Object.hash(page, limit, search, sort, roomId, allowItemId);
}

/* -------- Paged Result -------- */
class PagedRacks {
  final List<StoreRack> rows;
  final int total;
  final int page;
  final int limit;
  const PagedRacks({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

final storeAllRackPagedStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> roomStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findRealAllRackPaged", {});
      socketManager.getSocket().on("store:findRealAllRackPaged", (data) {
        // print(data);
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        roomStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });

/* -------- WS: list paged -------- */
final storeRackPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRacks, RackQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRacks>(sync: true);

      // print('WS -> emit store:findAllRackPaged ${query.toJson()}');

      void handler(dynamic data) {
        // print('WS <- store:findAllRackPaged dataType=${data.runtimeType}');
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRack.fromMap(e as Map<String, dynamic>))
                    .toList();

            controller.add(
              PagedRacks(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? query.page) as int,
                limit: (data['limit'] ?? query.limit) as int,
              ),
            );
          }
        } catch (e) {
          print('parse error: $e');
        }
      }

      socket.on('store:findAllRackPaged', handler);
      socket.emit('store:findAllRackPaged', query.toJson());

      ref.onDispose(() {
        socket.off('store:findAllRackPaged', handler);
        controller.close();
      });

      // ✅ ensures provider is not stuck in loading
      yield PagedRacks(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      yield* controller.stream;
    });

final storeScrapRackPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRacks, RackQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRacks>(sync: true);

      // print('WS -> emit store:findAllRackPaged ${query.toJson()}');

      void handler(dynamic data) {
        // print('WS <- store:findAllRackPaged dataType=${data.runtimeType}');
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRack.fromMap(e as Map<String, dynamic>))
                    .toList();

            controller.add(
              PagedRacks(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? query.page) as int,
                limit: (data['limit'] ?? query.limit) as int,
              ),
            );
          }
        } catch (e) {
          print('parse error: $e');
        }
      }

      socket.on('store:findAllScrapRackPaged', handler);
      socket.emit('store:findAllScrapRackPaged', query.toJson());

      ref.onDispose(() {
        socket.off('store:findAllScrapRackPaged', handler);
        controller.close();
      });

      // ✅ ensures provider is not stuck in loading
      yield PagedRacks(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      yield* controller.stream;
    });

final storeGoodMachineRackPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRacks, RackQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRacks>(sync: true);

      // print('WS -> emit store:findAllRackPaged ${query.toJson()}');

      void handler(dynamic data) {
        // print('WS <- store:findAllRackPaged dataType=${data.runtimeType}');
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRack.fromMap(e as Map<String, dynamic>))
                    .toList();

            controller.add(
              PagedRacks(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? query.page) as int,
                limit: (data['limit'] ?? query.limit) as int,
              ),
            );
          }
        } catch (e) {
          print('parse error: $e');
        }
      }

      socket.on('store:findAllGoodMachineRackPaged', handler);
      socket.emit('store:findAllGoodMachineRackPaged', query.toJson());

      ref.onDispose(() {
        socket.off('store:findAllGoodMachineRackPaged', handler);
        controller.close();
      });

      // ✅ ensures provider is not stuck in loading
      yield PagedRacks(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      yield* controller.stream;
    });

final storeScrapMachineRackPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRacks, RackQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRacks>(sync: true);

      // print('WS -> emit store:findAllRackPaged ${query.toJson()}');

      void handler(dynamic data) {
        // print('WS <- store:findAllRackPaged dataType=${data.runtimeType}');
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRack.fromMap(e as Map<String, dynamic>))
                    .toList();

            controller.add(
              PagedRacks(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? query.page) as int,
                limit: (data['limit'] ?? query.limit) as int,
              ),
            );
          }
        } catch (e) {
          print('parse error: $e');
        }
      }

      socket.on('store:findAllScrapMachineRackPaged', handler);
      socket.emit('store:findAllScrapMachineRackPaged', query.toJson());

      ref.onDispose(() {
        socket.off('store:findAllScrapMachineRackPaged', handler);
        controller.close();
      });

      // ✅ ensures provider is not stuck in loading
      yield PagedRacks(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      yield* controller.stream;
    });

/* -------- WS: get one -------- */
final storeRackOneStreamProvider = StreamProvider.autoDispose
    .family<StoreRack?, String>((ref, id) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<StoreRack?>(sync: true);

      void handler(dynamic data) {
        try {
          if (data is Map) {
            controller.add(StoreRack.fromMap(data.cast<String, dynamic>()));
          }
        } catch (_) {}
      }

      socket.on('store:findOneRack', handler);
      socket.emit('store:findOneRack', {'id': id});

      ref.onDispose(() {
        socket.off('store:findOneRack', handler);
        controller.close();
      });

      yield null;
      await for (final v in controller.stream) {
        yield v;
      }
    });

final storeNotOccupiecRackPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRacks, RackQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRacks>(sync: true);

      void handler(dynamic data) {
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRack.fromMap(e as Map<String, dynamic>))
                    .toList();

            controller.add(
              PagedRacks(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? query.page) as int,
                limit: (data['limit'] ?? query.limit) as int,
              ),
            );
          }
        } catch (_) {}
      }

      // ✅ use the NOT occupied event for both on + emit
      socket.on('store:findNotOccupiedRackPaged', handler);
      socket.emit('store:findNotOccupiedRackPaged', query.toJson());

      ref.onDispose(() {
        socket.off('store:findNotOccupiedRackPaged', handler);
        controller.close();
      });

      yield PagedRacks(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );
      yield* controller.stream;
    });

final rackDataByRoomDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreRack>, RackByRoomArgs>((ref, args) {
      final socketManager = ref.watch(socketProvider);
      final socket = socketManager.getSocket();

      final controller = StreamController<List<StoreRack>>.broadcast(
        sync: true,
      );

      void handler(dynamic data) {
        try {
          final out = <StoreRack>[];

          // Your server SHOULD return a List, but be defensive:
          if (data is List) {
            for (final e in data) {
              if (e is Map) {
                out.add(StoreRack.fromMap(Map<String, dynamic>.from(e)));
              }
            }
          } else if (data is Map) {
            final rows = data['rows'] ?? data['data'] ?? data['result'];
            if (rows is List) {
              for (final e in rows) {
                if (e is Map) {
                  out.add(StoreRack.fromMap(Map<String, dynamic>.from(e)));
                }
              }
            }
          }

          if (!controller.isClosed) controller.add(out);
        } catch (_) {
          if (!controller.isClosed) controller.add(<StoreRack>[]);
        }
      }

      // ✅ IMPORTANT: register listener BEFORE emit (prevents missed response)
      socket.on("store:findRackDataByRoomData", handler);

      socket.emit("store:findRackDataByRoomData", {
        "roomid": args.roomId,
        "itemid": args.itemId,
      });

      // ✅ Clean up properly
      ref.onDispose(() {
        socket.off("store:findRackDataByRoomData", handler);
        controller.close();
      });

      return controller.stream;
    });

final rackGoodDataByRoomDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreRack>, RackByRoomArgs>((ref, args) {
      final socketManager = ref.watch(socketProvider);
      final socket = socketManager.getSocket();

      final controller = StreamController<List<StoreRack>>.broadcast(
        sync: true,
      );

      void handler(dynamic data) {
        try {
          final out = <StoreRack>[];

          // Your server SHOULD return a List, but be defensive:
          if (data is List) {
            for (final e in data) {
              if (e is Map) {
                out.add(StoreRack.fromMap(Map<String, dynamic>.from(e)));
              }
            }
          } else if (data is Map) {
            final rows = data['rows'] ?? data['data'] ?? data['result'];
            if (rows is List) {
              for (final e in rows) {
                if (e is Map) {
                  out.add(StoreRack.fromMap(Map<String, dynamic>.from(e)));
                }
              }
            }
          }

          if (!controller.isClosed) controller.add(out);
        } catch (_) {
          if (!controller.isClosed) controller.add(<StoreRack>[]);
        }
      }

      // ✅ IMPORTANT: register listener BEFORE emit (prevents missed response)
      socket.on("store:findRackGoodDataByRoomData", handler);

      socket.emit("store:findRackGoodDataByRoomData", {
        "roomid": args.roomId,
        "itemid": args.itemId,
      });

      // ✅ Clean up properly
      ref.onDispose(() {
        socket.off("store:findRackGoodDataByRoomData", handler);
        controller.close();
      });

      return controller.stream;
    });

final rackDataByItemDataStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, itemid) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> roomStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findRackDataByItemData", {
        "itemid": itemid,
      });
      socketManager.getSocket().on("store:findRackDataByItemData", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        roomStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });

final rackDataByItemNonZeroDataStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, itemid) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> roomStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit(
        "store:findRackDataByItemDataNonZeroStock",
        {"itemid": itemid},
      );
      socketManager.getSocket().on("store:findRackDataByItemDataNonZeroStock", (
        data,
      ) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        roomStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });

final rackDataStockDataStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, rackid) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<Map<String, dynamic>?> roomStream = StreamController(
        sync: true,
      );
      Map<String, dynamic>? returnValue = {};
      socketManager.getSocket().emit("store:findRackStock", {"rackid": rackid});
      socketManager.getSocket().on("store:findRackStock", (data) {
        returnValue = {};
        try {
          if (data is Map) {
            returnValue = data.cast<String, dynamic>();
          }
        } catch (_) {}
        roomStream.add(returnValue!);
      });

      yield returnValue!;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });

final rackByItemDataStockDataStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, Map<String, dynamic>>((ref, dto) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<Map<String, dynamic>?> roomStream = StreamController(
        sync: true,
      );
      Map<String, dynamic>? returnValue = {};
      socketManager.getSocket().emit("store:findRackStockByItem", {
        'itemId': dto["itemId"],
        'rackId': dto["rackId"],
      });
      socketManager.getSocket().on("store:findRackStockByItem", (data) {
        returnValue = {};
        try {
          if (data is Map) {
            // print(data);
            returnValue = data.cast<String, dynamic>();
          }
        } catch (_) {}
        roomStream.add(returnValue!);
      });

      yield returnValue!;
      await for (final returnValue in roomStream.stream) {
        yield returnValue;
      }
    });
final allRackByItemDataStockDataStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, itemId) async* {
      final socketManager = ref.watch(socketProvider);
      final socket = socketManager.getSocket();

      final controller = StreamController<List<Map<String, dynamic>>>();

      void handler(dynamic data) {
        final List<Map<String, dynamic>> rows = [];

        if (data is List) {
          for (final element in data) {
            if (element is Map) {
              rows.add(Map<String, dynamic>.from(element));
            }
          }
        }

        controller.add(rows);
      }

      // listen first
      socket.on("store:findAllRackStockByItem", handler);

      // emit after listener is ready
      socket.emit("store:findAllRackStockByItem", {'itemId': itemId});

      // cleanup
      ref.onDispose(() {
        socket.off("store:findAllRackStockByItem", handler);
        controller.close();
      });

      // optional immediate empty value so UI does not stay loading
      yield const <Map<String, dynamic>>[];

      await for (final value in controller.stream) {
        yield value;
      }
    });

final racksByItemFutureProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, itemId) async {
      return ref.read(storeRackControllerProvider).getRacksByItem(itemId);
    });

final storeRackControllerProvider = Provider<RackNotifier>((ref) {
  return RackNotifier(
    storeRackRepository: ref.read(storeRackRepositoryProvider),
    ref: ref,
  );
});

class RackNotifier extends StateNotifier<bool> {
  final RackRepository _repo;
  final Ref _ref;

  RackNotifier({required RackRepository storeRackRepository, required Ref ref})
    : _repo = storeRackRepository,
      _ref = ref,
      super(false);

  Future<bool> createRack({required Map<String, dynamic> storeRack}) async {
    state = true;
    bool ok = false;

    final res = await _repo.addRack(storeRack);
    res.fold((_) => showSnackBar('Create failed.'), (data) {
      if (data['status'] == true) {
        showSnackBar(data['msg'] ?? 'Created');
        ok = true;
      } else {
        showSnackBar(data['msg'] ?? 'Create failed');
      }
    });

    state = false;
    return ok;
  }

  Future<bool> updateRack({required Map<String, dynamic> storeRack}) async {
    state = true;
    bool ok = false;

    final res = await _repo.updateRack(storeRack);
    res.fold((_) => showSnackBar('Update failed.'), (data) {
      if (data['status'] == true) {
        showSnackBar(data['msg'] ?? 'Updated');
        ok = true;
      } else {
        showSnackBar(data['msg'] ?? 'Update failed');
      }
    });

    state = false;
    return ok;
  }

  Future<bool> deleteRack({required String id}) async {
    state = true;
    bool ok = false;

    final res = await _repo.deleteRack(id);
    res.fold((_) => showSnackBar('Delete failed.'), (data) {
      if (data['status'] == true) {
        showSnackBar(data['msg'] ?? 'Deleted');
        ok = true;
      } else {
        showSnackBar(data['msg'] ?? 'Delete failed');
      }
    });

    state = false;
    return ok;
  }

  Future<List<Map<String, dynamic>>> getRacksByItem(String itemId) async {
    try {
      final token =
          await _ref.read(spRepositoryProvider).getStringValue('token') ??
          await _ref.read(spRepositoryProvider).getStringValue('authToken') ??
          '';
      final url = Uri.parse("${Constants.socketUrl}/api/racks/by-item/$itemId");

      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return <Map<String, dynamic>>[];
      }

      final decoded = jsonDecode(res.body);

      List<dynamic>? rows;

      // Handle: direct list
      if (decoded is List) {
        rows = decoded;
      }

      // Handle: wrapped list
      if (decoded is Map<String, dynamic>) {
        final r = decoded["rows"] ?? decoded["data"] ?? decoded["result"];
        if (r is List) rows = r;
      }

      if (rows == null) return <Map<String, dynamic>>[];

      // Convert each element safely to Map<String, dynamic>
      return rows
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<StoreRack>> getScrapRacksByItem(String itemId) async {
    try {
      final token =
          await _ref.read(spRepositoryProvider).getStringValue('token') ??
          await _ref.read(spRepositoryProvider).getStringValue('authToken') ??
          '';
      final url = Uri.parse(
        "${Constants.socketUrl}/api/store/storeitems/by-item-scrap/$itemId",
      );

      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          if (token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );


      if (res.statusCode < 200 || res.statusCode >= 300) {
        return <StoreRack>[];
      }

      final decoded = jsonDecode(res.body);

      // Handle: direct list
      if (decoded is List) {
        return decoded.map((e) => StoreRack.fromMap(e)).toList();
      }

      // Handle: wrapped list
      if (decoded is Map<String, dynamic>) {
        final rows = decoded["rows"] ?? decoded["data"] ?? decoded["result"];
        if (rows is List) {
          return rows.map((e) => StoreRack.fromMap(e)).toList();
        }
      }

      return <StoreRack>[];
    } catch (_) {
      return <StoreRack>[];
    }
  }

  Future<List<StoreRack>> getRacksByRoom(String roomId, String itemId) async {
    try {
      final url = Uri.parse(
        "${Constants.socketUrl}/api/racks/by-room/$roomId",
      ).replace(queryParameters: {"itemId": itemId});

      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          // if (token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return <StoreRack>[];
      }

      final decoded = jsonDecode(res.body);

      // Handle: direct list
      if (decoded is List) {
        return decoded.map((e) => StoreRack.fromMap(e)).toList();
      }

      // Handle: wrapped list
      if (decoded is Map<String, dynamic>) {
        final rows = decoded["rows"] ?? decoded["data"] ?? decoded["result"];
        if (rows is List) {
          return rows.map((e) => StoreRack.fromMap(e)).toList();
        }
      }

      return <StoreRack>[];
    } catch (_) {
      return <StoreRack>[];
    }
  }

  Future<List<StoreRack>> getScrapRacksByRoom(String roomId) async {
    try {
      final url = Uri.parse(
        "${Constants.socketUrl}/api/store/storeitems/by-room-scrap/$roomId",
      );

      final res = await http.get(
        url,
        headers: {
          "Content-Type": "application/json",
          // if (token.isNotEmpty) "Authorization": "Bearer $token",
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return <StoreRack>[];
      }

      final decoded = jsonDecode(res.body);

      // Handle: direct list
      if (decoded is List) {
        return decoded.map((e) => StoreRack.fromMap(e)).toList();
      }

      // Handle: wrapped list
      if (decoded is Map<String, dynamic>) {
        final rows = decoded["rows"] ?? decoded["data"] ?? decoded["result"];
        if (rows is List) {
          return rows.map((e) => StoreRack.fromMap(e)).toList();
        }
      }

      return <StoreRack>[];
    } catch (_) {
      return <StoreRack>[];
    }
  }
}

@immutable
class RackByRoomArgs {
  final String roomId;
  final String itemId;

  const RackByRoomArgs({required this.roomId, required this.itemId});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RackByRoomArgs &&
          runtimeType == other.runtimeType &&
          roomId == other.roomId &&
          itemId == other.itemId;

  @override
  int get hashCode => Object.hash(roomId, itemId);
}
