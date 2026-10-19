import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final itemIssueRepositoryProvider = Provider<ItemIssueRepository>((ref) {
  return ItemIssueRepository(ref);
});

abstract class IItemIssueRepository {
  FutureEither<Map<String, dynamic>> addItemIssue(
    Map<String, dynamic> addItemIssue,
  );
  FutureEither<Map<String, dynamic>> updateItemIssue(
    Map<String, dynamic> updateItemIssue,
  );

  FutureEither<Map<String, dynamic>> approveItemIssue(
    Map<String, dynamic> approveItemIssue,
  );

  FutureEither<Map<String, dynamic>> itemIssueToPlace(
    Map<String, dynamic> itemIssueToPlace,
  );

  FutureEither<Map<String, dynamic>> returnItemIssue(
    Map<String, dynamic> returnItemIssue,
  );

  FutureEither<Map<String, dynamic>> rejectItemIssue(
    Map<String, dynamic> rejectItemIssue,
  );
  FutureEither<Map<String, dynamic>> closeItemIssue(
    Map<String, dynamic> returnItemIssue,
  );
  FutureEither<Map<String, dynamic>> deleteItemIssue(String id); // optional
}

class ItemIssueRepository implements IItemIssueRepository {
  final dynamic ref;
  ItemIssueRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addItemIssue(
    Map<String, dynamic> itemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.itemIssueRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateItemIssue(
    Map<String, dynamic> itemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemIssueRoute}/${itemIssue["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> approveItemIssue(
    Map<String, dynamic> approveItemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemIssuesApproveRoute}/${approveItemIssue["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(approveItemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> rejectItemIssue(
    Map<String, dynamic> rejectItemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.itemIssuesRejectRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(rejectItemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> itemIssueToPlace(
    Map<String, dynamic> itemIssueToPlace,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.itemIssuesToPlaceRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemIssueToPlace),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteItemIssue(String id) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemIssuesDeleteRoute}/$id",
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> returnItemIssue(
    Map<String, dynamic> returnItemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.returnItemIssueRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(returnItemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> closeItemIssue(
    Map<String, dynamic> closeItemIssue,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.closeItemIssueRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(closeItemIssue),
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
      log(e.toString(), name: "Current ItemIssue");
      log(
        'createItemIssue error: $e',
        stackTrace: st,
        name: 'ItemIssueRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }
}
