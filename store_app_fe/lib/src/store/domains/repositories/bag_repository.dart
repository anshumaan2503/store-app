// lib/domains/repositories/bag_repository.dart

import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final bagRepositoryProvider = Provider<BagRepository>((ref) {
  return BagRepository(ref);
});

abstract class IBagRepository {
  FutureEither<Map<String, dynamic>> addBag(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> updateBag(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> deleteBag(String id);
}

class BagRepository implements IBagRepository {
  final Ref ref;
  BagRepository(this.ref);

  Uri _uri(String path) => Uri.http(Constants.serverUrl, path);

  @override
  FutureEither<Map<String, dynamic>> addBag(Map<String, dynamic> body) async {
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

    final payload = {
      ...body,
      if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
    };

    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            _uri(ApiRouteConstants.bagRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Create bag failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('addBag error: $e', stackTrace: st, name: 'BagRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateBag(
    Map<String, dynamic> body,
  ) async {
    try {
      final id = body['id']?.toString() ?? body['_id']?.toString();
      if (id == null) {
        return Left(
          Failure('Bag id is required for update', StackTrace.current),
        );
      }
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final payload = {
        ...body,
        if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
      };
      final res = await ref
          .read(httpClientProvider)
          .put(
            _uri('${ApiRouteConstants.bagRoute}/$id/update'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Update bag failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('updateBag error: $e', stackTrace: st, name: 'BagRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteBag(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = _uri(
        '${ApiRouteConstants.bagRoute}/$id'
        '${createdBy.isNotEmpty ? '?createdBy=$createdBy' : ''}',
      );

      final res = await ref
          .read(httpClientProvider)
          .delete(uri, headers: {'Content-Type': 'application/json'});
      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Delete bag failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('deleteBag error: $e', stackTrace: st, name: 'BagRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> transferToOtherBag({
    required String sourceBagId,
    required String targetBagId,
    required num qty,
  }) async {
    final createdBy =
        await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";
    var body = {
      'sourceBagId': sourceBagId,
      'targetBagId': targetBagId,
      'qty': qty,
      if (createdBy.isNotEmpty) "createdBy": createdBy,
    };

    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            _uri('${ApiRouteConstants.bagRoute}/$sourceBagId/transfer-to-bag'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          );
      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Delete bag failed').toString();
        return Left(Failure(message, StackTrace.current));
      }

      // final res = await api.post(
      //   '/bags/transfer-to-bag',
      //   body: {
      //     'sourceBagId': sourceBagId,
      //     'targetBagId': targetBagId,
      //     'qty': qty,
      //   },
      // );
      // return Right(res);
    } catch (e, st) {
      log('updateBag error: $e', stackTrace: st, name: 'BagRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> addStock({
    required String bagId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final id = body['qty']?.toString();
      if (id == null) {
        return Left(
          Failure('Bag id is required for update', StackTrace.current),
        );
      }
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final payload = {
        ...body,
        if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
      };
      final res = await ref
          .read(httpClientProvider)
          .put(
            _uri('${ApiRouteConstants.bagRoute}/$bagId/add-stock'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) {
        return Right(data);
      } else {
        final message =
            (data['msg'] ?? data['error'] ?? 'Delete bag failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('updateBag error: $e', stackTrace: st, name: 'BagRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
