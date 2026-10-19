import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_category_model.dart';
import '../domains/repositories/store_category_repository.dart';

class CategoryPagedResult {
  final List<StoreCategory> rows;
  final int total;
  final int page;
  final int limit;
  const CategoryPagedResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class CategoryPagedQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;
  const CategoryPagedQuery({
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
}

final categoryPagedStreamProvider = StreamProvider.autoDispose
    .family<CategoryPagedResult, CategoryPagedQuery>((ref, q) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<CategoryPagedResult>(sync: true);

      void handler(dynamic data) {
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map(
                      (e) => StoreCategory.fromMap(e as Map<String, dynamic>),
                    )
                    .toList();
            ctrl.add(
              CategoryPagedResult(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? q.page) as int,
                limit: (data['limit'] ?? q.limit) as int,
              ),
            );
          }
        } catch (_) {}
      }

      socket.on('store:findAllCategoryPaged', handler);
      socket.emit('store:findAllCategoryPaged', q.toJson());

      ref.onDispose(() {
        socket.off('store:findAllCategoryPaged', handler);
        ctrl.close();
      });

      yield CategoryPagedResult(
        rows: const [],
        total: 0,
        page: q.page,
        limit: q.limit,
      );
      await for (final v in ctrl.stream) {
        yield v;
      }
    });

final parentcategoryAllDataStreamProvider =
    StreamProvider.autoDispose<List<StoreCategory>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreCategory>> categoryByIdItemStream =
          StreamController(sync: true);
      List<StoreCategory> returnValue = [];
      socketManager.getSocket().emit("store:parentcategory", {});
      socketManager.getSocket().on("store:parentcategory", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreCategory.fromMap(element));
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final levelOnecategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreCategory>> categoryByIdItemStream =
          StreamController(sync: true);
      List<StoreCategory> returnValue = [];
      socketManager.getSocket().emit("store:levelOnecategoryByIdperent", {
        "id": categoryId,
      });
      socketManager.getSocket().on("store:levelOnecategoryByIdperent", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreCategory.fromMap(element));
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final levelTwocategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreCategory>> categoryByIdItemStream =
          StreamController(sync: true);
      List<StoreCategory> returnValue = [];
      socketManager.getSocket().emit("store:levelTwocategoryByIdperent", {
        "id": categoryId,
      });
      socketManager.getSocket().on("store:levelTwocategoryByIdperent", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreCategory.fromMap(element));
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final levelThreecategoryByIdperentDataStreamProvider = StreamProvider
    .autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreCategory>> categoryByIdItemStream =
          StreamController(sync: true);
      List<StoreCategory> returnValue = [];
      socketManager.getSocket().emit("store:levelThreecategoryByIdperent", {
        "id": categoryId,
      });
      socketManager.getSocket().on("store:levelThreecategoryByIdperent", (
        data,
      ) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreCategory.fromMap(element));
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final itemCategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<StoreCategory>> categoryByIdItemStream =
          StreamController(sync: true);
      List<StoreCategory> returnValue = [];
      socketManager.getSocket().emit("store:itemMachineCategoryGet:req", {
        "id": categoryId,
      });
      socketManager.getSocket().on("store:itemMachineCategoryGet:res", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(StoreCategory.fromMap(element));
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final storeCategoryOneStreamProvider = StreamProvider.autoDispose
    .family<StoreCategory?, String>((ref, id) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final controller = StreamController<StoreCategory?>(sync: true);

      void handler(dynamic data) {
        try {
          if (data is Map) {
            controller.add(StoreCategory.fromMap(data.cast<String, dynamic>()));
          }
        } catch (_) {}
      }

      socket.on('store:findOneCategory', handler);
      socket.emit('store:findOneCategory', {'id': id});

      ref.onDispose(() {
        socket.off('store:findOneCategory', handler);
        controller.close();
      });

      yield null;
      await for (final v in controller.stream) {
        yield v;
      }
    });

final storeCategoryByItemissueProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> categoryByIdItemStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:issueByIdItemWithCategory");
      socketManager.getSocket().on("store:issueByIdItemWithCategory", (data) {
        print(data);
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        categoryByIdItemStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in categoryByIdItemStream.stream) {
        yield returnValue;
      }
    });

final storeCategoryControllerProvider = Provider(
  (ref) => StoreCategoryController(ref),
);

class StoreCategoryController extends StateNotifier<bool> {
  final Ref ref;
  StoreCategoryController(this.ref) : super(false);

  Future<StoreCategory?> createCategory({
    required Map<String, dynamic> dto,
  }) async {
    state = true;

    StoreCategory? created;
    final res = await ref.read(storeCategoryRepositoryProvider).create(dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      if (data['status'] == true && data['data'] is Map) {
        created = StoreCategory.fromMap(
          (data['data'] as Map).cast<String, dynamic>(),
        );
        showSnackBar(data['msg']?.toString() ?? 'Created');
      } else {
        showSnackBar(data['msg']?.toString() ?? 'Create failed');
      }
    });

    state = false;
    return created;
  }

  Future<bool> updateCategory({
    required String id,
    required Map<String, dynamic> dto,
  }) async {
    state = true;

    bool ok = false;
    final res = await ref.read(storeCategoryRepositoryProvider).update(id, dto);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Updated' : 'Update failed'),
      );
    });

    state = false;
    return ok;
  }

  Future<bool> deleteCategory(String id) async {
    state = true;

    bool ok = false;
    final res = await ref.read(storeCategoryRepositoryProvider).delete(id);

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Deleted' : 'Delete failed'),
      );
    });

    state = false;
    return ok;
  }
}
