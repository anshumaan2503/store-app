import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final storePlaceRepositoryProvider = Provider<StorePlaceRepository>((ref) {
  return StorePlaceRepository(ref);
});

abstract class IStorePlaceRepository {
  FutureEither<Map<String, dynamic>> addStorePlace(
    Map<String, dynamic> storePlace,
  );
  FutureEither<Map<String, dynamic>> updateStorePlace(
    Map<String, dynamic> storePlace,
  );
  FutureEither<Map<String, dynamic>> deleteStorePlace(String id); // optional
}

class StorePlaceRepository implements IStorePlaceRepository {
  final dynamic ref;
  StorePlaceRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addStorePlace(
    Map<String, dynamic> storePlace,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.storePlaceRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(storePlace),
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
      log(e.toString(), name: "Current StorePlace");
      log(
        'createStorePlace error: $e',
        stackTrace: st,
        name: 'StorePlaceRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateStorePlace(
    Map<String, dynamic> storePlace,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storePlaceRoute}/${storePlace["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(storePlace),
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
      log(e.toString(), name: "Current StorePlace");
      log(
        'createStorePlace error: $e',
        stackTrace: st,
        name: 'StorePlaceRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteStorePlace(String id) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storePlacesDeleteRoute}/$id",
            ),
            headers: {'Content-Type': 'application/json'},
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
      log(e.toString(), name: "Current StorePlace");
      log(
        'createStorePlace error: $e',
        stackTrace: st,
        name: 'StorePlaceRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }
}
