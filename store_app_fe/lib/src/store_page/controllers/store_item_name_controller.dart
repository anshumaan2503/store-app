// import 'dart:async';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import '../../components/socket_manager.dart';
// import '../../components/utils.dart';
// import '../domains/models/store_item_name_model.dart';
// import '../domains/repositories/store_item_name_repository.dart';

// class ItemNamePagedResult {
//   final List<StoreItemName> rows;
//   final int total;
//   final int page;
//   final int limit;
//   const ItemNamePagedResult({
//     required this.rows,
//     required this.total,
//     required this.page,
//     required this.limit,
//   });
// }

// class ItemNamePagedQuery {
//   final int page;
//   final int limit;
//   final String search;
//   final String sort;
//   const ItemNamePagedQuery({
//     this.page = 1,
//     this.limit = 12,
//     this.search = '',
//     this.sort = '-createdAt',
//   });

//   Map<String, dynamic> toJson() => {
//     "page": page,
//     "limit": limit,
//     "search": search,
//     "sort": sort,
//   };
// }

// final itemNamePagedStreamProvider = StreamProvider.autoDispose
//     .family<ItemNamePagedResult, ItemNamePagedQuery>((ref, q) async* {
//       final socket = ref.watch(socketProvider).getSocket();
//       final ctrl = StreamController<ItemNamePagedResult>(sync: true);

//       void handler(dynamic data) {
//         try {
//           if (data is Map) {
//             final list =
//                 (data['rows'] as List? ?? const [])
//                     .map(
//                       (e) => StoreItemName.fromMap(e as Map<String, dynamic>),
//                     )
//                     .toList();
//             ctrl.add(
//               ItemNamePagedResult(
//                 rows: list,
//                 total: (data['total'] ?? list.length) as int,
//                 page: (data['page'] ?? q.page) as int,
//                 limit: (data['limit'] ?? q.limit) as int,
//               ),
//             );
//           }
//         } catch (_) {}
//       }

//       socket.on('store:findAllItemNamePaged', handler);
//       socket.emit('store:findAllItemNamePaged', q.toJson());

//       ref.onDispose(() {
//         socket.off('store:findAllItemNamePaged', handler);
//         ctrl.close();
//       });

//       yield ItemNamePagedResult(
//         rows: const [],
//         total: 0,
//         page: q.page,
//         limit: q.limit,
//       );
//       await for (final v in ctrl.stream) yield v;
//     });

// final storeItemNameControllerProvider = Provider(
//   (ref) => StoreItemNameController(ref),
// );

// class StoreItemNameController extends StateNotifier<bool> {
//   final Ref ref;
//   StoreItemNameController(this.ref) : super(false);

//   Future<StoreItemName?> createItemName({
//     required Map<String, dynamic> dto,
//   }) async {
//     state = true;
//     StoreItemName? created;
//     final res = await ref.read(storeItemNameRepositoryProvider).create(dto);
//     res.fold((f) => showSnackBar(f.message), (data) {
//       if (data['status'] == true && data['data'] is Map) {
//         created = StoreItemName.fromMap(
//           (data['data'] as Map).cast<String, dynamic>(),
//         );
//         showSnackBar(data['msg']?.toString() ?? 'Created');
//       } else {
//         showSnackBar(data['msg']?.toString() ?? 'Create failed');
//       }
//     });
//     state = false;
//     return created;
//   }

//   Future<bool> updateItemName({
//     required String id,
//     required Map<String, dynamic> dto,
//   }) async {
//     state = true;
//     bool ok = false;
//     final res = await ref.read(storeItemNameRepositoryProvider).update(id, dto);
//     res.fold((f) => showSnackBar(f.message), (data) {
//       ok = data['status'] == true;
//       showSnackBar(
//         data['msg']?.toString() ?? (ok ? 'Updated' : 'Update failed'),
//       );
//     });
//     state = false;
//     return ok;
//   }

//   Future<bool> deleteItemName(String id) async {
//     state = true;
//     bool ok = false;
//     final res = await ref.read(storeItemNameRepositoryProvider).delete(id);
//     res.fold((f) => showSnackBar(f.message), (data) {
//       ok = data['status'] == true;
//       showSnackBar(
//         data['msg']?.toString() ?? (ok ? 'Deleted' : 'Delete failed'),
//       );
//     });
//     state = false;
//     return ok;
//   }
// }
