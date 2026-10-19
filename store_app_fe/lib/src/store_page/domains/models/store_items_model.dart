// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:store_app/src/common/utils/defensive_parsing.dart';

class StoreItemsModel {
  final String id;
  final String itemCode;
  final bool isScrap;
  // final String itemNameId;
  final String itemName;
  // final String itemNameCode;

  final List<String> rackId;

  final String? categoryId;
  final String categoryLabel;

  final String unit;
  final String description;
  final int maxCapacity;
  final int minStockQuantity;
  final int defaultRefillQuantity;

  final int totalStockQuantity;
  final int stockAvailableQuantity;
  final int stockRequestedQuantity;
  final int stockIssueQuantity;
  final int stockissueCompleted;
  final int stockscrapQuantity;
  final bool isIndentReady;
  final double latestPurchasePrice;

  final String imageUrl;
  StoreItemsModel({
    required this.id,
    required this.itemCode,
    required this.isScrap,
    required this.itemName,
    required this.rackId,
    this.categoryId,
    required this.categoryLabel,
    required this.unit,
    required this.description,
    required this.maxCapacity,
    this.minStockQuantity = 0,
    this.defaultRefillQuantity = 0,
    required this.totalStockQuantity,
    required this.stockAvailableQuantity,
    this.stockRequestedQuantity = 0,
    required this.stockIssueQuantity,
    required this.stockissueCompleted,
    required this.stockscrapQuantity,
    this.isIndentReady = false,
    this.latestPurchasePrice = 0.0,
    required this.imageUrl,
  });

  StoreItemsModel copyWith({
    String? id,
    String? itemCode,
    bool? isScrap,
    String? itemName,
    List<String>? rackId,
    String? categoryId,
    String? categoryLabel,
    String? unit,
    String? description,
    int? maxCapacity,
    int? minStockQuantity,
    int? defaultRefillQuantity,
    int? totalStockQuantity,
    int? stockAvailableQuantity,
    int? stockRequestedQuantity,
    int? stockIssueQuantity,
    int? stockissueCompleted,
    int? stockscrapQuantity,
    bool? isIndentReady,
    double? latestPurchasePrice,
    String? imageUrl,
  }) {
    return StoreItemsModel(
      id: id ?? this.id,
      itemCode: itemCode ?? this.itemCode,
      isScrap: isScrap ?? this.isScrap,
      itemName: itemName ?? this.itemName,
      rackId: rackId ?? this.rackId,
      categoryId: categoryId ?? this.categoryId,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      unit: unit ?? this.unit,
      description: description ?? this.description,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      minStockQuantity: minStockQuantity ?? this.minStockQuantity,
      defaultRefillQuantity:
          defaultRefillQuantity ?? this.defaultRefillQuantity,
      totalStockQuantity: totalStockQuantity ?? this.totalStockQuantity,
      stockAvailableQuantity:
          stockAvailableQuantity ?? this.stockAvailableQuantity,
      stockRequestedQuantity:
          stockRequestedQuantity ?? this.stockRequestedQuantity,
      stockIssueQuantity: stockIssueQuantity ?? this.stockIssueQuantity,
      stockissueCompleted: stockissueCompleted ?? this.stockissueCompleted,
      stockscrapQuantity: stockscrapQuantity ?? this.stockscrapQuantity,
      isIndentReady: isIndentReady ?? this.isIndentReady,
      latestPurchasePrice: latestPurchasePrice ?? this.latestPurchasePrice,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemCode': itemCode,
      'isScrap': isScrap,
      'itemName': itemName,
      'rackId': rackId,
      'categoryId': categoryId,
      'categoryLabel': categoryLabel,
      'unit': unit,
      'description': description,
      'maxCapacity': maxCapacity,
      'maxQuantity': maxCapacity,
      'minStockQuantity': minStockQuantity,
      'defaultRefillQuantity': defaultRefillQuantity,
      'totalStockQuantity': totalStockQuantity,
      'stockAvailableQuantity': stockAvailableQuantity,
      'stockRequestedQuantity': stockRequestedQuantity,
      'stockIssueQuantity': stockIssueQuantity,
      'stockissueCompleted': stockissueCompleted,
      'stockscrapQuantity': stockscrapQuantity,
      'isIndentReady': isIndentReady,
      'latestPurchasePrice': latestPurchasePrice,
      'imageUrl': imageUrl,
    };
  }

