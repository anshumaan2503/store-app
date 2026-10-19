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

final storeReceiveRepositoryProvider = Provider(
  (ref) => StoreReceiveRepository(ref),
);

class StoreReceiveRepository {
  final Ref ref;
  StoreReceiveRepository(this.ref);

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

  FutureEither<Map<String, dynamic>> receiveItem({
    required String itemId,
    required int qty,
    required String receivedBy,
    required String rackId,
    String? remark,
    String? indentId,
    double? unitPrice,
    String? grnId,
    String? grnNo,
    bool? autoIssue,
  }) async {
    try {
      final body = {
        "itemId": itemId,
        "qty": qty,
        "rackId": rackId,
        "receivedBy": receivedBy,
        if (remark != null && remark.trim().isNotEmpty) "remark": remark.trim(),
        if (indentId != null && indentId.trim().isNotEmpty) "indentId": indentId.trim(),
        if (autoIssue != null) "autoIssue": autoIssue,
        if (unitPrice != null && unitPrice > 0) "unitPrice": unitPrice,
        if (grnId != null && grnId.trim().isNotEmpty) "grnId": grnId.trim(),
        if (grnNo != null && grnNo.trim().isNotEmpty) "grnNo": grnNo.trim(),
      };

      final token = await _getToken();

      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/storeitems/receive'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      String errorMsg = 'Receive failed';
      if (data['msg'] != null && data['msg'].toString().isNotEmpty) {
        errorMsg = data['msg'].toString();
      } else if (data['message'] != null) {
        if (data['message'] is List) {
          errorMsg = (data['message'] as List).join(', ');
        } else {
          errorMsg = data['message'].toString();
        }
      } else if (data['error'] != null) {
        errorMsg = data['error'].toString();
      }

      return Left(
        Failure(
          errorMsg,
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('receive error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> uploadReceiveImageBase64({
    required String receiveId,
    required String dataUrl,
  }) async {
    try {
      final token = await _getToken();

      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(
              Constants.serverUrl,
              'api/store/storeitems/$receiveId/receive/image/base64',
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode({'base64': dataUrl}),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      String errorMsg = 'Image upload failed';
      if (data['msg'] != null && data['msg'].toString().isNotEmpty) {
        errorMsg = data['msg'].toString();
      } else if (data['message'] != null) {
        if (data['message'] is List) {
          errorMsg = (data['message'] as List).join(', ');
        } else {
          errorMsg = data['message'].toString();
        }
      } else if (data['error'] != null) {
        errorMsg = data['error'].toString();
      }

      return Left(
        Failure(
          errorMsg,
          StackTrace.current,
        ),
      );
    } catch (e, st) {
      log('upload receive image error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }
}
