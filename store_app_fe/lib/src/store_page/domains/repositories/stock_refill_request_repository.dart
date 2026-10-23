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
import '../models/stock_refill_request_model.dart';

final stockRefillRequestRepositoryProvider = Provider(
  (ref) => StockRefillRequestRepository(ref),
);

final indentRaiseRepositoryProvider = stockRefillRequestRepositoryProvider;

class StockRefillRequestRepository {
  final Ref ref;
  StockRefillRequestRepository(this.ref);

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

  FutureEither<StockRefillRequestModel> createRefillRequest({
    required String itemId,
    required num requestedQty,
    required String reason,
    num? indentQty,
    String? itemDescription,
    String? unitOfMeasure,
    String? make,
    String? techSpec,
    String? hsnCode,
    String? lineNumber,
    num? preReqQty,
    num? preqQty,
    String? documentCategory,
    String? company,
    String? costCenter,
    String? documentDate,
    String? documentType,
  }) async {
    try {
      final token = await _getToken();
      final qty = indentQty ?? requestedQty;
      final body = <String, dynamic>{
        'itemId': itemId,
        'indentQty': qty,
        'requestedQty': qty,
        'reason': reason.trim(),
        if (itemDescription != null && itemDescription.trim().isNotEmpty)
          'itemDescription': itemDescription.trim(),
        if (unitOfMeasure != null && unitOfMeasure.trim().isNotEmpty)
          'unitOfMeasure': unitOfMeasure.trim(),
        if (make != null && make.trim().isNotEmpty) 'make': make.trim(),
        if (techSpec != null && techSpec.trim().isNotEmpty)
          'techSpec': techSpec.trim(),
        if (hsnCode != null && hsnCode.trim().isNotEmpty)
          'hsnCode': hsnCode.trim(),
        if (lineNumber != null && lineNumber.trim().isNotEmpty)
          'lineNumber': lineNumber.trim(),
        if (preReqQty != null) 'preReqQty': preReqQty,
        if (preqQty != null) 'preqQty': preqQty,
        if (documentCategory != null && documentCategory.trim().isNotEmpty)
          'documentCategory': documentCategory.trim(),
        if (company != null && company.trim().isNotEmpty)
          'company': company.trim(),
        if (costCenter != null && costCenter.trim().isNotEmpty)
          'costCenter': costCenter.trim(),
        if (documentDate != null && documentDate.trim().isNotEmpty)
          'documentDate': documentDate.trim(),
        if (documentType != null && documentType.trim().isNotEmpty)
          'documentType': documentType.trim(),
      };

      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/indents'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final itemJson = data['data'] as Map<String, dynamic>;
        return Right(StockRefillRequestModel.fromJson(itemJson));
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to create indent request');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('createRefillRequest error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StockRefillRequestModel> createIndentRequest({
    required String itemId,
    required num indentQty,
    required String reason,
    String? itemDescription,
    String? unitOfMeasure,
    String? make,
    String? techSpec,
    String? hsnCode,
    String? lineNumber,
    num? preReqQty,
    num? preqQty,
    String? documentCategory,
    String? company,
    String? costCenter,
    String? documentDate,
    String? documentType,
  }) {
    return createRefillRequest(
      itemId: itemId,
      requestedQty: indentQty,
      indentQty: indentQty,
      reason: reason,
      itemDescription: itemDescription,
      unitOfMeasure: unitOfMeasure,
      make: make,
      techSpec: techSpec,
      hsnCode: hsnCode,
      lineNumber: lineNumber,
      preReqQty: preReqQty,
      preqQty: preqQty,
      documentCategory: documentCategory,
      company: company,
      costCenter: costCenter,
      documentDate: documentDate,
      documentType: documentType,
    );
  }

  FutureEither<List<StockRefillRequestModel>> getRefillRequests({
    String? status,
    String? search,
    String? itemId,
    bool? uncredited,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{
        if (status != null && status.isNotEmpty && status != 'ALL')
          'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (itemId != null && itemId.trim().isNotEmpty) 'itemId': itemId.trim(),
        if (uncredited == true) 'uncredited': 'true',
      };

      final res = await ref
          .read(httpClientProvider)
          .get(
            Uri.http(
              Constants.serverUrl,
              'api/store/indents',
              queryParams.isEmpty ? null : queryParams,
            ),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final list = (data['data'] as List? ?? [])
            .map((e) => StockRefillRequestModel.fromJson(e as Map<String, dynamic>))
            .toList();
        return Right(list);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to load indent requests');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('getRefillRequests error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StockRefillRequestModel> approveRefillRequest(
    String id, {
    String? reviewRemarks,
    bool? directStockIn,
    String? rackId,
    num? creditQty,
    bool overrideMaxCapacity = false,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (reviewRemarks != null && reviewRemarks.trim().isNotEmpty)
          'reviewRemarks': reviewRemarks.trim(),
        if (directStockIn != null) 'directStockIn': directStockIn,
        if (rackId != null && rackId.trim().isNotEmpty)
          'rackId': rackId.trim(),
        if (creditQty != null && creditQty > 0)
          'creditQty': creditQty,
        if (overrideMaxCapacity) 'overrideMaxCapacity': true,
      };

      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/indents/$id/approve'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final itemJson = data['data'] as Map<String, dynamic>;
        return Right(StockRefillRequestModel.fromJson(itemJson));
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to approve indent request');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('approveRefillRequest error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StockRefillRequestModel> creditStock(
    String id, {
    String? rackId,
    num? creditQty,
    String? reviewRemarks,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (reviewRemarks != null && reviewRemarks.trim().isNotEmpty)
          'reviewRemarks': reviewRemarks.trim(),
        if (rackId != null && rackId.trim().isNotEmpty)
          'rackId': rackId.trim(),
        if (creditQty != null && creditQty > 0)
          'creditQty': creditQty,
        'directStockIn': true,
      };

      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/indents/$id/credit-stock'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final itemJson = data['data'] as Map<String, dynamic>;
        return Right(StockRefillRequestModel.fromJson(itemJson));
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to credit stock for indent');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('creditStock error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StockRefillRequestModel> rejectRefillRequest(
    String id, {
    String? reviewRemarks,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (reviewRemarks != null && reviewRemarks.trim().isNotEmpty)
          'reviewRemarks': reviewRemarks.trim(),
      };

      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/indents/$id/reject'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final itemJson = data['data'] as Map<String, dynamic>;
        return Right(StockRefillRequestModel.fromJson(itemJson));
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to reject indent request');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('rejectRefillRequest error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StockRefillRequestModel> updateIndentQuantity(
    String id, {
    required num indentQty,
    String? reason,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'indentQty': indentQty,
        'requestedQty': indentQty,
        if (reason != null && reason.trim().isNotEmpty)
          'reason': reason.trim(),
      };

      final res = await ref
          .read(httpClientProvider)
          .put(
            Uri.http(Constants.serverUrl, 'api/store/indents/$id/update-qty'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final itemJson = data['data'] as Map<String, dynamic>;
        return Right(StockRefillRequestModel.fromJson(itemJson));
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to update indent quantity');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('updateIndentQuantity error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<bool> deleteRefillRequest(String id) async {
    try {
      final token = await _getToken();
      final res = await ref
          .read(httpClientProvider)
          .delete(
            Uri.http(Constants.serverUrl, 'api/store/indents/$id'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return const Right(true);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to delete indent request');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('deleteRefillRequest error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> triggerEodScheduler() async {
    try {
      final token = await _getToken();
      final res = await ref
          .read(httpClientProvider)
          .post(
            Uri.http(Constants.serverUrl, 'api/store/indents/trigger-eod-scheduler'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          );

      final data =
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to run End-of-Day scheduler');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('triggerEodScheduler error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }


  FutureEither<StoreConsolidationPayloadModel> getStoreConsolidationPayload({
    String? search,
    String? groupBy,
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (groupBy != null && groupBy.trim().isNotEmpty) 'groupBy': groupBy.trim(),
      };

      final res = await ref.read(httpClientProvider).get(
            Uri.http(Constants.serverUrl, 'api/store/indents/pending-store-consolidation', queryParams),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final payload = StoreConsolidationPayloadModel.fromJson(data['data']);
        return Right(payload);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to fetch pending store consolidation');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('getStoreConsolidationPayload error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<List<ConsolidatedStoreItemModel>> getPendingStoreConsolidation({
    String? search,
  }) async {
    final payloadRes = await getStoreConsolidationPayload(search: search);
    return payloadRes.fold(
      (l) => Left(l),
      (r) => Right(r.itemWise),
    );
  }

  FutureEither<Map<String, dynamic>> approveIndentItem({
    required String id,
    num? approvedQty,
    String? remarks,
    bool overrideMaxCapacity = false,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (approvedQty != null && approvedQty > 0) 'approvedQty': approvedQty,
        if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        if (overrideMaxCapacity) 'overrideMaxCapacity': true,
      };

      final res = await ref.read(httpClientProvider).post(
            Uri.http(Constants.serverUrl, 'api/store/indents/approve-item/$id'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to approve indent item');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('approveIndentItem error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> rejectWholeIndent({
    required String indentNumber,
    String? remarks,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
      };

      final encodedNum = Uri.encodeComponent(indentNumber);
      final res = await ref.read(httpClientProvider).post(
            Uri.http(Constants.serverUrl, 'api/store/indents/reject-whole-indent/$encodedNum'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to reject whole indent');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('rejectWholeIndent error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> approveWholeIndent({
    required String indentNumber,
    String? remarks,
    bool overrideMaxCapacity = false,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        if (overrideMaxCapacity) 'overrideMaxCapacity': true,
      };

      final encodedNum = Uri.encodeComponent(indentNumber);
      final res = await ref.read(httpClientProvider).post(
            Uri.http(Constants.serverUrl, 'api/store/indents/approve-whole-indent/$encodedNum'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to approve whole indent');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('approveWholeIndent error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<Map<String, dynamic>> consolidatedStoreApprove({
    required List<Map<String, dynamic>> items,
    String? overallRemarks,
    bool overrideMaxCapacity = false,
  }) async {
    try {
      final token = await _getToken();
      final body = {
        'items': items,
        if (overallRemarks != null && overallRemarks.trim().isNotEmpty)
          'overallRemarks': overallRemarks.trim(),
        if (overrideMaxCapacity)
          'overrideMaxCapacity': true,
      };

      final res = await ref.read(httpClientProvider).post(
            Uri.http(Constants.serverUrl, 'api/store/indents/consolidated-store-approve'),
            headers: <String, String>{
              'Content-Type': 'application/json; charset=UTF-8',
              if (token.isNotEmpty) 'Authorization': 'Bearer $token',
            },
            body: json.encode(body),
          );

      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return Right(data);
      }

      final errorMsg = _extractErrorMessage(data, fallback: 'Failed to approve consolidated indents');
      return Left(Failure(errorMsg, StackTrace.current));
    } catch (e, st) {
      log('consolidatedStoreApprove error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  String _extractErrorMessage(Map<String, dynamic> data, {required String fallback}) {
    if (data['msg'] != null && data['msg'].toString().isNotEmpty) {
      return data['msg'].toString();
    }
    if (data['message'] != null) {
      if (data['message'] is List) {
        return (data['message'] as List).join(', ');
      }
      return data['message'].toString();
    }
    if (data['error'] != null) {
      return data['error'].toString();
    }
    return fallback;
  }
}
