// lib/src/store/domains/models/store_room_model.dart
// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class StoreRoom {
  final String id;
  final String code;
  final String roomName;
  final bool isOneRack;
  final String remark;
  final bool isScrap;

  StoreRoom({
    required this.id,
    required this.code,
    this.roomName = '',
    required this.isOneRack,
    required this.remark,
    required this.isScrap,
  });

  String get displayName =>
      roomName.trim().isNotEmpty ? '$roomName ($code)' : code;

  StoreRoom copyWith({
    String? id,
    String? code,
    String? roomName,
    bool? isOneRack,
    String? remark,
    bool? isScrap,
  }) {
    return StoreRoom(
      id: id ?? this.id,
      code: code ?? this.code,
      roomName: roomName ?? this.roomName,
      isOneRack: isOneRack ?? this.isOneRack,
      remark: remark ?? this.remark,
      isScrap: isScrap ?? this.isScrap,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'roomName': roomName,
      'isOneRack': isOneRack,
      'remark': remark,
      'isScrap': isScrap,
    };
  }

  factory StoreRoom.fromMap(Map<String, dynamic> map) {
    return StoreRoom(
      id: (map['_id'] ?? map['id'] ?? '').toString(),
      code: (map['code'] ?? '').toString(),
      roomName: (map['roomName'] ?? map['name'] ?? '').toString(),
      isOneRack: map['isOneRack'] ?? false,
      remark: (map['remark'] ?? '').toString(),
      isScrap: map['isScrap'] ?? false,
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreRoom.fromJson(String source) =>
      StoreRoom.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreRoom(id: $id, code: $code, roomName: $roomName, isOneRack: $isOneRack, remark: $remark, isScrap: $isScrap)';
  }

  @override
  bool operator ==(covariant StoreRoom other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.code == code &&
        other.roomName == roomName &&
        other.isOneRack == isOneRack &&
        other.remark == remark &&
        other.isScrap == isScrap;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        code.hashCode ^
        roomName.hashCode ^
        isOneRack.hashCode ^
        remark.hashCode ^
        isScrap.hashCode;
  }
}
