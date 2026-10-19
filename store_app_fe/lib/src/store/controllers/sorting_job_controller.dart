// lib/src/sorting_jobs/controllers/sorting_job_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/shared/repositories/shared_preference_repository.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/sorting_job_machine_model.dart';
import '../domains/models/sorting_job_model.dart';
import '../domains/repositories/sorting_job_repository.dart';

// ✅ WebSocket list provider (GET)
final sortingJobAllDataStreamProvider =
    StreamProvider.autoDispose<List<SortingJobModel>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      // SocketManager socket = socketManager.getSocket();
      StreamController<List<SortingJobModel>> controller = StreamController(
        sync: true,
      );

      List<SortingJobModel> current = [];

      void handler(dynamic data) {
        try {
          final next = <SortingJobModel>[];
          if (data is List) {
            for (final e in data) {
              if (e is Map) {
                next.add(SortingJobModel.fromMap(Map<String, dynamic>.from(e)));
              }
            }
          }
          current = next;
          controller.add(current);
        } catch (_) {
          controller.add(const []);
        }
      }

      socketManager.getSocket().emit("sortingJob:findAllSortingJob", {});
      socketManager.getSocket().on("sortingJob:findAllSortingJob", handler);

      ref.onDispose(() {
        socketManager.getSocket().off("sortingJob:findAllSortingJob", handler);
        controller.close();
      });

      yield current;

      await for (final v in controller.stream) {
        yield v;
      }
    });

final sortingJobMachineAllDataStreamProvider =
    StreamProvider.autoDispose<List<MachineModel>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      // SocketManager socket = socketManager.getSocket();
      StreamController<List<MachineModel>> controller = StreamController(
        sync: true,
      );

      List<MachineModel> current = [];

      void handler(dynamic data) {
        try {
          final next = <MachineModel>[];
          if (data is List) {
            for (final e in data) {
              if (e is Map) {
                next.add(MachineModel.fromMap(Map<String, dynamic>.from(e)));
              }
            }
          }
          current = next;
          controller.add(current);
        } catch (_) {
          controller.add(const []);
        }
      }

      socketManager.getSocket().emit("sortingJob:findAllSortingJobMachine", {});
      socketManager.getSocket().on(
        "sortingJob:findAllSortingJobMachine",
        handler,
      );

      ref.onDispose(() {
        socketManager.getSocket().off(
          "sortingJob:findAllSortingJobMachine",
          handler,
        );
        controller.close();
      });

      yield current;

      await for (final v in controller.stream) {
        yield v;
      }
    });

// ✅ MUST be StateNotifierProvider so UI can use `.notifier` and watch bool loading.
final sortingJobControllerProvider =
    StateNotifierProvider<SortingJobNotifier, bool>((ref) {
      return SortingJobNotifier(
        sortingJobRepository: ref.read(sortingJobRepositoryProvider),
        ref: ref,
      );
    });

class SortingJobNotifier extends StateNotifier<bool> {
  final SortingJobRepository _repo;
  final Ref _ref;

  SortingJobNotifier({
    required SortingJobRepository sortingJobRepository,
    required Ref ref,
  }) : _repo = sortingJobRepository,
       _ref = ref,
       super(false);

