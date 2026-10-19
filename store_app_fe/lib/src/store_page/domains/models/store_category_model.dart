// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

class StoreCategory {
  final String id;
  final String code;
  final String name;
  final String remark;
  final List<String>? parentId;
  final bool isbag;
  final bool isMachine;
  final bool isNormalItem;
  StoreCategory({
    required this.id,
    required this.code,
    required this.name,
    required this.remark,
    this.parentId,
    required this.isbag,
    required this.isMachine,
    required this.isNormalItem,
  });

  StoreCategory copyWith({
    String? id,
    String? code,
    String? name,
    String? remark,
    List<String>? parentId,
    bool? isbag,
    bool? isMachine,
    bool? isNormalItem,
  }) {
    return StoreCategory(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      remark: remark ?? this.remark,
      parentId: parentId ?? this.parentId,
      isbag: isbag ?? this.isbag,
      isMachine: isMachine ?? this.isMachine,
      isNormalItem: isNormalItem ?? this.isNormalItem,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name': name,
      'remark': remark,
      'parentId': parentId,
      'isbag': isbag,
      'isMachine': isMachine,
      'isNormalItem': isNormalItem,
    };
  }

  factory StoreCategory.fromMap(Map<String, dynamic> map) {
    return StoreCategory(
      id: map['_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      remark: map['remark'] as String,
      parentId:
          map['parentId'] != null ? List<String>.from((map['parentId'])) : [],
      isbag: map['isbag'] as bool,
      isMachine: map['isMachine'] as bool,
      isNormalItem: map['isNormalItem'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreCategory.fromJson(String source) =>
      StoreCategory.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreCategory(id: $id, code: $code, name: $name, remark: $remark, parentId: $parentId, isbag: $isbag, isMachine: $isMachine, isNormalItem: $isNormalItem)';
  }

  @override
  bool operator ==(covariant StoreCategory other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.code == code &&
        other.name == name &&
        other.remark == remark &&
        listEquals(other.parentId, parentId) &&
        other.isbag == isbag &&
        other.isMachine == isMachine &&
        other.isNormalItem == isNormalItem;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        code.hashCode ^
        name.hashCode ^
        remark.hashCode ^
        parentId.hashCode ^
        isbag.hashCode ^
        isMachine.hashCode ^
        isNormalItem.hashCode;
  }
}
