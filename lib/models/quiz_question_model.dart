class QuizQuestionModel {
  final String id;
  final String quizId;
  final String questionText;
  final String type;
  final List<String>? options;
  final String correctAnswer;
  final int marks;

  QuizQuestionModel({
    required this.id,
    required this.quizId,
    required this.questionText,
    required this.type,
    this.options,
    required this.correctAnswer,
    required this.marks,
  });

  factory QuizQuestionModel.fromMap(Map<String, dynamic> map, String id) {
    return QuizQuestionModel(
      id: id,
      quizId: map['quiz_id'] ?? '',
      questionText: map['question_text'] ?? '',
      type: map['type'] ?? '',
      options: map['options'] != null ? List<String>.from(map['options']) : null,
      correctAnswer: map['correct_answer'] ?? '',
      marks: map['marks']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'quiz_id': quizId,
      'question_text': questionText,
      'type': type,
      'options': options,
      'correct_answer': correctAnswer,
      'marks': marks,
    };
  }
}
