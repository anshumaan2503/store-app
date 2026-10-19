// lib/src/size/controllers/size_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/size_model.dart';
import '../domains/repositories/size_repository.dart';

/// WebSocket stream – same pattern as gradeAllDataStreamProvider
final sizeAllDataStreamProvider =
    StreamProvider.autoDispose<List<SizeModel>>((ref) async* {
  SocketManager socketManager = ref.watch(socketProvider);
  StreamController<List<SizeModel>> sizeStream =
      StreamController(sync: true);

  List<SizeModel> returnValue = [];

  socketManager.getSocket().emit("size:findAllSize", {});

  socketManager.getSocket().on("size:findAllSize", (data) {
    returnValue = [];
    for (var element in data) {
      returnValue.add(SizeModel.fromMap(Map<String, dynamic>.from(element)));
    }
    sizeStream.add(returnValue);
  });

  ref.onDispose(() {
    socketManager.getSocket().off("size:findAllSize");
    sizeStream.close();
  });

  yield returnValue;

  await for (final v in sizeStream.stream) {
    yield v;
  }
});

/// StateNotifier<bool> -> bool = isLoading
final sizeControllerProvider =
    StateNotifierProvider<SizeNotifier, bool>((ref) {
  return SizeNotifier(
    sizeRepository: ref.read(sizeRepositoryProvider),
    ref: ref,
  );
});

class SizeNotifier extends StateNotifier<bool> {
  final SizeRepository _sizeRepository;
  final Ref _ref;

  SizeNotifier({
    required SizeRepository sizeRepository,
    required Ref ref,
  })  : _sizeRepository = sizeRepository,
        _ref = ref,
        super(false);

  Future<String?> createSize({required Map<String, dynamic> size}) async {
    state = true;
    String? createdId;

    final res = await _sizeRepository.addSize(size);
    res.fold(
      (failure) => showSnackBar('Create size failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Size created' : 'Create failed'),
        );
        if (ok) {
          final created = data['data'] as Map<String, dynamic>?;
          createdId = (created?['_id'] ?? created?['id'])?.toString();
        }
      },
    );
    state = false;
    return createdId;
  }

  Future<bool> updateSize({required Map<String, dynamic> size}) async {
    state = true;
    bool okRes = false;

    final res = await _sizeRepository.updateSize(size);
    res.fold(
      (failure) => showSnackBar('Update size failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Size updated' : 'Update failed'),
        );
        okRes = ok;
      },
    );
    state = false;
    return okRes;
  }

  Future<bool> deleteSize({required String id}) async {
    state = true;
    bool okRes = false;

    final res = await _sizeRepository.deleteSize(id);
    res.fold(
      (failure) => showSnackBar('Delete size failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Size deleted' : 'Delete failed'),
        );
        okRes = ok;
      },
    );
    state = false;
    return okRes;
  }
}
