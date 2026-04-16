import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../models/quiz_question_model.dart';
import '../../models/quiz_submission_model.dart';
import '../../models/student_dashboard_data.dart';
import '../../services/student_dashboard_service.dart';

Future<void> showQuizResultSheet({
  required BuildContext context,
  required QuizDashboardItem quiz,
  required QuizSubmissionModel submission,
}) async {
  List<QuizQuestionModel> questions = const <QuizQuestionModel>[];
  try {
    questions = await StudentDashboardService.instance.fetchQuizQuestions(
      quiz.quiz.id,
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final totalMarks = quiz.quiz.totalMarks;
      final percentage = totalMarks <= 0
          ? 0.0
          : (submission.score / totalMarks) * 100;
      final attemptedCount = questions.where((question) {
        final answer = submission.answers[question.id]?.trim() ?? '';
        return answer.isNotEmpty;
      }).length;
      final correctCount = questions.where((question) {
        final answer =
            submission.answers[question.id]?.trim().toLowerCase() ?? '';
        final correct = question.correctAnswer.trim().toLowerCase();
        return answer.isNotEmpty && answer == correct;
      }).length;
      final unattemptedCount = questions.length - attemptedCount;
      final wrongCount =
          (questions.length - attemptedCount) + (attemptedCount - correctCount);

      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.86,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.quiz.title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${quiz.courseCode} | ${quiz.courseTitle}',
                  style: const TextStyle(
                    color: AppColors.ink500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                _SummaryGrid(
                  scoreText: '${submission.score}/$totalMarks',
                  percentageText: '${percentage.toStringAsFixed(1)}%',
                  correctText: '$correctCount',
                  wrongText: '$wrongCount',
                  unattemptedText: '$unattemptedCount',
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: questions.isEmpty
                      ? const Center(
                          child: Text(
                            'No question details were found for this quiz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.ink500),
                          ),
                        )
                      : ListView.separated(
                          itemCount: questions.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final question = questions[index];
                            final userAnswer =
                                submission.answers[question.id]?.trim() ?? '';
                            final correctAnswer = question.correctAnswer.trim();
                            final isAttempted = userAnswer.isNotEmpty;
                            final isCorrect =
                                isAttempted &&
                                userAnswer.toLowerCase() ==
                                    correctAnswer.toLowerCase();
                            final statusLabel = !isAttempted
                                ? 'Not attempted'
                                : isCorrect
                                ? 'Correct'
                                : 'Wrong';
                            final statusColor = !isAttempted
                                ? AppColors.ink500
                                : isCorrect
                                ? AppColors.success
                                : AppColors.danger;

                            return _QuestionReviewCard(
                              questionNumber: index + 1,
                              questionText: question.questionText,
                              userAnswer: isAttempted
                                  ? userAnswer
                                  : 'No answer selected',
                              correctAnswer: correctAnswer,
                              marks: question.marks,
                              statusLabel: statusLabel,
                              statusColor: statusColor,
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    child: const Text('Close Review'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  DateFormat(
                    'dd MMM, hh:mm a',
                  ).format(submission.submittedAt.toDate()),
                  style: const TextStyle(color: AppColors.ink300, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SummaryGrid extends StatelessWidget {
  final String scoreText;
  final String percentageText;
  final String correctText;
  final String wrongText;
  final String unattemptedText;

  const _SummaryGrid({
    required this.scoreText,
    required this.percentageText,
    required this.correctText,
    required this.wrongText,
    required this.unattemptedText,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _SummaryChip(
          label: 'Score',
          value: scoreText,
          color: AppColors.primaryDark,
        ),
        _SummaryChip(
          label: 'Percentage',
          value: percentageText,
          color: AppColors.success,
        ),
        _SummaryChip(
          label: 'Correct',
          value: correctText,
          color: AppColors.success,
        ),
        _SummaryChip(label: 'Wrong', value: wrongText, color: AppColors.danger),
        _SummaryChip(
          label: 'Unattempted',
          value: unattemptedText,
          color: AppColors.ink500,
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.of(context).size.width - 60) / 2,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionReviewCard extends StatelessWidget {
  final int questionNumber;
  final String questionText;
  final String userAnswer;
  final String correctAnswer;
  final int marks;
  final String statusLabel;
  final Color statusColor;

  const _QuestionReviewCard({
    required this.questionNumber,
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
    required this.marks,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Q$questionNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    fontSize: 16,
                  ),
                ),
              ),
              _StatusPill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            questionText,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
              color: AppColors.ink900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _DetailRow(
            label: 'Your answer',
            value: userAnswer,
            color: statusColor,
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Correct answer',
            value: correctAnswer,
            color: AppColors.success,
          ),
          const SizedBox(height: 8),
          _DetailRow(label: 'Marks', value: '$marks', color: AppColors.ink500),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _DetailRow({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 118,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.ink500,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
