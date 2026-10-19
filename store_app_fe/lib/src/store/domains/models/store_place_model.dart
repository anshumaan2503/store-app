// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

class StorePlace {
  final String id;
  final String name;
  final String code;
  final String type;
  final List<String> stockItemId;
  final String remark;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  StorePlace({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    required this.stockItemId,
    required this.remark,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  StorePlace copyWith({
    String? id,
    String? name,
    String? code,
    String? type,
    List<String>? stockItemId,
    String? remark,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StorePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      type: type ?? this.type,
      stockItemId: stockItemId ?? this.stockItemId,
      remark: remark ?? this.remark,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'code': code,
      'type': type,
      'stockItemId': stockItemId,
      'remark': remark,
      'createdBy': createdBy,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory StorePlace.fromMap(Map<String, dynamic> map) {
    return StorePlace(
      id: map['_id'] as String,
      name: map['name'] as String,
      code: map['code'] as String,
      type: map['type'] as String,
      stockItemId:
          map['stockItemId'] != null
              ? List<String>.from((map['stockItemId'] as List<dynamic>))
              : [],
      remark: map['remark'] as String,
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt']) ?? DateTime.now(),
      updatedAt: DateTime.parse(map['updatedAt']) ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StorePlace.fromJson(String source) =>
      StorePlace.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StorePlace(id: $id, name: $name, code: $code, type: $type, stockItemId: $stockItemId, remark: $remark, createdBy: $createdBy, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant StorePlace other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.name == name &&
        other.code == code &&
        other.type == type &&
        listEquals(other.stockItemId, stockItemId) &&
        other.remark == remark &&
        other.createdBy == createdBy &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        code.hashCode ^
        type.hashCode ^
        stockItemId.hashCode ^
        remark.hashCode ^
        createdBy.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
