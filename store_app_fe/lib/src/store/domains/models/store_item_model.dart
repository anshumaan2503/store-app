// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:store_app/src/common/utils/defensive_parsing.dart';

class StoreItem {
  final String id;
  final String name;
  final String description;
  final String category;
  final int totalStockQuantity;
  final int stockAvailableQuantity;
  final int stockIssueQuantity;
  final int stockissueCompleted;
  final int stockscrapQuantity;
  final List<String> stockPlace;
  final String unit;
  final String imageUrl;
  final String createdBy;
  final bool isBag;
  final int maxQuantity;
  final DateTime createdAt;
  final DateTime updatedAt;
  StoreItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.totalStockQuantity,
    required this.stockAvailableQuantity,
    required this.stockIssueQuantity,
    required this.stockissueCompleted,
    required this.stockscrapQuantity,
    required this.stockPlace,
    required this.unit,
    required this.imageUrl,
    required this.createdBy,
    required this.isBag,
    required this.maxQuantity,
    required this.createdAt,
    required this.updatedAt,
  });

  StoreItem copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? totalStockQuantity,
    int? stockAvailableQuantity,
    int? stockIssueQuantity,
    int? stockissueCompleted,
    int? stockscrapQuantity,
    List<String>? stockPlace,
    String? unit,
    String? imageUrl,
    String? createdBy,
    bool? isBag,
    int? maxQuantity,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      totalStockQuantity: totalStockQuantity ?? this.totalStockQuantity,
      stockAvailableQuantity:
          stockAvailableQuantity ?? this.stockAvailableQuantity,
      stockIssueQuantity: stockIssueQuantity ?? this.stockIssueQuantity,
      stockissueCompleted: stockissueCompleted ?? this.stockissueCompleted,
      stockscrapQuantity: stockscrapQuantity ?? this.stockscrapQuantity,
      stockPlace: stockPlace ?? this.stockPlace,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy ?? this.createdBy,
      isBag: isBag ?? this.isBag,
      maxQuantity: maxQuantity ?? this.maxQuantity,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'totalStockQuantity': totalStockQuantity,
      'stockAvailableQuantity': stockAvailableQuantity,
      'stockIssueQuantity': stockIssueQuantity,
      'stockissueCompleted': stockissueCompleted,
      'stockscrapQuantity': stockscrapQuantity,
      'stockPlace': stockPlace,
      'unit': unit,
      'imageUrl': imageUrl,
      'createdBy': createdBy,
      'isBag': isBag,
      'maxQuantity': maxQuantity,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory StoreItem.fromMap(Map<String, dynamic> map) {
    return StoreItem(
      id: extractId(map),
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      totalStockQuantity: toInt(map['totalStockQuantity']) ?? 0,
      stockAvailableQuantity: toInt(map['stockAvailableQuantity']) ?? 0,
      stockIssueQuantity: toInt(map['stockIssueQuantity']) ?? 0,
      stockissueCompleted: toInt(map['stockissueCompleted']) ?? 0,
      stockscrapQuantity: toInt(map['stockscrapQuantity']) ?? 0,
      stockPlace:
          map['stockPlace'] != null
              ? List<String>.from((map['stockPlace'] as List<dynamic>))
              : [],
      unit: map['unit']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      createdBy: map['createdBy']?.toString() ?? '',
      isBag: map['isBag'] ?? false,
      maxQuantity: toInt(map['maxQuantity']) ?? 0,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is DateTime
              ? map['updatedAt'] as DateTime
              : DateTime.parse(map['updatedAt'].toString()))
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreItem.fromJson(String source) =>
      StoreItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreItem(id: $id, name: $name, description: $description, category: $category, totalStockQuantity: $totalStockQuantity, stockAvailableQuantity: $stockAvailableQuantity, stockIssueQuantity: $stockIssueQuantity, stockissueCompleted: $stockissueCompleted, stockscrapQuantity: $stockscrapQuantity, stockPlace: $stockPlace, unit: $unit, imageUrl: $imageUrl, createdBy: $createdBy, isBag: $isBag, maxQuantity: $maxQuantity, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant StoreItem other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.name == name &&
        other.description == description &&
        other.category == category &&
        other.totalStockQuantity == totalStockQuantity &&
        other.stockAvailableQuantity == stockAvailableQuantity &&
        other.stockIssueQuantity == stockIssueQuantity &&
        other.stockissueCompleted == stockissueCompleted &&
        other.stockscrapQuantity == stockscrapQuantity &&
        listEquals(other.stockPlace, stockPlace) &&
        other.unit == unit &&
        other.imageUrl == imageUrl &&
        other.createdBy == createdBy &&
        other.isBag == isBag &&
        other.maxQuantity == maxQuantity &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        description.hashCode ^
        category.hashCode ^
        totalStockQuantity.hashCode ^
        stockAvailableQuantity.hashCode ^
        stockIssueQuantity.hashCode ^
        stockissueCompleted.hashCode ^
        stockscrapQuantity.hashCode ^
        stockPlace.hashCode ^
        unit.hashCode ^
        imageUrl.hashCode ^
        createdBy.hashCode ^
        isBag.hashCode ^
        maxQuantity.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
