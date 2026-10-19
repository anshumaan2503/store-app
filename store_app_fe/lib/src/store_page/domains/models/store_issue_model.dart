import 'package:store_app/src/common/utils/defensive_parsing.dart';

class IssueModel {
  final String id;
  final String issNo;
  final String reason;
  final String remark;
  final List<IssueLine> lines;
  final String status;
  final String createdBy;
  final List<IssueAllocation> allocations;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;
  final String approvedBy;
  final String approvedByName;
  final DateTime? rejectedAt;
  final String rejectedBy;
  final String rejectedByName;
  final DateTime? closedAt;
  final String closedBy;
  final String closedByName;
  final String creatorName;
  final String departmentName;

  IssueModel({
    required this.id,
    required this.issNo,
    required this.reason,
    required this.remark,
    required this.lines,
    this.status = 'DRAFT',
    required this.createdBy,
    required this.allocations,
    required this.createdAt,
    required this.updatedAt,
    this.approvedAt,
    this.approvedBy = '',
    this.approvedByName = '',
    this.rejectedAt,
    this.rejectedBy = '',
    this.rejectedByName = '',
    this.closedAt,
    this.closedBy = '',
    this.closedByName = '',
    this.creatorName = '',
    this.departmentName = '',
  });

  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isApproved => status.toUpperCase() == 'APPROVED';
  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isClosed => status.toUpperCase() == 'CLOSED';

  int get totalRequested =>
      lines.fold(0, (sum, l) => sum + (l.requestedQty > 0 ? l.requestedQty : 0));
  int get totalApproved =>
      lines.fold(0, (sum, l) => sum + (l.approvedQty > 0 ? l.approvedQty : 0));
  int get totalIssued =>
      lines.fold(0, (sum, l) => sum + (l.issuedQty > 0 ? l.issuedQty : 0));

  bool get isFullyPickedUp =>
      !isRejected && totalApproved > 0 && totalIssued >= totalApproved;

  DateTime? get latestIssuedAt {
    if (allocations.isNotEmpty) {
      final sorted = List<IssueAllocation>.from(allocations)
        ..sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
      return sorted.last.issuedAt;
    }
    return closedAt;
  }

  String get latestIssuedByName {
    if (allocations.isNotEmpty) {
      final last = allocations.last;
      return last.issuedByName.isNotEmpty ? last.issuedByName : last.issuedBy;
    }
    return closedByName.isNotEmpty ? closedByName : closedBy;
  }

  // Factory method to create an instance from a JSON object
  factory IssueModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString()) ?? DateTime.now();
    }

    DateTime? parseNullableDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      return DateTime.tryParse(val.toString());
    }

    final rawLines = json['lines'];
    final linesList = (rawLines is List)
        ? rawLines
            .whereType<Map>()
            .map((item) => IssueLine.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <IssueLine>[];

    final rawAllocations = json['allocations'];
    final allocationsList = (rawAllocations is List)
        ? rawAllocations
            .whereType<Map>()
            .map((item) => IssueAllocation.fromJson(Map<String, dynamic>.from(item)))
            .toList()
        : <IssueAllocation>[];

    return IssueModel(
      id: parseMongoId(json['_id']),
      issNo: json['issNo']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      remark: json['remark']?.toString() ?? '',
      lines: linesList,
      status: json['status']?.toString() ?? 'DRAFT',
      createdBy: json['createdBy']?.toString() ?? '',
      allocations: allocationsList,
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      approvedAt: parseNullableDate(json['approvedAt']),
      approvedBy: json['approvedBy']?.toString() ?? '',
      approvedByName: json['approvedByName']?.toString() ?? '',
      rejectedAt: parseNullableDate(json['rejectedAt']),
      rejectedBy: json['rejectedBy']?.toString() ?? '',
      rejectedByName: json['rejectedByName']?.toString() ?? '',
      closedAt: parseNullableDate(json['closedAt']),
      closedBy: json['closedBy']?.toString() ?? '',
      closedByName: json['closedByName']?.toString() ?? '',
      creatorName: json['creatorName']?.toString() ?? '',
      departmentName: json['departmentName']?.toString() ?? '',
    );
  }

  // Method to convert the instance to a JSON object
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'issNo': issNo,
      'reason': reason,
      'remark': remark,
      'lines': lines.map((line) => line.toJson()).toList(),
      'status': status,
      'createdBy': createdBy,
      'allocations':
          allocations.map((allocation) => allocation.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'approvedBy': approvedBy,
      'approvedByName': approvedByName,
      'rejectedAt': rejectedAt?.toIso8601String(),
      'rejectedBy': rejectedBy,
      'rejectedByName': rejectedByName,
      'closedAt': closedAt?.toIso8601String(),
      'closedBy': closedBy,
      'closedByName': closedByName,
      'creatorName': creatorName,
      'departmentName': departmentName,
    };
  }

  // The copyWith method to create a new instance with some properties modified
  IssueModel copyWith({
    String? id,
    String? issNo,
    String? reason,
    String? remark,
    List<IssueLine>? lines,
    String? status,
    String? createdBy,
    List<IssueAllocation>? allocations,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? approvedAt,
    String? approvedBy,
    String? approvedByName,
    DateTime? rejectedAt,
    String? rejectedBy,
    String? rejectedByName,
    DateTime? closedAt,
    String? closedBy,
    String? closedByName,
    String? creatorName,
    String? departmentName,
  }) {
    return IssueModel(
      id: id ?? this.id,
      issNo: issNo ?? this.issNo,
      reason: reason ?? this.reason,
      remark: remark ?? this.remark,
      lines: lines ?? this.lines,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      allocations: allocations ?? this.allocations,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedByName: approvedByName ?? this.approvedByName,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      rejectedBy: rejectedBy ?? this.rejectedBy,
      rejectedByName: rejectedByName ?? this.rejectedByName,
      closedAt: closedAt ?? this.closedAt,
      closedBy: closedBy ?? this.closedBy,
      closedByName: closedByName ?? this.closedByName,
      creatorName: creatorName ?? this.creatorName,
      departmentName: departmentName ?? this.departmentName,
    );
  }
}

