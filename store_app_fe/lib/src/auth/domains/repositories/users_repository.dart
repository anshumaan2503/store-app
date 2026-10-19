import 'dart:convert';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:store_app/src/auth/domains/models/auth_model.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';
import '../../shared/providers/providers.dart';

final userRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref);
});

abstract class IUsersRepository {
  FutureEither<Map<String, dynamic>> addUser(AuthModel user);
  FutureEither<Map<String, dynamic>> updateUser(AuthModel user);
  FutureEither<Map<String, dynamic>> deleteUser(String id); // optional
  FutureEither<Map<String, dynamic>> createDivision(
    Map<String, dynamic> dto,
  ); // optional
}

class UsersRepository implements IUsersRepository {
  final dynamic ref;
  UsersRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addUser(AuthModel user) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.authUserRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(user),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateUser(AuthModel user) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.authUserRoute}/${user.uid}',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(user),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteUser(String id) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .delete(
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.authUserRoute}/$id',
            ),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Register failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Current User");
      log('createAuth error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> createDivision(
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.authDivisionsRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(dto),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Division failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(e.toString(), name: "Division User");
      log('createDivision error: $e', stackTrace: st, name: 'AuthRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