  factory StoreItemsModel.fromMap(Map<String, dynamic> map) {
    return StoreItemsModel(
      id: extractId(map),
      itemCode: map['itemCode']?.toString() ?? '',
      isScrap: map['isScrap'] ?? false,
      // itemNameId: map['itemNameId'] as String,
      itemName: map['itemName']?.toString() ?? '',
      // itemNameCode: map['itemNameCode'] as String,
      rackId: [],
      categoryId:
          map['categoryId'] != null ? parseMongoId(map['categoryId']) : null,
      categoryLabel: map['categoryLabel']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      maxCapacity: toInt(map['maxCapacity']) ?? toInt(map['maxQuantity']) ?? 0,
      minStockQuantity:
          toInt(map['minStockQuantity']) ?? toInt(map['minimumValue']) ?? 0,
      defaultRefillQuantity: toInt(map['defaultRefillQuantity']) ?? 0,
      totalStockQuantity: toInt(map['totalStockQuantity']) ?? 0,
      stockAvailableQuantity: toInt(map['stockAvailableQuantity']) ?? 0,
      stockRequestedQuantity: toInt(map['stockRequestedQuantity']) ?? 0,
      stockIssueQuantity: toInt(map['stockIssueQuantity']) ?? 0,
      stockissueCompleted: toInt(map['stockissueCompleted']) ?? 0,
      stockscrapQuantity: toInt(map['stockscrapQuantity']) ?? 0,
      isIndentReady: map['isIndentReady'] == true,
      latestPurchasePrice: toDouble(map['latestPurchasePrice']) ?? 0.0,
      imageUrl: map['imageUrl']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreItemsModel.fromJson(String source) =>
      StoreItemsModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreItemsModel(id: $id, itemCode: $itemCode, isScrap: $isScrap, itemName: $itemName, rackId: $rackId, categoryId: $categoryId, categoryLabel: $categoryLabel, unit: $unit, description: $description, maxCapacity: $maxCapacity, minStockQuantity: $minStockQuantity, defaultRefillQuantity: $defaultRefillQuantity, totalStockQuantity: $totalStockQuantity, stockAvailableQuantity: $stockAvailableQuantity, stockIssueQuantity: $stockIssueQuantity, stockissueCompleted: $stockissueCompleted, stockscrapQuantity: $stockscrapQuantity, imageUrl: $imageUrl)';
  }

  @override
  bool operator ==(covariant StoreItemsModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.itemCode == itemCode &&
        other.isScrap == isScrap &&
        other.itemName == itemName &&
        listEquals(other.rackId, rackId) &&
        other.categoryId == categoryId &&
        other.categoryLabel == categoryLabel &&
        other.unit == unit &&
        other.description == description &&
        other.maxCapacity == maxCapacity &&
        other.minStockQuantity == minStockQuantity &&
        other.defaultRefillQuantity == defaultRefillQuantity &&
        other.totalStockQuantity == totalStockQuantity &&
        other.stockAvailableQuantity == stockAvailableQuantity &&
        other.stockIssueQuantity == stockIssueQuantity &&
        other.stockissueCompleted == stockissueCompleted &&
        other.stockscrapQuantity == stockscrapQuantity &&
        other.imageUrl == imageUrl;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        itemCode.hashCode ^
        isScrap.hashCode ^
        itemName.hashCode ^
        rackId.hashCode ^
        categoryId.hashCode ^
        categoryLabel.hashCode ^
        unit.hashCode ^
        description.hashCode ^
        maxCapacity.hashCode ^
        totalStockQuantity.hashCode ^
        stockAvailableQuantity.hashCode ^
        stockIssueQuantity.hashCode ^
        stockissueCompleted.hashCode ^
        stockscrapQuantity.hashCode ^
        imageUrl.hashCode;
  }
}
