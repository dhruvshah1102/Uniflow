import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import 'student_grades_screen.dart';
import '../../models/attendance.dart';
import '../../models/semester_registration.dart';
import '../../models/quiz_question_model.dart';
import '../../models/quiz_submission_model.dart';
import '../../models/student_dashboard_data.dart';
import '../../providers/auth_provider.dart';
import 'semester_registration_screen.dart';
import 'assignment_details_screen.dart';
import '../../services/student_dashboard_service.dart';
import '../../services/semester_registration_service.dart';
import 'course_detail_screen.dart' as course_detail;


enum _StudentTab {
  courses,
  attendance,
  grades,
  notifications,
  profile,
}

_StudentTab _studentTabFromQuery(String? tab) {
  switch ((tab ?? '').trim().toLowerCase()) {
    case 'courses':
      return _StudentTab.courses;
    case 'attendance':
      return _StudentTab.attendance;
    case 'grades':
      return _StudentTab.grades;
    case 'notifications':
      return _StudentTab.notifications;
    case 'profile':
      return _StudentTab.profile;
    default:
      return _StudentTab.profile;
  }
}

class StudentDashboardScreen extends StatefulWidget {
  final String? initialTab;

  const StudentDashboardScreen({super.key, this.initialTab});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final StudentDashboardService _service = StudentDashboardService.instance;
  Stream<StudentDashboardData>? _stream;
  String? _boundFirebaseUid;
  _StudentTab _tab = _StudentTab.profile;

  @override
  void initState() {
    super.initState();
    _tab = _studentTabFromQuery(widget.initialTab);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureLoaded();
  }

  void _ensureLoaded() {
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) return;
    if (_stream != null && _boundFirebaseUid == firebaseUser.uid) return;
    _boundFirebaseUid = firebaseUser.uid;
    _stream = _service.watchDashboard(
      firebaseUid: firebaseUser.uid,
      user: auth.currentUser!,
      studentProfile: auth.studentProfile,
    );
  }

  Future<void> _reload() async {
    final auth = context.read<AuthProvider>();
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (auth.currentUser == null || firebaseUser == null) return;

    setState(() {
      _boundFirebaseUid = firebaseUser.uid;
      _stream = _service.watchDashboard(
        firebaseUid: firebaseUser.uid,
        user: auth.currentUser!,
        studentProfile: auth.studentProfile,
      );
    });
    await _stream?.first;
  }

  void _logout() {
    context.read<AuthProvider>().logout();
  }

  Future<void> _openRegistrationScreen() async {
    final auth = context.read<AuthProvider>();
    final student = auth.studentProfile;
    if (student == null) return;

    final open = await SemesterRegistrationService.instance.isRegistrationOpen(
      semester: student.semester + 1,
      department: student.department,
    );
    if (!context.mounted) return;

    if (!open) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration is closed right now.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SemesterRegistrationScreen(),
      ),
    );
  }

  String get _title {
    switch (_tab) {
      case _StudentTab.courses:
        return 'Courses';
      case _StudentTab.attendance:
        return 'Attendance';
      case _StudentTab.grades:
        return 'Grades & Transcript';
      case _StudentTab.notifications:
        return 'Notifications';
      case _StudentTab.profile:
        return 'Profile';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.currentUser == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: _logout,
            child: const Text('Sign in again'),
          ),
        ),
      );
    }

    _ensureLoaded();

    return Scaffold(
      backgroundColor: AppColors.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWarm,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.school_outlined, color: AppColors.primaryDark, size: 18),
            ),
            const SizedBox(width: 10),
            const Text(
              'IIITNagpur',
              style: TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.ink700),
            onPressed: _reload,
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined, color: AppColors.ink700),
            onPressed: _logout,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<StudentDashboardData>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _ErrorView(
              message: 'Unable to load dashboard data.',
              details: snapshot.error.toString(),
              onRetry: _reload,
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(
              child: Text('No student dashboard data found.'),
            );
          }

          return _buildSelectedTab(data);
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _tab.index,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryDark,
          unselectedItemColor: AppColors.ink300,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          showUnselectedLabels: true,
          onTap: (index) => setState(() => _tab = _StudentTab.values[index]),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Courses'),
            BottomNavigationBarItem(icon: Icon(Icons.timeline_outlined), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.grade_outlined), label: 'Grades'),
            BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), label: 'Notices'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTab(StudentDashboardData data) {
    switch (_tab) {
      case _StudentTab.courses:
        return _CoursesTab(
          data: data,
          onOpenRegistration: _openRegistrationScreen,
        );
      case _StudentTab.attendance:
        return _AttendanceTab(data: data);
      case _StudentTab.grades:
        return const StudentGradesScreen();
      case _StudentTab.notifications:
        return _NotificationsTab(data: data);
      case _StudentTab.profile:
        return _ProfileTab(
          data: data,
          onLogout: _logout,
          onOpenCourses: () => _switchTab(_StudentTab.courses),
          onOpenRegistration: _openRegistrationScreen,
        );
    }
  }

  void _switchTab(_StudentTab tab) {
    setState(() => _tab = tab);
  }
}

class _DashboardTab extends StatelessWidget {
  final StudentDashboardData data;
  final ValueChanged<_StudentTab> onOpenTab;
  final Future<void> Function() onRefresh;

