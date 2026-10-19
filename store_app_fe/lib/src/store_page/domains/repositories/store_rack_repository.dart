import 'dart:convert';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../auth/shared/providers/token_provider.dart';
import '../../../auth/shared/repositories/shared_preference_repository.dart';
import '../../../components/api_route_contants.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final storeRackRepositoryProvider = Provider<RackRepository>((ref) {
  return RackRepository(ref);
});

abstract class IRackRepository {
  FutureEither<Map<String, dynamic>> addRack(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> updateRack(Map<String, dynamic> body);
  FutureEither<Map<String, dynamic>> deleteRack(String id);
}

class RackRepository implements IRackRepository {
  final Ref ref;
  RackRepository(this.ref);

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

  @override
  FutureEither<Map<String, dynamic>> addRack(Map<String, dynamic> body) async {
    print(body);
    try {
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, ApiRouteConstants.storeRacksRoute),
            headers: headers,
            body: json.encode(body),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) return Right(data);

      final message = _parseErrorMessage(data, 'Create failed');
      return Left(Failure(message, StackTrace.current));
    } catch (e, st) {
      log('addRack error: $e', stackTrace: st, name: 'RackRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> updateRack(
    Map<String, dynamic> body,
  ) async {
    try {
      final id = (body['id'] ?? '').toString();
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storeRacksRoute}/$id",
            ),
            headers: headers,
            body: json.encode(body),
          );

      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) return Right(data);

      final message = _parseErrorMessage(data, 'Update failed');
      return Left(Failure(message, StackTrace.current));
    } catch (e, st) {
      log('updateRack error: $e', stackTrace: st, name: 'RackRepository');
      return Left(Failure(e.toString(), st));
    }
  }

  @override
  FutureEither<Map<String, dynamic>> deleteRack(String id) async {
    try {
      final headers = await _headers();
      final res = await ref
          .read(httpClientProvider)
          .delete(
            Uri.http(
              Constants.serverUrl,
              "${ApiRouteConstants.storeRacksRoute}/$id",
            ),
            headers: headers,
          );

      final status = res.statusCode;
      final Map<String, dynamic> data = jsonDecode(utf8.decode(res.bodyBytes));
      if (status >= 200 && status < 300) return Right(data);

      final message = _parseErrorMessage(data, 'Delete failed');
      return Left(Failure(message, StackTrace.current));
    } catch (e, st) {
      log('deleteRack error: $e', stackTrace: st, name: 'RackRepository');
      return Left(Failure(e.toString(), st));
    }
  }
}
