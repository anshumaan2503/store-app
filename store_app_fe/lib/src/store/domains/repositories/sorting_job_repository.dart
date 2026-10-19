// lib/src/sorting_jobs/domains/repositories/sorting_job_repository.dart
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

final sortingJobRepositoryProvider = Provider<SortingJobRepository>((ref) {
  return SortingJobRepository(ref);
});

class SortingJobRepository {
  final Ref ref;
  SortingJobRepository(this.ref);

  FutureEither<Map<String, dynamic>> createSortingJob(
    Map<String, dynamic> body,
  ) async {
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
            Uri.http(Constants.serverUrl, ApiRouteConstants.sortingJobsRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);
      return Left(
        Failure(
          (data['msg'] ?? data['error'] ?? 'Create failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('createSortingJob error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> completeSortingJob(
    String id,
    Map<String, dynamic> body,
  ) async {
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
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.sortingJobsRoute}/$id/complete',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);
      return Left(
        Failure(
          (data['msg'] ?? data['error'] ?? 'Complete failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('completeSortingJob error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> startJob(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = Uri.http(
        '${ApiRouteConstants.sortingJobsRoute}/$id/start'
        '${createdBy.isNotEmpty ? '?createdBy=$createdBy' : ''}',
      );

      final res = await ref
          .read(httpClientProvider)
          .put(uri, headers: {'Content-Type': 'application/json'});
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);
      return Left(
        Failure(
          (data['msg'] ?? data['error'] ?? 'Start failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> stopJob(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = Uri.http(
        '${ApiRouteConstants.sortingJobsRoute}/$id/stop'
        '${createdBy.isNotEmpty ? '?createdBy=$createdBy' : ''}',
      );

      final res = await ref
          .read(httpClientProvider)
          .put(uri, headers: {'Content-Type': 'application/json'});
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);
      return Left(
        Failure(
          (data['msg'] ?? data['error'] ?? 'Stop failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> restartJob(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = Uri.http(
        '${ApiRouteConstants.gradeRoute}/$id'
        '${createdBy.isNotEmpty ? '?createdBy=$createdBy' : ''}',
      );

      final res = await ref
          .read(httpClientProvider)
          .put(uri, headers: {'Content-Type': 'application/json'});
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);
      return Left(
        Failure(
          (data['msg'] ?? data['error'] ?? 'Restart failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> updateJob(
    Map<String, dynamic> body,
  ) async {
    // optional: implement if you have PUT endpoint
    return Right({'status': true});
  }

  FutureEither<Map<String, dynamic>> processJob(
    String id,
    Map<String, dynamic> body,
  ) async {
    // optional: implement if you have endpoint
    return Right({'status': true});
  }

  FutureEither<Map<String, dynamic>> transferOne({
    required String jobId,
    required Map<String, dynamic> body,
  }) async {
    try {
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
              '${ApiRouteConstants.sortingJobsRoute}/$jobId/transfer-one',
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
            (data['msg'] ?? data['error'] ?? 'Transfer failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log(
        'transferOne error: $e',
        stackTrace: st,
        name: 'SortingJobRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> transferToBag({
    required String jobId,
    required Map<String, dynamic> body,
  }) async {
    try {
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
              '${ApiRouteConstants.sortingJobsRoute}/$jobId/transfer-to-bag',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) return Right(data);
      final msg =
          (data['msg'] ?? data['error'] ?? 'Transfer failed').toString();
      return Left(Failure(msg, StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> transferToBagTwo({
    required String jobId,
    required Map<String, dynamic> body,
  }) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.sortingJobsRoute}/$jobId/transfer-to-bag-two',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) return Right(data);
      final msg =
          (data['msg'] ?? data['error'] ?? 'Transfer failed').toString();
      return Left(Failure(msg, StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> addBagToJob({
    required String jobId,
    required Map<String, dynamic> body,
    required String createdBy,
  }) async {
    final payload = {
      ...body,
      if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
    };

    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.sortingJobsRoute}/$jobId/add-bag',
            ),
            headers: {
              'Content-Type': 'application/json',
              // if (createdBy.isNotEmpty) 'x-user-id': createdBy,
            },
            body: jsonEncode(payload),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) return Right(data);
      final message =
          (data['msg'] ?? data['error'] ?? 'Add bag failed').toString();
      return Left(Failure(message, StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> addMachineToJob({
    required Map<String, dynamic> body,
    required String createdBy,
  }) async {
    final payload = {
      ...body,
      if (createdBy.isNotEmpty) "createdBy": createdBy, // ✅ attach here
    };

    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              '${ApiRouteConstants.sortingJobsRoute}/machinetojob',
            ),
            headers: {
              'Content-Type': 'application/json',
              // if (createdBy.isNotEmpty) 'x-user-id': createdBy,
            },
            body: jsonEncode(payload),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (status >= 200 && status < 300) return Right(data);
      final message =
          (data['msg'] ?? data['error'] ?? 'Add bag failed').toString();
      return Left(Failure(message, StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }
}
