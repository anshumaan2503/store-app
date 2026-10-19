// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class PlaceItem {
  final String id;
  final String itemId;
  final String itemName;
  final String placeId;
  final String placeName;
  final int totalQuantity;
  final int issuedQuantity;
  PlaceItem({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.placeId,
    required this.placeName,
    required this.totalQuantity,
    required this.issuedQuantity,
  });

  PlaceItem copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? placeId,
    String? placeName,
    int? totalQuantity,
    int? issuedQuantity,
  }) {
    return PlaceItem(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      placeId: placeId ?? this.placeId,
      placeName: placeName ?? this.placeName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      issuedQuantity: issuedQuantity ?? this.issuedQuantity,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'placeId': placeId,
      'placeName': placeName,
      'totalQuantity': totalQuantity,
      'issuedQuantity': issuedQuantity,
    };
  }

  factory PlaceItem.fromMap(Map<String, dynamic> map) {
    return PlaceItem(
      id: map['_id'] as String,
      itemId: map['itemId'] as String,
      itemName: map['itemName'] as String,
      placeId: map['placeId'] as String,
      placeName: map['placeName'] as String,
      totalQuantity: map['totalQuantity'] as int,
      issuedQuantity: map['issuedQuantity'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaceItem.fromJson(String source) => PlaceItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'PlaceItem(id: $id, itemId: $itemId, itemName: $itemName, placeId: $placeId, placeName: $placeName, totalQuantity: $totalQuantity, issuedQuantity: $issuedQuantity)';
  }

  @override
  bool operator ==(covariant PlaceItem other) {
    if (identical(this, other)) return true;
  
    return 
      other.id == id &&
      other.itemId == itemId &&
      other.itemName == itemName &&
      other.placeId == placeId &&
      other.placeName == placeName &&
      other.totalQuantity == totalQuantity &&
      other.issuedQuantity == issuedQuantity;
  }

  @override
  int get hashCode {
    return id.hashCode ^
      itemId.hashCode ^
      itemName.hashCode ^
      placeId.hashCode ^
      placeName.hashCode ^
      totalQuantity.hashCode ^
      issuedQuantity.hashCode;
  }
}
