import 'package:cloud_firestore/cloud_firestore.dart';

class EnrollmentModel {
  final String id;
  final String studentId;
  final String courseId;
  final int semester;
  final String status;
  final Timestamp enrolledAt;

  EnrollmentModel({
    required this.id,
    required this.studentId,
    required this.courseId,
    required this.semester,
    required this.status,
    required this.enrolledAt,
  });

  factory EnrollmentModel.fromMap(Map<String, dynamic> map, String id) {
    return EnrollmentModel(
      id: id,
      studentId: map['student_id'] ?? '',
      courseId: map['course_id'] ?? '',
      semester: map['semester']?.toInt() ?? 1,
      status: map['status'] ?? 'pending',
      enrolledAt: map['enrolled_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'student_id': studentId,
      'course_id': courseId,
      'semester': semester,
      'status': status,
      'enrolled_at': enrolledAt,
    };
  }
}
