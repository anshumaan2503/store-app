// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:store_app/src/common/utils/defensive_parsing.dart';

class ItemRackQtyModel {
  final String id;
  final String itemId;
  final String itemName;
  final String rackId;
  final String rackCode;
  final int totalStockQuantity;
  final int stockAvailableQuantity;
  final int stockIssueQuantity;
  final int stockissueCompleted;
  final int stockscrapQuantity;
  ItemRackQtyModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.rackId,
    required this.rackCode,
    required this.totalStockQuantity,
    required this.stockAvailableQuantity,
    required this.stockIssueQuantity,
    required this.stockissueCompleted,
    required this.stockscrapQuantity,
  });

  ItemRackQtyModel copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? rackId,
    String? rackCode,
    int? totalStockQuantity,
    int? stockAvailableQuantity,
    int? stockIssueQuantity,
    int? stockissueCompleted,
    int? stockscrapQuantity,
  }) {
    return ItemRackQtyModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      rackId: rackId ?? this.rackId,
      rackCode: rackCode ?? this.rackCode,
      totalStockQuantity: totalStockQuantity ?? this.totalStockQuantity,
      stockAvailableQuantity:
          stockAvailableQuantity ?? this.stockAvailableQuantity,
      stockIssueQuantity: stockIssueQuantity ?? this.stockIssueQuantity,
      stockissueCompleted: stockissueCompleted ?? this.stockissueCompleted,
      stockscrapQuantity: stockscrapQuantity ?? this.stockscrapQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'rackId': rackId,
      'rackCode': rackCode,
      'totalStockQuantity': totalStockQuantity,
      'stockAvailableQuantity': stockAvailableQuantity,
      'stockIssueQuantity': stockIssueQuantity,
      'stockissueCompleted': stockissueCompleted,
      'stockscrapQuantity': stockscrapQuantity,
    };
  }

  factory ItemRackQtyModel.fromMap(Map<String, dynamic> map) {
    return ItemRackQtyModel(
      id: extractId(map),
      itemId: parseMongoId(map['itemId']),
      itemName: map['itemName']?.toString() ?? '',
      rackId: parseMongoId(map['rackId']),
      rackCode: map['rackCode']?.toString() ?? '',
      totalStockQuantity: toInt(map['totalStockQuantity']) ?? 0,
      stockAvailableQuantity: toInt(map['stockAvailableQuantity']) ?? 0,
      stockIssueQuantity: toInt(map['stockIssueQuantity']) ?? 0,
      stockissueCompleted: toInt(map['stockissueCompleted']) ?? 0,
      stockscrapQuantity: toInt(map['stockscrapQuantity']) ?? 0,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemRackQtyModel.fromJson(String source) =>
      ItemRackQtyModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ItemRackQtyModel(id: $id, itemId: $itemId, itemName: $itemName, rackId: $rackId, rackCode: $rackCode, totalStockQuantity: $totalStockQuantity, stockAvailableQuantity: $stockAvailableQuantity, stockIssueQuantity: $stockIssueQuantity, stockissueCompleted: $stockissueCompleted, stockscrapQuantity: $stockscrapQuantity)';
  }

  @override
  bool operator ==(covariant ItemRackQtyModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.itemId == itemId &&
        other.itemName == itemName &&
        other.rackId == rackId &&
        other.rackCode == rackCode &&
        other.totalStockQuantity == totalStockQuantity &&
        other.stockAvailableQuantity == stockAvailableQuantity &&
        other.stockIssueQuantity == stockIssueQuantity &&
        other.stockissueCompleted == stockissueCompleted &&
        other.stockscrapQuantity == stockscrapQuantity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        itemId.hashCode ^
        itemName.hashCode ^
        rackId.hashCode ^
        rackCode.hashCode ^
        totalStockQuantity.hashCode ^
        stockAvailableQuantity.hashCode ^
        stockIssueQuantity.hashCode ^
        stockissueCompleted.hashCode ^
        stockscrapQuantity.hashCode;
  }
}
