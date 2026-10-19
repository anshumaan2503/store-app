// lib/src/grade/domains/repositories/grade_repository.dart
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

final gradeRepositoryProvider = Provider<GradeRepository>((ref) {
  return GradeRepository(ref);
});

abstract class IGradeRepository {
  FutureEither<Map<String, dynamic>> addGrade(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> updateGrade(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> deleteGrade(String id);
}

class GradeRepository implements IGradeRepository {
  final Ref ref;
  GradeRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addGrade(Map<String, dynamic> body) async {
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
            Uri.http(Constants.serverUrl, ApiRouteConstants.gradeRoute),
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
            (data['msg'] ?? data['error'] ?? 'Create grade failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('addGrade error: $e', stackTrace: st, name: 'GradeRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateGrade(
    Map<String, dynamic> body,
  ) async {
    try {
      final id = body['id']?.toString() ?? body['_id']?.toString();
      if (id == null) {
        return Left(
          Failure('Grade id is required for update', StackTrace.current),
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
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.gradeRoute}/$id',
            ),
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
            (data['msg'] ?? data['error'] ?? 'Update grade failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('updateGrade error: $e', stackTrace: st, name: 'GradeRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteGrade(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = Uri.http(
        '${ApiRouteConstants.gradeRoute}/$id'
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
            (data['msg'] ?? data['error'] ?? 'Delete grade failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('deleteGrade error: $e', stackTrace: st, name: 'GradeRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