  const _DashboardTab({
    required this.data,
    required this.onOpenTab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final recentNotifications = data.notifications.take(3).toList();
    final activities = <_ActivityEntry>[
      ...data.attendanceRecords.take(2).map(_ActivityEntry.fromAttendance),
      ...recentNotifications.map(_ActivityEntry.fromNotification),
    ];

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _BrandHeader(
            eyebrow: 'STUDENT PERFORMANCE',
            title: 'Attendance',
            subtitle: 'Track attendance, enrolled courses and the latest academic updates from one place.',
          ),
          const SizedBox(height: 16),
          const _SegmentedBanner(
            leftLabel: 'Current Semester',
          ),
          const SizedBox(height: 16),
          _AttendanceRingCard(
            attendance: data.overallAttendance,
            presentCount: data.attendanceRecords.where((r) => r.present).length,
            absentCount: data.attendanceRecords.where((r) => !r.present).length,
            note: data.overallAttendance >= 75
                ? 'Excellent standings. Keep above 75% to stay eligible for final examinations.'
                : 'Attendance is getting close to the minimum threshold. Keep pushing.',
          ),
          const SizedBox(height: 16),
          _ThresholdCard(
            title: 'Course-wise Threshold',
            subtitle: _courseAttendanceThresholdInfo(data.courses).subtitle,
            progress: _courseAttendanceThresholdInfo(data.courses).progress,
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            eyebrow: 'COURSE BREAKDOWN',
            title: 'Course Breakdown',
            subtitle: 'Subject wise attendance and current risk level.',
          ),
          const SizedBox(height: 8),
          if (data.courses.isEmpty)
            const _EmptyState(message: 'No enrolled courses found yet.')
          else
            ...data.courses.map(
              (course) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseBreakdownCard(course: course),
              ),
            ),
          const SizedBox(height: 12),
          const _SectionHeader(
            eyebrow: 'RECENT ACTIVITY',
            title: 'Recent Activity',
            subtitle: 'Latest attendance and announcement updates.',
          ),
          const SizedBox(height: 12),
          if (activities.isEmpty)
            const _EmptyState(message: 'No recent activity available.')
          else
            _SurfaceCard(
              child: Column(
                children: [
                  for (var i = 0; i < activities.take(4).length; i++) ...[
                    _ActivityTile(entry: activities[i]),
                    if (i != activities.take(4).length - 1)
                      const Divider(height: 1, color: AppColors.border),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 16),
          _SurfaceCard(
            child: Column(
              children: [
                _InfoRow(label: 'Name', value: data.user.name),
                _InfoRow(label: 'Email', value: data.user.email),
                _InfoRow(label: 'Department', value: data.studentProfile?.department ?? '-'),
                _InfoRow(label: 'Semester', value: '${data.studentProfile?.semester ?? '-'}'),
                _InfoRow(
                  label: 'Section',
                  value: data.studentProfile?.section.isNotEmpty == true ? data.studentProfile!.section : '-',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ActionPill(
                label: 'Courses',
                icon: Icons.menu_book_outlined,
                onTap: () => onOpenTab(_StudentTab.courses),
              ),
              _ActionPill(
                label: 'Attendance',
                icon: Icons.check_circle_outline,
                onTap: () => onOpenTab(_StudentTab.attendance),
              ),

              _ActionPill(
                label: 'Notices',
                icon: Icons.campaign_outlined,
                onTap: () => onOpenTab(_StudentTab.notifications),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _BrandHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            letterSpacing: 1.5,
            color: AppColors.primaryDark,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.05,
                color: AppColors.ink900,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.ink500,
            height: 1.4,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

class _SegmentedBanner extends StatelessWidget {
  final String leftLabel;

  const _SegmentedBanner({
    required this.leftLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            leftLabel,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Icon(Icons.schedule_outlined, size: 18, color: AppColors.ink500),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const _SurfaceCard({
    required this.child,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accentColor ?? AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 11,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.ink500, height: 1.35),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(message, style: const TextStyle(color: AppColors.ink500)),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: AppColors.primaryDark),
      label: Text(label),
      backgroundColor: Colors.white,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink700),
      side: const BorderSide(color: AppColors.border),
    );
  }
}

class _AttendanceRingCard extends StatelessWidget {
  final double attendance;
  final int presentCount;
  final int absentCount;
  final String note;

  const _AttendanceRingCard({
    required this.attendance,
    required this.presentCount,
    required this.absentCount,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: (attendance / 100).clamp(0.0, 1.0),
                      strokeWidth: 10,
                      backgroundColor: AppColors.ink100,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${attendance.toStringAsFixed(0)}%',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.ink900),
                      ),
                      const Text(
                        'AGGREGATE',
                        style: TextStyle(
                          color: AppColors.ink500,
                          fontSize: 11,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Excellent Standings',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink900),
          ),
          const SizedBox(height: 8),
          Text(note, style: const TextStyle(color: AppColors.ink500, height: 1.4)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _CountColumn(label: 'Present', value: presentCount.toString())),
              Expanded(child: _CountColumn(label: 'Absent', value: absentCount.toString())),
            ],
          ),
        ],
      ),
    );
  }
}

class _ThresholdCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;

  const _ThresholdCard({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.24),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7EE0D1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceThresholdInfo {
  final String subtitle;
  final double progress;

  const _AttendanceThresholdInfo({
    required this.subtitle,
    required this.progress,
  });
}

_AttendanceThresholdInfo _courseAttendanceThresholdInfo(List<CourseDashboardItem> courses) {
  if (courses.isEmpty) {
    return const _AttendanceThresholdInfo(
      subtitle: 'No enrolled courses yet. Course-wise attendance will appear after classes are recorded.',
      progress: 0,
    );
  }

  CourseDashboardItem? weakest;
  for (final course in courses) {
    if (weakest == null || course.attendancePercentage < weakest.attendancePercentage) {
      weakest = course;
    }
  }

  final weakestCourse = weakest!;
  final needed = _classesNeededToReachTarget(
    presentClasses: weakestCourse.presentClasses,
    totalClasses: weakestCourse.totalClasses,
    targetPercent: 75,
  );

  if (weakestCourse.totalClasses == 0) {
    return _AttendanceThresholdInfo(
      subtitle: '${weakestCourse.course.code} has no attendance yet. Keep it above 75% once classes begin.',
      progress: 0,
    );
  }

  if (weakestCourse.attendancePercentage >= 75) {
    return _AttendanceThresholdInfo(
      subtitle: 'All courses are at or above 75%. Keep every subject above the minimum.',
      progress: 1,
    );
  }

  return _AttendanceThresholdInfo(
    subtitle: '${weakestCourse.course.code} needs $needed more present class${needed == 1 ? '' : 'es'} to reach 75%.',
    progress: (weakestCourse.attendancePercentage / 75).clamp(0.0, 1.0),
  );
}

int _classesNeededToReachTarget({
  required int presentClasses,
  required int totalClasses,
  required int targetPercent,
}) {
  if (targetPercent <= 0) return 0;
  if (totalClasses <= 0) return 0;
  if (presentClasses * 100 >= targetPercent * totalClasses) return 0;

  final numerator = targetPercent * totalClasses - 100 * presentClasses;
  final denominator = 100 - targetPercent;
  return (numerator / denominator).ceil();
}

class _CourseBreakdownCard extends StatelessWidget {
  final CourseDashboardItem course;

  const _CourseBreakdownCard({required this.course});

  Color get _statusColor {
    if (course.attendancePercentage >= 85) return AppColors.success;
    if (course.attendancePercentage >= 75) return AppColors.warning;
    return AppColors.danger;
  }

  String get _statusLabel {
    if (course.attendancePercentage >= 85) return 'Safe';
    if (course.attendancePercentage >= 75) return 'Low Risk';
    return 'Shortage Risk';
  }

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      accentColor: _statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.course.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900)),
                    const SizedBox(height: 4),
                    Text('${course.course.code} • ${course.facultyName}', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
                  ],
                ),
              ),
              _SoftChip(
                label: '${course.attendancePercentage.toStringAsFixed(0)}%',
                color: _statusColor.withOpacity(0.14),
                textColor: _statusColor,
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (course.attendancePercentage / 100).clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: AppColors.ink100,
              valueColor: AlwaysStoppedAnimation(_statusColor),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Lectures: ${course.presentClasses}/${course.totalClasses}', style: const TextStyle(color: AppColors.ink700, fontWeight: FontWeight.w600)),
              Text(_statusLabel, style: TextStyle(color: _statusColor, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallCounter extends StatelessWidget {
  final String title;
  final String value;

  const _SmallCounter({
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceWarm,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.primaryDark, fontSize: 24, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _DeadlineRow extends StatelessWidget {
  final DashboardTaskItem task;

  const _DeadlineRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = DateFormat('dd MMM').format(task.dueDate);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              DateFormat('MMM').format(task.dueDate).toUpperCase(),
              style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w800, fontSize: 10),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(task.assignment.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900)),
              const SizedBox(height: 4),
              Text('${task.courseCode} • Due $due', style: const TextStyle(color: AppColors.ink500)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: AppColors.ink300),
      ],
    );
  }
}

class _CountColumn extends StatelessWidget {
  final String label;
  final String value;

  const _CountColumn({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: const TextStyle(color: AppColors.ink500, fontSize: 11, letterSpacing: 1.1)),
      ],
    );
  }
}

class _ActivityEntry {
  final String title;
  final String subtitle;
  final String trailing;
  final IconData icon;
  final Color color;
  final DateTime date;

  const _ActivityEntry({
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.icon,
    required this.color,
    required this.date,
  });

  factory _ActivityEntry.fromAttendance(AttendanceModel record) {
    return _ActivityEntry(
      title: record.present ? 'Present' : 'Absent',
      subtitle: record.courseId,
      trailing: record.present ? '+1 Lecture' : 'Missed',
      icon: record.present ? Icons.check_circle : Icons.cancel,
      color: record.present ? AppColors.success : AppColors.danger,
      date: record.date.toDate(),
    );
  }

  factory _ActivityEntry.fromNotification(DashboardNotificationItem item) {
    return _ActivityEntry(
      title: item.notification.title,
      subtitle: item.notification.body,
      trailing: item.read ? 'Read' : 'New',
      icon: Icons.notifications_none,
      color: AppColors.primaryDark,
      date: item.createdAt,
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityEntry entry;

  const _ActivityTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('dd MMM, hh:mm a').format(entry.date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: entry.color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(entry.icon, color: entry.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900)),
                const SizedBox(height: 4),
                Text('${entry.subtitle} • $time', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(entry.trailing, style: TextStyle(color: entry.color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _AttendanceActivityRow extends StatelessWidget {
  final AttendanceModel record;

  const _AttendanceActivityRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM, hh:mm a').format(record.date.toDate());
    final isPresent = record.present;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isPresent ? AppColors.success.withOpacity(0.12) : AppColors.danger.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(isPresent ? Icons.check_circle : Icons.cancel, color: isPresent ? AppColors.success : AppColors.danger, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${isPresent ? 'Present' : 'Absent'} • ${record.courseId}',
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900),
                ),
                const SizedBox(height: 4),
                Text(date, style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
              ],
            ),
          ),
          Text(
            isPresent ? '+1 Lecture' : 'Missed',
            style: TextStyle(color: isPresent ? AppColors.success : AppColors.danger, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _OverviewBar extends StatelessWidget {
  final String label;
  final String value;
  final double progress;

  const _OverviewBar({
    required this.label,
    required this.value,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1.2),
              ),
            ),
            Text(value, style: const TextStyle(color: AppColors.ink900, fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: AppColors.ink100,
            valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _SoftChip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primaryDark,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.ink500,
        fontWeight: FontWeight.w700,
      ),
      backgroundColor: AppColors.ink100,
      side: BorderSide.none,
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String name;
  final String department;
  final String avatarText;

  const _IdentityCard({
    required this.name,
    required this.department,
    required this.avatarText,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F6FB),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: AppColors.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    avatarText,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: AppColors.primaryDark),
                  ),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(Icons.verified, size: 12, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SoftChip(
            label: 'STUDENT IDENTITY',
            color: AppColors.success.withOpacity(0.14),
            textColor: AppColors.success,
          ),
          const SizedBox(height: 12),
          Text(name, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.school_outlined, size: 18, color: AppColors.ink700),
              const SizedBox(width: 6),
              Text(department, style: const TextStyle(fontSize: 16, color: AppColors.ink700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SemesterCard extends StatelessWidget {
  final int semester;
  final String academicYear;

  const _SemesterCard({
    required this.semester,
    required this.academicYear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Text(
            'CURRENT SEMESTER',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            semester.toString(),
            style: const TextStyle(fontSize: 56, height: 0.95, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(color: AppColors.success, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 10),
          Text(academicYear, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CourseFeatureCard extends StatelessWidget {
  final CourseDashboardItem course;

  const _CourseFeatureCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      accentColor: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.menu_book_outlined, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _SoftChip(
                        label: '${course.course.code} | SEM ${course.course.semester}',
                        color: AppColors.ink100,
                        textColor: AppColors.ink500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course.course.title,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink900, height: 1.15),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      course.course.description,
                      style: const TextStyle(color: AppColors.ink500, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Faculty', value: course.facultyName)),
              Expanded(child: _StatTile(label: 'Attendance', value: '${course.attendancePercentage.toStringAsFixed(0)}%')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppColors.ink500,
            fontSize: 11,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink900,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _FeaturedTaskCard extends StatelessWidget {
  final DashboardTaskItem task;

  const _FeaturedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = DateFormat('dd MMM, hh:mm a').format(task.dueDate);
    final badgeColor = task.isOverdue ? AppColors.danger : AppColors.warning;

    return _SurfaceCard(
      accentColor: badgeColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SoftChip(
                label: task.isOverdue ? 'CRITICAL PRIORITY' : 'DUE SOON',
                color: badgeColor.withOpacity(0.12),
                textColor: badgeColor,
              ),
              const SizedBox(width: 10),
              Text(
                task.isOverdue ? 'Overdue' : 'Due $due',
                style: TextStyle(color: badgeColor, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${task.courseCode}: ${task.assignment.title}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.ink900),
          ),
          const SizedBox(height: 8),
          Text(
            task.assignment.description,
            style: const TextStyle(color: AppColors.ink500, height: 1.35),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 150,
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AssignmentDetailsScreen(
                      assignment: task.assignment,
                      courseCode: task.courseCode,
                    ),
                  ),
                );
              },
              child: const Text('Start Now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskFeatureCard extends StatelessWidget {
  final DashboardTaskItem task;

  const _TaskFeatureCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = DateFormat('dd MMM, hh:mm a').format(task.dueDate);
    final statusColor = task.isOverdue ? AppColors.danger : AppColors.primaryDark;

    return _SurfaceCard(
      accentColor: statusColor,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AssignmentDetailsScreen(
                assignment: task.assignment,
                courseCode: task.courseCode,
              ),
            ),
          );
        },
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(task.isOverdue ? Icons.warning_amber_outlined : Icons.assignment_outlined, color: statusColor),
        ),
        title: Text(
          task.assignment.title,
          style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${task.courseCode} | Due $due',
            style: const TextStyle(color: AppColors.ink500),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: AppColors.ink300),
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final QuizDashboardItem quiz;
  final QuizSubmissionModel? submission;
  final VoidCallback onStart;

  const _QuizCard({
    required this.quiz,
    required this.submission,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final end = DateFormat('dd MMM, hh:mm a').format(quiz.endTime);
    return _SurfaceCard(
      accentColor: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.quiz_outlined, color: AppColors.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  quiz.quiz.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${quiz.courseCode} | ${quiz.courseTitle}',
            style: const TextStyle(color: AppColors.ink500),
          ),
          const SizedBox(height: 8),
          Text(
            '${quiz.questionCount} questions | ${quiz.quiz.totalMarks} marks | Ends $end',
            style: const TextStyle(color: AppColors.ink700),
          ),
          const SizedBox(height: 6),
          if (submission != null)
            Text(
              'Result: ${submission!.score}/${quiz.quiz.totalMarks}',
              style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(
              onPressed: onStart,
              child: Text(submission == null ? 'Start Quiz' : 'View Result'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialDownloadCard extends StatelessWidget {
  final StudyMaterialDashboardItem material;

  const _MaterialDownloadCard({required this.material});

  @override
  Widget build(BuildContext context) {
    final uploaded = DateFormat('dd MMM, hh:mm a').format(material.uploadedAt);
    return _SurfaceCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.material.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink900),
                ),
                const SizedBox(height: 4),
                Text(
                  '${material.courseCode} | ${material.courseTitle}',
                  style: const TextStyle(color: AppColors.ink500, fontSize: 12),
                ),
                const SizedBox(height: 3),
                Text('Uploaded $uploaded', style: const TextStyle(color: AppColors.ink500, fontSize: 12)),
              ],
            ),
          ),
          const Icon(Icons.open_in_new, color: AppColors.ink300),
        ],
      ),
    );
  }
}

class QuizAttemptScreen extends StatefulWidget {
  final QuizDashboardItem quiz;

  const QuizAttemptScreen({required this.quiz});

  @override
  State<QuizAttemptScreen> createState() => QuizAttemptScreenState();
}

class QuizAttemptScreenState extends State<QuizAttemptScreen> with WidgetsBindingObserver {
  final StudentDashboardService _service = StudentDashboardService.instance;
  final Map<String, String> _answers = {};
  late final Future<List<QuizQuestionModel>> _questionsFuture;
  bool _submitting = false;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    _questionsFuture = _service.fetchQuizQuestions(widget.quiz.quiz.id);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_locked || _submitting) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _submitQuiz(autoSubmitted: true);
    }
  }

  Future<void> _submitQuiz({bool autoSubmitted = false}) async {
    if (_locked || _submitting) return;
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return;
    late final List<QuizQuestionModel> questions;

    setState(() => _submitting = true);
    try {
      questions = await _questionsFuture;
      await _service.submitQuizAttempt(
        quizId: widget.quiz.quiz.id,
        studentId: user.id,
        answers: _answers,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _locked = true;
    });
    final correctCount = questions.where((q) => _answers[q.id]?.trim().toLowerCase() == q.correctAnswer.trim().toLowerCase()).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          autoSubmitted
              ? 'Quiz auto-submitted due to app exit. Correct answers: $correctCount/${questions.length}'
              : 'Quiz submitted. Score saved. Correct answers: $correctCount/${questions.length}',
        ),
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.quiz.quiz.title),
      ),
      body: FutureBuilder<List<QuizQuestionModel>>(
        future: _questionsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString(), textAlign: TextAlign.center));
          }
          final questions = snapshot.data ?? [];
          if (questions.isEmpty) {
            return const Center(child: Text('No quiz questions found.'));
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.quiz.courseTitle, style: const TextStyle(color: AppColors.ink500)),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.quiz.questionCount} questions | ${widget.quiz.quiz.totalMarks} marks',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryDark),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF4B860)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFB85C00)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Warning: if you switch tabs, minimize the app, or lock the screen, this quiz will be auto-submitted.',
                        style: const TextStyle(
                          color: Color(0xFF8A4B00),
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...questions.asMap().entries.map(
                (entry) {
                  final question = entry.value;
                  final options = question.options ?? const <String>[];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SurfaceCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Q${entry.key + 1}. ${question.questionText}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
                          ),
                          const SizedBox(height: 12),
                          ...options.map(
                            (option) => RadioListTile<String>(
                              value: option,
                              groupValue: _answers[question.id],
                              onChanged: _locked ? null : (value) => setState(() => _answers[question.id] = value ?? ''),
                              title: Text(option),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: (_submitting || _locked) ? null : () => _submitQuiz(),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(_locked ? 'Submitted' : (_submitting ? 'Submitting...' : 'Submit Quiz')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatefulWidget {
  final DashboardNotificationItem notification;
  const _AnnouncementCard({required this.notification});

  @override
  State<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends State<_AnnouncementCard> {
  bool _expanded = false;

  Future<String> _routeForNotification() async {
    return _resolveLegacyNoticeRoute(widget.notification);
  }

  String get _actionText {
    switch (widget.notification.notification.type.toLowerCase()) {
      case 'assignment': return 'View Assignment';
      case 'quiz': return 'View Quiz';
      case 'attendance': return 'View Attendance';
      case 'material': return 'View Material';
      default: return 'View Details';
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.notification;
    final time = DateFormat('hh:mm a').format(note.createdAt);
    final date = DateFormat('MMM dd').format(note.createdAt);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: note.read ? Colors.transparent : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: note.read ? Colors.transparent : AppColors.border),
        boxShadow: note.read ? [] : [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: note.read ? AppColors.ink100 : AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _notificationIcon(note.notification.type),
                        size: 20,
                        color: note.read ? AppColors.ink500 : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  note.notification.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: note.read ? FontWeight.w600 : FontWeight.w800,
                                    color: note.read ? AppColors.ink700 : AppColors.ink900,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!note.read) const CircleAvatar(radius: 4, backgroundColor: AppColors.primary),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _expanded ? note.notification.body : note.notification.body.replaceAll('\n', ' '),
                            maxLines: _expanded ? null : 2,
                            overflow: _expanded ? null : TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: note.read ? AppColors.ink500 : AppColors.ink700,
                              height: 1.4,
                            ),
                          ),
                          if (_expanded) ...[
                             const SizedBox(height: 16),
                             Row(
                               children: [
                                 Text('$date at $time', style: const TextStyle(fontSize: 12, color: AppColors.ink300, fontWeight: FontWeight.w600)),
                                 const Spacer(),
                                 FilledButton.tonal(
                                   style: FilledButton.styleFrom(
                                     visualDensity: VisualDensity.compact,
                                     backgroundColor: AppColors.primary.withOpacity(0.1),
                                     foregroundColor: AppColors.primaryDark,
                                   ),
                                   onPressed: () async {
                                      final route = await _routeForNotification();
                                      if (route.isNotEmpty && context.mounted) context.push(route);
                                   },
                                   child: Text(_actionText, style: const TextStyle(fontWeight: FontWeight.w700)),
                                 ),
                               ],
                             )
                          ] else ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(_prettyType(note.notification.type), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primaryLight, letterSpacing: 0.5)),
                                const Spacer(),
                                Text(time, style: const TextStyle(fontSize: 12, color: AppColors.ink300, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

bool _isLegacyGenericDashboardRoute(String route) {
  final normalized = route.trim().toLowerCase();
  return normalized == '/student/dashboard?tab=tasks' ||
      normalized == '/student/dashboard?tab=courses';
}

Future<String?> _recoverCourseIdFromDocument(String collection, String? sourceId) async {
  final id = sourceId?.trim();
  if (id == null || id.isEmpty) return null;
  final snapshot = await FirebaseFirestore.instance.collection(collection).doc(id).get();
  final data = snapshot.data();
  if (data == null) return null;
  final courseId = (data['courseId'] ?? data['course_id'])?.toString().trim();
  if (courseId == null || courseId.isEmpty) return null;
  return courseId;
}

Future<String> _resolveLegacyNoticeRoute(DashboardNotificationItem notificationItem) async {
  final note = notificationItem.notification;
  final explicit = note.route?.trim();
  final courseId = note.courseId?.trim();
  final sourceId = note.sourceId?.trim();
  final assignmentId = note.assignmentId?.trim();
  final quizId = note.quizId?.trim();
  final sourceCollection = note.sourceCollection?.trim().toLowerCase();
  final type = note.type.trim().toLowerCase();

  final resolvedAssignmentId = (assignmentId != null && assignmentId.isNotEmpty) ? assignmentId : sourceId;
  final resolvedQuizId = (quizId != null && quizId.isNotEmpty) ? quizId : sourceId;

  if (explicit != null && explicit.isNotEmpty && !_isLegacyGenericDashboardRoute(explicit)) {
    return explicit;
  }

  if (courseId != null && courseId.isNotEmpty) {
    if ((sourceCollection == 'assignments' || type == 'assignment') &&
        resolvedAssignmentId != null &&
        resolvedAssignmentId.isNotEmpty) {
      return '/student/course/$courseId?tab=assignments&assignmentId=$resolvedAssignmentId';
    }
    if ((sourceCollection == 'quizzes' || type == 'quiz') &&
        resolvedQuizId != null &&
        resolvedQuizId.isNotEmpty) {
      return '/student/course/$courseId?tab=quizzes&quizId=$resolvedQuizId';
    }
    if (sourceCollection == 'materials' || type == 'material') {
      return '/student/course/$courseId?tab=materials&materialId=${sourceId ?? ''}';
    }
  }

  if (sourceCollection == 'assignments' || type == 'assignment') {
    final recoveredCourseId = await _recoverCourseIdFromDocument('assignments', resolvedAssignmentId);
    if (recoveredCourseId != null) {
      return '/student/course/$recoveredCourseId?tab=assignments&assignmentId=${resolvedAssignmentId ?? ''}';
    }
  }

  if (sourceCollection == 'quizzes' || type == 'quiz') {
    final recoveredCourseId = await _recoverCourseIdFromDocument('quizzes', resolvedQuizId);
    if (recoveredCourseId != null) {
      return '/student/course/$recoveredCourseId?tab=quizzes&quizId=${resolvedQuizId ?? ''}';
    }
  }

  if (sourceCollection == 'materials' || type == 'material') {
    final recoveredCourseId = await _recoverCourseIdFromDocument('materials', sourceId);
    if (recoveredCourseId != null) {
      return '/student/course/$recoveredCourseId?tab=materials&materialId=${sourceId ?? ''}';
    }
  }

  switch (type) {
    case 'assignment':
      return '/student/dashboard?tab=notifications';
    case 'quiz':
      return '/student/dashboard?tab=notifications';
    case 'material':
      return '/student/dashboard?tab=notifications';
    case 'attendance':
      return '/student/dashboard?tab=attendance';
    default:
      return '/student/dashboard?tab=notifications';
  }
}


String _prettyType(String type) {
  if (type.isEmpty) {
    return 'General';
  }
  return type[0].toUpperCase() + type.substring(1).toLowerCase();
}

IconData _notificationIcon(String type) {
  switch (type.toLowerCase()) {
    case 'assignment':
      return Icons.assignment_outlined;
    case 'material':
      return Icons.description_outlined;
    case 'attendance':
      return Icons.check_circle_outline;
    case 'quiz':
      return Icons.quiz_outlined;
    default:
      return Icons.notifications_none;
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'S';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
}

class _CoursesTab extends StatelessWidget {
  final StudentDashboardData data;
  final VoidCallback onOpenRegistration;

  const _CoursesTab({
    required this.data,
    required this.onOpenRegistration,
  });

  void _navigateToDetail(BuildContext context, CourseDashboardItem course) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => course_detail.CourseDetailScreen(course: course, data: data),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _SectionHeader(
          eyebrow: 'CURRENT SEMESTER',
          title: 'Courses',
          subtitle: 'Your active enrollments for this semester.',
        ),
        const SizedBox(height: 16),
        if (data.currentCourses.isEmpty)
          const _EmptyState(message: 'No course enrollment found yet.')
        else
          ...data.currentCourses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _navigateToDetail(context, course),
                child: _CourseFeatureCard(course: course),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (data.upcomingCourses.isNotEmpty) ...[
          const _SectionHeader(
            eyebrow: 'UPCOMING SEMESTER',
            title: 'Upcoming Courses',
            subtitle: 'Approved next semester courses.',
          ),
          const SizedBox(height: 12),
          ...data.upcomingCourses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _UpcomingCourseCard(course: course),
            ),
          ),
        ],
      ],
    );
  }
}

class _UpcomingCourseCard extends StatelessWidget {
  final UpcomingCourseDashboardItem course;

  const _UpcomingCourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      accentColor: AppColors.primaryDark.withOpacity(0.16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.course.code,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      course.course.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Upcoming',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Faculty: ${course.facultyName}', style: const TextStyle(color: AppColors.ink700)),
          const SizedBox(height: 4),
          Text('Semester: ${course.course.semester}', style: const TextStyle(color: AppColors.ink500)),
          const SizedBox(height: 4),
          Text('Credits: ${course.course.credits}', style: const TextStyle(color: AppColors.ink500)),
        ],
      ),
    );
  }
}

class _RegistrationStatusCard extends StatelessWidget {
  final SemesterRegistrationRecord? registration;
  final bool registrationOpen;
  final VoidCallback onOpenRegistration;

  const _RegistrationStatusCard({
    required this.registration,
    required this.registrationOpen,
    required this.onOpenRegistration,
  });

  @override
  Widget build(BuildContext context) {
    final status = registration?.status ?? '';
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final isRejected = status == 'rejected';

    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (registration == null || isRejected) ...[
            const Text(
              'Your current semester courses stay unchanged when you register for the next semester.',
              style: TextStyle(color: AppColors.ink700, height: 1.35),
            ),
            if (isRejected) ...[
              const SizedBox(height: 10),
              Text(
                registration?.rejectionReason?.trim().isNotEmpty == true
                    ? 'Previous request was rejected: ${registration!.rejectionReason}'
                    : 'Previous request was rejected. You can submit a fresh registration.',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: registrationOpen ? onOpenRegistration : null,
                icon: const Icon(Icons.event_available_outlined),
                label: Text(registrationOpen ? 'Register for Next Semester' : 'Registration Closed'),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Icon(
                  isApproved ? Icons.verified_outlined : Icons.hourglass_top_rounded,
                  color: isApproved ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isApproved ? 'Registration Submitted / Approved' : 'Registration Submitted',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Target semester: Semester ${registration!.targetSemester}',
              style: const TextStyle(color: AppColors.ink700),
            ),
            const SizedBox(height: 4),
            Text(
              isPending
                  ? 'The request is under review. Current semester courses remain available during approval.'
                  : 'Approved courses are now listed in your active semester courses.',
              style: const TextStyle(color: AppColors.ink500, height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  final StudentDashboardData data;

  const _AttendanceTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _BrandHeader(
          eyebrow: 'STUDENT PERFORMANCE',
          title: 'Attendance',
          subtitle: 'View your attendance position and subject wise standing.',
        ),
        const SizedBox(height: 16),
        const _SegmentedBanner(
          leftLabel: 'Current Semester',
        ),
        const SizedBox(height: 16),
        _AttendanceRingCard(
          attendance: data.overallAttendance,
          presentCount: data.attendanceRecords.where((r) => r.present).length,
          absentCount: data.attendanceRecords.where((r) => !r.present).length,
          note: data.overallAttendance >= 75
              ? 'Excellent standings. Keep above 75% to stay eligible for final examinations.'
              : 'Your attendance needs attention. Try to keep the next few classes strong.',
        ),
        const SizedBox(height: 16),
        _ThresholdCard(
          title: 'Course-wise Threshold',
          subtitle: _courseAttendanceThresholdInfo(data.courses).subtitle,
          progress: _courseAttendanceThresholdInfo(data.courses).progress,
        ),
        const SizedBox(height: 20),
        const _SectionHeader(
          eyebrow: 'COURSE BREAKDOWN',
          title: 'Course Breakdown',
          subtitle: 'Attendance by subject with a simple risk indicator.',
        ),
        const SizedBox(height: 12),
        if (data.courses.isEmpty)
          const _EmptyState(message: 'No attendance data available.')
        else
          ...data.courses.map(
            (course) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CourseBreakdownCard(course: course),
            ),
          ),
        const SizedBox(height: 20),
        const _SectionHeader(
          eyebrow: 'RECENT ACTIVITY',
          title: 'Recent Activity',
          subtitle: 'Latest class records and related updates.',
        ),
        const SizedBox(height: 12),
        _SurfaceCard(
          child: Column(
            children: [
              if (data.attendanceRecords.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('No attendance activity found yet.'),
                )
              else
                ...data.attendanceRecords.take(4).map((record) => _AttendanceActivityRow(record: record)),
            ],
          ),
        ),
      ],
    );
  }
}

class _TasksTab extends StatelessWidget {
  final StudentDashboardData data;

  const _TasksTab({required this.data});

  QuizSubmissionModel? _submissionForQuiz(String quizId) {
    for (final submission in data.quizSubmissions) {
      if (submission.quizId == quizId) return submission;
    }
    return null;
  }

  Future<void> _openQuiz(BuildContext context, QuizDashboardItem quiz) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => QuizAttemptScreen(quiz: quiz),
      ),
    );
  }

  Future<void> _showQuizResult(BuildContext context, QuizDashboardItem quiz, QuizSubmissionModel submission) async {
    final totalMarks = quiz.quiz.totalMarks;
    final percentage = totalMarks <= 0 ? 0.0 : (submission.score / totalMarks) * 100;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quiz.quiz.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('${quiz.courseCode} | ${quiz.courseTitle}', style: const TextStyle(color: AppColors.ink500)),
            const SizedBox(height: 14),
            _SurfaceCard(
              child: Column(
                children: [
                  _InfoRow(label: 'Score', value: '${submission.score}/$totalMarks'),
                  _InfoRow(label: 'Percentage', value: '${percentage.toStringAsFixed(0)}%'),
                  _InfoRow(label: 'Submitted At', value: DateFormat('dd MMM, hh:mm a').format(submission.submittedAt.toDate())),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('You have already submitted this quiz.', style: TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...data.pendingTasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final featured = sorted.isNotEmpty ? sorted.first : null;
    final quizzes = [...data.quizzes]..sort((a, b) => a.endTime.compareTo(b.endTime));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _BrandHeader(
          eyebrow: 'ACADEMIC TASKS',
          title: 'Academic Tasks',
          subtitle: 'Manage quizzes, lab assignments and milestones in one place.',
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: _InfoRow(label: 'Pending tasks', value: '${data.pendingTasks.length}'),
        ),
        const SizedBox(height: 16),
        if (featured != null)
          _FeaturedTaskCard(task: featured)
        else
          const _EmptyState(message: 'No pending assignments or quizzes right now.'),
        const SizedBox(height: 16),
        if (sorted.isNotEmpty)
          ...sorted.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TaskFeatureCard(task: task),
            ),
          ),
        const SizedBox(height: 8),
        const _SectionHeader(
          eyebrow: 'QUIZZES',
          title: 'Available Quizzes',
          subtitle: 'Take active quizzes directly from your account.',
        ),
        const SizedBox(height: 12),
        if (quizzes.isEmpty)
          const _EmptyState(message: 'No quizzes are active right now.')
        else
          ...quizzes.map(
            (quiz) {
              final submission = _submissionForQuiz(quiz.quiz.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _QuizCard(
                  quiz: quiz,
                  submission: submission,
                  onStart: submission == null
                      ? () => _openQuiz(context, quiz)
                      : () => _showQuizResult(context, quiz, submission),
                ),
              );
            },
          ),
        const SizedBox(height: 12),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Task Overview',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
              ),
              const SizedBox(height: 12),
              _OverviewBar(
                label: 'Active Tasks',
                value: data.pendingTasks.length.toString().padLeft(2, '0'),
                progress: (data.pendingTasks.length / 10).clamp(0.0, 1.0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotificationsTab extends StatefulWidget {
  final StudentDashboardData data;
  const _NotificationsTab({required this.data});
  @override
  State<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends State<_NotificationsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    final items = [...widget.data.notifications]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final query = _searchController.text.trim().toLowerCase();
    final filtered = items.where((item) {
      final matchesQuery = query.isEmpty ||
          item.notification.title.toLowerCase().contains(query) ||
          item.notification.body.toLowerCase().contains(query);
      final type = item.notification.type.toLowerCase();
      final matchesFilter = switch (_filter) {
        'all' => true,
        'academic' => type == 'announcement' || type == 'assignment' || type == 'quiz' || type == 'material',
        'assignment' => type == 'assignment',
        'general' => type == 'general' || type == 'announcement',
        _ => type == _filter,
      };
      return matchesQuery && matchesFilter;
    }).toList();

    // Grouping
    final today = <DashboardNotificationItem>[];
    final yesterday = <DashboardNotificationItem>[];
    final earlier = <DashboardNotificationItem>[];

    final now = DateTime.now();
    final yesterdayDate = now.subtract(const Duration(days: 1));

    for (final note in filtered) {
      if (_isSameDay(note.createdAt, now)) {
        today.add(note);
      } else if (_isSameDay(note.createdAt, yesterdayDate)) {
        yesterday.add(note);
      } else {
        earlier.add(note);
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Notices', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _SurfaceCard(
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, color: AppColors.ink300),
                    hintText: 'Search notices...',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterPill(label: 'All Notices', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Academic', selected: _filter == 'academic', onTap: () => setState(() => _filter = 'academic')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'Assignments', selected: _filter == 'assignment', onTap: () => setState(() => _filter = 'assignment')),
                  const SizedBox(width: 8),
                  _FilterPill(label: 'General', selected: _filter == 'general', onTap: () => setState(() => _filter = 'general')),
                ],
              ),
            ),
          ),
          if (filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(child: _EmptyState(message: 'No notices found.')),
            )
          else ...[
            if (today.isNotEmpty) _buildSection('Today', today),
            if (yesterday.isNotEmpty) _buildSection('Yesterday', yesterday),
            if (earlier.isNotEmpty) _buildSection('Earlier', earlier),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ]
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<DashboardNotificationItem> items) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink500, letterSpacing: 1.2)),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AnnouncementCard(notification: items[index - 1]),
            );
          },
          childCount: items.length + 1,
        ),
      ),
    );
  }
}


