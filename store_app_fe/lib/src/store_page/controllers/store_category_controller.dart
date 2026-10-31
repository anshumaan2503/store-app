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
    .family<CategoryPagedResult, CategoryPagedQuery>((ref, q) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<CategoryPagedResult>();
      Timer? timeoutTimer;

      void handler(dynamic data) {
        timeoutTimer?.cancel();
        timeoutTimer = null;
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map(
                      (e) => StoreCategory.fromMap(e as Map<String, dynamic>),
                    )
                    .toList();
            if (!ctrl.isClosed) {
              ctrl.add(
                CategoryPagedResult(
                  rows: list,
                  total: (data['total'] ?? list.length) as int,
                  page: (data['page'] ?? q.page) as int,
                  limit: (data['limit'] ?? q.limit) as int,
                ),
              );
            }
          }
        } catch (_) {}
      }

      socket.on('store:findAllCategoryPaged', handler);
      socket.emit('store:findAllCategoryPaged', q.toJson());

      // Fallback timer: only emit empty after timeout if server never responds
      timeoutTimer = Timer(const Duration(seconds: 15), () {
        if (!ctrl.isClosed) {
          ctrl.add(
            CategoryPagedResult(
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
        socket.off('store:findAllCategoryPaged', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final parentcategoryAllDataStreamProvider =
    StreamProvider.autoDispose<List<StoreCategory>>((ref) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreCategory>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:parentcategory", handler);
      socket.emit("store:parentcategory", {});

      ref.onDispose(() {
        socket.off("store:parentcategory", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final levelOnecategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreCategory>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:levelOnecategoryByIdperent", handler);
      socket.emit("store:levelOnecategoryByIdperent", {"id": categoryId});

      ref.onDispose(() {
        socket.off("store:levelOnecategoryByIdperent", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final levelTwocategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreCategory>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:levelTwocategoryByIdperent", handler);
      socket.emit("store:levelTwocategoryByIdperent", {"id": categoryId});

      ref.onDispose(() {
        socket.off("store:levelTwocategoryByIdperent", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final levelThreecategoryByIdperentDataStreamProvider = StreamProvider
    .autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreCategory>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:levelThreecategoryByIdperent", handler);
      socket.emit("store:levelThreecategoryByIdperent", {"id": categoryId});

      ref.onDispose(() {
        socket.off("store:levelThreecategoryByIdperent", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final itemCategoryByIdperentDataStreamProvider = StreamProvider.autoDispose
    .family<List<StoreCategory>, String>((ref, categoryId) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<StoreCategory>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => StoreCategory.fromMap(Map<String, dynamic>.from(e)))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:itemMachineCategoryGet:res", handler);
      socket.emit("store:itemMachineCategoryGet:req", {"id": categoryId});

      ref.onDispose(() {
        socket.off("store:itemMachineCategoryGet:res", handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final storeCategoryOneStreamProvider = StreamProvider.autoDispose
    .family<StoreCategory?, String>((ref, id) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<StoreCategory?>();

      void handler(dynamic data) {
        try {
          if (data is Map) {
            if (!ctrl.isClosed) {
              ctrl.add(StoreCategory.fromMap(data.cast<String, dynamic>()));
            }
          }
        } catch (_) {}
      }

      socket.on('store:findOneCategory', handler);
      socket.emit('store:findOneCategory', {'id': id});

      ref.onDispose(() {
        socket.off('store:findOneCategory', handler);
        ctrl.close();
      });

      return ctrl.stream;
    });

final storeCategoryByItemissueProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<List<Map<String, dynamic>>>();

      void handler(dynamic data) {
        try {
          if (data is! List) return;
          final list = data
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          if (!ctrl.isClosed) ctrl.add(list);
        } catch (_) {}
      }

      socket.on("store:issueByIdItemWithCategory", handler);
      socket.emit("store:issueByIdItemWithCategory");

      ref.onDispose(() {
        socket.off("store:issueByIdItemWithCategory", handler);
        ctrl.close();
      });

      return ctrl.stream;
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
