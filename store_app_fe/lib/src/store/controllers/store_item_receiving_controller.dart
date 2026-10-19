// Repository provider (configure baseUrl in your app bootstrap)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/repositories/store_item_receiving_repository.dart';

// Query model (allows multi-status; item-name search; sort)
class ReceivingPagedQuery {
  final int page;
  final int limit;
  final String search; // recNo/source search
  final List<String> status; // e.g. ['DRAFT'] or ['APPROVED','CLOSED']
  final String item; // item name/code search (server applies on lines)
  final String sort; // e.g. -createdAt

  const ReceivingPagedQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.status,
    required this.item,
    required this.sort,
  });

  ReceivingPagedQuery copyWith({
    int? page,
    int? limit,
    String? search,
    List<String>? status,
    String? item,
    String? sort,
  }) {
    return ReceivingPagedQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      status: status ?? this.status,
      item: item ?? this.item,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
    "page": page,
    "limit": limit,
    "search": search,
    "status": status,
    "item": item,
    "sort": sort,
  };
}

class PagedReceivings {
  final List<Map<String, dynamic>> rows;
  final int total;
  final int page;
  final int limit;
  const PagedReceivings({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

final receivingPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedReceivings, ReceivingPagedQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedReceivings>(sync: true);

      void handler(dynamic data) {
        try {
          final rows =
              (data['rows'] as List? ?? const [])
                  .map<Map<String, dynamic>>(
                    (e) => Map<String, dynamic>.from(e),
                  )
                  .toList();
          controller.add(
            PagedReceivings(
              rows: rows,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? query.page) as int,
              limit: (data['limit'] ?? query.limit) as int,
            ),
          );
        } catch (_) {
          /* ignore */
        }
      }

      socket.on('store:receivings:approve:paged', handler);
      socket.emit('store:receivings:approve:paged', query.toJson());

      ref.onDispose(() {
        socket.off('store:receivings:approve:paged', handler);
        controller.close();
      });

      // initial (optional)
      yield PagedReceivings(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );
      await for (final e in controller.stream) {
        yield e;
      }
    });

final itemReceiveAllDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> itemReceiveStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findAllItemReceive", {});
      socketManager.getSocket().on("store:findAllItemReceive", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        itemReceiveStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemReceiveStream.stream) {
        yield returnValue;
      }
    });

final itemReceiveStatusDataStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, List<String>>((ref, status) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> itemReceiveStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findStatusItemReceive", {
        "status": status,
      });
      socketManager.getSocket().on("store:findStatusItemReceive", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        itemReceiveStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemReceiveStream.stream) {
        yield returnValue;
      }
    });

final itemReceiveOneDataStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, receiveId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<Map<String, dynamic>?> itemReceiveStream =
          StreamController(sync: true);
      Map<String, dynamic>? returnValue;
      socketManager.getSocket().emit("store:findOneItemReceive", {
        "id": receiveId,
      });
      socketManager.getSocket().on("store:findOneItemReceive", (data) {
        returnValue = data;

        itemReceiveStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemReceiveStream.stream) {
        yield returnValue;
      }
    });

final itemReceiveControllerProvider = Provider<ItemReceiveNotifier>((ref) {
  return ItemReceiveNotifier(
    itemReceiveRepository: ref.read(itemReceiveRepositoryProvider),
    ref: ref,
  );
});

/// Holds and manages the list of itemReceive
class ItemReceiveNotifier extends StateNotifier<bool> {
  final ItemReceiveRepository _itemReceiveRepository;
  final Ref _ref;

  ItemReceiveNotifier({
    required ItemReceiveRepository itemReceiveRepository,
    required Ref ref,
  }) : _ref = ref,
       _itemReceiveRepository = itemReceiveRepository,
       super(false);

  Future<bool> createItemReceive({
    required Map<String, dynamic> itemReceiveModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.addItemReceive(itemReceiveModel);

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

  Future<bool> updateItemReceive({
    required Map<String, dynamic> itemReceiveModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.updateItemReceive(
      itemReceiveModel,
    );

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

  Future<bool> approveItemReceive({
    required Map<String, dynamic> approveItemReceive,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.approveItemReceive(
      approveItemReceive,
    );

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

  Future<bool> rejectItemReceive({
    required Map<String, dynamic> approveItemReceive,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.rejectItemReceive(
      approveItemReceive,
    );

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

  Future<bool> itemReceiveToPlace({
    required Map<String, dynamic> itemReceiveToPlace,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.itemReceiveToPlace(
      itemReceiveToPlace,
    );

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

  Future<bool> deleteItemReceive({required String id}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.deleteItemReceive(id);

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

  Future<bool> closeItemReceive({
    required Map<String, dynamic> closeItemReceive,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.closeItemReceive(closeItemReceive);

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

  Future<bool> postReceiveStock({
    required Map<String, dynamic> postReceiveStock,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemReceive");
    //   return false;
    // }
    final res = await _itemReceiveRepository.postReceiveStock(postReceiveStock);

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
