import 'package:flutter/foundation.dart';
import 'store_items_model.dart';

@immutable
class StoreNotificationModel {
  final String id;
  final String userId;
  final String itemId;
  final String type;
  final String title;
  final String message;
  final String itemName;
  final String itemCode;
  final String unit;
  final num availableQuantity;
  final num totalQuantity;
  final bool isRead;
  final bool isActive;
  final bool hasPendingRefill;
  final DateTime? readAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StoreNotificationModel({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.type,
    required this.title,
    required this.message,
    required this.itemName,
    required this.itemCode,
    required this.unit,
    required this.availableQuantity,
    required this.totalQuantity,
    required this.isRead,
    required this.isActive,
    this.hasPendingRefill = false,
    this.readAt,
    this.createdAt,
    this.updatedAt,
  });

  StoreNotificationModel copyWith({
    String? id,
    String? userId,
    String? itemId,
    String? type,
    String? title,
    String? message,
    String? itemName,
    String? itemCode,
    String? unit,
    num? availableQuantity,
    num? totalQuantity,
    bool? isRead,
    bool? isActive,
    bool? hasPendingRefill,
    DateTime? readAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StoreNotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      unit: unit ?? this.unit,
      availableQuantity: availableQuantity ?? this.availableQuantity,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      isRead: isRead ?? this.isRead,
      isActive: isActive ?? this.isActive,
      hasPendingRefill: hasPendingRefill ?? this.hasPendingRefill,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory StoreNotificationModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) {
        return v > 1000000000000
            ? DateTime.fromMillisecondsSinceEpoch(v)
            : DateTime.fromMillisecondsSinceEpoch(v * 1000);
      }
      return null;
    }

    return StoreNotificationModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      itemId: (json['itemId'] is Map ? json['itemId']['_id'] : json['itemId'] ?? '').toString(),
      type: (json['type'] ?? 'LOW_STOCK').toString(),
      title: (json['title'] ?? 'Stock running low').toString(),
      message: (json['message'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\s+out\s+of\s+[\d\.]+', caseSensitive: false), ''),
      itemName: (json['itemName'] ?? '').toString(),
      itemCode: (json['itemCode'] ?? '').toString(),
      unit: (json['unit'] ?? '').toString(),
      availableQuantity: (json['availableQuantity'] as num?) ?? 0,
      totalQuantity: (json['totalQuantity'] as num?) ?? 0,
      isRead: json['isRead'] == true,
      isActive: json['isActive'] != false,
      hasPendingRefill: json['hasPendingRefill'] == true,
      readAt: parseDate(json['readAt']),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'itemId': itemId,
      'type': type,
      'title': title,
      'message': message,
      'itemName': itemName,
      'itemCode': itemCode,
      'unit': unit,
      'availableQuantity': availableQuantity,
      'totalQuantity': totalQuantity,
      'isRead': isRead,
      'isActive': isActive,
      'hasPendingRefill': hasPendingRefill,
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Converts this notification into a StoreItemsModel representation
  /// so it can be passed directly to the existing StockRefillRequestCreatePage.
  StoreItemsModel toItemModel() {
    return StoreItemsModel(
      id: itemId,
      itemCode: itemCode,
      itemName: itemName,
      isScrap: false,
      rackId: const [],
      categoryLabel: '',
      unit: unit,
      description: '',
      maxCapacity: 0,
      totalStockQuantity: totalQuantity.toInt(),
      stockAvailableQuantity: availableQuantity.toInt(),
      stockIssueQuantity: 0,
      stockissueCompleted: 0,
      stockscrapQuantity: 0,
      imageUrl: '',
    );
  }
}
