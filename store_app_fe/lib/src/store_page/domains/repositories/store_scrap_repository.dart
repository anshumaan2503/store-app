import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../../auth/shared/providers/providers.dart';
import '../../../components/constants.dart';
import '../../../components/failure.dart';
import '../../../components/type_defs.dart';

final storeScrapRepositoryProvider = Provider(
  (ref) => StoreScrapRepository(ref),
);

class StoreScrapRepository {
  final Ref ref;
  StoreScrapRepository(this.ref);

  FutureEither<Map<String, dynamic>> scrapItem({
    required String itemId,
    required int qty,
    required String createdBy,
    required String rackId,
    required String roomId,
    String? remark,
  }) async {
    try {
      final body = {
        "itemId": itemId,
        "itemQuantity": qty,
        "rackId": rackId,
        "roomId": roomId,
        "createdBy": createdBy,
        if (remark != null && remark.trim().isNotEmpty) "remark": remark.trim(),
      };

      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/itemscrap'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) return Right(data);

      return Left(
        Failure((data['msg'] ?? 'Scrap failed').toString(), StackTrace.current),
      );
    } catch (e, st) {
      log('scrap error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }
}