  Future<String?> createJob({required Map<String, dynamic> payload}) async {
    state = true;
    String? createdId;

    final res = await _repo.createSortingJob(payload);
    res.fold((failure) => showSnackBar(failure.message), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Created' : 'Create failed'),
      );
      if (ok) {
        final d = data['data'] as Map<String, dynamic>?;
        createdId = (d?['_id'] ?? d?['id'])?.toString();
      }
    });

    state = false;
    return createdId;
  }

  Future<bool> completeJob({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    state = true;
    bool okRes = false;

    final res = await _repo.completeSortingJob(id, payload);
    res.fold((failure) => showSnackBar(failure.message), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Completed' : 'Complete failed'),
      );
      okRes = ok;
    });

    state = false;
    return okRes;
  }

  Future<bool> updateJob({required Map<String, dynamic> body}) async {
    state = true;
    bool okRes = false;
    final res = await _repo.updateJob(body);
    res.fold((failure) => showSnackBar('Update sorting job failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Job updated' : 'Update failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> startJob({required String id}) async {
    state = true;
    bool okRes = false;
    final res = await _repo.startJob(id);
    res.fold((failure) => showSnackBar('Start sorting job failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Job started' : 'Start failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> stopJob({required String id}) async {
    state = true;
    bool okRes = false;
    final res = await _repo.stopJob(id);
    res.fold((failure) => showSnackBar('Stop sorting job failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Job stopped' : 'Stop failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> restartJob({required String id}) async {
    state = true;
    bool okRes = false;
    final res = await _repo.restartJob(id);
    res.fold((failure) => showSnackBar('Restart sorting job failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Job restarted' : 'Restart failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> processJob({
    required String id,
    required Map<String, dynamic> body,
  }) async {
    state = true;
    bool okRes = false;
    final res = await _repo.processJob(id, body);
    res.fold((failure) => showSnackBar('Process sorting job failed.'), (data) {
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Processed' : 'Process failed'),
      );
      okRes = ok;
    });
    state = false;
    return okRes;
  }

  Future<bool> transferOne({
    required String jobId,
    required String bagCode,
    required double transferQtyInWt,
    String? bagId, // optional if backend supports it
  }) async {
    state = true;
    bool okRes = false;

    final body = <String, dynamic>{
      'bagCode': bagCode,
      'transferQtyInWt': transferQtyInWt,
    };
    if (bagId != null && bagId.isNotEmpty) body['bagId'] = bagId;

    final res = await _repo.transferOne(jobId: jobId, body: body);

    res.fold((failure) => showSnackBar(failure.message), (data) {
      print(data);
      final ok = data['status'] == true;
      showSnackBar(
        data['msg']?.toString() ?? (ok ? 'Transferred' : 'Transfer failed'),
      );
      okRes = ok;
    });

    state = false;
    return okRes;
  }

  Future<bool> transferToAnotherBag({
    required String jobId,
    required String sourceBagId,
    required String targetBagId,
    required double transferQtyInWt,
  }) async {
    state = true;
    bool ok = false;

    final res = await _repo.transferToBag(
      jobId: jobId,
      body: {
        'sourceBagId': sourceBagId,
        'targetBagId': targetBagId,
        'transferQtyInWt': transferQtyInWt,
      },
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Transferred' : 'Failed'));
    });

    state = false;
    return ok;
  }

  Future<bool> transferToAnotherBagTwo({
    required String jobId,
    required String targetBagId,
    required double transferQtyInWt,
    required String createdBy,
  }) async {
    state = true;
    bool ok = false;

    final res = await _repo.transferToBagTwo(
      jobId: jobId,
      body: {
        'targetBagId': targetBagId,
        'transferQtyInWt': transferQtyInWt,
        'createdBy': createdBy,
      },
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Transferred' : 'Failed'));
    });

    state = false;
    return ok;
  }

  Future<bool> addBagToJob({
    required String jobId,
    required String bagId,
    required double qtyInWt,
  }) async {
    state = true;
    bool ok = false;

    final createdBy = await _ref
        .read(spRepositoryProvider)
        .getStringValue("uid");

    final res = await _repo.addBagToJob(
      jobId: jobId,
      createdBy: createdBy,
      body: {'bagId': bagId, 'qtyInWt': qtyInWt},
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Added' : 'Failed'));
    });

    state = false;
    return ok;
  }

  Future<bool> addMachineToJob({required Map<String, dynamic> machine}) async {
    state = true;
    bool ok = false;

    final createdBy = await _ref
        .read(spRepositoryProvider)
        .getStringValue("uid");

    final res = await _repo.addMachineToJob(
      createdBy: createdBy,
      body: machine,
    );

    res.fold((f) => showSnackBar(f.message), (data) {
      ok = data['status'] == true;
      showSnackBar(data['msg']?.toString() ?? (ok ? 'Added' : 'Failed'));
    });

    state = false;
    return ok;
  }
}
