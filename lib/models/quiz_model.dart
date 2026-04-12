import 'package:cloud_firestore/cloud_firestore.dart';

class QuizModel {
  final String id;
  final String courseId;
  final String facultyId;
  final String title;
  final Timestamp startTime;
  final Timestamp endTime;
  final int totalMarks;
  final String? classroomQuizId;

  QuizModel({
    required this.id,
    required this.courseId,
    required this.facultyId,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.totalMarks,
    this.classroomQuizId,
  });

  factory QuizModel.fromMap(Map<String, dynamic> map, String id) {
    return QuizModel(
      id: id,
      courseId: map['course_id'] ?? '',
      facultyId: map['faculty_id'] ?? '',
      title: map['title'] ?? '',
      startTime: map['start_time'] ?? Timestamp.now(),
      endTime: map['end_time'] ?? Timestamp.now(),
      totalMarks: map['total_marks']?.toInt() ?? 0,
      classroomQuizId: map['classroom_quiz_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'course_id': courseId,
      'faculty_id': facultyId,
      'title': title,
      'start_time': startTime,
      'end_time': endTime,
      'total_marks': totalMarks,
      'classroom_quiz_id': classroomQuizId,
    };
  }
}
