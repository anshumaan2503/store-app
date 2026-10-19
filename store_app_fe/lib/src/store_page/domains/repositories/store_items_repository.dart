import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/token_provider.dart';
import '../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';
import '../../../auth/shared/providers/providers.dart';

final storeItemsRepositoryProvider = Provider(
  (ref) => StoreItemsRepository(ref),
);

class StoreItemsRepository {
  final Ref ref;
  StoreItemsRepository(this.ref);

  Future<String> _getToken() async {
    String token = ref.read(authTokenProvider);
    if (token.isEmpty) {
      token =
          await ref.read(spRepositoryProvider).getStringValue('authToken');
      if (token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).updateToken(token);
      }
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  String _parseErrorMessage(Map<String, dynamic> data, String fallback) {
    if (data['msg'] != null && data['msg'].toString().isNotEmpty) {
      return data['msg'].toString();
    }
    if (data['message'] != null) {
      if (data['message'] is List) {
        return (data['message'] as List).join(', ');
      }
      return data['message'].toString();
    }
    if (data['error'] != null && data['error'].toString().isNotEmpty) {
      return data['error'].toString();
    }
    return fallback;
  }

  FutureEither<Map<String, dynamic>> create(Map<String, dynamic> dto) async {
    try {
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/storeitems'),
            headers: headers,
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          _parseErrorMessage(data, 'Create failed'),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items create error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> dto,
  ) async {
    try {
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/storeitems/$id'),
            headers: headers,
            body: json.encode(dto),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          _parseErrorMessage(data, 'Update failed'),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items update error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> delete(String id) async {
    try {
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .delete(
            Uri.http(Constants.serverUrl, 'api/store/storeitems/$id', {
              'force': 'true',
            }),
            headers: headers,
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          _parseErrorMessage(data, 'Delete failed'),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items delete error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// ✅ Transfer Rack (qty must be 0 on backend)
  FutureEither<Map<String, dynamic>> transferRack({
    required String itemId,
    required String toRackId,
  }) async {
    try {
      final createdBy = await ref
          .read(spRepositoryProvider)
          .getStringValue("uid");
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/storeitems/$itemId/transfer-rack',
            ),
            headers: headers,
            body: json.encode({"toRackId": toRackId, "createdBy": createdBy}),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['msg'] ?? data['message'] ?? data['error'] ?? 'Rack transfer failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items transferRack error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> removeRack({
    required String toRackId,
  }) async {
    try {
      final createdBy = await ref
          .read(spRepositoryProvider)
          .getStringValue("uid");
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/storeitems/remove-rack'),
            headers: headers,
            body: json.encode({"toRackId": toRackId, "createdBy": createdBy}),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['msg'] ?? data['message'] ?? data['error'] ?? 'Rack transfer failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items transferRack error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  /// ✅ Transfer Item qty (qty <= available enforced on backend)
  FutureEither<Map<String, dynamic>> transferItem({
    required String itemId,
    required String fromRackId,
    required String toRackId,
    required int qty,
  }) async {
    try {
      final createdBy = await ref
          .read(spRepositoryProvider)
          .getStringValue("uid");
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              'api/store/storeitems/$itemId/transfer-item',
            ),
            headers: headers,
            body: json.encode({
              "fromRackId": fromRackId,
              "toRackId": toRackId,
              "qty": qty,
              "createdBy": createdBy,
            }),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          (data['msg'] ?? data['message'] ?? data['error'] ?? 'Item transfer failed').toString(),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items transferItem error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> getRateHistory(String itemId) async {
    try {
      final headers = await _headers();
      final res = await ref.read(httpClientProvider).get(
            Uri.http(Constants.serverUrl, 'api/store/storeitems/$itemId/rate-history'),
            headers: headers,
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure(
          _parseErrorMessage(data, 'Failed to fetch rate history'),
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('items getRateHistory error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }
}