class _ProfileTab extends StatelessWidget {
  final StudentDashboardData data;
  final VoidCallback onLogout;
  final VoidCallback onOpenCourses;
  final VoidCallback onOpenRegistration;

  const _ProfileTab({
    required this.data,
    required this.onLogout,
    required this.onOpenCourses,
    required this.onOpenRegistration,
  });

  @override
  Widget build(BuildContext context) {
    final student = data.studentProfile;
    final semester = student?.semester ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _BrandHeader(
          eyebrow: 'STUDENT IDENTITY',
          title: 'Profile',
          subtitle: 'Your academic identity and account details.',
        ),
        const SizedBox(height: 16),
        _IdentityCard(
          name: data.user.name,
          department: student?.department ?? 'Student',
          avatarText: _initials(data.user.name),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Academic Credentials',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
              ),
              const SizedBox(height: 12),
              _InfoRow(label: 'Enrollment No', value: student?.enrollmentNo ?? '-'),
              _InfoRow(label: 'Institutional Email', value: data.user.email),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SemesterCard(semester: semester, academicYear: 'Academic Year 2023-24'),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Column(
            children: [
              _InfoRow(label: 'Section', value: student?.section.isNotEmpty == true ? student!.section : '-'),
              _InfoRow(label: 'Department', value: student?.department ?? '-'),
              _InfoRow(label: 'Logged-in Role', value: data.user.role),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Active Courses',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink900),
              ),
              const SizedBox(height: 8),
              Text(
                'You are enrolled in ${data.courses.length} courses this semester.',
                style: const TextStyle(color: AppColors.ink500),
              ),
              const SizedBox(height: 16),
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  onPressed: onOpenCourses,
                  child: const Text('View Courses'),
                ),
              ),
            ],
          ),
        ),
        if (data.registrationOpen || data.nextSemesterRegistration != null) ...[
          const SizedBox(height: 24),
          const _SectionHeader(
            eyebrow: 'REGISTRATION',
            title: 'Next Semester Registration',
            subtitle: 'Submit or track your registration for upcoming academic terms.',
          ),
          const SizedBox(height: 12),
          _RegistrationStatusCard(
            registration: data.nextSemesterRegistration,
            registrationOpen: data.registrationOpen,
            onOpenRegistration: onOpenRegistration,
          ),
          const SizedBox(height: 24),
        ],
        ElevatedButton.icon(
          onPressed: onLogout,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Last sync: ${DateFormat('dd MMM, hh:mm a').format(DateTime.now())}',
            style: const TextStyle(color: AppColors.ink500),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final StudentDashboardData data;

  const _HeroCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final student = data.studentProfile;
    final nextDeadline = data.nextDeadline == null
        ? 'No deadlines'
        : DateFormat('dd MMM').format(data.nextDeadline!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryDark, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello, ${data.user.name}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            data.user.email,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(text: student?.department ?? 'Student'),
              _Pill(text: 'Sem ${student?.semester ?? '-'}'),
              _Pill(text: student?.section.isNotEmpty == true ? 'Section ${student!.section}' : 'Section -'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Attendance',
                  value: '${data.overallAttendance.toStringAsFixed(0)}%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Next deadline',
                  value: nextDeadline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  final CourseDashboardItem course;

  const _AttendanceCard({required this.course});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(course.course.code, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(course.course.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: (course.attendancePercentage / 100).clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AppColors.ink100,
              borderRadius: BorderRadius.circular(999),
            ),
            const SizedBox(height: 10),
            Text(
              '${course.presentClasses}/${course.totalClasses} classes attended  •  ${course.attendancePercentage.toStringAsFixed(0)}%',
              style: const TextStyle(color: AppColors.ink700),
            ),
            const SizedBox(height: 4),
            Text('Faculty: ${course.facultyName}', style: const TextStyle(color: AppColors.ink500)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _CardShell extends StatelessWidget {
  final Widget child;

  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.ink500,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink900,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final CourseDashboardItem course;

  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final next = course.nextDeadline == null
        ? 'No task due'
        : DateFormat('dd MMM').format(course.nextDeadline!);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.course.code,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.course.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text('${course.pendingTaskCount} due'),
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              course.course.description,
              style: const TextStyle(color: AppColors.ink700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TinyStat(
                    label: 'Attendance',
                    value: '${course.attendancePercentage.toStringAsFixed(0)}%',
                  ),
                ),
                Expanded(
                  child: _TinyStat(
                    label: 'Credits',
                    value: '${course.course.credits}',
                  ),
                ),
                Expanded(
                  child: _TinyStat(
                    label: 'Faculty',
                    value: course.facultyName,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TinyStat extends StatelessWidget {
  final String label;
  final String value;

  const _TinyStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppColors.ink500,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink900,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  final DashboardTaskItem task;

  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final due = DateFormat('dd MMM, hh:mm a').format(task.dueDate);
    final soon = task.dueDate.difference(DateTime.now()).inDays <= 2;

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: task.isOverdue
              ? AppColors.danger.withOpacity(0.12)
              : soon
                  ? AppColors.warning.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.12),
          child: Icon(
            task.isOverdue ? Icons.warning_amber_outlined : Icons.edit_note,
            color: task.isOverdue
                ? AppColors.danger
                : soon
                    ? AppColors.warning
                    : AppColors.primary,
          ),
        ),
        title: Text(task.assignment.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('${task.courseCode}  -  Due $due'),
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final DashboardNotificationItem notification;

  const _NotificationCard({required this.notification});

  Future<String> _routeForNotification() async {
    return _resolveLegacyNoticeRoute(notification);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () async {
          final route = await _routeForNotification();
          if (route.isNotEmpty && context.mounted) {
            context.push(route);
          }
        },
        leading: CircleAvatar(
          backgroundColor: notification.read
              ? AppColors.ink100
              : AppColors.primary.withOpacity(0.12),
          child: Icon(
            Icons.notifications_none,
            color: notification.read ? AppColors.ink500 : AppColors.primary,
          ),
        ),
        title: Text(notification.notification.title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(notification.notification.body),
        ),
        trailing: notification.read
            ? null
            : const CircleAvatar(
                radius: 5,
                backgroundColor: AppColors.primary,
              ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;

  const _Pill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: AppColors.primary),
      label: Text(label),
      side: BorderSide.none,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String details;
  final Future<void> Function() onRetry;

  const _ErrorView({
    required this.message,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              details,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink500),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

