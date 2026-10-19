// lib/src/store/domains/repositories/issue_repository.dart
import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../auth/shared/providers/token_provider.dart';
import '../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final issueRepositoryProvider = Provider((ref) => IssueRepository(ref));

class IssueRepository {
  final Ref ref;
  IssueRepository(this.ref);

  Future<String> _getToken() async {
    String token = ref.read(authTokenProvider);
    if (token.isEmpty) {
      token = await ref.read(spRepositoryProvider).getStringValue('authToken');
      if (token.isEmpty) {
        token = await ref.read(spRepositoryProvider).getStringValue('token');
      }
      if (token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).updateToken(token);
      }
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return <String, String>{
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// POST: /api/store/issues/draft
  FutureEither<Map<String, dynamic>> createDraft(
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/issues/draft'),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Draft create failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue draft error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// PUT: /api/store/issues/:id/approve
  FutureEither<Map<String, dynamic>> approve(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/issues/$issueId/approve'),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['msg'] ?? 'Approve failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue approve error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// PUT: /api/store/issues/:id/revert-approval
  FutureEither<Map<String, dynamic>> revertApproval(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/revert-approval',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Revert approval failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue revert approval error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// PUT: /api/store/issues/:id/reject
  FutureEither<Map<String, dynamic>> rejectIssue(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/reject',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Reject request failed')
              .toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue reject error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// POST: /api/store/issues/:id/issue
  FutureEither<Map<String, dynamic>> issue(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/issues/$issueId/issue'),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Issue failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue issue error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// POST: /api/store/issues/:id/return
  FutureEither<Map<String, dynamic>> returnAgainstAllocation(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/issues/$issueId/return'),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Return failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  // store_item_issue_repository.dart (add these methods)

  Future<Either<Failure, Map<String, dynamic>>> approveIssueLine(
    String issueId,
    String itemId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/lines/$itemId/approve',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Approve failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> approveIssueBulk(
    String issueId,
    Map<String, dynamic> dto,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/issues/$issueId/approve'),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Approve failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> issueLine({
    required String issueId,
    required String itemId,
    required String rackId,
    required String issuedBy,
    required int qty,
    required int issuedRejectQty,
  }) async {
    try {
      var dto = {
        'issuedBy': issuedBy,
        'itemId': itemId,
        'rackId': rackId,
        'qty': qty,
        'issuedRejectQty': issuedRejectQty,
      };

      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/issue-line',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Issues failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> issueBulk({
    required String issueId,
    required String issuedBy,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      var dto = {'issuedBy': issuedBy, 'lines': lines};
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/issue-bulk',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Issue failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> returnLine({
    required String issueId,
    required String itemId,
    required String rackId,
    required String scrapRackId,
    required String returnedBy,
    required int goodQty,
    required int scrapQty,
  }) async {
    try {
      var dto = {
        'returnedBy': returnedBy,
        'itemId': itemId,
        'rackId': rackId,
        'scrapRackId': scrapRackId,
        'goodQty': goodQty,
        'scrapQty': scrapQty,
      };
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/return-line',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Return failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  Future<Either<Failure, Map<String, dynamic>>> returnBulk({
    required String issueId,
    required String returnedBy,
    required List<Map<String, dynamic>> lines,
  }) async {
    try {
      var dto = {'returnedBy': returnedBy, 'lines': lines};
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/issues/$issueId/return-bulk',
            ),
            headers: await _headers(),
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Return failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue return error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> getItemIssueBreakdown(String itemId) async {
    try {
      final res = await ref.read(httpClientProvider).get(
        Uri.http(Constants.serverUrl, 'api/store/issues/item/$itemId/breakdown'),
        headers: await _headers(),
      );
      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['message'] ?? data['msg'] ?? 'Fetch breakdown failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('issue breakdown error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }
}
