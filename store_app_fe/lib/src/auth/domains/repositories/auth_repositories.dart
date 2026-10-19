import 'dart:convert';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:store_app/src/auth/shared/repositories/shared_preference_repository.dart';
import 'package:store_app/src/components/failure.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/type_defs.dart';
import '../../shared/providers/auth_model_provider.dart';
import '../../shared/providers/providers.dart';
import '../../shared/providers/token_provider.dart';
import '../models/auth_model.dart';
import '../providers/uid_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref);
});

// abstract class IauthRepository {
//   FutureEither<Map<String, dynamic>> createAuth(Map<String, dynamic> authModel);
//   FutureEither<Map<String, dynamic>> loginAuth(Map<String, dynamic> authModel);
// }

class AuthRepository {
  final Ref ref;
  AuthRepository(this.ref);

  Future<AuthModel?> getCurrentAuthUserById() async {
    String id =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    AuthModel? returnValue;
    if (id.isNotEmpty) {
      try {
        var response = await ref
            .read(httpClientProvider)
            .get(
              Uri.http(
                Constants.serverUrl,
                "${ApiRouteConstants.authUserRoute}/$id",
              ),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
                "Authorization": "Bearer ${ref.read(authTokenProvider)}",
              },
            );
        var decodedResponse =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        returnValue = AuthModel.fromMap(decodedResponse);
      } catch (e) {
        log(e.toString(), name: "Current User");
      }
    }
    return returnValue;
  }

  Future<AuthModel?> getAuthConnection(String? uid) async {
    AuthModel? returnValue;
    if (uid!.isNotEmpty) {
      try {
        var response = await ref
            .read(httpClientProvider)
            .get(
              Uri.http(
                Constants.serverUrl,
                "${ApiRouteConstants.authUserRoute}/$uid",
              ),
              headers: <String, String>{
                'Content-Type': 'application/json; charset=UTF-8',
                "Authorization": "Bearer ${ref.read(authTokenProvider)}",
              },
            );
        var decodedResponse =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        returnValue = AuthModel.fromMap(decodedResponse);
      } catch (e) {
        log(e.toString(), name: "Current User");
      }
    }
    return returnValue;
  }

  FutureEither<Map<String, dynamic>> createAuth(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.authregisterRoute),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final statusCode = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (statusCode >= 200 && statusCode < 300) {
        // AuthModel user = AuthModel(
        //   uid: "",
        //   email: "email",
        //   phoneNumber: "phoneNumber",
        //   name: "name",
        //   fcmToken: "fcmToken",
        //   isActive: false,
        //   isSuperAdmin: false,
        //   devices: [],
        //   deviceHistory: [],
        //   apps: [],
        //   createdAt: DateTime.now(),
        //   updatedAt: DateTime.now(),
        // );
        // final token = data['token'] as String;
        // final uid = data['id'] as String;
        final msg = data['msg'] as String;
        final status = data['status'] as bool;

        // if (token != "") {
        //   ref.read(spRepositoryProvider).setStringValue('authToken', token);
        //   ref.read(spRepositoryProvider).setStringValue('uid', uid);
        //   ref.read(authTokenProvider.notifier).updateToken(token);

        //   await getCurrentAuthUserById().then((value) {
        //     ref.read(authModelProvider.notifier).setAuthModel(value);
        //   });
        // }

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{
          // 'token': token,
          // 'user': user.toMap(),
          "msg": msg,
          "status": status,
        });
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> createUser(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.authCreateRegisterRoute,
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final status = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (status >= 200 && status < 300) {
        // AuthModel user = AuthModel(
        //   uid: "",
        //   email: "email",
        //   phoneNumber: "phoneNumber",
        //   name: "name",
        //   fcmToken: "fcmToken",
        //   isActive: false,
        //   isSuperAdmin: false,
        //   devices: [],
        //   deviceHistory: [],
        //   apps: [],
        //   createdAt: DateTime.now(),
        //   updatedAt: DateTime.now(),
        // );

        final msg = data['msg'] as String;
        final status = data['status'] as bool;

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{"msg": msg, "status": status});
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> updateUser(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.authCreateRegisterRoute}/${authModel["id"]}",
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final status = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (status >= 200 && status < 300) {
        // AuthModel user = AuthModel(
        //   uid: "",
        //   email: "email",
        //   phoneNumber: "phoneNumber",
        //   name: "name",
        //   fcmToken: "fcmToken",
        //   isActive: false,
        //   isSuperAdmin: false,
        //   devices: [],
        //   deviceHistory: [],
        //   apps: [],
        //   createdAt: DateTime.now(),
        //   updatedAt: DateTime.now(),
        // );

        final msg = data['msg'] as String;
        final status = data['status'] as bool;

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{"msg": msg, "status": status});
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('update Auth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> resetPasswordUser(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.authResetRoute}/${authModel["userId"]}",
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final status = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (status >= 200 && status < 300) {
        // AuthModel user = AuthModel(
        //   uid: "",
        //   email: "email",
        //   phoneNumber: "phoneNumber",
        //   name: "name",
        //   fcmToken: "fcmToken",
        //   isActive: false,
        //   isSuperAdmin: false,
        //   devices: [],
        //   deviceHistory: [],
        //   apps: [],
        //   createdAt: DateTime.now(),
        //   updatedAt: DateTime.now(),
        // );

        final msg = data['msg'] as String;
        final status = data['status'] as bool;

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{"msg": msg, "status": status});
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('update Auth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> deleteUser(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.authDeleteRoute}/${authModel["userId"]}",
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final status = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (status >= 200 && status < 300) {
        // AuthModel user = AuthModel(
        //   uid: "",
        //   email: "email",
        //   phoneNumber: "phoneNumber",
        //   name: "name",
        //   fcmToken: "fcmToken",
        //   isActive: false,
        //   isSuperAdmin: false,
        //   devices: [],
        //   deviceHistory: [],
        //   apps: [],
        //   createdAt: DateTime.now(),
        //   updatedAt: DateTime.now(),
        // );

        final msg = data['msg'] as String;
        final status = data['status'] as bool;

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{"msg": msg, "status": status});
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('update Auth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> loginAuth(
    Map<String, dynamic> authModel,
  ) async {
    try {
      var response = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.authloginRoute),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
              // "Authorization": "Bearer ${ref.read(authTokenProvider)}",
            },
            body: jsonEncode(authModel),
          );

      final status = response.statusCode;
      final Map<String, dynamic> data = jsonDecode(
        utf8.decode(response.bodyBytes),
      );
      if (status >= 200 && status < 300) {
        final token = (data['token'] ?? '') as String;
        final uid = (data['id'] ?? '') as String;
        final msg = (data['msg'] ?? '') as String;
        final status = (data['status'] ?? false) as bool;

        if (token != "") {
          await ref
              .read(spRepositoryProvider)
              .setStringValue('authToken', token);
          await ref.read(spRepositoryProvider).setStringValue('uid', uid);

          ref.read(authTokenProvider.notifier).updateToken(token);

          // ✅ ADD THIS LINE (whatever your notifier method is)
          ref.read(uidProvider.notifier).updateUid(uid);

          await getCurrentAuthUserById().then((value) {
            ref.read(authModelProvider.notifier).setAuthModel(value);
          });
        }

        // var decodedResponse =
        //     jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        // returnValue = AuthModel.fromMap(decodedResponse);
        return Right(<String, dynamic>{
          // 'token': token,
          "msg": msg,
          "status": status,
        });
      } else {
        final message =
            (data['message'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
