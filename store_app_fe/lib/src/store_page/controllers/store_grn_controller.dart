import 'dart:convert';
import 'dart:developer';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';

import '../../auth/shared/providers/providers.dart';
import '../../auth/shared/providers/token_provider.dart';
import '../../auth/shared/repositories/shared_preference_repository.dart';
import '../../components/constants.dart';
import '../../components/failure.dart';
import '../../components/type_defs.dart';
import '../../components/utils.dart';
import '../domains/models/stock_refill_request_model.dart';
import '../domains/models/store_grn_model.dart';
import 'stock_refill_request_controller.dart';

// ==================== GRN CART STATE ====================

class GrnCartEntry {
  final StockRefillRequestModel indent;
  final int orderedQty;
  int receivedQty;
  double unitPrice;

  GrnCartEntry({
    required this.indent,
    required this.orderedQty,
    required this.receivedQty,
    this.unitPrice = 0.0,
  });

  double get totalPrice => receivedQty * unitPrice;

  GrnCartEntry copyWith({
    int? receivedQty,
    double? unitPrice,
  }) {
    return GrnCartEntry(
      indent: indent,
      orderedQty: orderedQty,
      receivedQty: receivedQty ?? this.receivedQty,
      unitPrice: unitPrice ?? this.unitPrice,
    );
  }
}

class GrnCartNotifier extends StateNotifier<Map<String, GrnCartEntry>> {
  GrnCartNotifier() : super({});

  void addIndent(StockRefillRequestModel indent) {
    final id = indent.id;
    if (state.containsKey(id)) return;

    final ord = (indent.indentQty > 0 ? indent.indentQty : indent.requestedQty).toInt();
    state = {
      ...state,
      id: GrnCartEntry(
        indent: indent,
        orderedQty: ord,
        receivedQty: ord,
        unitPrice: 0.0,
      ),
    };
  }

  void removeIndent(String indentId) {
    if (!state.containsKey(indentId)) return;
    final copy = Map<String, GrnCartEntry>.from(state);
    copy.remove(indentId);
    state = copy;
  }

  void updateReceivedQty(String indentId, int qty) {
    if (!state.containsKey(indentId)) return;
    final current = state[indentId]!;
    state = {
      ...state,
      indentId: current.copyWith(receivedQty: qty < 0 ? 0 : qty),
    };
  }

  void updateUnitPrice(String indentId, double price) {
    if (!state.containsKey(indentId)) return;
    final current = state[indentId]!;
    state = {
      ...state,
      indentId: current.copyWith(unitPrice: price < 0 ? 0.0 : price),
    };
  }

  void clear() {
    state = {};
  }

  int get totalItems => state.length;
  int get totalQuantity => state.values.fold(0, (sum, it) => sum + it.receivedQty);
  double get totalValue => state.values.fold(0.0, (sum, it) => sum + it.totalPrice);
}

final grnCartProvider =
    StateNotifierProvider<GrnCartNotifier, Map<String, GrnCartEntry>>((ref) {
  return GrnCartNotifier();
});

// ==================== REPOSITORY ====================

final storeGrnRepositoryProvider = Provider((ref) => StoreGrnRepository(ref));

class StoreGrnRepository {
  final Ref ref;
  StoreGrnRepository(this.ref);

