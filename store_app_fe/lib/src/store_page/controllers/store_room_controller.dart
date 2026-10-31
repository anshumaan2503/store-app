// lib/src/store/controllers/store_storeRoom_controller.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/utils.dart';
import '../domains/models/store_room_model.dart';
import 'dart:async';
import '../../components/socket_manager.dart';
import '../domains/repositories/store_room_repository.dart';

/* -------- Query -------- */
@immutable
class RoomQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;
  final bool isScrap;

  const RoomQuery({
    this.page = 1,
    this.limit = 12,
    this.search = '',
    this.sort = '-createdAt',
    this.isScrap = false,
  });

  Map<String, dynamic> toJson() => {
    'page': page,
    'limit': limit,
    'search': search,
    'sort': sort,
    'isScrap': isScrap,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoomQuery &&
          other.page == page &&
          other.limit == limit &&
          other.search == search &&
          other.sort == sort &&
          other.isScrap == isScrap;

  @override
  int get hashCode => Object.hash(page, limit, search, sort, isScrap);
}

/* -------- Paged Result -------- */
class PagedRooms {
  final List<StoreRoom> rows;
  final int total;
  final int page;
  final int limit;
  const PagedRooms({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

/* -------- WS: list paged -------- */
final storeRoomPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRooms, RoomQuery>((ref, query) {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRooms>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRoom.fromMap(e as Map<String, dynamic>))
                    .toList();

            if (!controller.isClosed) {
              controller.add(
                PagedRooms(
                  rows: list,
                  total: (data['total'] ?? list.length) as int,
                  page: (data['page'] ?? query.page) as int,
                  limit: (data['limit'] ?? query.limit) as int,
                ),
              );
            }
          }
        } catch (_) {}
      }

      socket.on('store:findAllRoomPaged', handler);
      socket.emit('store:findAllRoomPaged', query.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!controller.isClosed) {
          controller.add(
            PagedRooms(
              rows: const [],
              total: 0,
              page: query.page,
              limit: query.limit,
            ),
          );
        }
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findAllRoomPaged', handler);
        controller.close();
      });

      return controller.stream;
    });

final storeSrcapRoomPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRooms, RoomQuery>((ref, query) {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRooms>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRoom.fromMap(e as Map<String, dynamic>))
                    .toList();

            if (!controller.isClosed) {
              controller.add(
                PagedRooms(
                  rows: list,
                  total: (data['total'] ?? list.length) as int,
                  page: (data['page'] ?? query.page) as int,
                  limit: (data['limit'] ?? query.limit) as int,
                ),
              );
            }
          }
        } catch (_) {}
      }

      socket.on('store:findAllScrapRoomPaged', handler);
      socket.emit('store:findAllScrapRoomPaged', query.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!controller.isClosed) {
          controller.add(
            PagedRooms(
              rows: const [],
              total: 0,
              page: query.page,
              limit: query.limit,
            ),
          );
        }
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findAllScrapRoomPaged', handler);
        controller.close();
      });

      return controller.stream;
    });

final storeGoodMachineRoomPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRooms, RoomQuery>((ref, query) {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRooms>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRoom.fromMap(e as Map<String, dynamic>))
                    .toList();

            if (!controller.isClosed) {
              controller.add(
                PagedRooms(
                  rows: list,
                  total: (data['total'] ?? list.length) as int,
                  page: (data['page'] ?? query.page) as int,
                  limit: (data['limit'] ?? query.limit) as int,
                ),
              );
            }
          }
        } catch (_) {}
      }

      socket.on('store:findAllGoodMachineRoomPaged', handler);
      socket.emit('store:findAllGoodMachineRoomPaged', query.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!controller.isClosed) {
          controller.add(
            PagedRooms(
              rows: const [],
              total: 0,
              page: query.page,
              limit: query.limit,
            ),
          );
        }
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findAllGoodMachineRoomPaged', handler);
        controller.close();
      });

      return controller.stream;
    });

final storeSrcapMachineRoomPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedRooms, RoomQuery>((ref, query) {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedRooms>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StoreRoom.fromMap(e as Map<String, dynamic>))
                    .toList();

            if (!controller.isClosed) {
              controller.add(
                PagedRooms(
                  rows: list,
                  total: (data['total'] ?? list.length) as int,
                  page: (data['page'] ?? query.page) as int,
                  limit: (data['limit'] ?? query.limit) as int,
                ),
              );
            }
          }
        } catch (_) {}
      }

      socket.on('store:findAllScrapMachineRoomPaged', handler);
      socket.emit('store:findAllScrapMachineRoomPaged', query.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!controller.isClosed) {
          controller.add(
            PagedRooms(
              rows: const [],
              total: 0,
              page: query.page,
              limit: query.limit,
            ),
          );
        }
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findAllScrapMachineRoomPaged', handler);
        controller.close();
      });

      return controller.stream;
    });

