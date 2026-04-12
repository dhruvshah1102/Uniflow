import 'package:cloud_firestore/cloud_firestore.dart';

class PyqModel {
  final String id;
  final String courseId;
  final String uploadedBy;
  final String subject;
  final int year;
  final String fileUrl;
  final Timestamp uploadedAt;

  PyqModel({
    required this.id,
    required this.courseId,
    required this.uploadedBy,
    required this.subject,
    required this.year,
    required this.fileUrl,
    required this.uploadedAt,
  });

  factory PyqModel.fromMap(Map<String, dynamic> map, String id) {
    return PyqModel(
      id: id,
      courseId: map['course_id'] ?? '',
      uploadedBy: map['uploaded_by'] ?? '',
      subject: map['subject'] ?? '',
      year: map['year']?.toInt() ?? 0,
      fileUrl: map['file_url'] ?? '',
      uploadedAt: map['uploaded_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'uploaded_by': uploadedBy,
      'subject': subject,
      'year': year,
      'file_url': fileUrl,
      'uploaded_at': uploadedAt,
    };
  }
}
