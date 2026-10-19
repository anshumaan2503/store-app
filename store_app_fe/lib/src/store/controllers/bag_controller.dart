// lib/controllers/bag_controller.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/bag_model.dart';
import '../domains/repositories/bag_repository.dart';

// ✅ WebSocket list stream provider (GET)
final bagAllDataStreamProvider = StreamProvider.autoDispose<List<BagModel>>((
  ref,
) async* {
  SocketManager socketManager = ref.watch(socketProvider);
  StreamController<List<BagModel>> controller = StreamController(sync: true);

  List<BagModel> returnValue = [];

  // client -> server
  socketManager.getSocket().emit("bag:findAllBag", {});

  socketManager.getSocket().on("bag:findAllBag", (data) {
    returnValue = [];
    for (var element in data) {
      returnValue.add(BagModel.fromMap(Map<String, dynamic>.from(element)));
    }
    controller.add(returnValue);
  });

  ref.onDispose(() {
    socketManager.getSocket().off("bag:findAllBag");
    controller.close();
  });

  yield returnValue;

  await for (final v in controller.stream) {
    yield v;
  }
});

/// ✅ bagControllerProvider MUST be StateNotifierProvider<BagNotifier, bool>
/// bool = isLoading
final bagControllerProvider = StateNotifierProvider<BagNotifier, bool>((ref) {
  return BagNotifier(repository: ref.read(bagRepositoryProvider), ref: ref);
});

class BagNotifier extends StateNotifier<bool> {
  final BagRepository _repository;
  final Ref _ref;

  BagNotifier({required BagRepository repository, required Ref ref})
    : _repository = repository,
      _ref = ref,
      super(false);

  Future<String?> createBag({required Map<String, dynamic> bag}) async {
    state = true;
    String? createdId;

    final res = await _repository.addBag(bag);
    res.fold((failure) => showSnackBar('Create bag failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Bag created' : 'Create failed'),
      );
      if (ok) {
        final created = data['data'] as Map<String, dynamic>?;
        createdId = (created?['_id'] ?? created?['id'])?.toString();
        // optional: refresh WS list by re-emitting
        _ref.read(socketProvider).getSocket().emit("bag:findAllBag", {});
      }
    });

    state = false;
    return createdId;
  }

  Future<bool> updateBag({required Map<String, dynamic> bag}) async {
    state = true;
    bool okRes = false;

    final res = await _repository.updateBag(bag);
    res.fold((failure) => showSnackBar('Update bag failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Bag updated' : 'Update failed'),
      );
      okRes = ok;
      if (ok) {
        _ref.read(socketProvider).getSocket().emit("bag:findAllBag", {});
      }
    });

    state = false;
    return okRes;
  }

  Future<bool> deleteBag({required String id}) async {
    state = true;
    bool okRes = false;

    final res = await _repository.deleteBag(id);
    res.fold((failure) => showSnackBar('Delete bag failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Bag deleted' : 'Delete failed'),
      );
      okRes = ok;
      if (ok) {
        _ref.read(socketProvider).getSocket().emit("bag:findAllBag", {});
      }
    });

    state = false;
    return okRes;
  }

  Future<bool> transferToOtherBag({
    required String sourceBagId,
    required String targetBagId,
    required double qty,
  }) async {
    state = true;
    bool ok = false;

    final res = await _repository.transferToOtherBag(
      sourceBagId: sourceBagId,
      targetBagId: targetBagId,
      qty: qty,
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Transferred' : 'Failed'));
    });

    state = false;
    return ok;
  }

  Future<bool> addStock({required String bagId, required int qty}) async {
    state = true;
    bool okRes = false;


    final res = await _repository.addStock(
      bagId: bagId,
      body: {'qty': qty, },
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      okRes = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (okRes ? 'Stock added' : 'Failed'),
      );
    });

    state = false;
    return okRes;
  }
}
