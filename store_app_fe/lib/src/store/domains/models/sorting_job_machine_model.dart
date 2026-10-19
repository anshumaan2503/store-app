// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class MachineModel {
  final String? id;
  final String machineCode;
  final String machineName;
  final String categoryId;
  final String? itemId;
  final String? remark;
  final String? createdBy;
  final bool isActive;
  MachineModel({
    this.id,
    required this.machineCode,
    required this.machineName,
    required this.categoryId,
    this.itemId,
    this.remark,
    this.createdBy,
    required this.isActive,
  });

  MachineModel copyWith({
    String? id,
    String? machineCode,
    String? machineName,
    String? categoryId,
    String? itemId,
    String? remark,
    String? createdBy,
    bool? isActive,
  }) {
    return MachineModel(
      id: id ?? this.id,
      machineCode: machineCode ?? this.machineCode,
      machineName: machineName ?? this.machineName,
      categoryId: categoryId ?? this.categoryId,
      itemId: itemId ?? this.itemId,
      remark: remark ?? this.remark,
      createdBy: createdBy ?? this.createdBy,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'machineCode': machineCode,
      'machineName': machineName,
      'categoryId': categoryId,
      'itemId': itemId,
      'remark': remark,
      'createdBy': createdBy,
      'isActive': isActive,
    };
  }

  factory MachineModel.fromMap(Map<String, dynamic> map) {
    return MachineModel(
      id: map['_id'] != null ? map['_id'] as String : null,
      machineCode: map['machineCode'] as String,
      machineName: map['machineName'] as String,
      categoryId: map['categoryId'] as String,
      itemId: map['itemId'] != null ? map['itemId'] as String : "",
      remark: map['remark'] != null ? map['remark'] as String : "",
      createdBy: map['createdBy'] != null ? map['createdBy'] as String : "",
      isActive: map['isActive'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory MachineModel.fromJson(String source) =>
      MachineModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'MachineModel(id: $id, machineCode: $machineCode, machineName: $machineName, categoryId: $categoryId, itemId: $itemId, remark: $remark, createdBy: $createdBy, isActive: $isActive)';
  }

  @override
  bool operator ==(covariant MachineModel other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.machineCode == machineCode &&
        other.machineName == machineName &&
        other.categoryId == categoryId &&
        other.itemId == itemId &&
        other.remark == remark &&
        other.createdBy == createdBy &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        machineCode.hashCode ^
        machineName.hashCode ^
        categoryId.hashCode ^
        itemId.hashCode ^
        remark.hashCode ^
        createdBy.hashCode ^
        isActive.hashCode;
  }
}
