// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:store_app/src/common/utils/defensive_parsing.dart';

class StoreScrapModel {
  final String id;
  final String itemId;
  final String itemName;
  final String itemCode;
  final String roomId;
  final String roomCode;
  final String rackId;
  final String rackCode;
  final double itemQuantity;
  final String remark;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;

  StoreScrapModel({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.itemCode,
    required this.roomId,
    required this.roomCode,
    required this.rackId,
    required this.rackCode,
    required this.itemQuantity,
    required this.remark,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  StoreScrapModel copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? itemCode,
    String? roomId,
    String? roomCode,
    String? rackId,
    String? rackCode,
    double? itemQuantity,
    String? remark,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
  }) {
    return StoreScrapModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      itemCode: itemCode ?? this.itemCode,
      roomId: roomId ?? this.roomId,
      roomCode: roomCode ?? this.roomCode,
      rackId: rackId ?? this.rackId,
      rackCode: rackCode ?? this.rackCode,
      itemQuantity: itemQuantity ?? this.itemQuantity,
      remark: remark ?? this.remark,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'itemCode': itemCode,
      'roomId': roomId,
      'roomCode': roomCode,
      'rackId': rackId,
      'rackCode': rackCode,
      'itemQuantity': itemQuantity,
      'remark': remark,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  factory StoreScrapModel.fromMap(Map<String, dynamic> map) {
    return StoreScrapModel(
      id: extractId(map),
      itemId: parseMongoId(map['itemId']),
      itemName: map['itemName']?.toString() ?? '',
      itemCode: map['itemCode']?.toString() ?? '',
      roomId: map['roomId'] != null ? parseMongoId(map['roomId']) : '',
      roomCode: map['roomCode']?.toString() ?? '',
      rackId: parseMongoId(map['rackId']),
      rackCode: map['rackCode']?.toString() ?? '',
      itemQuantity: toDouble(map['itemQuantity']) ?? 0.0,
      remark: map['remark']?.toString() ?? '',
      createdBy: parseMongoId(map['createdBy']),
      createdByName: map['createdByName']?.toString() ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is DateTime
              ? map['createdAt'] as DateTime
              : DateTime.parse(map['createdAt'].toString()))
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreScrapModel.fromJson(String source) =>
      StoreScrapModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreScrapModel(id: $id, itemId: $itemId, itemName: $itemName, itemCode: $itemCode, roomId: $roomId, roomCode: $roomCode, rackId: $rackId, rackCode: $rackCode, itemQuantity: $itemQuantity, remark: $remark, createdBy: $createdBy, createdByName: $createdByName, createdAt: $createdAt)';
  }

  @override
  bool operator ==(covariant StoreScrapModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.itemId == itemId &&
        other.itemName == itemName &&
        other.itemCode == itemCode &&
        other.roomId == roomId &&
        other.roomCode == roomCode &&
        other.rackId == rackId &&
        other.rackCode == rackCode &&
        other.itemQuantity == itemQuantity &&
        other.remark == remark &&
        other.createdBy == createdBy &&
        other.createdByName == createdByName &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        itemId.hashCode ^
        itemName.hashCode ^
        itemCode.hashCode ^
        roomId.hashCode ^
        roomCode.hashCode ^
        rackId.hashCode ^
        rackCode.hashCode ^
        itemQuantity.hashCode ^
        remark.hashCode ^
        createdBy.hashCode ^
        createdByName.hashCode ^
        createdAt.hashCode;
  }
}