final findAllRoomDataByScrapStreamProvider =
    StreamProvider.autoDispose<List<StoreRoom>>((ref) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreRoom>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = <StoreRoom>[];
          for (var element in data) {
            if (element is Map) {
              list.add(StoreRoom.fromMap(Map<String, dynamic>.from(element)));
            }
          }
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:findAllRoomDataByScrap", handler);
      socket.emit("store:findAllRoomDataByScrap");

      ref.onDispose(() {
        socket.off("store:findAllRoomDataByScrap", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final findAllRoomDataByGoodStreamProvider =
    StreamProvider.autoDispose<List<StoreRoom>>((ref) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreRoom>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = <StoreRoom>[];
          for (var element in data) {
            if (element is Map) {
              list.add(StoreRoom.fromMap(Map<String, dynamic>.from(element)));
            }
          }
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:findAllRoomDataByGood", handler);
      socket.emit("store:findAllRoomDataByGood");

      ref.onDispose(() {
        socket.off("store:findAllRoomDataByGood", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final findAllMachineRoomDataByGoodStreamProvider = StreamProvider.autoDispose<
  List<StoreRoom>
>((ref) {
  final socket = ref.watch(socketProvider).getSocket();
  final ctrl = StreamController<List<StoreRoom>>();

  void handler(dynamic data) {
    try {
      if (data is! List) return;
      final list = <StoreRoom>[];
      for (var element in data) {
        if (element is Map) {
          list.add(StoreRoom.fromMap(Map<String, dynamic>.from(element)));
        }
      }
      if (!ctrl.isClosed) ctrl.add(list);
    } catch (_) {}
  }

  socket.on("store:findAllMachineRoomDataByGood", handler);
  socket.emit("store:findAllMachineRoomDataByGood");

  ref.onDispose(() {
    socket.off("store:findAllMachineRoomDataByGood", handler);
    ctrl.close();
  });

  return ctrl.stream;
});

final findAllMachineRoomDataByScrapStreamProvider = StreamProvider.autoDispose<
  List<StoreRoom>
>((ref) {
  final socket = ref.watch(socketProvider).getSocket();
  final ctrl = StreamController<List<StoreRoom>>();

  void handler(dynamic data) {
    try {
      if (data is! List) return;
      final list = <StoreRoom>[];
      for (var element in data) {
        if (element is Map) {
          list.add(StoreRoom.fromMap(Map<String, dynamic>.from(element)));
        }
      }
      if (!ctrl.isClosed) ctrl.add(list);
    } catch (_) {}
  }

  socket.on("store:findAllMachineRoomDataByScrap", handler);
  socket.emit("store:findAllMachineRoomDataByScrap");

  ref.onDispose(() {
    socket.off("store:findAllMachineRoomDataByScrap", handler);
    ctrl.close();
  });

  return ctrl.stream;
});

/* -------- WS: get one -------- */
final storeRoomOneStreamProvider = StreamProvider.autoDispose
    .family<StoreRoom?, String>((ref, id) {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<StoreRoom?>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            if (!controller.isClosed) {
              controller.add(StoreRoom.fromMap(data.cast<String, dynamic>()));
            }
          }
        } catch (_) {}
      }

      socket.on('store:findOneRoom', handler);
      socket.emit('store:findOneRoom', {'id': id});

      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!controller.isClosed) controller.add(null);
      });

      ref.onDispose(() {
        timeoutTimer?.cancel();
        socket.off('store:findOneRoom', handler);
        controller.close();
      });

      return controller.stream;
    });

final roomAllDataStreamProvider = StreamProvider.autoDispose<List<StoreRoom>>((
  ref,
) {
  final socket = ref.watch(socketProvider).getSocket();
  final ctrl = StreamController<List<StoreRoom>>();

  void handler(dynamic data) {
    try {
      if (data is! List) return;
      final list = <StoreRoom>[];
      for (var element in data) {
        if (element is Map) {
          list.add(StoreRoom.fromMap(Map<String, dynamic>.from(element)));
        }
      }
      if (!ctrl.isClosed) ctrl.add(list);
    } catch (_) {}
  }

  socket.on("store:findAllRoomData", handler);
  socket.emit("store:findAllRoomData", {});

  ref.onDispose(() {
    socket.off("store:findAllRoomData", handler);
    ctrl.close();
  });

  return ctrl.stream;
});

final storeRoomControllerProvider = Provider<RoomNotifier>((ref) {
  return RoomNotifier(
    storeRoomRepository: ref.read(storeRoomRepositoryProvider),
    ref: ref,
  );
});

class RoomNotifier extends StateNotifier<bool> {
  final RoomRepository _repo;
  final Ref _ref;

  RoomNotifier({required RoomRepository storeRoomRepository, required Ref ref})
    : _repo = storeRoomRepository,
      _ref = ref,
      super(false);
  Future<StoreRoom?> createRoom({
    required Map<String, dynamic> storeRoom,
  }) async {
    state = true;
    StoreRoom? created;

    final res = await _repo.addRoom(storeRoom);
    res.fold((_) => showSnackBar('Create failed.'), (data) {
      if (data['status'] == true) {
        showSnackBar(data['msg'] ?? 'Created');

        // ✅ Expect backend to return created room in `data['data']`
        final raw = data['data'];
        if (raw is Map<String, dynamic>) {
          created = StoreRoom.fromMap(raw);
        }
      } else {
        showSnackBar(data['msg'] ?? 'Create failed');
      }
    });

    state = false;
    return created;
  }

  Future<bool> updateRoom({required Map<String, dynamic> storeRoom}) async {
    state = true;
    bool ok = false;

    final res = await _repo.updateRoom(storeRoom);
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

  Future<bool> multirackRoom({
    required Map<String, dynamic> storeRoom,
    bool showFeedback = true,
  }) async {
    state = true;
    bool ok = false;

    final res = await _repo.multirackRoom(storeRoom);
    res.fold((_) {
      if (showFeedback) showSnackBar('Update failed.');
    }, (data) {
      if (data['status'] == true) {
        if (showFeedback) showSnackBar(data['msg'] ?? 'Updated');
        ok = true;
      } else {
        if (showFeedback) showSnackBar(data['msg'] ?? 'Update failed');
      }
    });

    state = false;
    return ok;
  }

  Future<bool> deleteRoom({required String id}) async {
    state = true;
    bool ok = false;

    final res = await _repo.deleteRoom(id);
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
}
