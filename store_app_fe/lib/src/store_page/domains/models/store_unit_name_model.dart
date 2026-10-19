// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class StoreUnitName {
  final String id;
  final String code;
  final String name;
  final String remark;
  StoreUnitName({
    required this.id,
    required this.code,
    required this.name,
    required this.remark,
  });

  StoreUnitName copyWith({
    String? id,
    String? code,
    String? name,
    String? remark,
  }) {
    return StoreUnitName(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      remark: remark ?? this.remark,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'code': code,
      'name': name,
      'remark': remark,
    };
  }

  factory StoreUnitName.fromMap(Map<String, dynamic> map) {
    return StoreUnitName(
      id: map['_id'] as String,
      code: map['code'] as String,
      name: map['name'] as String,
      remark: map['remark'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory StoreUnitName.fromJson(String source) =>
      StoreUnitName.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'StoreUnitName(id: $id, code: $code, name: $name, remark: $remark)';
  }

  @override
  bool operator ==(covariant StoreUnitName other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.code == code &&
        other.name == name &&
        other.remark == remark;
  }

  @override
  int get hashCode {
    return id.hashCode ^ code.hashCode ^ name.hashCode ^ remark.hashCode;
  }
}
