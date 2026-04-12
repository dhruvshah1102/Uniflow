import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationCourseOption {
  final String id;
  final String courseName;
  final String courseCode;
  final int credits;
  final int semester;
  final String department;

  const RegistrationCourseOption({
    required this.id,
    required this.courseName,
    required this.courseCode,
    required this.credits,
    required this.semester,
    required this.department,
  });

  factory RegistrationCourseOption.fromMap(Map<String, dynamic> data, String id) {
    return RegistrationCourseOption(
      id: id,
      courseName: _string(data['courseName']) ?? _string(data['title']) ?? 'Untitled Course',
      courseCode: _string(data['code']) ?? _string(data['courseCode']) ?? id.toUpperCase(),
      credits: _int(data['credits']) ?? 0,
      semester: _semester(data['semester']) ?? 0,
      department: _string(data['department']) ?? '',
    );
  }

  String get label => '$courseCode - $courseName';
}

class SemesterRegistrationRecord {
  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final int currentSemester;
  final int targetSemester;
  final int creditLimit;
  final int totalCredits;
  final List<String> selectedCourseIds;
  final List<String> selectedCourseNames;
  final List<String> backlogCourseIds;
  final List<String> backlogCourseNames;
  final String status;
  final String? rejectionReason;
  final Timestamp createdAt;
  final Timestamp? reviewedAt;
  final String? reviewedBy;

  const SemesterRegistrationRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.currentSemester,
    required this.targetSemester,
    required this.creditLimit,
    required this.totalCredits,
    required this.selectedCourseIds,
    required this.selectedCourseNames,
    required this.backlogCourseIds,
    required this.backlogCourseNames,
    required this.status,
    required this.createdAt,
    this.rejectionReason,
    this.reviewedAt,
    this.reviewedBy,
  });

  factory SemesterRegistrationRecord.fromMap(Map<String, dynamic> data, String id) {
    return SemesterRegistrationRecord(
      id: id,
      studentId: _string(data['studentId']) ?? '',
      studentName: _string(data['studentName']) ?? '',
      studentEmail: _string(data['studentEmail']) ?? '',
      currentSemester: _int(data['currentSemester']) ?? 0,
      targetSemester: _int(data['targetSemester']) ?? 0,
      creditLimit: _int(data['creditLimit']) ?? 24,
      totalCredits: _int(data['totalCredits']) ?? 0,
      selectedCourseIds: _stringList(data['selectedCourses']),
      selectedCourseNames: _stringList(data['selectedCourseNames']),
      backlogCourseIds: _stringList(data['backlogCourses']),
      backlogCourseNames: _stringList(data['backlogCourseNames']),
      status: (_string(data['status']) ?? 'pending').toLowerCase(),
      rejectionReason: _string(data['rejectionReason']),
      createdAt: _timestamp(data['createdAt']) ?? Timestamp.now(),
      reviewedAt: _timestamp(data['reviewedAt']),
      reviewedBy: _string(data['reviewedBy']),
    );
  }
}

class SemesterRegistrationContext {
  final String studentId;
  final String studentName;
  final String studentEmail;
  final int currentSemester;
  final int targetSemester;
  final int creditLimit;
  final List<RegistrationCourseOption> availableCourses;
  final List<RegistrationCourseOption> backlogCourses;
  final List<String> enrolledCourseIds;
  final List<String> upcomingCourseIds;
  final SemesterRegistrationRecord? activeRegistration;

  const SemesterRegistrationContext({
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.currentSemester,
    required this.targetSemester,
    required this.creditLimit,
    required this.availableCourses,
    required this.backlogCourses,
    required this.enrolledCourseIds,
    required this.upcomingCourseIds,
    required this.activeRegistration,
  });
}

String? _string(dynamic value) {
  if (value == null) return null;
  if (value is String) return value.trim();
  return value.toString().trim();
}

int? _int(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
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
    return value.whereType<dynamic>().map((item) => item.toString()).map((item) => item.trim()).where((item) => item.isNotEmpty).toList();
  }
  return const [];
}
