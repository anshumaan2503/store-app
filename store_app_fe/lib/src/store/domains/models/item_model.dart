// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// lib/models/item_model.dart
class ItemModel {
  final String? id;
  final String code;
  final String name;
  final String? sizeId;
  final String? size;
  final String? gradeId;
  final String? grade;
  final int openingStock;
  final String? unit;
  final String? unitName;
  ItemModel({
    this.id,
    required this.code,
    required this.name,
    this.sizeId,
    this.size,
    this.gradeId,
    this.grade,
    required this.openingStock,
    this.unit,
    this.unitName,
  });

  ItemModel copyWith({
    String? id,
    String? code,
    String? name,
    String? sizeId,
    String? size,
    String? gradeId,
    String? grade,
    int? openingStock,
    String? unit,
    String? unitName,
  }) {
    return ItemModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      sizeId: sizeId ?? this.sizeId,
      size: size ?? this.size,
      gradeId: gradeId ?? this.gradeId,
      grade: grade ?? this.grade,
      openingStock: openingStock ?? this.openingStock,
      unit: unit ?? this.unit,
      unitName: unitName ?? this.unitName,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name': name,
      'sizeId': sizeId,
      'size': size,
      'gradeId': gradeId,
      'grade': grade,
      'openingStock': openingStock,
      'unit': unit,
      'unitName': unitName,
    };
  }

  factory ItemModel.fromMap(Map<String, dynamic> map) {
    return ItemModel(
      id: map['_id'] != null ? map['_id'] as String : "",
      code: map['code'] as String,
      name: map['name'] as String,
      sizeId: map['sizeId'] != null ? map['sizeId'] as String : "",
      size: map['size'] != null ? map['size'] as String : "",
      gradeId: map['gradeId'] != null ? map['gradeId'] as String : "",
      grade: map['grade'] != null ? map['grade'] as String : "",
      openingStock: map['openingStock'] as int,
      unit: map['unit'] != null ? map['unit'] as String : "",
      unitName: map['unitName'] != null ? map['unitName'] as String : "",
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemModel.fromJson(String source) =>
      ItemModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'ItemModel(id: $id, code: $code, name: $name, sizeId: $sizeId, size: $size, gradeId: $gradeId, grade: $grade, openingStock: $openingStock, unit: $unit, unitName: $unitName)';
  }

  @override
  bool operator ==(covariant ItemModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.code == code &&
        other.name == name &&
        other.sizeId == sizeId &&
        other.size == size &&
        other.gradeId == gradeId &&
        other.grade == grade &&
        other.openingStock == openingStock &&
        other.unit == unit &&
        other.unitName == unitName;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        code.hashCode ^
        name.hashCode ^
        sizeId.hashCode ^
        size.hashCode ^
        gradeId.hashCode ^
        grade.hashCode ^
        openingStock.hashCode ^
        unit.hashCode ^
        unitName.hashCode;
  }
}
