import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/student_dashboard_data.dart';
import '../../providers/auth_provider.dart';
import '../../services/student_dashboard_service.dart';
import '../../widgets/common/loading_skeleton_page.dart';
import 'course_detail_screen.dart';

class StudentCourseRouteScreen extends StatefulWidget {
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
  State<StudentCourseRouteScreen> createState() =>
      _StudentCourseRouteScreenState();
}

class _StudentCourseRouteScreenState extends State<StudentCourseRouteScreen> {
  final StudentDashboardService _service = StudentDashboardService.instance;
  Stream<StudentDashboardData>? _stream;
  String? _boundFirebaseUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) {
      return;
    }

    if (_stream != null && _boundFirebaseUid == firebaseUser.uid) {
      return;
    }

    _boundFirebaseUid = firebaseUser.uid;
    _stream = _service.watchDashboard(
      firebaseUid: firebaseUser.uid,
      user: auth.currentUser!,
      studentProfile: auth.studentProfile,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) {
      return const Scaffold(body: LoadingSkeletonPage(cardCount: 3));
    }

    _ensureLoaded();
    final stream = _stream;
    if (stream == null) {
      return const Scaffold(body: LoadingSkeletonPage(cardCount: 4));
    }

    return StreamBuilder<StudentDashboardData>(
      stream: stream,
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
          return const Scaffold(
            body: Center(child: Text('No student data found.')),
          );
        }

        final allCourses = <dynamic>[
          ...data.currentCourses,
          ...data.upcomingCourses,
        ];
        CourseDashboardItem? course;
        for (final item in allCourses) {
          if (item.course.courseId == widget.courseId) {
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
          initialTab: widget.initialTab,
          highlightAssignmentId: widget.assignmentId,
          highlightQuizId: widget.quizId,
        );
      },
    );
  }
}
