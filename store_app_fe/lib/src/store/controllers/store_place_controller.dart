// Repository provider (configure baseUrl in your app bootstrap)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_place_model.dart';
import '../domains/repositories/store_place_repository.dart';

/// Query dto sent to socket
class StorePlaceQuery {
  final int page; // 1-based
  final int limit; // e.g., 12
  final String search; // free text
  final String sort; // "-createdAt" | "createdAt" | "name" | "-name"
  const StorePlaceQuery({
    this.page = 1,
    this.limit = 12,
    this.search = "",
    this.sort = "-createdAt",
  });

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "sort": sort,
  };
}

/// Result dto parsed from server
class PagedStorePlaces {
  final List<StorePlace> rows;
  final int total;
  final int page;
  final int limit;
  const PagedStorePlaces({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

final storePlacePagedStreamProvider = StreamProvider.autoDispose
    .family<PagedStorePlaces, StorePlaceQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedStorePlaces>(sync: true);

      void handler(dynamic data) {
        try {
          // If your backend already returns {rows,total,page,limit}
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map((e) => StorePlace.fromMap(e as Map<String, dynamic>))
                    .toList();
            final result = PagedStorePlaces(
              rows: list,
              total: (data['total'] ?? list.length) as int,
              page: (data['page'] ?? query.page) as int,
              limit: (data['limit'] ?? query.limit) as int,
            );
            controller.add(result);
            return;
          }

          // Fallback: backend still returns a plain array
          if (data is List) {
            final list =
                data
                    .map((e) => StorePlace.fromMap(e as Map<String, dynamic>))
                    .toList();
            controller.add(
              PagedStorePlaces(
                rows: list,
                total: list.length,
                page: 1,
                limit: list.length,
              ),
            );
          }
        } catch (_) {
          // swallow parse errors
        }
      }

      socket.on("store:findAllStorePlace", handler);
      socket.emit("store:findAllStorePlace", query.toJson());

      ref.onDispose(() {
        socket.off("store:findAllStorePlace", handler);
        controller.close();
      });

      // initial empty
      yield PagedStorePlaces(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      await for (final v in controller.stream) {
        yield v;
      }
    });

/// Shape we need for the page
class ReceivingLite {
  final String id; // _id
  final String recNo; // recNo
  final String source; // source
  final List<ReceivingLineLite> lines; // only remaining>0 lines

  ReceivingLite({
    required this.id,
    required this.recNo,
    required this.source,
    required this.lines,
  });

  factory ReceivingLite.fromMap(Map<String, dynamic> m) {
    final id = (m['_id'] ?? m['id'] ?? '').toString();
    final recNo = (m['recNo'] ?? '').toString();
    final source = (m['source'] ?? '').toString();
    final rawLines = (m['lines'] as List?) ?? const [];
    final parsedLines = <ReceivingLineLite>[];
    for (final e in rawLines) {
      if (e is Map<String, dynamic>) {
        final l = ReceivingLineLite.fromMap(e);
        if (l.remaining > 0) parsedLines.add(l);
      }
    }
    return ReceivingLite(
      id: id,
      recNo: recNo,
      source: source,
      lines: parsedLines,
    );
  }
}

class ReceivingLineLite {
  final String itemId;
  final String itemName;
  final String unit;
  final int approved;
  final int received;
  int get remaining => (approved - received).clamp(0, 1 << 30);

  ReceivingLineLite({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.approved,
    required this.received,
  });

  static String _idOf(dynamic v) {
    if (v is String) return v;
    if (v is Map && v[r'$oid'] != null) return v[r'$oid'].toString();
    return v?.toString() ?? '';
  }

