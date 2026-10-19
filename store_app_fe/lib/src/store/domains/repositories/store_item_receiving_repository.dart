import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final itemReceiveRepositoryProvider = Provider<ItemReceiveRepository>((ref) {
  return ItemReceiveRepository(ref);
});

abstract class IItemReceiveRepository {
  FutureEither<Map<String, dynamic>> addItemReceive(
    Map<String, dynamic> addItemReceive,
  );
  FutureEither<Map<String, dynamic>> updateItemReceive(
    Map<String, dynamic> updateItemReceive,
  );

  FutureEither<Map<String, dynamic>> approveItemReceive(
    Map<String, dynamic> approveItemReceive,
  );

  FutureEither<Map<String, dynamic>> itemReceiveToPlace(
    Map<String, dynamic> itemReceiveToPlace,
  );
  FutureEither<Map<String, dynamic>> rejectItemReceive(
    Map<String, dynamic> rejectItemReceive,
  );
  FutureEither<Map<String, dynamic>> closeItemReceive(
    Map<String, dynamic> closeItemReceive,
  );
  FutureEither<Map<String, dynamic>> postReceiveStock(
    Map<String, dynamic> closeItemReceive,
  );
  FutureEither<Map<String, dynamic>> deleteItemReceive(String id); // optional
}

class ItemReceiveRepository implements IItemReceiveRepository {
  final dynamic ref;
  ItemReceiveRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addItemReceive(
    Map<String, dynamic> itemReceive,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.itemReceiveRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemReceive),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateItemReceive(
    Map<String, dynamic> itemReceive,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemReceiveRoute}/${itemReceive["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemReceive),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> approveItemReceive(
    Map<String, dynamic> itemReceive,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemReceivesApproveRoute}/${itemReceive["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemReceive),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> rejectItemReceive(
    Map<String, dynamic> itemReceive,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.itemReceivesRejectRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemReceive),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> itemReceiveToPlace(
    Map<String, dynamic> itemReceiveToPlace,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.itemReceivesToPlaceRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(itemReceiveToPlace),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteItemReceive(String id) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemReceivesDeleteRoute}/$id",
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> closeItemReceive(
    Map<String, dynamic> closeItemReceive,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.itemReceivesCloseRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(closeItemReceive),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> postReceiveStock(
    Map<String, dynamic> postReceiveStock,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.itemPlaceReceivesCloseRoute}/${postReceiveStock["placeId"]}/receive",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(postReceiveStock),
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
      log(e.toString(), name: "Current ItemReceive");
      log(
        'createItemReceive error: $e',
        stackTrace: st,
        name: 'ItemReceiveRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }
}
