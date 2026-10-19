// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

// lib/src/store/domains/models/store_rack_model.dart
class StoreRack {
  final String id;
  final String roomId;
  final String roomName;
  final List<String> itemId;
  final String code;
  final String rackName;
  final bool isScrap;
  final String remark;

  StoreRack({
    required this.id,
    required this.roomId,
    required this.roomName,
    required this.itemId,
    required this.code,
    this.rackName = '',
    required this.isScrap,
    required this.remark,
  });

  String get displayName =>
      rackName.trim().isNotEmpty ? '$rackName ($code)' : code;

  StoreRack copyWith({
    String? id,
    String? roomId,
    String? roomName,
    List<String>? itemId,
    String? code,
    String? rackName,
    bool? isScrap,
    String? remark,
  }) {
    return StoreRack(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      itemId: itemId ?? this.itemId,
      code: code ?? this.code,
      rackName: rackName ?? this.rackName,
      isScrap: isScrap ?? this.isScrap,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'roomId': roomId,
      'roomName': roomName,
      'itemId': itemId,
      'code': code,
      'rackName': rackName,
      'isScrap': isScrap,
      'remark': remark,
    };
  }

  factory StoreRack.fromMap(Map<String, dynamic> map) {
    final rawItemId = map['itemId'];
    List<String> items = [];
    if (rawItemId is List) {
      items = rawItemId.map((e) => e.toString()).toList();
    } else if (rawItemId is String && rawItemId.isNotEmpty) {
      items = [rawItemId];
    }

    return StoreRack(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      roomId: (map['roomId'] ?? '').toString(),
      roomName: (map['roomName'] ?? '').toString(),
      itemId: items,
      code: (map['code'] ?? '').toString(),
      rackName: (map['rackName'] ?? map['name'] ?? '').toString(),
      isScrap: map['isScrap'] == true,
      remark: (map['remark'] ?? '').toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreRack.fromJson(String source) =>
      StoreRack.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreRack(id: $id, roomId: $roomId, roomName: $roomName, itemId: $itemId, code: $code, rackName: $rackName, isScrap: $isScrap, remark: $remark)';
  }

  @override
  bool operator ==(covariant StoreRack other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.roomId == roomId &&
        other.roomName == roomName &&
        listEquals(other.itemId, itemId) &&
        other.code == code &&
        other.rackName == rackName &&
        other.isScrap == isScrap &&
        other.remark == remark;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        roomId.hashCode ^
        roomName.hashCode ^
        itemId.hashCode ^
        code.hashCode ^
        rackName.hashCode ^
        isScrap.hashCode ^
        remark.hashCode;
  }
}
