// lib/src/item/controllers/item_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/item_model.dart';
import '../domains/repositories/item_repository.dart';

final itemAllDataStreamProvider = StreamProvider.autoDispose<List<ItemModel>>((
  ref,
) async* {
  final socketManager = ref.watch(socketProvider);
  final stream = StreamController<List<ItemModel>>(sync: true);
  List<ItemModel> items = [];

  socketManager.getSocket().emit("item:findAllItem", {});
  socketManager.getSocket().on("item:findAllItem", (data) {
    items = [];
    for (var element in data) {
      items.add(ItemModel.fromMap(Map<String, dynamic>.from(element)));
    }
    stream.add(items);
  });

  ref.onDispose(() {
    socketManager.getSocket().off("item:findAllItem");
    stream.close();
  });

  yield items;
  await for (final v in stream.stream) {
    yield v;
  }
});

final itemControllerProvider = Provider<ItemNotifier>((ref) {
  return ItemNotifier(
    itemRepository: ref.read(itemRepositoryProvider),
    ref: ref,
  );
});

class ItemNotifier extends StateNotifier<bool> {
  final ItemRepository _itemRepository;
  final Ref _ref;

  ItemNotifier({required ItemRepository itemRepository, required Ref ref})
    : _itemRepository = itemRepository,
      _ref = ref,
      super(false);

  Future<String?> createItem({required Map<String, dynamic> item}) async {
    state = true;
    String? createdId;

    final res = await _itemRepository.addItem(item);
    res.fold((failure) => showSnackBar('Create item failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Item created' : 'Create item failed'),
      );
      if (ok) {
        final created = data['data'] as Map<String, dynamic>?;
        createdId = (created?['_id'] ?? created?['id'])?.toString();
      }
    });
    state = false;
    return createdId;
  }

  Future<bool> updateItem({required Map<String, dynamic> item}) async {
    state = true;
    bool okRes = false;

    final res = await _itemRepository.updateItem(item);
    res.fold((failure) => showSnackBar('Update item failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Item updated' : 'Update item failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> deleteItem({required String id}) async {
    state = true;
    bool okRes = false;

    final res = await _itemRepository.deleteItem(id);
    res.fold((failure) => showSnackBar('Delete item failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Item deleted' : 'Delete item failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }
}
