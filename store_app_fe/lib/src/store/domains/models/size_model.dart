// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// lib/models/size_model.dart
class SizeModel {
  final String? id;
  final String code;
  final String name;
  SizeModel({this.id, required this.code, required this.name});

  SizeModel copyWith({String? id, String? code, String? name}) {
    return SizeModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{'id': id, 'code': code, 'name': name};
  }

  factory SizeModel.fromMap(Map<String, dynamic> map) {
    return SizeModel(
      id: map['_id'] != null ? map['_id'] as String : null,
      code: map['code'] as String,
      name: map['name'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory SizeModel.fromJson(String source) =>
      SizeModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'SizeModel(id: $id, code: $code, name: $name)';

  @override
  bool operator ==(covariant SizeModel other) {
    if (identical(this, other)) return true;

    return other.id == id && other.code == code && other.name == name;
  }

  @override
  int get hashCode => id.hashCode ^ code.hashCode ^ name.hashCode;
}
