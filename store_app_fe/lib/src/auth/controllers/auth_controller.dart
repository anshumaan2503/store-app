import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../components/constants.dart';
import '../../components/socket_manager.dart';
import '../../components/utils.dart';
import '../domains/models/auth_model.dart';
import '../domains/providers/uid_provider.dart';
import '../domains/repositories/auth_repositories.dart';
import '../shared/providers/auth_model_provider.dart';
import '../shared/providers/providers.dart';
import '../shared/providers/token_provider.dart';
import '../shared/repositories/shared_preference_repository.dart';
import '../../store_page/controllers/guided_tour_controller.dart';
import '../../store_page/controllers/store_cart_controller.dart';
import 'users_controller.dart';

final authStateChangesProvider = StreamProvider.autoDispose<AuthModel?>((
  ref,
) async* {
  AuthModel? returnValue = ref.watch(authModelProvider);

  if (returnValue != null) {
    yield returnValue;
  }

  final uid = await ref.read(spRepositoryProvider).getStringValue("uid");

  if (uid.isNotEmpty) {
    ref.read(uidProvider.notifier).updateUid(uid);
    try {
      final fetchedAuthModel = await ref
          .read(authRepositoryProvider)
          .getAuthConnection(uid);

      // If a new auth model is fetched and it's different from the current one, update the state
      if (fetchedAuthModel != null && fetchedAuthModel != returnValue) {
        ref.read(authModelProvider.notifier).setAuthModel(fetchedAuthModel);

        // Yield the newly fetched auth model
        yield fetchedAuthModel;
      }
    } catch (e) {
      // Handle error while fetching the auth model
      print("Error fetching auth details: $e");
    }
  }
  yield returnValue;
});

final findOneAuthStateChangesProvider = StreamProvider.autoDispose.family<
  AuthModel?,
  String
>((ref, uid) async* {
  AuthModel? returnValue = ref.watch(authModelProvider);

  if (returnValue != null) {
    yield returnValue;
  }

  // final uid = await ref.read(spRepositoryProvider).getStringValue("uid");

  // if (uid != null && uid.isNotEmpty) {
  ref.read(uidProvider.notifier).updateUid(uid);
  try {
    final fetchedAuthModel = await ref
        .read(authRepositoryProvider)
        .getAuthConnection(uid);

    // If a new auth model is fetched and it's different from the current one, update the state
    if (fetchedAuthModel != null && fetchedAuthModel != returnValue) {
      ref.read(authModelProvider.notifier).setAuthModel(fetchedAuthModel);

      // Yield the newly fetched auth model
      yield fetchedAuthModel;
    }
  } catch (e) {
    // Handle error while fetching the auth model
    print("Error fetching auth details: $e");
  }
  // }
  yield returnValue;
});

// ✅ One user per id (cached by id)
final userByIdProvider = FutureProvider.family.autoDispose<AuthModel?, String>((
  ref,
  userId,
) async {
  final id = userId.trim();
  if (id.isEmpty) return null;

  // IMPORTANT: use read so it doesn't refetch on unrelated rebuilds
  return ref.read(authControllerProvider).getUserById(id);
});

final authControllerProvider = Provider<AuthNotifier>((ref) {
  //   return AuthNotifier(ref.read(authRepositoryProvider), null);
  // });

  return AuthNotifier(
    authRepository: ref.read(authRepositoryProvider),
    ref: ref,
  );
});

class AuthNotifier extends StateNotifier<bool> {
  final AuthRepository _authRepository;
  final Ref _ref;
  AuthNotifier({required AuthRepository authRepository, required Ref ref})
    : _ref = ref,
      _authRepository = authRepository,
      super(false);

  void logout(WidgetRef ref) async {
    ref.read(loggerProvider).i("logout pressed");
    ref.read(socketProvider).dispose(ref);
    await ref.read(spRepositoryProvider).setStringValue("uid", "");
    await ref.read(spRepositoryProvider).setStringValue("authToken", "");
    ref.read(authTokenProvider.notifier).clearToken();
    ref.read(uidProvider.notifier).clearUid();
    ref.read(authModelProvider.notifier).setAuthModel(null);
    ref.invalidate(socketProvider);
    ref.invalidate(userFindOneDataStreamProvider);
    ref.invalidate(guidedTourStep1SessionDismissedProvider);
    ref.invalidate(storeCartProvider);
  }

  Future<bool> createAuth({required Map<String, dynamic> authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.createAuth(authModel);

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

  Future<bool> createUser({required Map<String, dynamic> authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.createUser(authModel);

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

  Future<bool> updateUser({required Map<String, dynamic> authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.updateUser(authModel);

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

  Future<bool> resetPasswordUser({
    required Map<String, dynamic> authModel,
  }) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.resetPasswordUser(authModel);

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

  Future<bool> deleteUser({required Map<String, dynamic> authModel}) async {
    state = true;
    // final createdBy = _ref.read(uidProvider);
    bool check = false;
    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.deleteUser(authModel);

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

  Future<bool> loginAuth({required Map<String, dynamic> authModel}) async {
    state = true;

    bool check = false;
    // final createdBy = _ref.read(uidProvider);

    // if (createdBy.isEmpty) {
    //   showSnackBar("unable to get current user");
    //   return false;
    // }
    final res = await _authRepository.loginAuth(authModel);

    res.fold(
      (failure) {
        showSnackBar(
          failure.message.isNotEmpty ? failure.message : "Login failed.",
        );
      },
      (data) {
        if (data['status']) {
          showSnackBar(data['msg']);
          check = true;
        } else {
          showSnackBar(data['msg']);
          // check = false;
        }
      },
    );

    return check;
  }

  Future<AuthModel?> getUserById(String id) async {
    try {
      final url = Uri.parse("${Constants.socketUrl}/api/auth/users/$id");

      final res = await http.get(
        url,
        headers: const {"Content-Type": "application/json"},
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(res.body);

      // direct object { ...user }
      if (decoded is Map<String, dynamic>) {
        // sometimes APIs wrap it like { data: {...} } or { result: {...} }
        final obj = decoded["data"] ?? decoded["result"] ?? decoded;
        if (obj is Map<String, dynamic>) {
          return AuthModel.fromMap(obj);
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}
