import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/auth_model.dart';
import '../domains/repositories/users_repository.dart';
import '../shared/providers/providers.dart';
import '../shared/repositories/shared_preference_repository.dart';

final userAllDataStreamProvider = StreamProvider.autoDispose<List<AuthModel>>((
  ref,
) async* {
  SocketManager socketManager = ref.watch(socketProvider);
  StreamController<List<AuthModel>> authStream = StreamController(sync: true);
  List<AuthModel> returnValue = [];
  socketManager.getSocket().emit("auth:findAll", {});
  socketManager.getSocket().on("auth:findAll", (data) {
    returnValue = [];
    for (var element in data) {
      returnValue.add(AuthModel.fromMap(element));
    }
    authStream.add(returnValue);
  });

  yield returnValue;
  await for (final returnValue in authStream.stream) {
    yield returnValue;
  }
});

final userDataStreamProvider = StreamProvider.autoDispose
    .family<AuthModel?, String>((ref, userId) async* {
      SocketManager socketManager = ref.watch(socketProvider);
      StreamController<AuthModel?> authStream = StreamController(sync: true);
      AuthModel? returnValue;
      socketManager.getSocket().emit("auth:findOneFetch", {"id": userId});
      socketManager.getSocket().on("auth:findOneFetch", (data) {
        returnValue = AuthModel.fromMap(data);
        authStream.add(returnValue);
      });

      yield returnValue;
      await for (final returnValue in authStream.stream) {
        yield returnValue;
      }
    });

final userFindOneDataStreamProvider = StreamProvider.autoDispose<AuthModel?>((
  ref,
) async* {
  final socketManager = ref.watch(socketProvider);

  // ✅ ensure auth connection + connect
  socketManager.initAuthConnection(ref);

  final socket = socketManager.getSocket();

  final uid = await ref.read(spRepositoryProvider).getStringValue("uid");
  if (uid.isEmpty) {
    yield null;
    return;
  }

  final controller = StreamController<AuthModel?>(sync: true);

  void handler(dynamic data) {
    try {
      if (data == null) {
        controller.add(null);
        return;
      }
      controller.add(AuthModel.fromMap(data));
    } catch (e, st) {
      ref.read(loggerProvider).e('auth:findOne deserialization error: $e\n$st');
      controller.add(null);
    }
  }

  ref.onDispose(() {
    socket.off("auth:findOne", handler);
    controller.close();
  });

  socket.on("auth:findOne", handler);

  // ✅ ensure connected before emit
  if (!socket.connected) socket.connect();

  socket.emit("auth:findOne", {"id": uid});

  yield* controller.stream;
});

final divisionAllDataStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final SocketManager socketManager = ref.watch(socketProvider);
      final socket = socketManager.getSocket();

      final controller = StreamController<List<Map<String, dynamic>>>(
        sync: true,
      );

      void handler(dynamic data) {
        final out = <Map<String, dynamic>>[];
        if (data is List) {
          for (final e in data) {
            if (e is Map) out.add(e.cast<String, dynamic>());
          }
        }
        controller.add(out);
      }

      socket.on('division:findAll', handler);
      socket.emit('division:findAll', {});

      ref.onDispose(() {
        socket.off('division:findAll', handler);
        controller.close();
      });

      return controller.stream;
    });

// Repository provider (configure baseUrl in your app bootstrap)
final usersControllerProvider = Provider<UsersNotifier>((ref) {
  return UsersNotifier(
    userRepository: ref.read(userRepositoryProvider),
    ref: ref,
  );
});

/// Holds and manages the list of users
class UsersNotifier extends StateNotifier<bool> {
  final UsersRepository _userRepository;
  final Ref _ref;

  UsersNotifier({required UsersRepository userRepository, required Ref ref})
    : _ref = ref,
      _userRepository = userRepository,
      super(false);

  Future<bool> createUser({required AuthModel authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _userRepository.addUser(authModel);

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

  Future<bool> updateUser({required AuthModel authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _userRepository.updateUser(authModel);

    res.fold(
      (failure) {
        showSnackBar("Update failed.");
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

  Future<bool> removeUser({required String authModelId}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _userRepository.deleteUser(authModelId);

    res.fold(
      (failure) {
        showSnackBar("Delete failed.");
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

  Future<bool> createDivision({required Map<String, dynamic> dto}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _userRepository.createDivision(dto);

    res.fold(
      (failure) {
        showSnackBar("division failed.");
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

// final usersProvider = AsyncNotifierProvider<UsersNotifier, List<AuthModel>>(
//   () => UsersNotifier(),
// );

/// Selector for a single user by id (used by edit page)
// final userByIdProvider = Provider.family<AuthModel?, String>((ref, id) {
//   final list = ref.watch(usersProvider).value;
//   return list?.firstWhere((u) => u.id == id, orElse: () => null);
// });
