// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// lib/models/bag_model.dart

class BagModel {
  final String? id;
  final String itemId;
  final String bagCode;
  final String itemName;
  final int itemStock;
  final int itemUsed;
  final String approvedStatus; // pending | approved | rejected
  final int transferQty;
  final String? transferType; // other_bag | sorting_machine | null
  final int? maxQty;
  BagModel({
    this.id,
    required this.itemId,
    required this.bagCode,
    required this.itemName,
    required this.itemStock,
    required this.itemUsed,
    required this.approvedStatus,
    required this.transferQty,
    this.transferType,
    this.maxQty,
  });


  BagModel copyWith({
    String? id,
    String? itemId,
    String? bagCode,
    String? itemName,
    int? itemStock,
    int? itemUsed,
    String? approvedStatus,
    int? transferQty,
    String? transferType,
    int? maxQty,
  }) {
    return BagModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      bagCode: bagCode ?? this.bagCode,
      itemName: itemName ?? this.itemName,
      itemStock: itemStock ?? this.itemStock,
      itemUsed: itemUsed ?? this.itemUsed,
      approvedStatus: approvedStatus ?? this.approvedStatus,
      transferQty: transferQty ?? this.transferQty,
      transferType: transferType ?? this.transferType,
      maxQty: maxQty ?? this.maxQty,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'bagCode': bagCode,
      'itemName': itemName,
      'itemStock': itemStock,
      'itemUsed': itemUsed,
      'approvedStatus': approvedStatus,
      'transferQty': transferQty,
      'transferType': transferType,
      'maxQty': maxQty,
    };
  }

  factory BagModel.fromMap(Map<String, dynamic> map) {
    return BagModel(
      id: map['_id'] != null ? map['_id'] as String : null,
      itemId: map['itemId'] as String,
      bagCode: map['bagCode'] as String,
      itemName: map['itemName'] as String,
      itemStock: map['itemStock'] as int,
      itemUsed: map['itemUsed'] as int,
      approvedStatus: map['approvedStatus'] as String,
      transferQty: map['transferQty'] as int,
      transferType: map['transferType'] != null ? map['transferType'] as String : null,
      maxQty: map['maxQty'] != null ? map['maxQty'] as int : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory BagModel.fromJson(String source) => BagModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'BagModel(id: $id, itemId: $itemId, bagCode: $bagCode, itemName: $itemName, itemStock: $itemStock, itemUsed: $itemUsed, approvedStatus: $approvedStatus, transferQty: $transferQty, transferType: $transferType, maxQty: $maxQty)';
  }

  @override
  bool operator ==(covariant BagModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.itemId == itemId &&
      other.bagCode == bagCode &&
      other.itemName == itemName &&
      other.itemStock == itemStock &&
      other.itemUsed == itemUsed &&
      other.approvedStatus == approvedStatus &&
      other.transferQty == transferQty &&
      other.transferType == transferType &&
      other.maxQty == maxQty;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      itemId.hashCode ^
      bagCode.hashCode ^
      itemName.hashCode ^
      itemStock.hashCode ^
      itemUsed.hashCode ^
      approvedStatus.hashCode ^
      transferQty.hashCode ^
      transferType.hashCode ^
      maxQty.hashCode;
  }
}
