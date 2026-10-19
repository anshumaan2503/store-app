import 'dart:convert';
import 'package:store_app/src/common/utils/defensive_parsing.dart';

class StoreReceiveLine {
  final String itemId;
  final String rackId;
  final int qty;
  final double? unitPrice;
  final double? totalPrice;
  final String? grnId;
  final String? grnNo;

  const StoreReceiveLine({
    required this.itemId,
    required this.rackId,
    required this.qty,
    this.unitPrice,
    this.totalPrice,
    this.grnId,
    this.grnNo,
  });

  StoreReceiveLine copyWith({
    String? itemId,
    String? rackId,
    int? qty,
    double? unitPrice,
    double? totalPrice,
    String? grnId,
    String? grnNo,
  }) {
    return StoreReceiveLine(
      itemId: itemId ?? this.itemId,
      rackId: rackId ?? this.rackId,
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      grnId: grnId ?? this.grnId,
      grnNo: grnNo ?? this.grnNo,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "itemId": itemId,
      "rackId": rackId,
      "qty": qty,
      if (unitPrice != null) "unitPrice": unitPrice,
      if (totalPrice != null) "totalPrice": totalPrice,
      if (grnId != null) "grnId": grnId,
      if (grnNo != null) "grnNo": grnNo,
    };
  }

  factory StoreReceiveLine.fromMap(Map<String, dynamic> map) {
    return StoreReceiveLine(
      itemId: (map["itemId"] ?? "").toString(),
      rackId: (map["rackId"] ?? "").toString(),
      qty:
          (map["qty"] is num)
              ? (map["qty"] as num).toInt()
              : int.tryParse(map["qty"].toString()) ?? 0,
      unitPrice: toDouble(map["unitPrice"]),
      totalPrice: toDouble(map["totalPrice"]),
      grnId: map["grnId"]?.toString(),
      grnNo: map["grnNo"]?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreReceiveLine.fromJson(String source) =>
      StoreReceiveLine.fromMap(json.decode(source) as Map<String, dynamic>);
}

class StoreReceive {
  final String? id; // Mongo _id
  final String receivedBy;
  final String? remark;
  final List<StoreReceiveLine> lines;

  final DateTime? createdAt; // timestamps: true
  final DateTime? updatedAt;

  const StoreReceive({
    this.id,
    required this.receivedBy,
    this.remark,
    required this.lines,
    this.createdAt,
    this.updatedAt,
  });

  StoreReceive copyWith({
    String? id,
    String? receivedBy,
    String? remark,
    List<StoreReceiveLine>? lines,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreReceive(
      id: id ?? this.id,
      receivedBy: receivedBy ?? this.receivedBy,
      remark: remark ?? this.remark,
      lines: lines ?? this.lines,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Use this when creating/updating (usually you don't send id/createdAt/updatedAt)
  Map<String, dynamic> toCreateMap() {
    return {
      "receivedBy": receivedBy,
      "remark": remark ?? "",
      "lines": lines.map((e) => e.toMap()).toList(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      "_id": id,
      "receivedBy": receivedBy,
      "remark": remark,
      "lines": lines.map((e) => e.toMap()).toList(),
      "createdAt": createdAt?.toIso8601String(),
      "updatedAt": updatedAt?.toIso8601String(),
    };
  }

  factory StoreReceive.fromMap(Map<String, dynamic> map) {
    final rawLines = (map["lines"] as List?) ?? const [];
    return StoreReceive(
      id: (map["_id"] ?? map["id"])?.toString(),
      receivedBy: (map["receivedBy"] ?? "").toString(),
      remark: map["remark"]?.toString(),
      lines:
          rawLines
              .map((e) => StoreReceiveLine.fromMap(e as Map<String, dynamic>))
              .toList(),
      createdAt:
          map["createdAt"] != null
              ? DateTime.tryParse(map["createdAt"].toString())
              : null,
      updatedAt:
          map["updatedAt"] != null
              ? DateTime.tryParse(map["updatedAt"].toString())
              : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreReceive.fromJson(String source) =>
      StoreReceive.fromMap(json.decode(source) as Map<String, dynamic>);
}
