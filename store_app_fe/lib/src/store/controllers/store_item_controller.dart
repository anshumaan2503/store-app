// Repository provider (configure baseUrl in your app bootstrap)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_item_model.dart';
import '../domains/repositories/store_item_repository.dart';

// lib/src/store/controllers/store_item_paged_models.dart
// lib/src/store/controllers/store_item_query.dart

class StoreItemQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;
  const StoreItemQuery({
    required this.page,
    required this.limit,
    required this.search,
    required this.sort,
  });

  StoreItemQuery copyWith({
    int? page,
    int? limit,
    String? search,
    String? sort,
  }) {
    return StoreItemQuery(
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      sort: sort ?? this.sort,
    );
  }

  Map<String, dynamic> toJson() => {
    'page': page,
    'limit': limit,
    'search': search,
    'sort': sort,
  };
}

class PagedStoreItems {
  final List<StoreItem> rows;
  final int total;
  final int page;
  final int limit;
  final String? error;
  const PagedStoreItems({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
    this.error,
  });
}

final storeItemPagedStreamProvider = StreamProvider.autoDispose
    .family<PagedStoreItems, StoreItemQuery>((ref, query) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<PagedStoreItems>(sync: true);

      void handler(dynamic data) {
        try {
          final rawRows =
              (data is Map && data['rows'] is List)
                  ? (data['rows'] as List)
                  : const [];
          final parsed = <StoreItem>[];
          for (final e in rawRows) {
            try {
              if (e is Map<String, dynamic>) {
                parsed.add(StoreItem.fromMap(e));
              } else if (e is Map) {
                parsed.add(
                  StoreItem.fromMap(Map<String, dynamic>.from(e)),
                );
              }
            } catch (_) {
              // ignore bad row
            }
          }
          controller.add(
            PagedStoreItems(
              rows: parsed,
              total: (data['total'] ?? 0) as int,
              page: (data['page'] ?? query.page) as int,
              limit: (data['limit'] ?? query.limit) as int,
            ),
          );
        } catch (e) {
          controller.add(
            PagedStoreItems(
              rows: const [],
              total: 0,
              page: query.page,
              limit: query.limit,
              error: 'Parse error',
            ),
          );
        }
      }

      socket.on("store:findAllStoreItemFilter", handler);
      socket.emit("store:findAllStoreItemFilter", query.toJson());

      ref.onDispose(() {
        socket.off("store:findAllStoreItemFilter", handler);
        controller.close();
      });

      yield PagedStoreItems(
        rows: const [],
        total: 0,
        page: query.page,
        limit: query.limit,
      );

      await for (final v in controller.stream) {
        yield v;
      }
    });

final storeItemAllDataStreamProvider =
    StreamProvider.autoDispose<List<StoreItem>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreItem>> storeItemStream = StreamController(
        sync: true,
      );
      List<StoreItem> returnValue = [];
      socketManager.getSocket().emit("store:findAllStoreItem", {});
      socketManager.getSocket().on("store:findAllStoreItem", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreItem.fromMap(element));
        }
        storeItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in storeItemStream.stream) {
        yield returnValue;
      }
    });

final storeItemOneDataStreamProvider = StreamProvider.autoDispose.family<
  StoreItem?,
  String
>((ref, storeItemId) async* {
  SocketManager socketManager = ref.watch(socketProvider);
  StreamController<StoreItem?> storeItemStream = StreamController(sync: true);
  StoreItem? returnValue;
  socketManager.getSocket().emit("store:findOneStoreItem", {"id": storeItemId});
  socketManager.getSocket().on("store:findOneStoreItem", (data) {
    returnValue = StoreItem.fromMap(data);

    storeItemStream.add(returnValue);
  });

  yield returnValue;
  await for (final returnValue in storeItemStream.stream) {
    yield returnValue;
  }
});

final storeItemScrapDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> storeItemStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findScrapStoreItem");
      socketManager.getSocket().on("store:findScrapStoreItem", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        storeItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in storeItemStream.stream) {
        yield returnValue;
      }
    });

final storeItemControllerProvider = Provider<StoreItemNotifier>((ref) {
  return StoreItemNotifier(
    storeItemRepository: ref.read(storeItemRepositoryProvider),
    ref: ref,
  );
});

/// Holds and manages the list of storeItem
class StoreItemNotifier extends StateNotifier<bool> {
  final StoreItemRepository _storeItemRepository;
  final Ref _ref;

  StoreItemNotifier({
    required StoreItemRepository storeItemRepository,
    required Ref ref,
  }) : _ref = ref,
       _storeItemRepository = storeItemRepository,
       super(false);

  Future<String?> createStoreItem({
    required Map<String, dynamic> storeItemModel,
  }) async {
    state = true;
    String? createdId;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storeItem");
    //   return false;
    // }
    final res = await _storeItemRepository.addStoreItem(storeItemModel);

    res.fold(
      (failure) {
        showSnackBar("Create failed.");
        // return false;
      },
      (data) {
        // Expecting: { status:true, msg:'Created', data:{ _id:'...' } }
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Created' : 'Create failed'),
        );
        if (ok) {
          final created = data['data'] as Map<String, dynamic>?;
          createdId = (created?['_id'] ?? created?['id'])?.toString();
        }
      },
    );
    return createdId;
  }

  Future<bool> updateStoreItem({
    required Map<String, dynamic> storeItemModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storeItem");
    //   return false;
    // }
    final res = await _storeItemRepository.updateStoreItem(storeItemModel);

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

  Future<bool> deleteStoreItem({required String id}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storeItem");
    //   return false;
    // }
    final res = await _storeItemRepository.deleteStoreItem(id);

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

  Future<bool> scrapStoreItem({
    required Map<String, dynamic> storeItemModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current storeItem");
    //   return false;
    // }
    final res = await _storeItemRepository.scrapStoreItem(storeItemModel);

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
