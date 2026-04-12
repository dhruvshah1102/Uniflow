import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentModel {
  final String enrollmentId;
  final String studentId; // uid of user with role student
  final String courseId; // reference to course document
  final Timestamp enrolledAt;
  final String status; // active, dropped

  EnrollmentModel({
    required this.enrollmentId,
    required this.studentId,
    required this.courseId,
    Timestamp? enrolledAt,
    this.status = 'active',
  }) : enrolledAt = enrolledAt ?? Timestamp.now();

  factory EnrollmentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return EnrollmentModel(
      enrollmentId: documentId,
      studentId: data['studentId'] ?? '',
      courseId: data['courseId'] ?? '',
      enrolledAt: data['enrolledAt'] ?? Timestamp.now(),
      status: data['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'courseId': courseId,
      'enrolledAt': enrolledAt,
      'status': status,
    };
  }
}
