import 'package:cloud_firestore/cloud_firestore.dart';

class SemesterRegistrationForm {
  final String id;
  final int semester;
  final String department;
  final List<String> availableCourseIds;
  final List<String> backlogCourseIds;
  final bool active;
  final Timestamp createdAt;
  final String? createdBy;

  const SemesterRegistrationForm({
    required this.id,
    required this.semester,
    required this.department,
    required this.availableCourseIds,
    required this.backlogCourseIds,
    required this.active,
    required this.createdAt,
    this.createdBy,
  });

  factory SemesterRegistrationForm.fromMap(Map<String, dynamic> data, String id) {
    return SemesterRegistrationForm(
      id: id,
      semester: _semester(data['semester']) ?? 0,
      department: _string(data['department']) ?? '',
      availableCourseIds: _stringList(data['availableCourses'] ?? data['availableCourseIds']),
      backlogCourseIds: _stringList(data['backlogCourses'] ?? data['backlogCourseIds']),
      active: data['active'] == true,
      createdAt: _timestamp(data['createdAt']) ?? Timestamp.now(),
      createdBy: _string(data['createdBy']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'semester': semester,
      'department': department,
      'availableCourses': availableCourseIds,
      'backlogCourses': backlogCourseIds,
      'active': active,
      'createdAt': createdAt,
      if (createdBy != null) 'createdBy': createdBy,
    };
  }
}

String? _string(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  return value.toString().trim();
}

int? _semester(dynamic value) {
  if (value == null) return null;
  if (value is int) return value >= 1 && value <= 12 ? value : null;
  if (value is num) {
    final parsed = value.toInt();
    return parsed >= 1 && parsed <= 12 ? parsed : null;
  }
  final text = value.toString().trim();
  final exact = int.tryParse(text);
  if (exact != null && exact >= 1 && exact <= 12) return exact;
  final parsed = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), ''));
  if (parsed != null && parsed >= 1 && parsed <= 12) return parsed;
  return null;
}

Timestamp? _timestamp(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value;
  if (value is DateTime) return Timestamp.fromDate(value);
  return null;
}

List<String> _stringList(dynamic value) {
  if (value is List) {
    return value
        .whereType<dynamic>()
        .map((item) => item.toString())
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}
