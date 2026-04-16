import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String department;
  final int? semester;
  final String division;
  final String uidFirebase;
  final String fcmToken;
  final Timestamp createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.semester,
    required this.division,
    required this.uidFirebase,
    required this.fcmToken,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? '',
      department: map['department'] ?? '',
      semester: map['semester'] is int ? map['semester'] : int.tryParse(map['semester']?.toString() ?? ''),
      division: map['division'] ?? map['section'] ?? 'A',
      uidFirebase: map['uid_firebase'] ?? '',
      fcmToken: map['fcm_token'] ?? '',
      createdAt: _timestamp(map['created_at']) ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      if (semester != null) 'semester': semester,
      'division': division,
      'uid_firebase': uidFirebase,
      'fcm_token': fcmToken,
      'created_at': createdAt,
    };
  }
}

Timestamp? _timestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  return parsed == null ? null : Timestamp.fromDate(parsed);
}
