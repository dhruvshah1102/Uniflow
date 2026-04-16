import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student_dashboard_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/student_dashboard_service.dart';
import '../../widgets/common/loading_skeleton_page.dart';
import 'course_detail_screen.dart';

class StudentCourseRouteScreen extends StatelessWidget {
  final String courseId;
  final String initialTab;
  final String? assignmentId;
  final String? quizId;

  const StudentCourseRouteScreen({
    super.key,
    required this.courseId,
    required this.initialTab,
    this.assignmentId,
    this.quizId,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) {
      return const Scaffold(body: LoadingSkeletonPage(cardCount: 3));
    }

    final service = StudentDashboardService.instance;
    return StreamBuilder<StudentDashboardData>(
      stream: service.watchDashboard(
        firebaseUid: firebaseUser.uid,
        user: auth.currentUser!,
        studentProfile: auth.studentProfile,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: LoadingSkeletonPage(cardCount: 4));
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString(),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        final data = snapshot.data;
        if (data == null) {
          return const Scaffold(body: Center(child: Text('No student data found.')));
        }

        final allCourses = <dynamic>[...data.currentCourses, ...data.upcomingCourses];
        CourseDashboardItem? course;
        for (final item in allCourses) {
          if (item.course.courseId == courseId) {
            course = item;
            break;
          }
        }

        if (course == null) {
          return const Scaffold(
            body: Center(
              child: Text('The requested course could not be found.'),
            ),
          );
        }

        return CourseDetailScreen(
          course: course,
          data: data,
          initialTab: initialTab,
          highlightAssignmentId: assignmentId,
          highlightQuizId: quizId,
        );
      },
    );
  }
}
