// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

@immutable
class AuthModel {
  final String uid;
  final String email;
  final String phoneNumber;
  final String name;
  final String fcmToken;
  final String imageUrl;
  final bool isActive;
  final bool isSuperAdmin;
  final List<String> devices;
  final List<String> deviceHistory;
  final List<String> apps;
  final List<String> appWorks;
  final List<String> divisionIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  const AuthModel({
    required this.uid,
    required this.email,
    required this.phoneNumber,
    required this.name,
    required this.fcmToken,
    required this.imageUrl,
    required this.isActive,
    required this.isSuperAdmin,
    required this.devices,
    required this.deviceHistory,
    required this.apps,
    required this.appWorks,
    required this.divisionIds,
    required this.createdAt,
    required this.updatedAt,
  });

  AuthModel copyWith({
    String? uid,
    String? email,
    String? phoneNumber,
    String? name,
    String? fcmToken,
    String? imageUrl,
    bool? isActive,
    bool? isSuperAdmin,
    List<String>? devices,
    List<String>? deviceHistory,
    List<String>? apps,
    List<String>? appWorks,
    List<String>? divisionIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AuthModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      fcmToken: fcmToken ?? this.fcmToken,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      devices: devices ?? this.devices,
      deviceHistory: deviceHistory ?? this.deviceHistory,
      apps: apps ?? this.apps,
      appWorks: appWorks ?? this.appWorks,
      divisionIds: divisionIds ?? this.divisionIds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'uid': uid,
      'email': email,
      'phoneNumber': phoneNumber,
      'name': name,
      'fcmToken': fcmToken,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'isSuperAdmin': isSuperAdmin,
      'devices': devices,
      'deviceHistory': deviceHistory,
      'apps': apps,
      'appWorks': appWorks,
      'divisionIds': divisionIds,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
    };
  }

  factory AuthModel.fromMap(dynamic rawData) {
    final Map<String, dynamic> map = rawData is Map<String, dynamic>
        ? rawData
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : {});

    return AuthModel(
      uid: (map['_id'] ?? map['id'] ?? "").toString(),
      email: (map['email'] ?? "").toString(),
      phoneNumber: (map['phoneNumber'] ?? "").toString(),
      name: (map['name'] ?? "").toString(),
      imageUrl: (map['imageUrl'] ?? "").toString(),
      fcmToken: (map['fcmToken'] ?? "").toString(),
      isActive: map['isActive'] == true,
      isSuperAdmin: map['isSuperAdmin'] == true,
      devices: (map['devices'] as List?)?.map((e) => e.toString()).toList() ?? [],
      deviceHistory:
          (map['deviceHistory'] as List?)?.map((e) => e.toString()).toList() ?? [],
      apps: (map['apps'] as List?)?.map((e) => e.toString()).toList() ?? [],
      appWorks:
          (map['appWorks'] as List?)?.map((e) => e.toString()).toList() ?? [],
      divisionIds:
          (map['divisionIds'] as List?)?.map((e) => e.toString()).toList() ?? [],
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int)
              : DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int)
              : DateTime.tryParse(map['updatedAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory AuthModel.fromJson(String source) =>
      AuthModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'AuthModel(uid: $uid, email: $email, phoneNumber: $phoneNumber, name: $name, fcmToken: $fcmToken, imageUrl: $imageUrl, isActive: $isActive, isSuperAdmin: $isSuperAdmin, devices: $devices, deviceHistory: $deviceHistory, apps: $apps, appWorks: $appWorks, divisionIds: $divisionIds, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(covariant AuthModel other) {
    if (identical(this, other)) return true;

    return other.uid == uid &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.name == name &&
        other.fcmToken == fcmToken &&
        other.imageUrl == imageUrl &&
        other.isActive == isActive &&
        other.isSuperAdmin == isSuperAdmin &&
        listEquals(other.devices, devices) &&
        listEquals(other.deviceHistory, deviceHistory) &&
        listEquals(other.apps, apps) &&
        listEquals(other.appWorks, appWorks) &&
        listEquals(other.divisionIds, divisionIds) &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return uid.hashCode ^
        email.hashCode ^
        phoneNumber.hashCode ^
        name.hashCode ^
        fcmToken.hashCode ^
        imageUrl.hashCode ^
        isActive.hashCode ^
        isSuperAdmin.hashCode ^
        devices.hashCode ^
        deviceHistory.hashCode ^
        apps.hashCode ^
        appWorks.hashCode ^
        divisionIds.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
