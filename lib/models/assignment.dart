import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentModel {
  final String assignmentId;
  final String courseId;
  final String title;
  final String description;
  final Timestamp dueDate;
  final String createdBy; // faculty UID
  final String status;
  final int totalMarks;
  final Timestamp createdAt;

  AssignmentModel({
    required this.assignmentId,
    required this.courseId,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.createdBy,
    this.status = 'pending',
    this.totalMarks = 100,
    Timestamp? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now();

  factory AssignmentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return AssignmentModel(
      assignmentId: documentId,
      courseId: data['courseId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      dueDate: data['dueDate'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
      status: data['status'] ?? 'pending',
      totalMarks: data['total_marks'] ?? data['totalMarks'] ?? 100,
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'courseId': courseId,
      'title': title,
      'description': description,
      'dueDate': dueDate,
      'createdBy': createdBy,
      'status': status,
      'total_marks': totalMarks,
      'createdAt': createdAt,
    };
  }
}
