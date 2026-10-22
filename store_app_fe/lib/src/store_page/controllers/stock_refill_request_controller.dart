import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/controllers/users_controller.dart';
import '../domains/models/stock_refill_request_model.dart';
import '../domains/repositories/stock_refill_request_repository.dart';

final refillRequestFilterStatusProvider =
    StateProvider<String>((ref) => 'ALL');

final refillRequestSearchProvider = StateProvider<String>((ref) => '');

final refillRequestsListProvider =
    FutureProvider.autoDispose<List<StockRefillRequestModel>>((ref) async {
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final status = ref.watch(refillRequestFilterStatusProvider);
  final search = ref.watch(refillRequestSearchProvider);

  final res = await repository.getRefillRequests(
    status: status,
    search: search,
  );

  return res.fold(
    (l) => throw l.message,
    (r) => r,
  );
});

final indentRequestsListProvider = refillRequestsListProvider;

final pendingRefillRequestsCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final res = await repository.getRefillRequests(status: 'PENDING');
  return res.fold(
    (l) => 0,
    (r) => r.length,
  );
});

final pendingIndentRequestsCountProvider = pendingRefillRequestsCountProvider;

final uncreditedApprovedIndentsProvider = FutureProvider.autoDispose
    .family<List<StockRefillRequestModel>, String>((ref, itemId) async {
  if (itemId.trim().isEmpty) return const [];
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final res = await repository.getRefillRequests(
    status: 'APPROVED',
    itemId: itemId,
    uncredited: true,
  );
  return res.fold(
    (l) => const [],
    (r) => r,
  );
});

final activeIndentForItemProvider = FutureProvider.autoDispose
    .family<StockRefillRequestModel?, String>((ref, itemId) async {
  if (itemId.trim().isEmpty) return null;
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final currentUser = ref.watch(userFindOneDataStreamProvider).valueOrNull;

  // 1. Check for PENDING indent
  final resPending = await repository.getRefillRequests(
    status: 'PENDING',
    itemId: itemId,
  );
  final pendingList = resPending.getOrElse((_) => []);
  if (pendingList.isNotEmpty) {
    if (currentUser != null) {
      final myPending = pendingList.where((ind) =>
          ind.requesterId == currentUser.uid ||
          (currentUser.name.trim().isNotEmpty &&
              ind.requestedBy.trim().toLowerCase() ==
                  currentUser.name.trim().toLowerCase()) ||
          (currentUser.phoneNumber.trim().isNotEmpty &&
              ind.requestedBy.trim().contains(currentUser.phoneNumber.trim())));
      if (myPending.isNotEmpty) {
        return myPending.first;
      }
      return null;
    }
    return pendingList.first;
  }

  // 2. Check for APPROVED in-transit (uncredited) indent
  final resApproved = await repository.getRefillRequests(
    status: 'APPROVED',
    itemId: itemId,
    uncredited: true,
  );
  final approvedList = resApproved.getOrElse((_) => []);
  if (approvedList.isNotEmpty) {
    if (currentUser != null) {
      final myApproved = approvedList.where((ind) =>
          ind.requesterId == currentUser.uid ||
          (currentUser.name.trim().isNotEmpty &&
              ind.requestedBy.trim().toLowerCase() ==
                  currentUser.name.trim().toLowerCase()) ||
          (currentUser.phoneNumber.trim().isNotEmpty &&
              ind.requestedBy.trim().contains(currentUser.phoneNumber.trim())));
      if (myApproved.isNotEmpty) {
        return myApproved.first;
      }
      return null;
    }
    return approvedList.first;
  }

  return null;
});

final storeConsolidationSearchProvider = StateProvider<String>((ref) => '');

final pendingStoreConsolidationProvider =
    FutureProvider.autoDispose<List<ConsolidatedStoreItemModel>>((ref) async {
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final search = ref.watch(storeConsolidationSearchProvider);
  final res = await repository.getPendingStoreConsolidation(search: search);
  return res.fold(
    (l) => throw l.message,
    (r) => r,
  );
});

final pendingStoreConsolidationCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final repository = ref.watch(stockRefillRequestRepositoryProvider);
  final res = await repository.getPendingStoreConsolidation();
  return res.fold(
    (l) => 0,
    (r) => r.length,
  );
});

final stockRefillRequestControllerProvider =
    StateNotifierProvider<StockRefillRequestController, AsyncValue<void>>(
  (ref) => StockRefillRequestController(ref),
);

final indentRaiseControllerProvider = stockRefillRequestControllerProvider;

class StockRefillRequestController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  StockRefillRequestController(this._ref) : super(const AsyncValue.data(null));

  Future<StockRefillRequestModel?> createRequest({
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
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.createRefillRequest(
      itemId: itemId,
      requestedQty: requestedQty,
      reason: reason,
      indentQty: indentQty ?? requestedQty,
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

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return null;
      },
      (created) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return created;
      },
    );
  }

  Future<StockRefillRequestModel?> createIndent({
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
  }) =>
      createRequest(
        itemId: itemId,
        requestedQty: indentQty,
        reason: reason,
        indentQty: indentQty,
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

  Future<bool> approveRequest(
    String id, {
    String? reviewRemarks,
    bool? directStockIn,
    String? rackId,
    num? creditQty,
    bool overrideMaxCapacity = false,
  }) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.approveRefillRequest(
      id,
      reviewRemarks: reviewRemarks,
      directStockIn: directStockIn,
      rackId: rackId,
      creditQty: creditQty,
      overrideMaxCapacity: overrideMaxCapacity,
    );

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return false;
      },
      (approved) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return true;
      },
    );
  }

  Future<bool> creditStock(
    String id, {
    String? rackId,
    num? creditQty,
    String? reviewRemarks,
  }) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.creditStock(
      id,
      rackId: rackId,
      creditQty: creditQty,
      reviewRemarks: reviewRemarks,
    );

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return false;
      },
      (credited) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return true;
      },
    );
  }

  Future<bool> rejectRequest(String id, {String? reviewRemarks}) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.rejectRefillRequest(
      id,
      reviewRemarks: reviewRemarks,
    );

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return false;
      },
      (rejected) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return true;
      },
    );
  }

  Future<StockRefillRequestModel?> updateIndentQuantity({
    required String id,
    required num indentQty,
    String? reason,
  }) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.updateIndentQuantity(
      id,
      indentQty: indentQty,
      reason: reason,
    );

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return null;
      },
      (updated) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return updated;
      },
    );
  }

  Future<Map<String, dynamic>?> triggerEodScheduler() async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.triggerEodScheduler();

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return null;
      },
      (data) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        _ref.invalidate(pendingStoreConsolidationProvider);
        _ref.invalidate(pendingStoreConsolidationCountProvider);
        return data;
      },
    );
  }

  Future<bool> deleteRequest(String id) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.deleteRefillRequest(id);

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return false;
      },
      (success) {
        state = const AsyncValue.data(null);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return success;
      },
    );
  }

  Future<bool> consolidatedStoreApprove({
    required List<Map<String, dynamic>> items,
    String? overallRemarks,
    bool overrideMaxCapacity = false,
  }) async {
    state = const AsyncValue.loading();
    final repo = _ref.read(stockRefillRequestRepositoryProvider);
    final res = await repo.consolidatedStoreApprove(
      items: items,
      overallRemarks: overallRemarks,
      overrideMaxCapacity: overrideMaxCapacity,
    );

    return res.fold(
      (failure) {
        state = AsyncValue.error(failure.message, failure.stackTrace);
        return false;
      },
      (data) {
        state = const AsyncValue.data(null);
        _ref.invalidate(pendingStoreConsolidationProvider);
        _ref.invalidate(pendingStoreConsolidationCountProvider);
        _ref.invalidate(refillRequestsListProvider);
        _ref.invalidate(pendingRefillRequestsCountProvider);
        return true;
      },
    );
  }
}
