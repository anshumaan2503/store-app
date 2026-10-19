import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/store_unit_name_model.dart';
import '../domains/repositories/store_unit_name_repository.dart';

class UnitNamePagedResult {
  final List<StoreUnitName> rows;
  final int total;
  final int page;
  final int limit;
  const UnitNamePagedResult({
    required this.rows,
    required this.total,
    required this.page,
    required this.limit,
  });
}

class UnitNamePagedQuery {
  final int page;
  final int limit;
  final String search;
  final String sort;
  const UnitNamePagedQuery({
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

final unitNamePagedStreamProvider = StreamProvider.autoDispose
    .family<UnitNamePagedResult, UnitNamePagedQuery>((ref, q) async* {
      final socket = ref.watch(socketProvider).getSocket();
      final ctrl = StreamController<UnitNamePagedResult>(sync: true);

      void handler(dynamic data) {
        try {
          if (data is Map) {
            final list =
                (data['rows'] as List? ?? const [])
                    .map(
                      (e) => StoreUnitName.fromMap(e as Map<String, dynamic>),
                    )
                    .toList();
            ctrl.add(
              UnitNamePagedResult(
                rows: list,
                total: (data['total'] ?? list.length) as int,
                page: (data['page'] ?? q.page) as int,
                limit: (data['limit'] ?? q.limit) as int,
              ),
            );
          }
        } catch (_) {}
      }

      socket.on('store:findAllUnitNamePaged', handler);
      socket.emit('store:findAllUnitNamePaged', q.toJson());

      ref.onDispose(() {
        socket.off('store:findAllUnitNamePaged', handler);
        ctrl.close();
      });

      yield UnitNamePagedResult(
        rows: const [],
        total: 0,
        page: q.page,
        limit: q.limit,
      );
      await for (final v in ctrl.stream) {
        yield v;
      }
    });

final storeUnitNameControllerProvider = Provider(
  (ref) => StoreUnitNameController(ref),
);

class StoreUnitNameController extends StateNotifier<bool> {
  final Ref ref;
  StoreUnitNameController(this.ref) : super(false);

  Future<StoreUnitName?> createUnitName({
    required Map<String, dynamic> dto,
  }) async {
    state = true;
    StoreUnitName? created;
    final res = await ref.read(storeUnitNameRepositoryProvider).create(dto);
    res.fold((f) => showSnackBar(f.message), (data) {
      if (data['status'] == true && data['data'] is Map) {
        created = StoreUnitName.fromMap(
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

  Future<bool> updateUnitName({
    required String id,
    required Map<String, dynamic> dto,
  }) async {
    state = true;
    bool ok = false;
    final res = await ref.read(storeUnitNameRepositoryProvider).update(id, dto);
    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Updated' : 'Update failed'),
      );
    });
    state = false;
    return ok;
  }

  Future<bool> deleteUnitName(String id) async {
    state = true;
    bool ok = false;
    final res = await ref.read(storeUnitNameRepositoryProvider).delete(id);
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
