// lib/src/size/domains/repositories/size_repository.dart

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

final sizeRepositoryProvider = Provider<SizeRepository>((ref) {
  return SizeRepository(ref);
});

abstract class ISizeRepository {
  FutureEither<Map<String, dynamic>> addSize(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> updateSize(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> deleteSize(String id);
}

class SizeRepository implements ISizeRepository {
  final Ref ref;
  SizeRepository(this.ref);

  Uri _uri(String path) => Uri.http(Constants.serverUrl, path);

  @override
  FutureEither<Map<String, dynamic>> addSize(Map<String, dynamic> body) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final payload = {
        ...body,
        if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
      };

      final res = await ref
          .read(httpClientProvider)
          .post(
            _uri(ApiRouteConstants.sizeRoute),
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
            (data['msg'] ?? data['error'] ?? 'Create size failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('addSize error: $e', stackTrace: st, name: 'SizeRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateSize(
    Map<String, dynamic> body,
  ) async {
    try {
      final id = body['id']?.toString() ?? body['_id']?.toString();
      if (id == null) {
        return Left(
          Failure('Size id is required for update', StackTrace.current),
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
            _uri('${ApiRouteConstants.sizeRoute}/$id'),
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
            (data['msg'] ?? data['error'] ?? 'Update size failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('updateSize error: $e', stackTrace: st, name: 'SizeRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteSize(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = _uri(
        '${ApiRouteConstants.sizeRoute}/$id'
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
            (data['msg'] ?? data['error'] ?? 'Delete size failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('deleteSize error: $e', stackTrace: st, name: 'SizeRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
