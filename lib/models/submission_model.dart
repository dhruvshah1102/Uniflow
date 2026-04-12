import 'package:cloud_firestore/cloud_firestore.dart';

class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final String fileUrl;
  final int? marksObtained;
  final Timestamp submittedAt;
  final String? classroomSubmissionId;

  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.fileUrl,
    this.marksObtained,
    required this.submittedAt,
    this.classroomSubmissionId,
  });

  factory SubmissionModel.fromMap(Map<String, dynamic> map, String id) {
    return SubmissionModel(
      id: id,
      assignmentId: map['assignment_id'] ?? '',
      studentId: map['student_id'] ?? '',
      fileUrl: map['file_url'] ?? '',
      marksObtained: map['marks_obtained']?.toInt(),
      submittedAt: map['submitted_at'] ?? Timestamp.now(),
      classroomSubmissionId: map['classroom_submission_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'assignment_id': assignmentId,
      'student_id': studentId,
      'file_url': fileUrl,
      'marks_obtained': marksObtained,
      'submitted_at': submittedAt,
      'classroom_submission_id': classroomSubmissionId,
    };
  }
}
