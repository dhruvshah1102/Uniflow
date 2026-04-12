import 'package:cloud_firestore/cloud_firestore.dart';

class AssignmentModel {
  final String id;
  final String courseId;
  final String facultyId;
  final String title;
  final String description;
  final Timestamp deadline;
  final int totalMarks;
  final String? classroomAssignmentId;

  AssignmentModel({
    required this.id,
    required this.courseId,
    required this.facultyId,
    required this.title,
    required this.description,
    required this.deadline,
    required this.totalMarks,
    this.classroomAssignmentId,
  });

  factory AssignmentModel.fromMap(Map<String, dynamic> map, String id) {
    return AssignmentModel(
      id: id,
      courseId: map['course_id'] ?? '',
      facultyId: map['faculty_id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      deadline: map['deadline'] ?? Timestamp.now(),
      totalMarks: map['total_marks']?.toInt() ?? 0,
      classroomAssignmentId: map['classroom_assignment_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'faculty_id': facultyId,
      'title': title,
      'description': description,
      'deadline': deadline,
      'total_marks': totalMarks,
      'classroom_assignment_id': classroomAssignmentId,
    };
  }
}
