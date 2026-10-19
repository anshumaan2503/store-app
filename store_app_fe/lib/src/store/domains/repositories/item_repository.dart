// lib/src/item/domains/repositories/item_repository.dart
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

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(ref);
});

abstract class IItemRepository {
  FutureEither<Map<String, dynamic>> addItem(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> updateItem(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> deleteItem(String id);
}

class ItemRepository implements IItemRepository {
  final Ref ref;
  ItemRepository(this.ref);

  @override
  FutureEither<Map<String, dynamic>> addItem(Map<String, dynamic> body) async {
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
            Uri.http(Constants.serverUrl, ApiRouteConstants.itemRoute),
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
            (data['msg'] ?? data['error'] ?? 'Create item failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('addItem error: $e', stackTrace: st, name: 'ItemRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateItem(
    Map<String, dynamic> body,
  ) async {
    try {
      final id = body['id']?.toString() ?? body['_id']?.toString();
      if (id == null) {
        return Left(
          Failure('Item id is required for update', StackTrace.current),
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
            Uri.http(Constants.serverUrl, '${ApiRouteConstants.itemRoute}/$id'),
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
            (data['msg'] ?? data['error'] ?? 'Update item failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('updateItem error: $e', stackTrace: st, name: 'ItemRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteItem(String id) async {
    try {
      final createdBy =
          await ref.read(spRepositoryProvider).getStringValue("uid") ?? "";

      final uri = Uri.http(
        '${ApiRouteConstants.itemRoute}/$id'
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
            (data['msg'] ?? data['error'] ?? 'Delete item failed').toString();
        return Left(Failure(message, StackTrace.current));
      }
    } catch (e, st) {
      log('deleteItem error: $e', stackTrace: st, name: 'ItemRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
