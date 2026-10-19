import 'package:flutter/foundation.dart';

@immutable
class IndentDraftItemModel {
  final String itemId;
  final String itemName;
  final String itemCode;
  final String unit;
  final String imageUrl;
  final int quantity;
  final String reason;
  final DateTime addedAt;
  final int realTimeAvailableQty;
  final int realTimeTotalQty;
  final int minStockQuantity;
  final bool isRestocked;

  const IndentDraftItemModel({
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.unit,
    this.imageUrl = '',
    required this.quantity,
    this.reason = '',
    required this.addedAt,
    this.realTimeAvailableQty = 0,
    this.realTimeTotalQty = 0,
    this.minStockQuantity = 0,
    this.isRestocked = false,
  });

  factory IndentDraftItemModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedAddedAt = DateTime.now();
    final rawAdded = map['addedAt'];
    if (rawAdded != null) {
      if (rawAdded is int) {
        parsedAddedAt = DateTime.fromMillisecondsSinceEpoch(rawAdded);
      } else if (rawAdded is String) {
        parsedAddedAt = DateTime.tryParse(rawAdded) ?? DateTime.now();
      }
    }

    final avail = int.tryParse(map['realTimeAvailableQty']?.toString() ?? '0') ?? 0;
    final qty = int.tryParse(map['quantity']?.toString() ?? '1') ?? 1;

    return IndentDraftItemModel(
      itemId: (map['itemId'] ?? map['id'] ?? map['_id'] ?? '').toString(),
      itemName: (map['itemName'] ?? '').toString(),
      itemCode: (map['itemCode'] ?? '').toString(),
      unit: (map['unit'] ?? 'PCS').toString(),
      imageUrl: (map['imageUrl'] ?? '').toString(),
      quantity: qty,
      reason: (map['reason'] ?? '').toString(),
      addedAt: parsedAddedAt,
      realTimeAvailableQty: avail,
      realTimeTotalQty: int.tryParse(map['realTimeTotalQty']?.toString() ?? '0') ?? 0,
      minStockQuantity: int.tryParse(map['minStockQuantity']?.toString() ?? '0') ?? 0,
      isRestocked: map['isRestocked'] == true || (avail >= qty && avail > 0),
    );
  }

  IndentDraftItemModel copyWith({
    String? itemId,
    String? itemName,
    String? itemCode,
    String? unit,
    String? imageUrl,
    int? quantity,
    String? reason,
    DateTime? addedAt,
    int? realTimeAvailableQty,
    int? realTimeTotalQty,
    int? minStockQuantity,
    bool? isRestocked,
  }) {
    return IndentDraftItemModel(
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      unit: unit ?? this.unit,
      imageUrl: imageUrl ?? this.imageUrl,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      addedAt: addedAt ?? this.addedAt,
      realTimeAvailableQty: realTimeAvailableQty ?? this.realTimeAvailableQty,
      realTimeTotalQty: realTimeTotalQty ?? this.realTimeTotalQty,
      minStockQuantity: minStockQuantity ?? this.minStockQuantity,
      isRestocked: isRestocked ?? this.isRestocked,
    );
  }
}