  static int _toInt(dynamic v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;

  factory ReceivingLineLite.fromMap(Map<String, dynamic> m) {
    return ReceivingLineLite(
      itemId: _idOf(m['itemId']),
      itemName: (m['itemName'] ?? '').toString(),
      unit: (m['unit'] ?? '').toString(),
      approved: _toInt(m['approvedQty']),
      received: _toInt(m['receivedQty']),
    );
  }
}

/// Stream: list of receivings (APPROVED) that still have remaining qty.
/// If your backend supports a filter, pass { status:"APPROVED", withRemaining:true }.
final receivingOpenListStreamProvider = StreamProvider.autoDispose<
  List<ReceivingLite>
>((ref) async* {
  final socket = ref.watch(socketProvider).getSocket();

  final ctrl = StreamController<List<ReceivingLite>>(sync: true);
  List<ReceivingLite> current = [];

  void onData(dynamic data) {
    try {
      final list =
          (data as List)
              .whereType<Map<String, dynamic>>()
              .map(ReceivingLite.fromMap)
              .where((r) => r.lines.isNotEmpty)
              .toList();
      current = list;
      ctrl.add(current);
    } catch (_) {}
  }

  // Ask BE for all receivings with remaining > 0 (adjust event name/filters!)
  socket.emit('receiving:listOpen', {
    "onlyApproved": true,
    "onlyWithRemaining": true,
  });

  // Listen for server push
  socket.on('receiving:listOpen', onData);

  // yield current snapshot if any (usually empty first frame)
  yield current;

  // then stream updates
  await for (final v in ctrl.stream) {
    yield v;
  }

  // cleanup
  ref.onDispose(() {
    socket.off('receiving:listOpen', onData);
    ctrl.close();
  });
});

/// Command helper to call your existing receiveToPlaceOne API over socket/controller
final itemReceiveControllerProvider = Provider<ItemReceiveController>((ref) {
  final socket = ref.watch(socketProvider).getSocket();
  return ItemReceiveController(socket);
});

class ItemReceiveController {
  final dynamic _socket;
  ItemReceiveController(this._socket);

  Future<bool> itemReceiveToPlace({
    required Map<String, dynamic> itemReceiveToPlace,
  }) async {
    final c = Completer<bool>();
    void once(resp) {
      try {
        final ok = (resp is Map && resp['status'] == true);
        c.complete(ok);
      } catch (_) {
        c.complete(false);
      }
    }

    _socket.emit('receiving:receiveToPlaceOne', itemReceiveToPlace);
    _socket.once('receiving:receiveToPlaceOne', once);

    final res = await c.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        try {
          _socket.off('receiving:receiveToPlaceOne', once);
        } catch (_) {}
        return false;
      },
    );
    return res;
  }
}

class PlaceItemQty {
  final String id;
  final String itemId;
  final String itemName;
  final String placeId;
  final String placeName;
  final int total;
  final int issued;
  final int completed;
  final int available;

  PlaceItemQty({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.placeId,
    required this.placeName,
    required this.total,
    required this.issued,
    required this.completed,
    required this.available,
  });

  factory PlaceItemQty.fromMap(Map<String, dynamic> m) {
    int i(v) => v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
    return PlaceItemQty(
      id: (m['_id'] ?? m['id'] ?? '').toString(),
      itemId: (m['itemId'] ?? '').toString(),
      itemName: (m['itemName'] ?? '').toString(),
      placeId: (m['placeId'] ?? '').toString(),
      placeName: (m['placeName'] ?? '').toString(),
      total: i(m['totalQuantity'] ?? m['total']),
      issued: i(m['issuedQuantity'] ?? m['IssuedQuantity'] ?? m['issued']),
      completed: i(m['completedQuantity'] ?? m['completed']),
      available: i(m['available']),
    );
  }
}