class IssueLine {
  final String itemId;
  final String itemName;
  final int requestedQty;
  final int approvedQty;
  final int issuedQty;
  final int returnQty;
  final String unit;
  final int scrapQty;
  final int approvedRejectQty;
  final int issuedRejectQty;
  final double unitPrice;
  final double totalPrice;

  IssueLine({
    required this.itemId,
    required this.itemName,
    required this.requestedQty,
    required this.approvedQty,
    required this.issuedQty,
    required this.returnQty,
    required this.unit,
    required this.scrapQty,
    required this.approvedRejectQty,
    required this.issuedRejectQty,
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
  });

  IssueLine copyWith({
    String? itemId,
    String? itemName,
    int? requestedQty,
    int? approvedQty,
    int? issuedQty,
    int? returnQty,
    String? unit,
    int? scrapQty,
    int? approvedRejectQty,
    int? issuedRejectQty,
    double? unitPrice,
    double? totalPrice,
  }) {
    return IssueLine(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      requestedQty: requestedQty ?? this.requestedQty,
      approvedQty: approvedQty ?? this.approvedQty,
      issuedQty: issuedQty ?? this.issuedQty,
      returnQty: returnQty ?? this.returnQty,
      scrapQty: scrapQty ?? this.scrapQty,
      approvedRejectQty: approvedRejectQty ?? this.approvedRejectQty,
      issuedRejectQty: issuedRejectQty ?? this.issuedRejectQty,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
    );
  }

  // Factory method to create an instance from JSON
  factory IssueLine.fromJson(Map<String, dynamic> json) {
    return IssueLine(
      itemId: parseMongoId(json['itemId']),
      itemName: json['itemName']?.toString() ?? '',
      requestedQty: toInt(json['requestedQty']) ?? 0,
      approvedQty: toInt(json['approvedQty']) ?? 0,
      issuedQty: toInt(json['issuedQty']) ?? 0,
      returnQty: toInt(json['returnQty']) ?? 0,
      unit: json['unit']?.toString() ?? '',
      scrapQty: toInt(json['scrapQty']) ?? 0,
      approvedRejectQty: toInt(json['approvedRejectQty']) ?? 0,
      issuedRejectQty: toInt(json['issuedRejectQty']) ?? 0,
      unitPrice: toDouble(json['unitPrice']) ?? 0.0,
      totalPrice: toDouble(json['totalPrice']) ?? 0.0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'requestedQty': requestedQty,
      'approvedQty': approvedQty,
      'issuedQty': issuedQty,
      'returnQty': returnQty,
      'unit': unit,
      'scrapQty': scrapQty,
      'approvedRejectQty': approvedRejectQty,
      'issuedRejectQty': issuedRejectQty,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}

class IssueAllocation {
  final String itemId;
  final String itemName;
  final String rackId;
  final String rackName;
  final int qty;
  final int returnedQty;
  final DateTime issuedAt;
  final String issuedBy;
  final String issuedByName;
  final int returnedGoodQty;
  final int returnedScrapQty;
  final double unitPrice;
  final double totalPrice;

  IssueAllocation({
    required this.itemId,
    required this.itemName,
    required this.rackId,
    required this.rackName,
    required this.qty,
    required this.returnedQty,
    required this.issuedAt,
    required this.issuedBy,
    this.issuedByName = '',
    required this.returnedGoodQty,
    required this.returnedScrapQty,
    this.unitPrice = 0.0,
    this.totalPrice = 0.0,
  });

  // Factory method to create an instance from JSON
  factory IssueAllocation.fromJson(Map<String, dynamic> json) {
    return IssueAllocation(
      itemId: parseMongoId(json['itemId']),
      itemName: json['itemName']?.toString() ?? '',
      rackId: parseMongoId(json['rackId']),
      rackName: json['rackName']?.toString() ?? '',
      qty: toInt(json['qty']) ?? 0,
      returnedQty: toInt(json['returnedQty']) ?? 0,
      issuedAt: json['issuedAt'] != null
          ? (json['issuedAt'] is DateTime
              ? json['issuedAt'] as DateTime
              : DateTime.parse(json['issuedAt'].toString()))
          : DateTime.now(),
      issuedBy: json['issuedBy']?.toString() ?? '',
      issuedByName: json['issuedByName']?.toString() ?? '',
      returnedGoodQty: toInt(json['returnedGoodQty']) ?? 0,
      returnedScrapQty: toInt(json['returnedScrapQty']) ?? 0,
      unitPrice: toDouble(json['unitPrice']) ?? 0.0,
      totalPrice: toDouble(json['totalPrice']) ?? 0.0,
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'rackId': rackId,
      'rackName': rackName,
      'qty': qty,
      'returnedQty': returnedQty,
      'issuedAt': issuedAt.toIso8601String(),
      'issuedBy': issuedBy,
      'issuedByName': issuedByName,
      'returnedGoodQty': returnedGoodQty,
      'returnedScrapQty': returnedScrapQty,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
    };
  }
}
