import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/student_dashboard_data.dart';
import '../../models/quiz_submission_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'assignment_details_screen.dart';
import 'student_module_screen.dart'; // Gives access to QuizAttemptScreen

class CourseDetailScreen extends StatelessWidget {
  final CourseDashboardItem course;
  final StudentDashboardData data;

  const CourseDetailScreen({
    super.key,
    required this.course,
    required this.data,
  });

  Future<void> _openMaterial(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid link.')));
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unable to open material.')));
    }
  }

  QuizSubmissionModel? _submissionForQuiz(String quizId) {
    for (final submission in data.quizSubmissions) {
      if (submission.quizId == quizId) return submission;
    }
    return null;
  }

  void _handleQuizTap(BuildContext context, QuizDashboardItem quiz) {
    final submission = _submissionForQuiz(quiz.quiz.id);
    if (submission != null) {
      _showQuizResult(context, quiz, submission);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => QuizAttemptScreen(quiz: quiz),
      ));
    }
  }

  Future<void> _showQuizResult(BuildContext context, QuizDashboardItem quiz, QuizSubmissionModel submission) async {
    final totalMarks = quiz.quiz.totalMarks;
    final percentage = totalMarks <= 0 ? 0.0 : (submission.score / totalMarks) * 100;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quiz.quiz.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.ink900, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            Text('${quiz.courseCode} | ${quiz.courseTitle}', style: const TextStyle(color: AppColors.ink500, fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surfaceWarm, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Score obtained', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink700)), Text('${submission.score}/$totalMarks', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 18))]),
                   const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider(height: 1, color: AppColors.border)),
                   Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Percentage', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink700)), Text('${percentage.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primaryDark, fontSize: 18))]),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.15), borderRadius: BorderRadius.circular(12)), 
              padding: const EdgeInsets.all(16), 
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success), 
                  SizedBox(width: 12), 
                  Expanded(
                    child: Text('You have successfully submitted this quiz.', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800))
                  )
                ]
              )
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter data specifically for this course
    final materials = data.studyMaterials.where((m) => m.material.courseId == course.course.courseId).toList();
    final assignments = data.pendingTasks.where((task) => task.assignment.courseId == course.course.courseId).toList();
    final quizzes = data.quizzes.where((q) => q.quiz.courseId == course.course.courseId).toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.surfaceWarm,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 200.0,
                floating: false,
                pinned: true,
                backgroundColor: AppColors.primaryDark,
                iconTheme: const IconThemeData(color: Colors.white),
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: false,
                  titlePadding: const EdgeInsets.only(left: 60, bottom: 64, right: 16),
                  title: Text(
                    course.course.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18.0),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryDark, AppColors.primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        right: -30,
                        top: -10,
                        child: Icon(Icons.school_rounded, size: 160, color: Colors.white.withOpacity(0.08)),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 64,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.library_books, color: Colors.white, size: 16),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        bottom: 96,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            course.course.code,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  indicatorColor: Colors.white,
                  indicatorWeight: 3.0,
                  isScrollable: true,
                  tabs: [
                    Tab(text: 'Overview'),
                    Tab(text: 'Materials'),
                    Tab(text: 'Assignments'),
                    Tab(text: 'Quizzes'),
                  ],
                ),
              ),
            ];
          },
          body: Container(
            color: AppColors.surfaceWarm,
            child: TabBarView(
              children: [
                // Tab 1: Overview
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('Faculty Instructor'),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Row(
                        children: [
                          CircleAvatar(backgroundColor: AppColors.primaryLight, child: Text(course.facultyName[0], style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 16),
                          Text(course.facultyName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink900)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Course Description'),
                    Text(course.course.description, style: const TextStyle(fontSize: 15, color: AppColors.ink700, height: 1.5)),
                    const SizedBox(height: 24),
                    _buildSectionTitle('Attendance Summary'),
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primaryDark, AppColors.primary], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${course.attendancePercentage.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white)),
                              const Text('Attendance Rate', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                            child: Column(
                              children: [
                                Text('${course.presentClasses} / ${course.totalClasses}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                                const Text('Classes', style: TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                  ],
                ),

                // Tab 2: Materials
                materials.isEmpty
                    ? const Center(child: Text('No study materials uploaded yet.', style: TextStyle(color: AppColors.ink500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: materials.length,
                        itemBuilder: (context, i) {
                          final m = materials[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _openMaterial(context, m.material.fileUrl),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.primaryDark.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.picture_as_pdf, color: AppColors.primaryDark),
                                ),
                                title: Text(m.material.fileName, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900, fontSize: 15)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Uploaded by ${m.material.uploadedBy}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.ink500, fontSize: 13)),
                                ),
                                trailing: const Icon(Icons.download_rounded, color: AppColors.primaryDark),
                              ),
                            ),
                          );
                        },
                      ),

                // Tab 3: Assignments
                assignments.isEmpty
                    ? const Center(child: Text('No pending assignments.', style: TextStyle(color: AppColors.ink500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: assignments.length,
                        itemBuilder: (context, i) {
                          final t = assignments[i];
                          final due = DateFormat('dd MMM, hh:mm a').format(t.dueDate);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => AssignmentDetailsScreen(
                                    assignment: t.assignment,
                                    courseCode: course.course.code,
                                  ),
                                ));
                              },
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.assignment, color: AppColors.warning),
                                ),
                                title: Text(t.assignment.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900, fontSize: 15)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Due: $due', style: TextStyle(color: t.isOverdue ? AppColors.danger : AppColors.ink700, fontWeight: t.isOverdue ? FontWeight.w700 : FontWeight.w500, fontSize: 13)),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.ink300),
                              ),
                            ),
                          );
                        },
                      ),

                // Tab 4: Quizzes
                quizzes.isEmpty
                    ? const Center(child: Text('No quizzes available.', style: TextStyle(color: AppColors.ink500)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: quizzes.length,
                        itemBuilder: (context, i) {
                          final q = quizzes[i];
                          final due = DateFormat('dd MMM, hh:mm a').format(q.endTime);
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => _handleQuizTap(context, q),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                leading: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                                  child: const Icon(Icons.quiz, color: AppColors.success),
                                ),
                                title: Text(q.quiz.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900, fontSize: 15)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text('Due: $due', style: const TextStyle(color: AppColors.ink700, fontSize: 13, fontWeight: FontWeight.w500)),
                                ),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.ink300),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primaryDark, letterSpacing: 1.2),
      ),
    );
  }
}