// Stream the list for one place
final placeItemQuantitiesStreamProvider = StreamProvider.autoDispose
    .family<List<PlaceItemQty>, String>((ref, placeId) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<List<PlaceItemQty>>(sync: true);

      // Request once; if you want live updates, have server emit on changes
      socket.emit("stock:listPlaceItems", {"placeId": placeId});

      void handler(dynamic data) {
        try {
          final List raw =
              (data is Map && data['data'] is List)
                  ? data['data'] as List
                  : (data is List ? data : <dynamic>[]);
          final rows =
              raw
                  .map((e) => PlaceItemQty.fromMap(e as Map<String, dynamic>))
                  .toList();
          controller.add(rows);
        } catch (_) {
          controller.add(<PlaceItemQty>[]);
        }
      }

      socket.on("stock:listPlaceItems", handler);

      yield* controller.stream;

      ref.onDispose(() {
        socket.off("stock:listPlaceItems", handler);
        controller.close();
      });
    });

final storePlaceAllDataStreamProvider =
    StreamProvider.autoDispose<List<StorePlace>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StorePlace>> storePlaceStream = StreamController(
        sync: true,
      );
      List<StorePlace> returnValue = [];
      socketManager.getSocket().emit("store:findAllStorePlace", {});
      socketManager.getSocket().on("store:findAllStorePlace", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StorePlace.fromMap(element));
        }
        storePlaceStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in storePlaceStream.stream) {
        yield returnValue;
      }
    });

final storePlaceOneDataStreamProvider = StreamProvider.autoDispose
    .family<StorePlace?, String>((ref, storePlaceId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<StorePlace?> storePlaceStream = StreamController(
        sync: true,
      );
      StorePlace? returnValue;
      socketManager.getSocket().emit("store:findOneStorePlace", {
        "id": storePlaceId,
      });
      socketManager.getSocket().on("store:findOneStorePlace", (data) {
        returnValue = StorePlace.fromMap(data);

        storePlaceStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in storePlaceStream.stream) {
        yield returnValue;
      }
    });

final storePlaceQuantityAllDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> storePlaceStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findAllStorePlaceQuantity", {});
      socketManager.getSocket().on("store:findAllStorePlaceQuantity", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        storePlaceStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in storePlaceStream.stream) {
        yield returnValue;
      }
    });

final storePlaceControllerProvider = Provider<StorePlaceNotifier>((ref) {
  return StorePlaceNotifier(
    storePlaceRepository: ref.read(storePlaceRepositoryProvider),
    ref: ref,
  );
});

/// Holds and manages the list of storePlace
class StorePlaceNotifier extends StateNotifier<bool> {
  final StorePlaceRepository _storePlaceRepository;
  final Ref _ref;

  StorePlaceNotifier({
    required StorePlaceRepository storePlaceRepository,
    required Ref ref,
  }) : _ref = ref,
       _storePlaceRepository = storePlaceRepository,
       super(false);

  Future<bool> createStorePlace({
    required Map<String, dynamic> storePlaceModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storePlace");
    //   return false;
    // }
    final res = await _storePlaceRepository.addStorePlace(storePlaceModel);

    res.fold(
      (failure) {
        showSnackBar("Create failed.");
        // return false;
      },
      (data) {
        if (data['status'] == true) {
          showSnackBar(data['msg']);
          check = true;
        } else {
          showSnackBar(data['msg']);
          // return false;
        }
      },
    );
    return check;
  }

  Future<bool> updateStorePlace({
    required Map<String, dynamic> storePlaceModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storePlace");
    //   return false;
    // }
    final res = await _storePlaceRepository.updateStorePlace(storePlaceModel);

    res.fold(
      (failure) {
        showSnackBar("Create failed.");
        // return false;
      },
      (data) {
        if (data['status'] == true) {
          showSnackBar(data['msg']);
          check = true;
        } else {
          showSnackBar(data['msg']);
          // return false;
        }
      },
    );
    return check;
  }

  Future<bool> deleteStorePlace({required String id}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storePlace");
    //   return false;
    // }
    final res = await _storePlaceRepository.deleteStorePlace(id);

    res.fold(
      (failure) {
        showSnackBar("Create failed.");
        // return false;
      },
      (data) {
        if (data['status'] == true) {
          showSnackBar(data['msg']);
          check = true;
        } else {
          showSnackBar(data['msg']);
          // return false;
        }
      },
    );
    return check;
  }
}
