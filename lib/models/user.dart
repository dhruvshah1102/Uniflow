import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role; // student, faculty, admin
  final String department;
  final int? semester;
  final String division;
  final String? profilePicUrl;
  final Timestamp createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.department,
    required this.semester,
    required this.division,
    this.profilePicUrl,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'student',
      department: data['department'] ?? '',
      semester: data['semester'] is int ? data['semester'] : int.tryParse(data['semester']?.toString() ?? ''),
      division: data['division'] ?? data['section'] ?? 'A',
      profilePicUrl: data['profilePicUrl'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'department': department,
      if (semester != null) 'semester': semester,
      'division': division,
      if (profilePicUrl != null) 'profilePicUrl': profilePicUrl,
      'createdAt': createdAt,
    };
  }
}
