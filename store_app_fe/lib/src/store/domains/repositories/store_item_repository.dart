import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' as http;

import '../../../auth/shared/providers/providers.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final storeItemRepositoryProvider = Provider<StoreItemRepository>((ref) {
  return StoreItemRepository(ref);
});

abstract class IStoreItemRepository {
  FutureEither<Map<String, dynamic>> addStoreItem(
    Map<String, dynamic> storeItem,
  );
  FutureEither<Map<String, dynamic>> updateStoreItem(
    Map<String, dynamic> storeItem,
  );
  FutureEither<Map<String, dynamic>> deleteStoreItem(String id); // optional

  FutureEither<Map<String, dynamic>> scrapStoreItem(
    Map<String, dynamic> storeItem,
  );
}

class StoreItemRepository implements IStoreItemRepository {
  final dynamic ref;
  StoreItemRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addStoreItem(
    Map<String, dynamic> storeItem,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.storeItemRoute),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(storeItem),
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
      log(e.toString(), name: "Current StoreItem");
      log(
        'createStoreItem error: $e',
        stackTrace: st,
        name: 'StoreItemRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  // NEW: upload image (multipart) for an existing StoreItem
  FutureEither<String> uploadStoreItemImage({
    required String itemId,
    required File file,
  }) async {
    try {
      final uri = Uri.http(
        Constants.serverUrl,
        '${ApiRouteConstants.storeItemRoute}/$itemId/image',
      );

      final request = http.MultipartRequest('POST', uri);
      // If you need auth: request.headers['Authorization'] = 'Bearer ...';

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      final Map<String, dynamic> body = jsonDecode(utf8.decode(res.bodyBytes));

      if (res.statusCode >= 200 && res.statusCode < 300) {
        // expecting { success: true, imageUrl: 'http...' }
        final imageUrl =
            (body['imageUrl'] ?? body['data']?['imageUrl'])?.toString();
        if (imageUrl == null || imageUrl.isEmpty) {
          return Left(Failure('No imageUrl returned', StackTrace.current));
        }
        return Right(imageUrl);
      } else {
        final message =
            (body['msg'] ?? body['error'] ?? 'Image upload failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateStoreItem(
    Map<String, dynamic> storeItem,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storeItemRoute}/${storeItem["id"]}",
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(storeItem),
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
      log(e.toString(), name: "Current StoreItem");
      log(
        'createStoreItem error: $e',
        stackTrace: st,
        name: 'StoreItemRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteStoreItem(String id) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storeItemsDeleteRoute}/$id",
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
      log(e.toString(), name: "Current StoreItem");
      log(
        'createStoreItem error: $e',
        stackTrace: st,
        name: 'StoreItemRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> scrapStoreItem(
    Map<String, dynamic> storeItem,
  ) async {
    try {
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              ApiRouteConstants.storeItemScrapRoute,
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(storeItem),
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
      log(e.toString(), name: "Current StoreItem");
      log(
        'createStoreItem error: $e',
        stackTrace: st,
        name: 'StoreItemRepository',
      );
      return Left(Failure(e.toString(), st));
    }
  }
}
