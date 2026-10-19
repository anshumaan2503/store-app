// lib/src/grade/controllers/grade_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/grade_model.dart';
import '../domains/repositories/grade_repository.dart';

final gradeAllDataStreamProvider =
    StreamProvider.autoDispose<List<GradeModel>>((ref) async* {
  SocketManager socketManager = ref.watch(socketProvider);
  StreamController<List<GradeModel>> gradeStream =
      StreamController(sync: true);

  List<GradeModel> returnValue = [];

  socketManager.getSocket().emit("grade:findAllGrade", {});

  socketManager.getSocket().on("grade:findAllGrade", (data) {
    returnValue = [];
    for (var element in data) {
      returnValue.add(GradeModel.fromMap(Map<String, dynamic>.from(element)));
    }
    gradeStream.add(returnValue);
  });

  ref.onDispose(() {
    socketManager.getSocket().off("grade:findAllGrade");
    gradeStream.close();
  });

  yield returnValue;

  await for (final v in gradeStream.stream) {
    yield v;
  }
});

final gradeControllerProvider =
    StateNotifierProvider<GradeNotifier, bool>((ref) {
  return GradeNotifier(
    gradeRepository: ref.read(gradeRepositoryProvider),
    ref: ref,
  );
});

class GradeNotifier extends StateNotifier<bool> {
  final GradeRepository _gradeRepository;
  final Ref _ref;

  GradeNotifier({
    required GradeRepository gradeRepository,
    required Ref ref,
  })  : _gradeRepository = gradeRepository,
        _ref = ref,
        super(false);

  Future<String?> createGrade({required Map<String, dynamic> grade}) async {
    state = true;
    String? createdId;

    final res = await _gradeRepository.addGrade(grade);
    res.fold(
      (failure) => showSnackBar('Create grade failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Grade created' : 'Create failed'),
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

  Future<bool> updateGrade({required Map<String, dynamic> grade}) async {
    state = true;
    bool okRes = false;

    final res = await _gradeRepository.updateGrade(grade);
    res.fold(
      (failure) => showSnackBar('Update grade failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Grade updated' : 'Update failed'),
        );
        okRes = ok;
      },
    );
    state = false;
    return okRes;
  }

  Future<bool> deleteGrade({required String id}) async {
    state = true;
    bool okRes = false;

    final res = await _gradeRepository.deleteGrade(id);
    res.fold(
      (failure) => showSnackBar('Delete grade failed.'),
      (data) {
        final ok = data['status'] == true;
        showSnackBar(
          data['msg']?.toString() ?? (ok ? 'Grade deleted' : 'Delete failed'),
        );
        okRes = ok;
      },
    );
    state = false;
    return okRes;
  }
}
