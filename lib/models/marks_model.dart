import 'package:cloud_firestore/cloud_firestore.dart';

class MarksModel {
  final String id;
  final String courseId;
  final String studentId;
  final int internalMarks;
  final int externalMarks;
  final int total;
  final String examType;
  final Timestamp uploadedAt;

  MarksModel({
    required this.id,
    required this.courseId,
    required this.studentId,
    required this.internalMarks,
    required this.externalMarks,
    required this.total,
    required this.examType,
    required this.uploadedAt,
  });

  factory MarksModel.fromMap(Map<String, dynamic> map, String id) {
    return MarksModel(
      id: id,
      courseId: map['course_id'] ?? '',
      studentId: map['student_id'] ?? '',
      internalMarks: map['internal_marks']?.toInt() ?? 0,
      externalMarks: map['external_marks']?.toInt() ?? 0,
      total: map['total']?.toInt() ?? 0,
      examType: map['exam_type'] ?? '',
      uploadedAt: map['uploaded_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'student_id': studentId,
      'internal_marks': internalMarks,
      'external_marks': externalMarks,
      'total': total,
      'exam_type': examType,
      'uploaded_at': uploadedAt,
    };
  }
}
