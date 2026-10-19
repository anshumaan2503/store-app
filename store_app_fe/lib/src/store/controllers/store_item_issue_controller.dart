// Repository provider (configure baseUrl in your app bootstrap)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/repositories/store_item_issue_repository.dart';

final itemIssueAllDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> itemIssueStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findAllItemIssue", {});
      socketManager.getSocket().on("store:findAllItemIssue", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        itemIssueStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemIssueStream.stream) {
        yield returnValue;
      }
    });

final itemIssueStatusDataStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, List<String>>((ref, status) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<List<Map<String, dynamic>>> itemIssueStream =
          StreamController(sync: true);
      List<Map<String, dynamic>> returnValue = [];
      socketManager.getSocket().emit("store:findStatusItemIssue", {
        "status": status,
      });
      socketManager.getSocket().on("store:findStatusItemIssue", (data) {
        returnValue = [];
        for (var element in data) {
          returnValue.add(element);
        }
        itemIssueStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemIssueStream.stream) {
        yield returnValue;
      }
    });

final itemIssueOneDataStreamProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, receiveId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<Map<String, dynamic>?> itemIssueStream =
          StreamController(sync: true);
      Map<String, dynamic>? returnValue;
      socketManager.getSocket().emit("store:findOneItemIssue", {
        "id": receiveId,
      });
      socketManager.getSocket().on("store:findOneItemIssue", (data) {
        returnValue = data;

        itemIssueStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in itemIssueStream.stream) {
        yield returnValue;
      }
    });

final itemIssueControllerProvider = Provider<ItemIssueNotifier>((ref) {
  return ItemIssueNotifier(
    itemIssueRepository: ref.read(itemIssueRepositoryProvider),
    ref: ref,
  );
});

/// Holds and manages the list of itemIssue
class ItemIssueNotifier extends StateNotifier<bool> {
  final ItemIssueRepository _itemIssueRepository;
  final Ref _ref;

  ItemIssueNotifier({
    required ItemIssueRepository itemIssueRepository,
    required Ref ref,
  }) : _ref = ref,
       _itemIssueRepository = itemIssueRepository,
       super(false);

  Future<bool> createItemIssue({
    required Map<String, dynamic> itemIssueModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.addItemIssue(itemIssueModel);

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

  Future<bool> updateItemIssue({
    required Map<String, dynamic> itemIssueModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.updateItemIssue(itemIssueModel);

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

  Future<bool> approveItemIssue({
    required Map<String, dynamic> approveItemIssue,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.approveItemIssue(approveItemIssue);

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

  Future<bool> rejectItemIssue({
    required Map<String, dynamic> approveItemIssue,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.rejectItemIssue(approveItemIssue);

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

  Future<bool> itemIssueToPlace({
    required Map<String, dynamic> itemIssueToPlace,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.itemIssueToPlace(itemIssueToPlace);

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

  Future<bool> deleteItemIssue({required String id}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.deleteItemIssue(id);

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

  Future<bool> returnItemIssue({
    required Map<String, dynamic> returnItemIssue,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.returnItemIssue(returnItemIssue);

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

  Future<bool> closeItemIssue({
    required Map<String, dynamic> returnItemIssue,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current itemIssue");
    //   return false;
    // }
    final res = await _itemIssueRepository.closeItemIssue(returnItemIssue);

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
