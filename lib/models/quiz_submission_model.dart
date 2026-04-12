import 'package:cloud_firestore/cloud_firestore.dart';

class QuizSubmissionModel {
  final String id;
  final String quizId;
  final String studentId;
  final Map<String, String> answers;
  final int score;
  final Timestamp submittedAt;

  QuizSubmissionModel({
    required this.id,
    required this.quizId,
    required this.studentId,
    required this.answers,
    required this.score,
    required this.submittedAt,
  });

  factory QuizSubmissionModel.fromMap(Map<String, dynamic> map, String id) {
    return QuizSubmissionModel(
      id: id,
      quizId: map['quiz_id'] ?? '',
      studentId: map['student_id'] ?? '',
      answers: map['answers'] != null ? Map<String, String>.from(map['answers']) : {},
      score: map['score']?.toInt() ?? 0,
      submittedAt: map['submitted_at'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quiz_id': quizId,
      'student_id': studentId,
      'answers': answers,
      'score': score,
      'submitted_at': submittedAt,
    };
  }
}
