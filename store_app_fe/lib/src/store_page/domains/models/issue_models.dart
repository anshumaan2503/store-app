// lib/src/store/domains/models/issue_models.dart
import 'package:flutter/foundation.dart';

@immutable
class IssueSourceBucket {
  final String categoryId;
  final String categoryName;
  final int available;
  final List<String> itemIds;

  const IssueSourceBucket({
    required this.categoryId,
    required this.categoryName,
    required this.available,
    required this.itemIds,
  });

  factory IssueSourceBucket.fromMap(Map<String, dynamic> m) {
    return IssueSourceBucket(
      categoryId: (m['categoryId'] ?? '').toString(),
      categoryName: (m['categoryName'] ?? '').toString(),
      available: _asInt(m['available']),
      itemIds:
          ((m['itemIds'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

@immutable
class IssueSourcesResponse {
  final String selectedItemId;
  final String itemNameId;
  final String itemName;
  final String itemNameCode;
  final String unit;
  final String? parentCategoryId;
  final List<IssueSourceBucket> buckets;

  const IssueSourcesResponse({
    required this.selectedItemId,
    required this.itemNameId,
    required this.itemName,
    required this.itemNameCode,
    required this.unit,
    required this.parentCategoryId,
    required this.buckets,
  });

  factory IssueSourcesResponse.fromMap(Map<String, dynamic> m) {
    return IssueSourcesResponse(
      selectedItemId: (m['selectedItemId'] ?? '').toString(),
      itemNameId: (m['itemNameId'] ?? '').toString(),
      itemName: (m['itemName'] ?? '').toString(),
      itemNameCode: (m['itemNameCode'] ?? '').toString(),
      unit: (m['unit'] ?? '').toString(),
      parentCategoryId:
          (m['parentCategoryId'] == null)
              ? null
              : (m['parentCategoryId'] ?? '').toString(),
      buckets:
          ((m['buckets'] as List?) ?? const [])
              .map((e) => IssueSourceBucket.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }
}

@immutable
class IssueDraftResult {
  final String id;
  final String issNo;

  final String chosenBucketCategoryId;
  final String chosenBucketCategoryName;
  final int chosenBucketAvailable;

  const IssueDraftResult({
    required this.id,
    required this.issNo,
    required this.chosenBucketCategoryId,
    required this.chosenBucketCategoryName,
    required this.chosenBucketAvailable,
  });

  factory IssueDraftResult.fromMap(Map<String, dynamic> m) {
    final chosen = Map<String, dynamic>.from((m['chosenBucket'] as Map?) ?? const {});
    return IssueDraftResult(
      id: (m['_id'] ?? '').toString(),
      issNo: (m['issNo'] ?? '').toString(),
      chosenBucketCategoryId: (chosen['categoryId'] ?? '').toString(),
      chosenBucketCategoryName: (chosen['categoryName'] ?? '').toString(),
      chosenBucketAvailable: _asInt(chosen['available']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

@immutable
class IssueAllocationModel {
  final String id;
  final String itemId;
  final String itemName;
  final String rackId;
  final String rackName;
  final int qty;
  final int returnedQty;

  const IssueAllocationModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.rackId,
    required this.rackName,
    required this.qty,
    required this.returnedQty,
  });

  int get remainingReturn => (qty - returnedQty);

  factory IssueAllocationModel.fromMap(Map<String, dynamic> m) {
    return IssueAllocationModel(
      id: (m['_id'] ?? '').toString(),
      itemId: (m['itemId'] ?? '').toString(),
      itemName: (m['itemName'] ?? '').toString(),
      rackId: (m['rackId'] ?? '').toString(),
      rackName: (m['rackName'] ?? '').toString(),
      qty: _asInt(m['qty']),
      returnedQty: _asInt(m['returnedQty']),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}

@immutable
class IssueDetailsModel {
  final String id;
  final String issNo;
  final String status;
  final int requestedQty;
  final int approvedQty;
  final int issuedQty;
  final int returnQty;
  final String unit;
  final List<IssueAllocationModel> allocations;

  const IssueDetailsModel({
    required this.id,
    required this.issNo,
    required this.status,
    required this.requestedQty,
    required this.approvedQty,
    required this.issuedQty,
    required this.returnQty,
    required this.unit,
    required this.allocations,
  });

  factory IssueDetailsModel.fromMap(Map<String, dynamic> m) {
    final lines = ((m['lines'] as List?) ?? const []);
    final line0 = lines.isNotEmpty ? Map<String, dynamic>.from(lines.first as Map) : const <String, dynamic>{};

    return IssueDetailsModel(
      id: (m['_id'] ?? '').toString(),
      issNo: (m['issNo'] ?? '').toString(),
      status: (m['status'] ?? '').toString(),
      requestedQty: _asInt(line0['requestedQty']),
      approvedQty: _asInt(line0['approvedQty']),
      issuedQty: _asInt(line0['issuedQty']),
      returnQty: _asInt(line0['returnQty']),
      unit: (line0['unit'] ?? '').toString(),
      allocations:
          ((m['allocations'] as List?) ?? const [])
              .map((e) => IssueAllocationModel.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList(),
    );
  }

  static int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }
}