  Future<String> _getToken() async {
    String token = ref.read(authTokenProvider);
    if (token.isEmpty) {
      token = await ref.read(spRepositoryProvider).getStringValue('authToken');
      if (token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).updateToken(token);
      }
    }
    return token;
  }

  Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  FutureEither<StoreGrnModel> createGrn({
    required List<Map<String, dynamic>> items,
    String? imageUrl,
    String? remarks,
    bool autoApprove = true,
  }) async {
    try {
      final res = await ref.read(httpClientProvider).post(
        Uri.http(Constants.serverUrl, 'api/store/grn'),
        headers: await _headers(),
        body: jsonEncode({
          'items': items,
          'imageUrl': imageUrl ?? '',
          'remarks': remarks ?? '',
          'autoApprove': autoApprove,
        }),
      );

      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> data = (raw is Map && raw.containsKey('data') && raw['data'] is Map)
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        return Right(StoreGrnModel.fromJson(data));
      }
      final msg = raw is Map ? raw['message']?.toString() : null;
      return Left(Failure(msg ?? 'Failed to create GRN', StackTrace.current));
    } catch (e, st) {
      log('createGrn error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<String> uploadImage(String base64) async {
    try {
      final res = await ref.read(httpClientProvider).post(
        Uri.http(Constants.serverUrl, 'api/store/grn/upload-image'),
        headers: await _headers(),
        body: jsonEncode({'base64': base64}),
      );
      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final url = raw is Map ? (raw['imageUrl'] ?? '').toString() : '';
        return Right(url);
      }
      final msg = raw is Map ? raw['message']?.toString() : null;
      return Left(Failure(msg ?? 'Image upload failed', StackTrace.current));
    } catch (e, st) {
      log('uploadImage error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<List<StoreGrnModel>> listGrn({String? status, String? search}) async {
    try {
      final queryParams = <String, String>{};
      if (status != null && status != 'ALL') queryParams['status'] = status;
      if (search != null && search.trim().isNotEmpty) queryParams['search'] = search.trim();

      final res = await ref.read(httpClientProvider).get(
        Uri.http(Constants.serverUrl, 'api/store/grn', queryParams),
        headers: await _headers(),
      );

      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final rawList = (raw is Map && raw.containsKey('data') && raw['data'] is List)
            ? (raw['data'] as List)
            : (raw is List ? raw : []);
        final list = rawList
            .whereType<Map>()
            .map((e) => StoreGrnModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return Right(list);
      }
      final msg = raw is Map ? raw['message']?.toString() : null;
      return Left(Failure(msg ?? 'Failed to list GRNs', StackTrace.current));
    } catch (e, st) {
      log('listGrn error: $e', stackTrace: st);
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StoreGrnModel> approveGrn(String grnId) async {
    try {
      final res = await ref.read(httpClientProvider).put(
        Uri.http(Constants.serverUrl, 'api/store/grn/$grnId/approve'),
        headers: await _headers(),
      );
      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> data = (raw is Map && raw.containsKey('data') && raw['data'] is Map)
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        return Right(StoreGrnModel.fromJson(data));
      }
      final msg = raw is Map ? raw['message']?.toString() : null;
      return Left(Failure(msg ?? 'Failed to approve GRN', StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }

  FutureEither<StoreGrnModel> rejectGrn(String grnId, String reason) async {
    try {
      final res = await ref.read(httpClientProvider).put(
        Uri.http(Constants.serverUrl, 'api/store/grn/$grnId/reject'),
        headers: await _headers(),
        body: jsonEncode({'reason': reason}),
      );
      final raw = jsonDecode(utf8.decode(res.bodyBytes));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final Map<String, dynamic> data = (raw is Map && raw.containsKey('data') && raw['data'] is Map)
            ? Map<String, dynamic>.from(raw['data'] as Map)
            : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
        return Right(StoreGrnModel.fromJson(data));
      }
      final msg = raw is Map ? raw['message']?.toString() : null;
      return Left(Failure(msg ?? 'Failed to reject GRN', StackTrace.current));
    } catch (e, st) {
      return Left(Failure(e.toString(), st));
    }
  }
}

// ==================== CONTROLLER & PROVIDERS ====================

final grnListFilterStatusProvider = StateProvider<String>((ref) => 'ALL');

final storeGrnListProvider = FutureProvider.autoDispose<List<StoreGrnModel>>((ref) async {
  final status = ref.watch(grnListFilterStatusProvider);
  final repo = ref.read(storeGrnRepositoryProvider);
  final res = await repo.listGrn(status: status);
  return res.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final storeGrnControllerProvider =
    StateNotifierProvider<StoreGrnController, bool>((ref) {
  return StoreGrnController(ref);
});

class StoreGrnController extends StateNotifier<bool> {
  final Ref ref;
  StoreGrnController(this.ref) : super(false);

  Future<StoreGrnModel?> submitGrn({
    String? base64Image,
    String? remarks,
    bool autoApprove = true,
  }) async {
    final cart = ref.read(grnCartProvider);
    if (cart.isEmpty) {
      showSnackBar('GRN Cart is empty');
      return null;
    }

    state = true;
    try {
      String uploadedUrl = '';
      if (base64Image != null && base64Image.isNotEmpty) {
        final imgRes = await ref.read(storeGrnRepositoryProvider).uploadImage(base64Image);
        imgRes.fold((f) {
          log('GRN image upload warning: ${f.message}');
        }, (url) {
          uploadedUrl = url;
        });
      }

      final itemsPayload = cart.values.map((entry) {
        return {
          'indentId': entry.indent.id,
          'indentNumber': entry.indent.indentNumber.isNotEmpty
              ? entry.indent.indentNumber
              : entry.indent.requestNo,
          'itemId': entry.indent.itemId,
          'itemName': entry.indent.itemName.isNotEmpty
              ? entry.indent.itemName
              : entry.indent.itemDescription,
          'itemCode': entry.indent.itemCode,
          'category': entry.indent.documentCategory ?? '',
          'unit': entry.indent.unitOfMeasure,
          'orderedQty': entry.orderedQty,
          'receivedQty': entry.receivedQty,
          'unitPrice': entry.unitPrice,
        };
      }).toList();

      final res = await ref.read(storeGrnRepositoryProvider).createGrn(
        items: itemsPayload,
        imageUrl: uploadedUrl,
        remarks: remarks,
        autoApprove: autoApprove,
      );

      return res.fold((f) {
        showSnackBar('Failed: ${f.message}');
        return null;
      }, (grn) {
        showSnackBar('GRN ${grn.grnNumber} Approved! Ready for QR rack putaway.');
        ref.read(grnCartProvider.notifier).clear();
        ref.invalidate(storeGrnListProvider);
        ref.invalidate(refillRequestsListProvider);
        return grn;
      });
    } finally {
      state = false;
    }
  }

  Future<bool> approveGrn(String grnId) async {
    state = true;
    try {
      final res = await ref.read(storeGrnRepositoryProvider).approveGrn(grnId);
      return res.fold((f) {
        showSnackBar('Approve failed: ${f.message}');
        return false;
      }, (grn) {
        showSnackBar('GRN ${grn.grnNumber} Approved! Ready for QR putaway.');
        ref.invalidate(storeGrnListProvider);
        return true;
      });
    } finally {
      state = false;
    }
  }

  Future<bool> rejectGrn(String grnId, String reason) async {
    state = true;
    try {
      final res = await ref.read(storeGrnRepositoryProvider).rejectGrn(grnId, reason);
      return res.fold((f) {
        showSnackBar('Reject failed: ${f.message}');
        return false;
      }, (grn) {
        showSnackBar('GRN ${grn.grnNumber} Rejected');
        ref.invalidate(storeGrnListProvider);
        return true;
      });
    } finally {
      state = false;
    }
  }
}
